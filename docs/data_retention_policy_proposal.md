# MADAR (مدار) — DATA LIFECYCLE & RETENTION POLICY PROPOSAL
**Document Version:** 1.0 (Phase 7 Production Operations)  
**Target Platform:** MADAR (Flutter Client, React Admin Web, Firebase Backend)  
**Legal Classification:** Internal Operational Proposal (Pending Legal Counsel & Management Sign-off)  
**Status:** `PROPOSED RETENTION / PENDING LEGAL/BUSINESS APPROVAL`  

---

## 1. PURPOSE & PRINCIPLES

This document establishes the proposed retention, archival, and purging policies across all **21 Core Data Entities** in the MADAR platform, balancing operational necessity, storage efficiency, user privacy rights (Right to Erasure), and statutory financial retention requirements in Iraq.

---

## 2. MASTER ENTITY RETENTION PROPOSAL TABLE

> [!IMPORTANT]
> The periods indicated below are technical proposals based on e-commerce, transportation, and privacy best practices.  
> **Final durations are SUBJECT TO FORMAL BUSINESS & LEGAL APPROVAL.**

| # | Entity Name | Firestore / Storage Location | Current State in Code | Proposed Retention Period | Archival & Purge Method | Legal / Operational Justification |
| :---: | :--- | :--- | :--- | :---: | :--- | :--- |
| **1** | **Users (Customers)** | `users/{uid}` | Active until deletion | **Account Lifetime + 90 Days** | Cascade deletion via `ProfilePage._showDeleteAccountDialog` | User account lifecycle & Right to Erasure |
| **2** | **Drivers / Captains** | `drivers/{uid}` | Active until termination | **Account Lifetime + 3 Years** | Soft-delete (`isDeleted: true`, `isSuspended: true`) | Dispute resolution & regulatory safety |
| **3** | **Restaurants** | `restaurants/{id}` | Active business profile | **Business Lifetime + 1 Year** | Soft-delete (`isDeleted: true`) | Historical order reconciliation |
| **4** | **Stores (Shops)** | `stores/{id}` | Active business profile | **Business Lifetime + 1 Year** | Soft-delete (`isDeleted: true`) | Merchant inventory & sales audits |
| **5** | **Couriers (Delegates)**| `delivery_boys/{uid}` | Active until termination | **Account Lifetime + 2 Years** | Soft-delete | Delivery dispute tracking |
| **6** | **Taxi Trips** | `trips/{id}` | Retained permanently in DB | **1 Year Active + 6 Years Archive** | Moved to Coldline Storage / BigQuery | Financial settlement & insurance safety |
| **7** | **Unified Orders** | `orders/{id}` | Retained in DB | **1 Year Active + 6 Years Archive** | Coldline archive | Commercial tax & accounting standards |
| **8** | **Food Orders** | `orders/{id}` (`type: food`) | Retained in DB | **1 Year Active + 6 Years Archive** | Coldline archive | Merchant payout audit trail |
| **9** | **Store Orders** | `orders/{id}` (`type: store`)| Retained in DB | **1 Year Active + 6 Years Archive** | Coldline archive | Stock & customer receipt integrity |
| **10**| **Mersal Deliveries** | `deliveries/{id}` | Retained in DB | **1 Year Active + 3 Years Archive** | Coldline archive | Parcel liability & customer delivery proof |
| **11**| **Notifications** | `users/{uid}/notifications`| Cleared manually / 90 days | **90 Days** | Automated Cloud Function cleanup | Ephemeral operational alerts |
| **12**| **Support Messages** | `support_chats/{id}/messages`| Active until ticket close | **180 Days post-resolution** | Purged upon customer satisfaction ACK | Customer service quality assurance |
| **13**| **KYC Documents** | Cloud Storage `kyc_documents/`| Gated by Admin claims | **Verification + 1 Year** | Purged on rejection; encrypted on approval | Identity verification & AML compliance |
| **14**| **Media (Meal/Store)**| Cloudinary / Storage | Active URLs | **Active Menu Lifetime** | Purged upon item removal | Storage optimization |
| **15**| **GPS Live Locations**| `drivers/{uid}.currentLocation`| Ephemeral realtime | **Live Only (Zero Permanent Store)** | Overwritten on next heartbeat | Privacy protection & battery efficiency |
| **16**| **Financial Records** | `commission_settlements` | Immutable Firestore docs | **7 Years** | Immutable append-only cold ledger | Iraqi Commercial Accounting standard |
| **17**| **Wallets** | `users/{uid}.walletBalance` | Balance tracked in user doc| **Account Lifetime + 7 Years** | Ledger history retained permanently | Financial integrity |
| **18**| **Loyalty Points** | `users/{uid}.points` | Increment/decrement | **2 Years from last activity** | Expired if dormant > 24 months | Marketing reward program rules |
| **19**| **Complaints** | `complaints/{id}` | Retained for admin | **2 Years** | Archived after formal resolution | Quality control & fleet safety audits |
| **20**| **App Reviews & Ratings**| `app_ratings/{id}` | Aggregated in real time | **Permanent Aggregate** | Individual text purged after 3 Years | Store quality scoring & analytics |
| **21**| **Security Audit Logs** | `audit_logs/{id}` | Cloud Functions generated | **1 Year** | Exported to BigQuery security workspace | Cybersecurity audit & intrusion detection |

---

## 3. NEXT STEPS FOR MANAGEMENT & LEGAL COUNSEL

1. **Review & Approval:** Business and legal representatives must review the table and approve the proposed retention periods.
2. **Implementation of Automated Purge Policies:** Upon approval, Cloud Functions scheduled crons will be deployed to archive records beyond the approved retention window.
