param(
    [string]$Repository = (Get-Location).Path,
    [switch]$ProbeOnly
)

# This script runs in its own process. Proxy overrides never leave its children.
$ErrorActionPreference = 'Stop'

function Write-SyncMessage([string]$Message) {
    $safe = $Message -replace '(?i)(https?://)[^/\s@]+@', '$1[redacted]@'
    [Console]::WriteLine($safe)
}

function ConvertTo-ProcessArgument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    return '"' + (($Value -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}

function Invoke-SyncGit {
    param([string[]]$GitArguments, [string]$Proxy = '', [int]$TimeoutSeconds = 180)
    $options = @('-c', 'credential.interactive=false', '-c', 'http.lowSpeedLimit=1',
        '-c', 'http.lowSpeedTime=20')
    if ($GitArguments[0] -ne 'config') {
        $options += @('-c', "http.proxy=$Proxy", '-c', "https.proxy=$Proxy")
        foreach ($remoteName in $script:RemoteNames) {
            $options += @('-c', "remote.$remoteName.proxy=$Proxy")
        }
    }
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $script:GitExecutable
    $start.WorkingDirectory = $script:RepositoryPath
    $start.Arguments = (($options + $GitArguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ')
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.Encoding]::UTF8
    $start.StandardErrorEncoding = [Text.Encoding]::UTF8
    foreach ($key in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
        $start.EnvironmentVariables[$key] = $Proxy
    }
    $start.EnvironmentVariables['NO_PROXY'] = $(if ($Proxy) { '' } else { '*' })
    $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $start.EnvironmentVariables['GCM_INTERACTIVE'] = 'Never'
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timedOut = !$process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            $killer = Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/PID', [string]$process.Id, '/T', '/F') -WindowStyle Hidden -Wait -PassThru
            if (!$process.WaitForExit(5000)) { throw 'Could not stop the timed-out Git process.' }
        }
        $process.WaitForExit()
        $output = ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()).Trim()
        $code = $process.ExitCode
        if ($timedOut) { $code = 124; $output += "`nGIT_TIMEOUT after $TimeoutSeconds seconds" }
        return [pscustomobject]@{ ExitCode = $code; Text = $output }
    } finally {
        $process.Dispose()
    }
}

function Test-SyncNetworkFailure($Result) {
    if ($Result.Text -match '(?i)Authentication failed|could not read Username|returned error: (401|403|404|429)|certificate problem|certificate verification failed') { return $false }
    return $Result.Text -match '(?i)GIT_TIMEOUT|Could not resolve|Failed to connect|Couldn.t connect|Connection (timed out|reset|refused)|Operation (timed out|too slow)|SSL_ERROR_SYSCALL|TLS.*(handshake|connection)|Empty reply|Recv failure|Send failure|HTTP/2 stream.*(closed|error)|remote end hung up'
}

function Get-SyncProxyCandidates([string]$Remote, [string]$Url) {
    $values = @()
    foreach ($configArguments in @(
        @('config', '--get', "remote.$Remote.proxy"),
        @('config', '--get-urlmatch', 'http.proxy', $Url),
        @('config', '--get', 'https.proxy')
    )) {
        $config = Invoke-SyncGit -GitArguments $configArguments
        if ($config.ExitCode -eq 0 -and $config.Text) { $values += $config.Text }
    }
    $values += @($env:HTTPS_PROXY, $env:HTTP_PROXY, $env:ALL_PROXY)
    return @($values | Where-Object { $_ -and $_.Trim() } | Select-Object -Unique)
}

function Test-SyncProxyListening([string]$Proxy) {
    $address = $null
    if (![Uri]::TryCreate($Proxy, [UriKind]::Absolute, [ref]$address) -or $address.Scheme -notin @('http','https','socks4','socks4a','socks5','socks5h')) { return $false }
    if (!$address.IsLoopback) { return $true }
    $client = New-Object Net.Sockets.TcpClient
    try {
        $port = $address.Port
        if ($port -lt 1) { $port = 1080 }
        $connection = $client.ConnectAsync($address.Host, $port)
        return ($connection.Wait(800) -and $client.Connected)
    } catch { return $false } finally { $client.Dispose() }
}

function Find-SyncProxyRoute([string[]]$Candidates, [string]$Remote) {
    foreach ($candidate in $Candidates) {
        if (!(Test-SyncProxyListening $candidate)) {
            Write-SyncMessage '  [network] Configured proxy is not listening; skipped'
            continue
        }
        $probe = Invoke-SyncGit -GitArguments @('ls-remote', '--heads', $Remote) -Proxy $candidate -TimeoutSeconds 15
        if ($probe.ExitCode -eq 0) { return [pscustomobject]@{ Proxy = $candidate; Name = 'PROXY' } }
        Write-SyncMessage $probe.Text
        if (!(Test-SyncNetworkFailure $probe)) { break }
    }
    return $null
}

