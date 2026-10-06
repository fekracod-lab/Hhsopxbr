@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $desktop = [Environment]::GetFolderPath('Desktop'); $s = $ws.CreateShortcut((Join-Path $desktop 'Madar POS.lnk')); $s.TargetPath = '%~dp0rest_madar.exe'; $s.WorkingDirectory = '%~dp0'; $s.IconLocation = '%~dp0rest_madar.exe,0'; $s.Description = 'Madar Restaurant POS'; $s.Save();"
echo ========================================================
echo   [OK] Desktop Shortcut Created Successfully!
echo ========================================================
timeout /t 2
exit
