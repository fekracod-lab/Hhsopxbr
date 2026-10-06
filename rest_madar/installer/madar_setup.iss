; ==============================================================================
; Inno Setup Script: نظام مدار لإدارة المطاعم ونقاط البيع (Madar POS)
; مخصص لبناء برنامج تثبيت قياسي واحترافي لبيئة Windows يماثل البرامج العالمية
; ==============================================================================

#define MyAppName "نظام مدار للمطاعم - Madar POS"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "مدار التقنية - Madar Tech"
#define MyAppURL "https://madar.com"
#define MyAppExeName "rest_madar.exe"
#define MyAppAssocName MyAppName + " Application"
#define MyAppAssocExt ".madar"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
; المعرف الفريد للنظام (GUID) لتفادي أي تداخل مع برامج أخرى
AppId={{D37E6F89-A2C4-4B81-9951-7E02D5B4A1C8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Madar POS
DefaultGroupName=نظام مدار للمطاعم
AllowNoIcons=yes
; مسار حفظ ملف الإعداد المُصدر
OutputDir=..\dist\installer
OutputBaseFilename=Madar_POS_Setup_v1.0.0
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=100
; مرونة التثبيت لكافة المستخدمين أو المستخدم الحالي
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; صفحات التعليمات والإرشادات قبل وبعد التثبيت (مثل البرامج العالمية)
InfoBeforeFile=instructions_before_install.txt
InfoAfterFile=instructions_after_install.txt

; تحسين الخط واللغة العربية
ShowLanguageDialog=auto

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.LaunchApp=تشغيل نظام مدار الآن (Launch Madar POS)
english.CreateDesktopIcon=إنشاء أيقونة اختصار على سطح المكتب (Desktop Shortcut)
english.CreateQuickLaunch=إنشاء اختصار في شريط التشغيل السريع

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunch}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; تضمين كافة ملفات النسخة النهائية المبنية (Release) باستثناء ملفات التطوير الثقيلة
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.lib,*.exp,*.ilk,*.pdb"

[Icons]
; اختصار قائمة ابدأ
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
; اختصار إرشادات ودليل الاستخدام
Name: "{group}\دليل الاستخدام والتعليمات"; Filename: "{app}\instructions_after_install.txt"
; اختصار إلغاء التثبيت
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; اختصار سطح المكتب
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
; خيار تشغيل التطبيق فور اكتمال التثبيت
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchApp}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; تنظيف الملفات المؤقتة وسجلات التثبيت عند الإلغاء
Type: files; Name: "{app}\debug_trace.log"
Type: filesandordirs; Name: "{app}\temp_cache"
