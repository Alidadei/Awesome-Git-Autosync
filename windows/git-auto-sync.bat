@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"
set "REPO_LIST=%ROOT_DIR%\config\repos.txt"
set "BRANCHES_FILE=%ROOT_DIR%\config\branches.txt"
set "LOG_FILE=%ROOT_DIR%\logs\git-auto-sync.log"
set "RECENT_LOG=%ROOT_DIR%\logs\git-auto-sync-recent.log"
set "TMP_LOG=%TEMP%\git-auto-sync.tmp"
set "CONFIG_FILE=%ROOT_DIR%\config\sync-settings.txt"

:: Ensure directories exist
if not exist "%ROOT_DIR%\logs" mkdir "%ROOT_DIR%\logs"
if not exist "%ROOT_DIR%\config" mkdir "%ROOT_DIR%\config"

:: Prevent duplicate instances — count all cmd.exe running this script
powershell -NoProfile -Command "$n=(Get-WmiObject Win32_Process -Filter \"Name='cmd.exe' AND CommandLine LIKE '%%git-auto-sync.bat%%'\" | Measure-Object).Count; if($n -gt 1){exit 1}else{exit 0}"
if errorlevel 1 exit /b 0

:: Auto-create repos.txt if missing
if not exist "%REPO_LIST%" goto :create_repos
goto :main_loop

:create_repos
echo # 每行填写一个git仓库的绝对路径 / Put one git repo absolute path per line> "%REPO_LIST%"
echo # 以 # 开头的行为注释，该仓库将暂停同步 / Lines starting with # are paused>> "%REPO_LIST%"
echo # 示例 / Example:>> "%REPO_LIST%"
echo # C:\Users\username\my-project>> "%REPO_LIST%"
echo # ===========================================================================================================>> "%REPO_LIST%"
echo.>> "%REPO_LIST%"
start /wait notepad "%REPO_LIST%"
goto :main_loop

:generate_branches
echo # 分支配置 / Branch configuration for Git Auto Sync> "%BRANCHES_FILE%"
echo # 每行格式：仓库名 分支名。默认同步 master>> "%BRANCHES_FILE%"
echo # 切换分支：注释当前行，取消注释目标行（每个仓库仅一行生效）>> "%BRANCHES_FILE%"
echo # ===========================================================================================================>> "%BRANCHES_FILE%"
echo.>> "%BRANCHES_FILE%"
for /f "usebackq tokens=* delims=" %%R in ("%REPO_LIST%") do call :gen_branch_line "%%R"
start /wait notepad "%BRANCHES_FILE%"
goto :main_loop

:gen_branch_line
set "GP=%~1"
if "%GP%"=="" goto :eof
echo %GP% | findstr /b "#" >nul
if not errorlevel 1 goto :eof
if not exist "%GP%\.git" goto :eof
for %%I in ("%GP%.") do set "GP_SHORT=%%~nxI"
pushd "%GP%"

:: Build header: # repo_name ：branch1；branch2
set "BLIST="
for /f "tokens=1,2" %%a in ('git branch --list 2^>nul') do call :add_branch "%%a" "%%b"
echo # %GP_SHORT% ：%BLIST%>> "%BRANCHES_FILE%"

:: Detect default branch
for /f "tokens=*" %%b in ('git symbolic-ref --short HEAD 2^>nul') do set "DEFAULT_BRANCH=%%b"
if "%DEFAULT_BRANCH%"=="" set "DEFAULT_BRANCH=master"

:: Active branch (detected default)
echo %GP_SHORT% %DEFAULT_BRANCH%>> "%BRANCHES_FILE%"

:: Other branches as commented
for /f "tokens=1,2" %%a in ('git branch --list 2^>nul') do (
    if "%%a"=="*" (
        if /i not "%%b"=="%DEFAULT_BRANCH%" echo #%GP_SHORT% %%b>> "%BRANCHES_FILE%"
    ) else (
        if /i not "%%a"=="%DEFAULT_BRANCH%" echo #%GP_SHORT% %%a>> "%BRANCHES_FILE%"
    )
)
echo.>> "%BRANCHES_FILE%"
popd
goto :eof

:add_branch
if "%~1"=="*" (
    set "BLIST=%BLIST%%~2；"
) else (
    set "BLIST=%BLIST%%~1；"
)
goto :eof

