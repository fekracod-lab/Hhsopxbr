import {
  collection,
  query,
  onSnapshot,
  doc,
  updateDoc,
  deleteDoc,
  orderBy,
  limit,
  serverTimestamp
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface CustomerEntity {
  uid: string;
  name: string;
  phone: string;
  email?: string;
  city?: string;
  role: string;
  isBlocked: boolean;
  blockReason?: string;
  walletBalance: number;
  totalOrdersCount: number;
  totalSpentIqd: number;
  createdAt: string;
  createdTimestamp: number;
  avatarUrl?: string;
}

export class CustomersRepository {
  /**
   * Subscribe to real customers from Firestore (Sorted: Newest to Oldest)
   */
  static subscribeToCustomers(callback: (customers: CustomerEntity[]) => void): () => void {
    const usersQuery = collection(db, 'users');

    return onSnapshot(
      usersQuery,
      (snapshot) => {
        const list: CustomerEntity[] = [];

        snapshot.docs.forEach((docSnap) => {
          const data = docSnap.data();
          const role = (data.role || data.accountType || 'customer').toString().toLowerCase();

          // Include customers and standard app users
          if (role === 'customer' || role === 'user' || role === 'passenger' || role === '') {
            const rawCreated = data.createdAt;
            let createdStr = 'الآن';
            let createdTs = 0;

            if (rawCreated?.toDate) {
              const dt = rawCreated.toDate();
              createdStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
              createdTs = dt.getTime();
            } else if (rawCreated) {
              const dt = new Date(rawCreated);
              createdStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
              createdTs = !isNaN(dt.getTime()) ? dt.getTime() : 0;
            }

            list.push({
              uid: docSnap.id,
              name: data.name || data.fullName || data.username || 'عميل مدار',
              phone: data.phoneNumber || data.phone || 'غير متوفر',
              email: data.email,
              city: data.city || data.town || 'القائم',
              role: role || 'customer',
              isBlocked: data.isBlocked === true || data.status === 'banned' || data.status === 'blocked',
              blockReason: data.blockReason || data.banReason,
              walletBalance: Number(data.walletBalance || data.balance || 0),
              totalOrdersCount: Number(data.totalOrders || data.ordersCount || data.tripsCount || 0),
              totalSpentIqd: Number(data.totalSpent || data.spentIqd || 0),
              createdAt: createdStr,
              createdTimestamp: createdTs,
              avatarUrl: data.photoUrl || data.avatarUrl || data.profileImage
            });
          }
        });

        // Sort: Newest registration to oldest
        list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);

        callback(list);
      },
      (err) => {
        console.warn('Customers stream error:', err.message);
        callback([]);
      }
    );
  }

  /**
   * Update Customer Details & Wallet
   */
  static async updateCustomerDetails(
    uid: string,
    details: {
      name?: string;
      phone?: string;
      email?: string;
      city?: string;
      walletBalance?: number;
    }
  ): Promise<void> {
    const payload: Record<string, any> = {
      updatedAt: new Date().toISOString()
    };

    if (details.name !== undefined) {
      payload.name = details.name;
      payload.fullName = details.name;
    }
    if (details.phone !== undefined) {
      payload.phone = details.phone;
      payload.phoneNumber = details.phone;
    }
    if (details.email !== undefined) {
      payload.email = details.email;
    }
    if (details.city !== undefined) {
      payload.city = details.city;
    }
    if (details.walletBalance !== undefined) {
      payload.walletBalance = details.walletBalance;
      payload.balance = details.walletBalance;
    }

    await updateDoc(doc(db, 'users', uid), payload);

    try {
      await AuditRepository.logAction('UPDATE_CUSTOMER_DETAILS', 'users', uid, details);
    } catch (_) {}
  }

  /**
   * Block or Unblock Customer
   */
  static async toggleBlockCustomer(uid: string, block: boolean, reason?: string): Promise<void> {
    await updateDoc(doc(db, 'users', uid), {
      isBlocked: block,
      status: block ? 'banned' : 'active',
      blockReason: block ? (reason || 'حظر بقرار إداري') : null
    });

    try {
      await AuditRepository.logAction(
        block ? 'BLOCK_USER' : 'UNBLOCK_USER',
        'users',
        uid,
        { isBlocked: block, reason }
      );
    } catch (_) {}
  }

  /**
   * Delete single customer account
   */
  static async deleteCustomer(uid: string): Promise<void> {
    await deleteDoc(doc(db, 'users', uid));

    try {
      await AuditRepository.logAction('DELETE_USER', 'users', uid, {});
    } catch (_) {}
  }

  /**
   * Bulk Delete multiple customers
   */
  static async deleteMultipleCustomers(uids: string[]): Promise<void> {
    const tasks = uids.map(uid => deleteDoc(doc(db, 'users', uid)).catch(() => {}));
    await Promise.all(tasks);

    try {
      await AuditRepository.logAction('BULK_DELETE_USERS', 'users', 'batch', {
        count: uids.length,
        uids
      });
    } catch (_) {}
  }
}
