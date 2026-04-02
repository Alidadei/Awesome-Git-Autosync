@echo off

set "SCRIPT_DIR=%~dp0"
set "REPO_LIST=%SCRIPT_DIR%repos.txt"
set "LOG_FILE=%SCRIPT_DIR%git-auto-sync.log"

echo [%date% %time:~0,8%] Sync started >> "%LOG_FILE%"

if not exist "%REPO_LIST%" (
    echo [%date% %time:~0,8%] ERROR repos.txt not found >> "%LOG_FILE%"
    exit /b 1
)

for /f "usebackq tokens=* delims=" %%R in ("%REPO_LIST%") do (
    call :sync_repo "%%R"
)

echo [%date% %time:~0,8%] Sync finished >> "%LOG_FILE%"
exit /b 0

:sync_repo
set "REPO=%~1"

if "%REPO%"=="" goto :eof
echo %REPO% | findstr /b "#" >nul
if not errorlevel 1 goto :eof

if not exist "%REPO%\.git" (
    echo [%date% %time:~0,8%] SKIP %REPO% not a git repo >> "%LOG_FILE%"
    goto :eof
)

echo [%date% %time:~0,8%] Syncing %REPO% >> "%LOG_FILE%"

pushd "%REPO%"

git add -A 2>> "%LOG_FILE%"

git diff --cached --quiet 2>nul
if errorlevel 1 (
    git commit -m "auto sync %date:/=-% %time:~0,5%" >> "%LOG_FILE%" 2>&1
    echo [%date% %time:~0,8%]   Committed >> "%LOG_FILE%"
) else (
    echo [%date% %time:~0,8%]   Nothing to commit >> "%LOG_FILE%"
)

git pull --rebase --autostash >> "%LOG_FILE%" 2>&1

git push >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    echo [%date% %time:~0,8%]   ERROR Push failed >> "%LOG_FILE%"
) else (
    echo [%date% %time:~0,8%]   Pushed >> "%LOG_FILE%"
)

popd
goto :eof
