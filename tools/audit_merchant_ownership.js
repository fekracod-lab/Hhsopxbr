/**
 * READ-ONLY audit: which staff accounts would lose access once Firestore rules
 * bind merchant data to `users/{uid}.restaurantId == merchantId`.
 *
 * Usage (from project root):
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account.json   (PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS="...")
 *   node tools/audit_merchant_ownership.js
 *
 * It never writes. It prints only uid / role / ids (no phones or names).
 */
const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

admin.initializeApp({ projectId: 'dala-alqaim' });
const db = admin.firestore();

const STAFF_ROLES = ['cashier', 'merchant', 'seller'];
const OWNER_ROLES = ['restaurant', 'store'];

async function loadUsers(roles) {
  const out = [];
  for (let i = 0; i < roles.length; i += 10) {
    const snap = await db.collection('users').where('role', 'in', roles.slice(i, i + 10)).get();
    snap.forEach((d) => out.push({ uid: d.id, ...d.data() }));
  }
  return out;
}

(async () => {
  const staff = await loadUsers(STAFF_ROLES);
  const owners = await loadUsers(OWNER_ROLES);

  const missing = [];
  const dangling = [];
  const cache = new Map();

  for (const u of staff) {
    const rid = u.restaurantId || u.merchantId || u.storeId;
    if (!rid) {
      missing.push({ uid: u.uid, role: u.role });
      continue;
    }
    if (!cache.has(rid)) {
      const [r, s, m] = await Promise.all([
        db.doc(`restaurants/${rid}`).get(),
        db.doc(`stores/${rid}`).get(),
        db.doc(`merchants/${rid}`).get(),
      ]);
      cache.set(rid, r.exists || s.exists || m.exists);
    }
    if (!cache.get(rid)) dangling.push({ uid: u.uid, role: u.role, restaurantId: rid });
  }

  console.log('--- Merchant ownership audit (read-only) ---');
  console.log(`Owner accounts (restaurant/store): ${owners.length}  (use uid == merchantId, unaffected)`);
  console.log(`Staff accounts (cashier/merchant/seller): ${staff.length}`);
  console.log(`\nWILL LOSE ACCESS - no restaurantId/merchantId/storeId: ${missing.length}`);
  missing.forEach((x) => console.log(`  ${x.uid}  role=${x.role}`));
  console.log(`\nWILL LOSE ACCESS - id points to missing merchant doc: ${dangling.length}`);
  dangling.forEach((x) => console.log(`  ${x.uid}  role=${x.role}  restaurantId=${x.restaurantId}`));
  console.log('\nNote: rules currently read only users.restaurantId; accounts that only have merchantId/storeId need that field copied.');
  process.exit(0);
})().catch((e) => {
  console.error('Audit failed:', e.message);
  process.exit(1);
});