:main_loop
:: Read config (re-read every cycle)
set "INTERVAL=10"
set "KEEP_RECENT=5"
for /f "tokens=2 delims==" %%a in ('findstr /b "INTERVAL=" "%CONFIG_FILE%"') do set "INTERVAL=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /b "KEEP_RECENT=" "%CONFIG_FILE%"') do set "KEEP_RECENT=%%a"
set /a INTERVAL_S=INTERVAL*60

:: Auto-generate branches.txt if needed
if exist "%BRANCHES_FILE%" goto :skip_gen_branches
set "HAS_REPOS="
for /f "tokens=* delims=" %%R in ('findstr /v /b /c:"#" "%REPO_LIST%"') do set "HAS_REPOS=1"
if not "!HAS_REPOS!"=="1" goto :skip_gen_branches
goto :generate_branches
:skip_gen_branches

:: Append branches for new repos not yet in branches.txt (single PS call for UTF-8 safe matching)
set "NEW_REPOS_FILE=%TEMP%\git-sync-new-repos.tmp"
if exist "%BRANCHES_FILE%" (
    powershell -NoProfile -Command ^
        "$bl=[IO.File]::ReadAllLines('%BRANCHES_FILE%',[Text.Encoding]::UTF8);" ^
        "foreach($line in [IO.File]::ReadAllLines('%REPO_LIST%',[Text.Encoding]::UTF8)){" ^
        "  if($line-match'^\s*#'-or$line-match'^\s*$'){continue};" ^
        "  $p=$line.Trim();if(!(Test-Path \"$p\.git\")){continue};" ^
        "  $s=Split-Path $p -Leaf;" ^
        "  $found=$false;foreach($b in $bl){if($b-match('^'+[regex]::Escape($s)+'\s')-or$b-match('^'+[regex]::Escape($p)+'\s')){$found=$true;break}};" ^
        "  if(!$found){$p}" ^
        "}" > "%NEW_REPOS_FILE%" 2>nul
    for /f "usebackq tokens=* delims=" %%R in ("%NEW_REPOS_FILE%") do (
        call :gen_branch_line "%%R"
        echo.>> "%BRANCHES_FILE%"
    )
    del "%NEW_REPOS_FILE%" 2>nul
)

:: Truncate temp file
echo. > "%TMP_LOG%" 2>nul

call :log "============================ Sync started ==="

if not exist "%REPO_LIST%" (
    call :log "ERROR repos.txt not found"
    goto :sync_done
)

for /f "usebackq tokens=* delims=" %%R in ("%REPO_LIST%") do (
    call :sync_repo "%%R"
)

:sync_done
call :log "============================ Sync finished ==="
call :log "Next sync in %INTERVAL% minutes"

:: Prepend new log to main log (full history), with UTF-8 BOM
powershell -NoProfile -Command ^
    "$new=[IO.File]::ReadAllText('%TMP_LOG%',[Text.Encoding]::UTF8);" ^
    "$old=''; if(Test-Path '%LOG_FILE%'){$old=[IO.File]::ReadAllText('%LOG_FILE%',[Text.Encoding]::UTF8)};" ^
    "[IO.File]::WriteAllText('%LOG_FILE%',$new+$old,(New-Object Text.UTF8Encoding $true))" >nul 2>&1

:: Prepend new log to recent log, then truncate to KEEP_RECENT cycles
powershell -NoProfile -Command ^
    "$new=[IO.File]::ReadAllText('%TMP_LOG%',[Text.Encoding]::UTF8);" ^
    "$rl='%RECENT_LOG%';$k=%KEEP_RECENT%;" ^
    "$c=$new;" ^
    "if(Test-Path $rl){$c=$c+[IO.File]::ReadAllText($rl,[Text.Encoding]::UTF8)};" ^
    "$m=[regex]::Matches($c,'\[.*?\] =+ Sync started =+');" ^
    "if($m.Count -gt $k){$c=$c.Substring(0,$m[$k].Index)};" ^
    "[IO.File]::WriteAllText($rl,$c,(New-Object Text.UTF8Encoding $true));" ^
    "Remove-Item '%TMP_LOG%' -Force" >nul 2>&1

:: Sleep and loop
if /i "%~1"=="--once" exit /b 0
timeout /t %INTERVAL_S% >nul 2>&1
goto :main_loop

