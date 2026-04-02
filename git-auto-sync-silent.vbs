Set WshShell = CreateObject("WScript.Shell")
WshShell.Run Chr(34) & Replace(WScript.ScriptFullName, "git-auto-sync-silent.vbs", "git-auto-sync.bat") & Chr(34), 0, False
