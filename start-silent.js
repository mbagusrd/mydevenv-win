// Run Dev Stack in background silently (no CMD window)
var wsh = new ActiveXObject("WScript.Shell");
var fso = new ActiveXObject("Scripting.FileSystemObject");
var root = fso.GetParentFolderName(WScript.ScriptFullName);

wsh.CurrentDirectory = root;
wsh.Run('cmd.exe /c ""' + root + '\\start.bat" --silent"', 0, false);
