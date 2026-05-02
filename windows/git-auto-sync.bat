@echo off
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"
set "REPO_LIST=%ROOT_DIR%\repos.txt"
set "LOG_FILE=%ROOT_DIR%\git-auto-sync.log"
set "RECENT_LOG=%ROOT_DIR%\git-auto-sync-recent.log"
set "TMP_LOG=%ROOT_DIR%\git-auto-sync.tmp"
set "CONFIG_FILE=%ROOT_DIR%\config.txt"

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
start notepad "%REPO_LIST%"
echo Set ws = CreateObject("WScript.Shell")> "%TEMP%\git-sync-prompt.vbs"
echo ws.Popup "repos.txt created. Please fill in your repo paths, then run sync again.", 0, "Git Auto Sync", 64>> "%TEMP%\git-sync-prompt.vbs"
cscript //nologo "%TEMP%\git-sync-prompt.vbs"
del "%TEMP%\git-sync-prompt.vbs" >nul 2>&1
exit /b 0

:main_loop
:: Read config (re-read every cycle)
set "INTERVAL=10"
set "KEEP_RECENT=5"
for /f "tokens=2 delims==" %%a in ('findstr /b "INTERVAL=" "%CONFIG_FILE%"') do set "INTERVAL=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /b "KEEP_RECENT=" "%CONFIG_FILE%"') do set "KEEP_RECENT=%%a"
set /a INTERVAL_S=INTERVAL*60

:: Truncate temp file
echo. > "%TMP_LOG%" 2>nul

call :log "=== Sync started ==="

if not exist "%REPO_LIST%" (
    call :log "ERROR repos.txt not found"
    goto :sync_done
)

for /f "usebackq tokens=* delims=" %%R in ("%REPO_LIST%") do (
    call :sync_repo "%%R"
)

:sync_done
call :log "=== Sync finished ==="
call :log "Next sync in %INTERVAL% minutes"

:: Prepend new log to main log (full history), with UTF-8 BOM
powershell -NoProfile -Command ^
    "$new=[IO.File]::ReadAllText('%TMP_LOG%',[Text.Encoding]::UTF8);" ^
    "$old=''; if(Test-Path '%LOG_FILE%'){$old=[IO.File]::ReadAllText('%LOG_FILE%',[Text.Encoding]::UTF8)};" ^
    "[IO.File]::WriteAllText('%LOG_FILE%',([char]239+[char]187+[char]191)+$new+$old,(New-Object Text.UTF8Encoding $false))" >nul 2>&1

:: Prepend new log to recent log, then truncate to KEEP_RECENT cycles
powershell -NoProfile -Command ^
    "$new=[IO.File]::ReadAllText('%TMP_LOG%',[Text.Encoding]::UTF8);" ^
    "$rl='%RECENT_LOG%';$k=%KEEP_RECENT%;" ^
    "$c=$new;" ^
    "if(Test-Path $rl){$c=$c+[IO.File]::ReadAllText($rl,[Text.Encoding]::UTF8)};" ^
    "$m=[regex]::Matches($c,'\[.*?\] === Sync started ===');" ^
    "if($m.Count -gt $k){$c=$c.Substring(0,$m[$k].Index)};" ^
    "[IO.File]::WriteAllText($rl,([char]239+[char]187+[char]191)+$c,(New-Object Text.UTF8Encoding $false));" ^
    "Remove-Item '%TMP_LOG%' -Force" >nul 2>&1

:: Sleep and loop
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

call :log "Syncing %REPO%"

pushd "%REPO%"

git add -A 2>> "%TMP_LOG%"

git diff --cached --quiet 2>nul
if errorlevel 1 (
    git commit -m "auto sync %date:/=-% %time:~0,5%" >> "%TMP_LOG%" 2>&1
    call :log "  Committed"
) else (
    call :log "  Nothing to commit"
)

git pull --rebase --autostash >> "%TMP_LOG%" 2>&1

git push >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
    call :log "  ERROR Push failed"
) else (
    call :log "  Pushed"
)

popd
goto :eof
