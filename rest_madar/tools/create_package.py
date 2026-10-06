import os
import shutil
from datetime import datetime

VERSION = "v1.0.1"
DATE_STR = datetime.now().strftime("%Y-%m-%d")

release_dir = r"C:\Users\omar muthana hamid\Desktop\dalal_Alqaim\dalal_alqaim\rest_madar\build\windows\x64\runner\Release"
dist_base = r"C:\Users\omar muthana hamid\Desktop\dalal_Alqaim\dalal_alqaim\rest_madar\dist"
dist_dir = os.path.join(dist_base, f"Madar_POS_{VERSION}_Portable")

# Updated zip filename requested by user to be easily distinguished
zip_name = f"Madar_POS_{VERSION}_Updated_{DATE_STR}"
zip_path = os.path.join(dist_base, f"{zip_name}.zip")

os.makedirs(dist_dir, exist_ok=True)

# 1. Copy fresh release files
for item in os.listdir(release_dir):
    if item.endswith(('.lib', '.exp', '.ilk', '.pdb')):
        continue
    s = os.path.join(release_dir, item)
    d = os.path.join(dist_dir, item)
    if os.path.isdir(s):
        if os.path.exists(d):
            shutil.rmtree(d)
        shutil.copytree(s, d)
    else:
        shutil.copy2(s, d)

# 2. Launcher
with open(os.path.join(dist_dir, "Launch_Madar_POS.bat"), "w", encoding="ascii") as f:
    f.write('@echo off\nstart "" "%~dp0rest_madar.exe"\nexit\n')

# 3. Desktop Shortcut Creator
shortcut_cmd = f"""@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $desktop = [Environment]::GetFolderPath('Desktop'); $s = $ws.CreateShortcut((Join-Path $desktop 'Madar POS {VERSION}.lnk')); $s.TargetPath = '%~dp0rest_madar.exe'; $s.WorkingDirectory = '%~dp0'; $s.IconLocation = '%~dp0rest_madar.exe,0'; $s.Description = 'Madar Restaurant POS {VERSION}'; $s.Save();"
echo ========================================================
echo   [OK] Desktop Shortcut Created for {VERSION}!
echo ========================================================
timeout /t 2
exit
"""
with open(os.path.join(dist_dir, "Create_Desktop_Shortcut.bat"), "w", encoding="ascii") as f:
    f.write(shortcut_cmd)

# 4. Readme with Instructions
instr_path = r"C:\Users\omar muthana hamid\Desktop\dalal_Alqaim\dalal_alqaim\rest_madar\installer\instructions_after_install.txt"
if os.path.exists(instr_path):
    with open(instr_path, "r", encoding="utf-8") as f:
        content = f.read()
    header = f"نظام مدار للمطاعم - تحديث الإصدار: {VERSION} ({DATE_STR})\n"
    with open(os.path.join(dist_dir, "Instructions_README.txt"), "w", encoding="utf-8-sig") as f:
        f.write(header + "="*60 + "\n" + content)

# 5. Create new distinct Zip archive
if os.path.exists(zip_path):
    os.remove(zip_path)

shutil.make_archive(zip_path.replace(".zip", ""), "zip", dist_dir)

# Also create a symlink / standard copy if desired
standard_zip = os.path.join(dist_base, f"Madar_POS_{VERSION}_Portable.zip")
shutil.copy2(zip_path, standard_zip)

print(f"SUCCESS: Created updated package with version {VERSION}!")
print(f"ZIP: {zip_path}")
