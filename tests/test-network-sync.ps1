param([string]$HelperPath = (Join-Path $PSScriptRoot '..\windows\git-network-sync.ps1'))
$ErrorActionPreference = 'Stop'
. $HelperPath

function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ($Actual -ne $Expected) { throw "$Label expected '$Expected', got '$Actual'" }
}

$nativeInvoke = ${function:Invoke-SyncGit}
$nativeListener = ${function:Test-SyncProxyListening}
$scenarios = @(
    @{ Name='direct'; Code=0; Pulls=1; Pushes=1; ProxyCalls=0 },
    @{ Name='proxy'; Code=0; Pulls=1; Pushes=1; ProxyCalls=3 },
    @{ Name='offline'; Code=1; Pulls=0; Pushes=0; ProxyCalls=0 },
    @{ Name='proxy-fails'; Code=1; Pulls=0; Pushes=0; ProxyCalls=1 },
    @{ Name='auth'; Code=1; Pulls=0; Pushes=0; ProxyCalls=0 },
    @{ Name='certificate'; Code=1; Pulls=0; Pushes=0; ProxyCalls=0 },
    @{ Name='rate-limit'; Code=1; Pulls=0; Pushes=0; ProxyCalls=0 },
    @{ Name='pull-conflict'; Code=2; Pulls=1; Pushes=0; ProxyCalls=0 },
    @{ Name='pull-network'; Code=0; Pulls=2; Pushes=1; ProxyCalls=3 },
    @{ Name='push-ambiguous'; Code=3; Pulls=1; Pushes=1; ProxyCalls=0 },
    @{ Name='probe-only'; Code=0; Pulls=0; Pushes=0; ProxyCalls=0 }
)

function Invoke-SyncGit {
    param([string[]]$GitArguments, [string]$Proxy='', [int]$TimeoutSeconds=180)
    $script:Calls += [pscustomobject]@{ Command=$GitArguments[0]; Proxy=$Proxy }
    $code=0; $message=''
    switch ($GitArguments[0]) {
        'symbolic-ref' { $message='main' }
        'remote' { $message='https://example.invalid/repository.git' }
        'config' {
            if ($GitArguments[-1] -eq 'branch.main.remote') { $message='origin' }
            elseif ($GitArguments[1] -eq '--get-urlmatch') { $message='http://127.0.0.1:18080' }
            else { $code=1 }
        }
        'ls-remote' {
            if (!$Proxy) {
                switch ($script:Scenario.Name) {
                    { $_ -in @('proxy','offline','proxy-fails') } { $code=128; $message='fatal: Failed to connect to github.com: Connection timed out' }
                    'auth' { $code=128; $message='fatal: Authentication failed' }
                    'certificate' { $code=128; $message='fatal: SSL certificate problem: unable to get local issuer certificate' }
                    'rate-limit' { $code=128; $message='fatal: The requested URL returned error: 429' }
                }
            } elseif ($script:Scenario.Name -eq 'proxy-fails') { $code=128; $message='fatal: Failed to connect to proxy' }
        }
        'pull' {
            if ($script:Scenario.Name -eq 'pull-conflict') { $code=1; $message='CONFLICT: Resolve all conflicts manually' }
            elseif ($script:Scenario.Name -eq 'pull-network' -and !$Proxy) { $code=128; $message='fatal: Connection reset by peer' }
        }
        'push' {
            if ($script:Scenario.Name -eq 'push-ambiguous') { $code=128; $message='fatal: Send failure: Connection reset by peer' }
        }
        default { throw "Unexpected Git command: $($GitArguments -join ' ')" }
    }
    return [pscustomobject]@{ ExitCode=$code; Text=$message }
}
function Test-SyncProxyListening([string]$Proxy) { return $script:Scenario.Name -ne 'offline' }

$passed=0
try {
    foreach ($scenario in $scenarios) {
        $script:Scenario=$scenario
        $script:Calls=@()
        $result=Invoke-GitNetworkSync -RepoPath $PSScriptRoot -OnlyProbe:($scenario.Name -eq 'probe-only')
        Assert-Equal $result $scenario.Code "$($scenario.Name): exit code"
        Assert-Equal @($script:Calls | Where-Object Command -eq 'pull').Count $scenario.Pulls "$($scenario.Name): pull count"
        Assert-Equal @($script:Calls | Where-Object Command -eq 'push').Count $scenario.Pushes "$($scenario.Name): push count"
        Assert-Equal @($script:Calls | Where-Object { $_.Proxy }).Count $scenario.ProxyCalls "$($scenario.Name): proxy calls"
        if ($scenario.Name -eq 'push-ambiguous') {
            Assert-Equal $script:Calls[-1].Command 'ls-remote' 'push failure: verify remote before retry'
        }
        $passed++
        [Console]::WriteLine("PASS $($scenario.Name)")
    }
} finally {
    ${function:Invoke-SyncGit}=$nativeInvoke
    ${function:Test-SyncProxyListening}=$nativeListener
}
[Console]::WriteLine("Passed $passed network behavior checks.")