function Invoke-SyncPull([string]$Proxy) {
    # Avoid rewriting local merge history or stashing live files when already current.
    $result = Invoke-SyncGit -GitArguments @('pull', '--no-rebase', '--ff-only', '--no-autostash') -Proxy $Proxy
    if ($result.ExitCode -ne 0 -and $result.Text -match '(?i)Not possible to fast-forward|Diverging branches can.t be fast-forwarded') {
        Write-SyncMessage '  [sync] Histories diverged; rebasing local commits'
        return Invoke-SyncGit -GitArguments @('pull', '--rebase', '--autostash') -Proxy $Proxy
    }
    return $result
}

function Invoke-GitNetworkSync {
    param([string]$RepoPath, [switch]$OnlyProbe)
    $script:RepositoryPath = [IO.Path]::GetFullPath($RepoPath)
    $script:GitExecutable = (Get-Command git.exe -ErrorAction Stop).Source
    $script:RemoteNames = @()
    $branch = Invoke-SyncGit -GitArguments @('symbolic-ref', '--short', 'HEAD')
    if ($branch.ExitCode -ne 0) { Write-SyncMessage $branch.Text; return 1 }
    $remoteResult = Invoke-SyncGit -GitArguments @('config', '--get', "branch.$($branch.Text).remote")
    $remote = 'origin'
    if ($remoteResult.ExitCode -eq 0 -and $remoteResult.Text) { $remote = $remoteResult.Text }
    $pushRemoteResult = Invoke-SyncGit -GitArguments @('config', '--get', "branch.$($branch.Text).pushRemote")
    if ($pushRemoteResult.ExitCode -ne 0) { $pushRemoteResult = Invoke-SyncGit -GitArguments @('config', '--get', 'remote.pushDefault') }
    $pushRemote = $remote
    if ($pushRemoteResult.ExitCode -eq 0 -and $pushRemoteResult.Text) { $pushRemote = $pushRemoteResult.Text }
    $url = Invoke-SyncGit -GitArguments @('remote', 'get-url', $remote)
    if ($url.ExitCode -ne 0) { Write-SyncMessage $url.Text; return 1 }
    # Read configured proxies before applying per-command remote overrides.
    $candidates = @(Get-SyncProxyCandidates -Remote $remote -Url $url.Text)
    $script:RemoteNames = @($remote, $pushRemote) | Select-Object -Unique
    $route = [pscustomobject]@{ Proxy = ''; Name = 'DIRECT' }
    $probe = Invoke-SyncGit -GitArguments @('ls-remote', '--heads', $remote) -TimeoutSeconds 15
    if ($probe.ExitCode -ne 0) {
        Write-SyncMessage '  [network] DIRECT probe failed'
        Write-SyncMessage $probe.Text
        if (!(Test-SyncNetworkFailure $probe)) { return 1 }
        $route = Find-SyncProxyRoute -Candidates $candidates -Remote $remote
        if (!$route) { Write-SyncMessage '  [network] ERROR No working route; will retry next cycle'; return 1 }
    }
    Write-SyncMessage "  [network] $($route.Name) selected for this sync only"
    if ($OnlyProbe) { return 0 }
    $pull = Invoke-SyncPull -Proxy $route.Proxy
    if ($pull.Text) { Write-SyncMessage $pull.Text }
    if ($pull.ExitCode -ne 0 -and $route.Name -eq 'DIRECT' -and (Test-SyncNetworkFailure $pull)) {
        $fallback = Find-SyncProxyRoute -Candidates $candidates -Remote $remote
        if ($fallback) {
            $route = $fallback
            Write-SyncMessage '  [network] Retrying pull once through the configured proxy'
            $pull = Invoke-SyncPull -Proxy $route.Proxy
            if ($pull.Text) { Write-SyncMessage $pull.Text }
        }
    }
    if ($pull.ExitCode -ne 0) { Write-SyncMessage '  ERROR Pull failed; push skipped'; return 2 }
    $push = Invoke-SyncGit -GitArguments @('push') -Proxy $route.Proxy
    if ($push.Text) { Write-SyncMessage $push.Text }
    if ($push.ExitCode -ne 0) {
        # A failed upload can already have reached the server. Never blindly retry it.
        if (Test-SyncNetworkFailure $push) {
            $state = Invoke-SyncGit -GitArguments @('ls-remote', '--heads', $pushRemote) -Proxy $route.Proxy -TimeoutSeconds 15
            if ($state.ExitCode -eq 0) { Write-SyncMessage '  [network] Remote state checked; next cycle will pull before any new push' }
        }
        Write-SyncMessage '  ERROR Push failed; no immediate upload retry'
        return 3
    }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    try { exit (Invoke-GitNetworkSync -RepoPath $Repository -OnlyProbe:$ProbeOnly) }
    catch { Write-SyncMessage ('  ERROR Network sync: ' + $_.Exception.Message); exit 1 }
}
