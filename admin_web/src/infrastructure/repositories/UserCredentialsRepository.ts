import { 
  collection, 
  onSnapshot, 
  doc, 
  getDoc, 
  setDoc, 
  updateDoc, 
  serverTimestamp,
  query,
  limit
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface DatabaseAccount {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: 'admin' | 'driver' | 'restaurant' | 'store' | 'user' | 'customer';
  roleArabic: string;
  sourceCollection: 'users' | 'drivers' | 'restaurants' | 'stores';
  currentPasswordHint?: string;
  updatedAt?: string;
}

export class UserCredentialsRepository {
  /**
   * Listen to all accounts with emails across users, drivers, restaurants, and stores
   */
  static subscribeToAllAccounts(callback: (accounts: DatabaseAccount[]) => void): () => void {
    let usersList: DatabaseAccount[] = [];
    let driversList: DatabaseAccount[] = [];
    let restaurantsList: DatabaseAccount[] = [];
    let storesList: DatabaseAccount[] = [];

    const notify = () => {
      const mergedMap = new Map<string, DatabaseAccount>();

      // 1. Add users collection accounts
      usersList.forEach(u => {
        if (u.email && u.email.trim() && u.email !== 'لا يوجد بريد') {
          mergedMap.set(u.email.toLowerCase().trim(), u);
        } else if (u.phone && u.phone.trim()) {
          mergedMap.set(u.id, u);
        }
      });

      // 2. Add/Merge drivers
      driversList.forEach(d => {
        const key = (d.email && d.email.trim() && d.email !== 'لا يوجد بريد') 
          ? d.email.toLowerCase().trim() 
          : d.id;
        if (!mergedMap.has(key)) {
          mergedMap.set(key, d);
        } else {
          // If already exists from users, ensure role is driver
          const existing = mergedMap.get(key)!;
          if (existing.role === 'user') {
            mergedMap.set(key, { ...existing, role: 'driver', roleArabic: ' كابتن تكسي / مندوب' });
          }
        }
      });

      // 3. Add/Merge restaurants
      restaurantsList.forEach(r => {
        const key = (r.email && r.email.trim() && r.email !== 'لا يوجد بريد') 
          ? r.email.toLowerCase().trim() 
          : r.id;
        mergedMap.set(key, r);
      });

      // 4. Add/Merge stores
      storesList.forEach(s => {
        const key = (s.email && s.email.trim() && s.email !== 'لا يوجد بريد') 
          ? s.email.toLowerCase().trim() 
          : s.id;
        mergedMap.set(key, s);
      });

      const list = Array.from(mergedMap.values());
      // Sort alphabetically or priority (admins, restaurants, stores, drivers, users)
      list.sort((a, b) => {
        if (a.role === 'admin') return -1;
        if (b.role === 'admin') return 1;
        return a.name.localeCompare(b.name, 'ar');
      });

      callback(list);
    };

    // Listen to users
    const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
      usersList = snap.docs.map(d => {
        const data = d.data();
        const rawRole = (data.role || 'user').toLowerCase();
        let roleArabic = ' زبون / مستخدم';
        let role: any = 'user';

        if (rawRole.includes('admin')) {
          role = 'admin';
          roleArabic = ' مشرف / أدمن';
        } else if (rawRole.includes('driver') || rawRole.includes('captain')) {
          role = 'driver';
          roleArabic = ' كابتن تكسي / مندوب';
        } else if (rawRole.includes('restaurant')) {
          role = 'restaurant';
          roleArabic = ' صاحب مطعم';
        } else if (rawRole.includes('store') || rawRole.includes('merchant')) {
          role = 'store';
          roleArabic = ' صاحب متجر / صيدلية';
        }

        return {
          id: d.id,
          name: data.name || data.username || data.fullName || 'مستخدم مدار',
          email: data.email || '',
          phone: data.phone || data.phoneNumber || '-',
          role,
          roleArabic,
          sourceCollection: 'users',
          currentPasswordHint: data.password || data.newPasswordTemporary,
          updatedAt: data.updatedAt
        };
      });
      notify();
    }, (err) => console.warn('Users credentials stream error:', err.message));

    // Listen to drivers
    const unsubDrivers = onSnapshot(collection(db, 'drivers'), (snap) => {
      driversList = snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name || data.fullName || 'كابتن مدار',
          email: data.email || '',
          phone: data.phone || data.phoneNumber || '-',
          role: 'driver',
          roleArabic: ' كابتن تكسي / مندوب',
          sourceCollection: 'drivers',
          currentPasswordHint: data.password || data.newPasswordTemporary,
          updatedAt: data.updatedAt
        };
      });
      notify();
    }, (err) => console.warn('Drivers credentials stream error:', err.message));

    // Listen to restaurants
    const unsubRestaurants = onSnapshot(collection(db, 'restaurants'), (snap) => {
      restaurantsList = snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name || data.restaurantName || 'مطعم مدار',
          email: data.email || '',
          phone: data.phone || data.phoneNumber || '-',
          role: 'restaurant',
          roleArabic: ' مطعم شريك',
          sourceCollection: 'restaurants',
          currentPasswordHint: data.password || data.newPasswordTemporary,
          updatedAt: data.updatedAt
        };
      });
      notify();
    }, (err) => console.warn('Restaurants credentials stream error:', err.message));

    // Listen to stores
    const unsubStores = onSnapshot(collection(db, 'stores'), (snap) => {
      storesList = snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name || data.storeName || 'متجر مدار',
          email: data.email || '',
          phone: data.phone || data.phoneNumber || '-',
          role: 'store',
          roleArabic: ' متجر / سوبرماركت شريك',
          sourceCollection: 'stores',
          currentPasswordHint: data.password || data.newPasswordTemporary,
          updatedAt: data.updatedAt
        };
      });
      notify();
    }, (err) => console.warn('Stores credentials stream error:', err.message));

    return () => {
      unsubUsers();
      unsubDrivers();
      unsubRestaurants();
      unsubStores();
    };
  }

  /**
   * Update Password / Credential for any chosen account
   */
  static async updateAccountPassword(params: {
    account: DatabaseAccount;
    newPassword: string;
    newEmail?: string;
    adminEmail?: string;
  }): Promise<void> {
    const { account, newPassword, newEmail, adminEmail } = params;
    const cleanPass = newPassword.trim();
    const cleanEmail = newEmail ? newEmail.trim() : undefined;

    const payload: any = {
      password: cleanPass,
      passwordUpdated: true,
      newPasswordTemporary: cleanPass,
      updatedAt: new Date().toISOString()
    };

    if (cleanEmail) {
      payload.email = cleanEmail;
    }

    // 1. Update in the main source collection
    const mainRef = doc(db, account.sourceCollection, account.id);
    await setDoc(mainRef, payload, { merge: true });

    // 2. If source collection is not 'users', also sync into 'users' collection
    if (account.sourceCollection !== 'users') {
      const userRef = doc(db, 'users', account.id);
      const userSnap = await getDoc(userRef);
      if (userSnap.exists()) {
        await setDoc(userRef, payload, { merge: true });
      }
    }

    // 3. Log Audit
    try {
      await AuditRepository.logAction(
        'CHANGE_ACCOUNT_PASSWORD',
        account.sourceCollection,
        account.id,
        {
          accountName: account.name,
          accountEmail: cleanEmail || account.email,
          role: account.role,
          changedBy: adminEmail || 'SuperAdmin'
        }
      );
    } catch (_) {}
  }
}
