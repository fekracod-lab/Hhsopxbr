# MADAR (مدار) — FIRESTORE PRODUCTION BACKUP & DISASTER RECOVERY RUNBOOK
**Document Version:** 1.0 (Phase 7 Production Operations)  
**Target Cloud Backend:** Google Cloud Platform / Firebase Project `dala-alqaim` (Region: `us-central1`)  
**Operational Classification:** Infrastructure Runbook & Disaster Recovery Protocol  
**Approval Status:** Proposed Operational Procedure (Pending Business & Cloud IAM Provisioning)  

---

## 1. BACKUP REQUIREMENT & PURPOSE

To ensure zero permanent data loss and compliance with high availability requirements for **MADAR**, an automated snapshot and recovery mechanism is required for all Firestore collections (Users, Orders, Trips, Deliveries, Financial Settlements, KYC references).

---

## 2. RECOMMENDED CADENCE & SCHEDULE

- **Cadence:** Daily automated incremental/full export.
- **Trigger Window:** 03:00 AM Baghdad Time (UTC+3) during minimal traffic hours.
- **Target Bucket:** `gs://dala-alqaim-firestore-backups` (Multi-Region or Dual-Region Storage Class).

---

## 3. PROPOSED DATA RETENTION SCHEDULE
> [!IMPORTANT]
> The retention periods below represent technical recommendations and are classified as:  
> **PROPOSED / PENDING BUSINESS-LEGAL APPROVAL**

| Data Tier | Collections | Proposed Backup Retention | Storage Class |
| :--- | :--- | :---: | :--- |
| **Financial & Ledger** | `commission_settlements`, `financial_accounts` | **7 Years** | Coldline / Archive |
| **Operational Records** | `orders`, `trips`, `deliveries` | **1 Year** | Nearline |
| **Customer & User Core** | `users`, `drivers`, `restaurants`, `stores` | **Lifetime + 90d post-deletion** | Standard / Nearline |
| **Transient Records** | `users/{uid}/notifications`, `support_chats` | **90 Days** | Standard |

---

## 4. AUTOMATED BACKUP IMPLEMENTATION (GCP Cloud Scheduler + Cloud Functions)

### Step 1: Create Backup Bucket
```bash
# Run in Google Cloud SDK with Project Owner permissions:
gcloud config set project dala-alqaim
gsutil mb -l us-central1 -c standard gs://dala-alqaim-firestore-backups/
```

### Step 2: Grant Permissions to App Engine / Cloud Functions Service Account
```bash
gcloud projects add-iam-policy-binding dala-alqaim \
    --member="serviceAccount:dala-alqaim@appspot.gserviceaccount.com" \
    --role="roles/datastore.importExportAdmin"

gsutil iam ch serviceAccount:dala-alqaim@appspot.gserviceaccount.com:roles/storage.admin gs://dala-alqaim-firestore-backups
```

### Step 3: Trigger Backup via gcloud Command
```bash
# Manual or Scheduled Full Database Export
gcloud firestore export gs://dala-alqaim-firestore-backups/$(date +%Y-%m-%d-%H%M%S)
```

---

## 5. STEP-BY-STEP RESTORE PROCEDURE (Disaster Recovery)

In the event of accidental data corruption, unauthorized purge, or catastrophic outage:

### Step 1: Identify Target Snapshot
```bash
gsutil ls gs://dala-alqaim-firestore-backups/
# Example Target: gs://dala-alqaim-firestore-backups/2026-09-05-030000/2026-09-05-030000.overall_export_metadata
```

### Step 2: Perform Full Restore
```bash
gcloud firestore import gs://dala-alqaim-firestore-backups/2026-09-05-030000/
```

### Step 3: Targeted Collection Restore (Optional)
```bash
# To restore specific collections without overwriting others:
gcloud firestore import gs://dala-alqaim-firestore-backups/2026-09-05-030000/ \
    --collection-ids='orders','trips','commission_settlements'
```

---

## 6. SERVICE LEVEL OBJECTIVES (SLAs)

- **Recovery Point Objective (RPO):** Maximum **24 Hours** of data loss in worst-case scenario.
- **Recovery Time Objective (RTO):** Total restore execution time **≤ 2 Hours** from disaster declaration to system verification.

---

## 7. RESPONSIBLE ROLES & VERIFICATION

- **Lead DevOps Engineer / System Administrator:** Responsible for verifying backup completion notifications via Google Cloud Monitoring Alerting.
- **Verification Drill Cadence:** Quarterly restore drill on isolated staging Firebase project (`dala-alqaim-staging`).
