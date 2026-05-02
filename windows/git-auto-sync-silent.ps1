$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Start-Process -FilePath "$scriptDir\git-auto-sync.bat" -WindowStyle Hidden
