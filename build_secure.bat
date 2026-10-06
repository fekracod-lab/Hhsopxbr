@echo off
chcp 65001 > nul
echo =============================================
echo 🔐 بدء بناء تطبيق مدار بشكل آمن ومحمي
echo =============================================
echo.
echo 🧹 1. تنظيف ملفات الكاش المؤقتة...
call flutter clean
echo.
echo 📦 2. تحميل الحزم والمكتبات...
call flutter pub get
echo.
echo 🚀 3. بدء تجميع التطبيق وتعمية الكود (Obfuscate)...
echo سيتم تشفير أسماء الكلاسات والدوال والمتغيرات لمنع الهندسة العكسية.
echo.
call flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
echo.
if %ERRORLEVEL% EQU 0 (
    echo =============================================
    echo ✅ تم بناء التطبيق بنجاح وحمايته من الهندسة العكسية!
    echo الملف الناتج: build\app\outputs\flutter-apk\app-release.apk
    echo =============================================
) else (
    echo.
    echo ❌ فشل بناء التطبيق. يرجى التحقق من الأخطاء أعلاه.
)
pause
