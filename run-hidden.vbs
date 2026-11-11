' Run an executable completely hidden (no console window).
' Usage: wscript run-hidden.vbs "C:\path\app.exe" [arg1] [arg2] ...
Set sh = CreateObject("WScript.Shell")
If WScript.Arguments.Count = 0 Then WScript.Quit
exe = Chr(34) & WScript.Arguments(0) & Chr(34)
args = ""
For i = 1 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next
sh.Run exe & args, 0, False
