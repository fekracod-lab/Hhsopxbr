# MADAR — Comprehensive iOS Privacy & Data Inventory
**Date:** September 5, 2026
**Policy Standard:** Apple App Review Guidelines 5.1.1 & 5.1.2 / Google Play Data Safety

---

## 1. Collected Data Matrix

| Data Type | Source | Storage Location | Access Controls | Third-Party Sharing | Retention Period | Deletion Mechanism | App Store Purpose | App Store Linked? |
|---|---|---|---|---|---|---|---|---|
| **Phone Number** | User input on Auth screen | Cloud Firestore `users/{uid}` & Firebase Auth | Owner + Admin | Ahyxi OTP API (Verification only) | Duration of account lifecycle | In-App Account Deletion | App Functionality / Account Management | YES |
| **User Full Name** | User input during registration | Cloud Firestore `users/{uid}` | Owner + Assigned Captain/Merchant + Admin | None | Duration of account lifecycle | In-App Account Deletion | App Functionality | YES |
| **Email Address** | Apple/Google Sign-In or User Input | Firebase Auth + Firestore `users/{uid}` | Owner + Admin | None | Duration of account lifecycle | In-App Account Deletion | App Functionality | YES |
| **Precise Location (GPS)** | Device GPS (`geolocator`) | Real-time memory + Firestore `trips`, `delivery_orders` | Customer + Assigned Driver + Admin | None (Direct Maps API tiles) | Real-time during active trip; Trip record retained for receipts | User can delete trip history / Account Deletion | App Functionality (Pickup, Dispatch, Tracking) | YES |
| **Photos & Media** | User Camera / Photo Picker | Firebase Storage `/users/{uid}`, `/merchants/{id}` | Public read for avatars/meals; Document KYC restricted | None | Duration of account lifecycle | In-App Account Deletion / Storage delete | App Functionality | YES |
| **Microphone / Voice** | User Microphone (`speech_to_text`) | Real-time memory (Audio buffer only) | Device local only | None (Streamed to native speech engine) | Not stored (Ephemeral) | N/A (Ephemeral) | App Functionality (Voice Assistant / Support) | NO |
| **FCM Device Token** | Firebase Messaging SDK | Firestore `users/{uid}/notification_devices` | Owner + Cloud Functions (Admin SDK) | Firebase Cloud Messaging (Google) | Active until token refresh or account deletion | Automatic Pruner (`pruneInvalidToken`) + Account Deletion | App Functionality (Push Notifications) | YES |
| **Crash & Diagnostic Data**| Firebase Crashlytics | Google Cloud Crashlytics | Technical Administrators | Google Firebase | 90 days | Automatic expiration | App Functionality / Diagnostics | NO |
| **Performance Data** | PerformanceTracker | Local debug logs / Analytics | Technical Administrators | Google Firebase Analytics | 90 days | Automatic expiration | App Functionality | NO |

---

## 2. Third-Party Services Integration Summary

1. **Firebase / Google Cloud:**
   - Auth, Cloud Firestore, Cloud Storage, Cloud Messaging, Crashlytics, Analytics.
   - Purpose: Primary backend infrastructure.
2. **Apple Services:**
   - Sign in with Apple, Apple Push Notification Service (APNs).
   - Purpose: Native authentication and background alert delivery.
3. **Ahyxi SMS Provider:**
   - Phone verification (OTP) executed exclusively server-side via Cloud Functions.
4. **OneSignal (Standby):**
   - Retained as fallback push infrastructure; FCM is authoritative.
