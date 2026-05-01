@echo off
chcp 65001 >nul

echo Killing sync processes...
powershell -NoProfile -Command "Get-WmiObject Win32_Process -Filter \"Name='cmd.exe' AND CommandLine LIKE '%%git-auto-sync%%'\" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" 2>nul
echo Done. Sync stopped.
echo.
pause
