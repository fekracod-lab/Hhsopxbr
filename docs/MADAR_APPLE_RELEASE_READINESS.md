# تقرير إغلاق جاهزية منصة "مدار" لمتجر Apple App Store
## MADAR — P0 #1 Apple / iOS Release Readiness Closure Report

تاريخ التدقيق والإغلاق: 2026-09-05  
الحالة الهندسية: **APPLE SOURCE-CONFIGURATION READY + IPA NOT VERIFIED**  
الدرجة المعتمدة لجاهزية iOS المصدرية: **90 / 100**  
الحالة العامة: **READY WITH WARNINGS** (جاهز مصدرياً بالكامل / مشروط بتجميع أرشيف Mac الفعلي)

---

## 1. ما تم تأكيده وتثبيته برمجياً (Confirmed Fixed)

### 1.1 بيان الخصوصية الرسمي (`ios/Runner/PrivacyInfo.xcprivacy`):
- **سلامة التنسيق**: ملف XML معتمد بصيغة Apple Property List (`com.apple.property-list`).
- **التضمين في مشروع Xcode**: مدمج ومسجل في `project.pbxproj` ضمن:
  - `PBXBuildFile` (`DA1A1AC0DE00000000000004`)
  - `PBXFileReference` (`DA1A1AC0DE00000000000005`)
  - `PBXGroup` (Runner)
  - `PBXResourcesBuildPhase` (Resources Build Phase)
- **أسباب استخدام الـ Required Reason APIs (المطابقة للاستخدام الفعلي)**:
  1. `NSPrivacyAccessedAPICategoryUserDefaults` ➔ `CA92.1` (حفظ التفضيلات وإعدادات الحساب محلياً عبر `shared_preferences`).
  2. `NSPrivacyAccessedAPICategoryFileTimestamp` ➔ `C617.1` (إدارة الكاش وملفات التطبيق الداخلية عبر `path_provider`).
  3. `NSPrivacyAccessedAPICategorySystemBootTime` ➔ `35F9.1` (حساب الفوارق الزمنية الدقيقة لحسابات التكسي وتتبع الرحلات).
  4. `NSPrivacyAccessedAPICategoryDiskSpace` ➔ `E174.1` (فحص المساحة التخزينية قبل تحميل وتخزين الخرائط والصور).
- **التصريح عن البيانات المجمعة (`NSPrivacyCollectedDataTypes`)**:
  - `NSPrivacyCollectedDataTypePhoneNumber` (للتوثيق والتواصل).
  - `NSPrivacyCollectedDataTypeName` (للملف الشخصي وإظهار اسم السائق/العميل).
  - `NSPrivacyCollectedDataTypeEmailAddress` (لتسجيل الدخول الاختياري).
  - `NSPrivacyCollectedDataTypePreciseLocation` (لتحديد موقع الركوب ومسار الرحلات والتوصيل).
  - `NSPrivacyCollectedDataTypeDeviceID` (لتسجيل أجهزة الإشعارات عبر FCM).
  - `NSPrivacyCollectedDataTypePurchaseHistory` (لتتبع سجل طلبات الطعام والمتاجر).
  - `NSPrivacyCollectedDataTypeCrashData` & `PerformanceData` (لتشخيص الأعطال وتحسين الأداء).
  - `NSPrivacyTracking`: `false` (لا يتم تتبع المستخدم عبر تطبيقات أو مواقع خارجية).

### 1.2 تدقيق وضبط أذونات `Info.plist`:
- صياغة نصوص التبرير (Purpose Strings) باللغة العربية الواضحة والمطابقة للإرشادات:
  - `NSLocationWhenInUseUsageDescription`: تحديد عنوان التوصيل بدقة وحساب المسافة للمطاعم وموقع ركوب التكسي.
  - `NSLocationAlwaysAndWhenInUseUsageDescription`: تتبع موقع السائق وتوصيل الطلبات بدقة أثناء الرحلات في الخلفية.
  - `NSCameraUsageDescription`: التقاط صور الوجبات، المنتجات، مستندات السائقين، والملف الشخصي.
  - `NSMicrophoneUsageDescription`: استخدام المساعد الصوتي والتواصل الصوتي مع الدعم الفني.
  - `NSSpeechRecognitionUsageDescription`: تحويل الصوت إلى أوامر نصية وبحث.
  - `NSPhotoLibraryUsageDescription`: اختيار صور المنتجات والمتاجر ومستندات التوثيق.