:: === Subroutines ===

:log
echo [%date% %time:~0,8%] %~1 >> "%TMP_LOG%"
goto :eof

:sync_repo
set "REPO=%~1"

if "%REPO%"=="" goto :eof
echo %REPO% | findstr /b "#" >nul
if not errorlevel 1 goto :eof

if not exist "%REPO%\.git" (
    call :log "SKIP %REPO% not a git repo"
    goto :eof
)

call :log "Syncing %REPO% ==="

pushd "%REPO%"

:: Preserve repositories with an unfinished Git operation or an active index lock.
for %%S in (rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD index.lock) do (
    for /f "tokens=*" %%P in ('git rev-parse --git-path %%S 2^>nul') do (
        if exist "%%P" (
            call :log "SKIP %REPO% unfinished Git operation or lock: %%S"
            popd
            goto :eof
        )
    )
)

:: Collect target branches (PowerShell for UTF-8 safe matching)
for %%I in ("%REPO%.") do set "REPO_SHORT=%%~nxI"
set "BRANCH_FOUND=0"
if exist "%BRANCHES_FILE%" (
    set "BRANCH_MATCH=%TEMP%\git-sync-branch.tmp"
    powershell -NoProfile -Command ^
        "$bl=[IO.File]::ReadAllLines('%BRANCHES_FILE%',[Text.Encoding]::UTF8);" ^
        "$s=$env:REPO_SHORT;$p=$env:REPO;" ^
        "foreach($b in $bl){if($b-match('^'+[regex]::Escape($s)+'\s+(.+)$')-or$b-match('^'+[regex]::Escape($p)+'\s+(.+)$')){$Matches[1].Trim()}}" > "!BRANCH_MATCH!" 2>nul
    for /f "usebackq tokens=*" %%b in ("!BRANCH_MATCH!") do (
        call :do_sync "%%b"
        set "BRANCH_FOUND=1"
    )
    del "!BRANCH_MATCH!" 2>nul
)
if "!BRANCH_FOUND!"=="0" (
    for /f "tokens=*" %%b in ('git symbolic-ref --short HEAD 2^>nul') do (
        call :do_sync "%%b"
        set "BRANCH_FOUND=1"
    )
)
if "!BRANCH_FOUND!"=="0" call :log "SKIP %REPO% unable to detect branch"

popd
goto :eof

:do_sync
set "BRANCH=%~1"

:: Branch checkout
set "CURRENT_BRANCH="
for /f "tokens=*" %%b in ('git symbolic-ref --short HEAD 2^>nul') do set "CURRENT_BRANCH=%%b"
if not "%BRANCH%"=="%CURRENT_BRANCH%" (
    git checkout "%BRANCH%" >> "%TMP_LOG%" 2>&1
    if errorlevel 1 (
        call :log "  [%BRANCH%] ERROR checkout failed"
        goto :eof
    )
    call :log "  [%BRANCH%] Switched"
) else (
    call :log "  [%BRANCH%]"
)

git add -A 2>> "%TMP_LOG%"
if errorlevel 1 (
    call :log "  [%BRANCH%] ERROR Staging failed; sync skipped"
    goto :eof
)

git diff --cached --quiet 2>> "%TMP_LOG%"
if errorlevel 2 (
    call :log "  [%BRANCH%] ERROR Unable to inspect staged changes; sync skipped"
    goto :eof
)
if errorlevel 1 (
    git commit -m "auto sync %date:/=-% %time:~0,5%" >> "%TMP_LOG%" 2>&1
    if errorlevel 1 (
        call :log "  [%BRANCH%] ERROR Commit failed; sync skipped"
        goto :eof
    )
    call :log "  [%BRANCH%] Committed"
) else (
    call :log "  [%BRANCH%] Nothing to commit"
)

:: Some repositories publish filtered mirrors through their own post-commit hook.
for /f "tokens=*" %%M in ('git config --get autosync.mode 2^>nul') do (
    if /i "%%M"=="commit-only" (
        call :log "  [%BRANCH%] Local save complete; repository hook manages mirror push"
        goto :eof
    )
)

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPT_DIR%git-network-sync.ps1" -Repository "%REPO%" >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
    call :log "  [%BRANCH%] ERROR Network sync failed; see the preceding error"
) else (
    call :log "  [%BRANCH%] Pushed"
)
goto :eof
