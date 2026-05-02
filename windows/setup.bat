@echo off
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
set "PS1_PATH=%SCRIPT_DIR%git-auto-sync-silent.ps1"

echo ============================================
echo   Git Auto Sync - Setup
echo ============================================
echo.

:: Remove old repeating task if exists
schtasks /delete /tn "GitAutoSync" /f >nul 2>&1

:: Register startup task (run once on logon, script loops internally)
schtasks /create /tn "GitAutoSync" /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%PS1_PATH%\"" /sc onlogon /f

if %errorlevel% equ 0 (
    echo [OK] Auto-start on login registered!
) else (
    echo [FAIL] Could not create scheduled task.
    echo        Try right-click setup.bat and "Run as administrator".
)

:: Kill old sync instance if running
powershell -NoProfile -Command "Get-WmiObject Win32_Process -Filter \"Name='cmd.exe' AND CommandLine LIKE '%%git-auto-sync%%'\" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" 2>nul

:: Start sync now
start "" powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%PS1_PATH%"
echo [OK] Sync started in background.
echo.
echo      To change interval: just edit sync-settings.txt, it takes effect on the next cycle.
echo.
pause
