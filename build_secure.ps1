# Build Secure Script for dalal_alqaim
# This script runs Flutter clean, fetches packages, and builds the Android APK with full obfuscation.

Write-Host "=============================================" -ForegroundColor Green
Write-Host "🔐 بدء بناء تطبيق مدار بشكل آمن ومحمي" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# 1. Clean build cache
Write-Host "🧹 1. تنظيف ملفات الكاش المؤقتة..." -ForegroundColor Cyan
flutter clean

# 2. Get packages
Write-Host "📦 2. تحميل الحزم والمكتبات..." -ForegroundColor Cyan
flutter pub get

# 3. Create symbols directory if not exist
$symbolsPath = "build/app/outputs/symbols"
if (!(Test-Path $symbolsPath)) {
    New-Item -ItemType Directory -Force -Path $symbolsPath | Out-Null
}

# 4. Run release build with obfuscation
Write-Host "🚀 3. بدء تجميع التطبيق وتعمية الكود (Obfuscate)..." -ForegroundColor Cyan
Write-Host "سيتم تشفير أسماء الكلاسات والدوال والمتغيرات لمنع الهندسة العكسية." -ForegroundColor Yellow

flutter build apk --release --obfuscate --split-debug-info=$symbolsPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "✅ تم بناء التطبيق بنجاح وحمايته من الهندسة العكسية!" -ForegroundColor Green
    Write-Host "الملف الناتج: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    Write-Host "ملفات الرموز المترجمة (لتتبع الأخطاء): $symbolsPath" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
} else {
    Write-Host "`n❌ فشل بناء التطبيق. يرجى التحقق من الأخطاء أعلاه." -ForegroundColor Red
}
