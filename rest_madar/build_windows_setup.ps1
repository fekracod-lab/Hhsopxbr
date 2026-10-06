# ==============================================================================
# سكربت تصدير وبناء معالج تثبيت وحزم نظام مدار لويندوز (Madar POS Windows Exporter)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "🚀 بدء تصدير وتجهيز نظام مدار للمطاعم والكاشير (Windows Release)" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 1. التحقق من وجود نسخة Release المبنية
$ReleaseSourceDir = Join-Path $ScriptDir "build\windows\x64\runner\Release"
$ReleaseExe = Join-Path $ReleaseSourceDir "rest_madar.exe"

if (!(Test-Path $ReleaseExe)) {
    Write-Host "⚠️ لم يتم العثور على نسخة Release مجمعة مسبقاً. جاري البناء الآن..." -ForegroundColor Yellow
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ فشل بناء مشروع Flutter لنظام Windows."
        exit 1
    }
} else {
    Write-Host "✅ تم العثور على نسخة Release جاهزة ومحدثة." -ForegroundColor Green
}

# 2. إنشاء مجلد التوزيع النظيف (Clean Distribution)
$DistBase = Join-Path $ScriptDir "dist"
$PortableDir = Join-Path $DistBase "Madar_POS_v1.0.0_Portable"
$InstallerOutputDir = Join-Path $DistBase "installer"

if (Test-Path $PortableDir) {
    Remove-Item -Recurse -Force $PortableDir
}
New-Item -ItemType Directory -Force -Path $PortableDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallerOutputDir | Out-Null

Write-Host "`n📦 جاري نسخ وتجميع ملفات التشغيل الضرورية إلى مجلد التوزيع..." -ForegroundColor Cyan

# نسخ الملفات الأساسية فقط (استثناء ملفات .lib و .exp غير اللازمة في التشغيل)
Get-ChildItem -Path $ReleaseSourceDir -Exclude "*.lib", "*.exp", "*.ilk", "*.pdb" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $PortableDir -Recurse -Force
}

# نسخ دليل التعليمات والإرشادات
$InstructionSource = Join-Path $ScriptDir "installer\instructions_after_install.txt"
if (Test-Path $InstructionSource) {
    Copy-Item -Path $InstructionSource -Destination (Join-Path $PortableDir "دليل_التشغيل_والتعليمات.txt") -Force
}

# إنشاء ملف تشغيل مباشر وسلس (Batch Launcher)
$LauncherBatLines = @(
    "@echo off",
    "chcp 65001 > nul",
    "title نظام مدار للمطاعم والكاشير",
    'start "" "%~dp0rest_madar.exe"'
)
[System.IO.File]::WriteAllLines((Join-Path $PortableDir "تشغيل_نظام_مدار.bat"), $LauncherBatLines, [System.Text.Encoding]::UTF8)

# إنشاء سكربت فوري لإنشاء اختصار سطح المكتب بنقرة واحدة (للنسخة المحمولة)
$ShortcutLines = @(
    "@echo off",
    'powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut([System.IO.Path]::Combine([Environment]::GetFolderPath(''Desktop''), ''نظام مدار للمطاعم.lnk'')); $Shortcut.TargetPath = ''%~dp0rest_madar.exe''; $Shortcut.WorkingDirectory = ''%~dp0''; $Shortcut.IconLocation = ''%~dp0rest_madar.exe,0''; $Shortcut.Description = ''نظام مدار لإدارة المطاعم ونقاط البيع''; $Shortcut.Save();"',
    "echo تم إنشاء اختصار نظام مدار على سطح المكتب بنجاح!",
    "pause"
)
[System.IO.File]::WriteAllLines((Join-Path $PortableDir "إنشاء_اختصار_سطح_المكتب.bat"), $ShortcutLines, [System.Text.Encoding]::UTF8)

Write-Host "✅ تم تجهيز النسخة المستقلة (Portable) بنجاح في:" -ForegroundColor Green
Write-Host "   $PortableDir" -ForegroundColor White

# 3. محاولة بناء ملف التثبيت الاحترافي (Inno Setup Compiler)
Write-Host "`n🔍 البحث عن معالج التثبيت العالمي (Inno Setup Compiler)..." -ForegroundColor Cyan

$InnoPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Get-Command iscc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
)

$IsccPath = $null
foreach ($p in $InnoPaths) {
    if ($p -and (Test-Path $p)) {
        $IsccPath = $p
        break
    }
}

$IssScript = Join-Path $ScriptDir "installer\madar_setup.iss"

if ($IsccPath -and (Test-Path $IssScript)) {
    Write-Host "✨ تم العثور على Inno Setup في: $IsccPath" -ForegroundColor Green
    Write-Host "🛠️ جاري بناء برنامج التثبيت (Setup.exe) بمظهر واحترافية البرامج العالمية..." -ForegroundColor Cyan

    & "$IsccPath" "$IssScript"
    
    $FinalSetupExe = Join-Path $InstallerOutputDir "Madar_POS_Setup_v1.0.0.exe"
    if (Test-Path $FinalSetupExe) {
        Write-Host "`n======================================================================" -ForegroundColor Green
        Write-Host "🎉 تم بنجاح إنشاء برنامج التثبيت الرسمي:" -ForegroundColor Green
        Write-Host "   $FinalSetupExe" -ForegroundColor Yellow
        Write-Host "======================================================================" -ForegroundColor Green
    }
} else {
    Write-Host "`n💡 لم يتم العثور على Inno Setup مثبت على الجهاز حالياً." -ForegroundColor Yellow
    Write-Host "لتجميع ملف الإعداد التلقائي (Madar_POS_Setup_v1.0.0.exe):" -ForegroundColor Cyan
    Write-Host "1. قم بتثبيت Inno Setup المجاني عبر تحميله من الموقع الرسمي: https://jrsoftware.org/isdl.php" -ForegroundColor White
    Write-Host "2. ثم أعد تشغيل هذا السكربت أو افتح ملف installer\madar_setup.iss واضغط Compile." -ForegroundColor White
}

# 4. ضغط النسخة المحمولة كـ ZIP جاهز للتوزيع السريع
Write-Host "`n📦 جاري إنشاء أرشيف ZIP جاهز للإرسال والنقل..." -ForegroundColor Cyan
$ZipOutput = Join-Path $DistBase "Madar_POS_v1.0.0_Portable.zip"
if (Test-Path $ZipOutput) { Remove-Item -Force $ZipOutput }
Compress-Archive -Path "$PortableDir\*" -DestinationPath $ZipOutput -Force

Write-Host "✅ تم تجهيز حزمة ZIP للتوزيع الفوري:" -ForegroundColor Green
Write-Host "   $ZipOutput" -ForegroundColor White

Write-Host "`n🏁 اكتملت جميع مراحل التجهيز بنجاح!" -ForegroundColor Green