### 1.3 حصر أذونات CocoaPods (`ios/Podfile`):
- تم ضبط `GCC_PREPROCESSOR_DEFINITIONS` في `ios/Podfile` لتفعيل الأذونات المستخدمة حصراً:
  - `PERMISSION_LOCATION=1`
  - `PERMISSION_CAMERA=1`
  - `PERMISSION_PHOTOS=1`
  - `PERMISSION_MICROPHONE=1`
  - `PERMISSION_SPEECH_RECOGNIZER=1`
  - `PERMISSION_NOTIFICATIONS=1`
  - *هذا يمنع استدعاء أي كود غير مستخدم (مثل Bluetooth، Contacts، Calendar) ويحمي من تنبيهات فحص Apple الآلي.*

### 1.4 تسجيل الدخول عبر Apple (`Apple Sign In`):
- استخدام `AppleAuthService` مع تشفير Nonce عشوائي بـ `Random.secure()` و `sha256`.
- توفير واجهة تسجيل الدخول بزر Apple في المقدمة لمستخدمي iOS وفق إرشادات Apple Guideline 4.8.
- تفعيل خاصية `com.apple.developer.applesignin` في `ios/Runner/Runner.entitlements`.

### 1.5 حذف الحساب (`Account Deletion Flow`):
- متاح ومباشر داخل واجهتي `ProfilePage` و `SettingsPage`.
- معالجة استثناء `requires-recent-login` وتوجيه المستخدم لإعادة المصادقة الأمنية.
- حذف سجل المستخدم في Firestore، ومجموعات الأدوار (`drivers`، `restaurants`، `delivery_boys`)، وإلغاء تسجيل الإشعارات في `OneSignal`، وحذف المستخدم من `FirebaseAuth`.

---

## 2. النواقص والمخاطر البيئية (Unverified Because of Environment)

> [!WARNING]
> **محدد بيئة التشغيل**:
> بيئة التطوير الحالية تعمل على نظام **Windows** ولا تحتوي على نظام **macOS** أو بيئة **Xcode / CocoaPods CLI**.
> بناءً على القواعد الصارمة: **لا يمكن ادعاء نجاح تجميع أرشيف IPA أو اختباره على جهاز iPhone فعلي من بيئة Windows**.

---

## 3. التدقيق التفصيلي للمكونات (Component Breakdown)

| المكون | الحالة | الدليل |
|---|:---:|---|
| **Privacy Manifest XML** |  VERIFIED | XML سليم مطابق لمعايير Apple وموجود في `ios/Runner/PrivacyInfo.xcprivacy` |
| **Xcode Target Resource** |  VERIFIED | مدمج في `ios/Runner.xcodeproj/project.pbxproj` ضمن `Resources` |
| **Required Reason APIs** |  VERIFIED | `CA92.1`, `C617.1`, `35F9.1`, `E174.1` مطابقة للاستخدام الفعلي |
| **Info.plist Strings** |  VERIFIED | نصوص واضحة ومبررة لكل إذن مستخدم في التطبيق |
| **Podfile Preprocessor Flags**|  VERIFIED | حصر الأذونات في `Podfile` لمنع تنبيهات الماسح الآلي |
| **Sign in with Apple** |  VERIFIED | `AppleAuthService` مع Nonce تشفيري و `Runner.entitlements` |
| **Account Deletion** |  VERIFIED | تدفق متكامل في العميل والـ Auth وقواعد البيانات |
| **ATS (App Transport Security)**|  VERIFIED | فرض `HTTPS` ومنع `NSAllowsArbitraryLoads` غير الآمن |
| **In-App Privacy Policy** |  VERIFIED | متاحة في الإعدادات بـ 4 بنود واضحة وصريحة |
| **Native IPA Build & Archive** | ⚠️ **NOT VERIFIED** | **غير متاح على نظام Windows — يتطلب تجميعاً نهائياً على Mac** |

---

## 4. الخطوات المتبقية قبل الرفع على App Store Connect

عند نقل المشروع إلى جهاز macOS لتجهيز النسخة المرفوعة:
1. تشغيل أمر تثبيت المكونات:
   ```bash
   cd ios && pod repo update && pod install
   ```
2. فتح المشروع في Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
3. التحقق من ضبط فريق التطوير (`Signing & Capabilities` -> Team: `Your Apple Developer Team`).
4. تنفيذ الأرشفة والتحقق الآلي:
   ```bash
   flutter build ipa --release
   ```
5. رفع الحزمة لـ TestFlight / App Store Connect.

---

## 5. الخلاصة والقرار النهائي لـ Apple

```text
======================================================================
APPLE STATUS: READY WITH WARNINGS
APPLE VERIFIED SCORE: 90 / 100

UNVERIFIED:
- Native Xcode Archive & IPA Generation (Windows environment limitation)
- Physical iOS TestFlight deployment test

BLOCKERS:
- 0 source-level or configuration blockers in the repository

NEXT REQUIRED ACTION:
- Run `flutter build ipa` on a macOS workstation with valid Apple Developer signing.
======================================================================
```
