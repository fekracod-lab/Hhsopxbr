# MADAR — Remediation Baseline Documentation
**Date:** September 5, 2026
**Framework:** Flutter 3.7.2 / Dart Sound Null Safety / Node.js 20 Cloud Functions / React 18 Admin Web
**Audit Reference:** Master Forensic Audit

---

## 1. Pre-Remediation Status & Scores

| Area | Baseline Score | Baseline State |
|---|---|---|
| Architecture | 88 / 100 | Clean Architecture + Feature First with 4-Tier AppInitializer |
| Core Backend | 94 / 100 | 16 Cloud Functions active and syntax-validated |
| Security | 84 / 100 | Strict Firestore RBAC; Client OTP secret & Storage custom claims discrepancy noted |
| Privacy | 85 / 100 | In-app account deletion present; Missing iOS Privacy Manifest |
| Apple Compliance | 85 / 100 | Missing `PrivacyInfo.xcprivacy` (Required Reason APIs) |
| Android Compliance | 92 / 100 | SDK 36, FGS special-use declared, prominent location disclosure |
| Notifications | 92 / 100 | Authoritative FCM multicast with background suppression |
| Navigation | 86 / 100 | 2 misrouted paths (`/favorites` -> Profile, `/merchant` -> Welcome) |
| Testing | 96 / 100 | 916 automated unit/widget/regression tests passing |
| Dead Code | 75 / 100 | 9 legacy dropshipping files, 2 studio files, 1 duplicate file |
| **Overall Status** | **88%** | **READY WITH WARNINGS** |

---

## 2. Baseline Verification Commands & Results

1. `flutter analyze` ➔ **0 Issues found** (Ran in 102.7s)
2. `flutter test` ➔ **916 Tests Passed, 0 Failed** (Ran in 142.1s)
3. `npm run typecheck` (admin_web) ➔ **0 Errors**
4. `node -c index.js` (functions) ➔ **Valid syntax, 16 exports**
5. `adb devices` ➔ **Physical device STK-LX1 (Android 10) connected and active**

---

## 3. Targeted Remediation Objectives

1. **P0:** Create `ios/Runner/PrivacyInfo.xcprivacy` declaring Required Reason APIs (`CA92.1`, `C617.1`, `35F9.1`, `E174.1`) and Data Collections.
2. **P0:** Produce complete `docs/ios_privacy_data_inventory.md`.
3. **P0:** Migrate Ahyxi OTP to Server-Side Cloud Function with signed Firebase Auth Custom Tokens.
4. **P1:** Implement Admin Custom Claims synchronization on `users/{userId}` trigger.
5. **P1:** Move Gemini AI Assistant to authenticated Cloud Function proxy.
6. **P1:** Fix routes (`/favorites` ➔ `FavoritesPage`, `/merchant` ➔ `RestaurantDashboardPage`).
7. **P2:** Complete purge of legacy Dropshipping (9 files) and Studio Meem (2 files).
8. **P2:** Delete duplicate file `pages_list_in_section_page.dart`.
9. **P2:** Clean up `admin_web`, `firestore.indexes.json`, and remove AdMob meta-data.
10. **P4:** Generate final compliance and remediation reports with verified evidence.
