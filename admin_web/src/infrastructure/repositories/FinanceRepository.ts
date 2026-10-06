import { 
  collection, 
  onSnapshot, 
  doc, 
  updateDoc, 
  setDoc, 
  addDoc, 
  getDoc,
  serverTimestamp,
  increment 
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface WalletTransactionRecord {
  id: string;
  targetId: string;
  targetName: string;
  targetPhone?: string;
  targetRole: 'driver' | 'customer' | 'merchant';
  operationType: 'deposit' | 'bonus' | 'penalty' | 'debt_cleared' | 'order_commission' | 'order_payout';
  amountIqd: number;
  previousBalanceIqd: number;
  newBalanceIqd: number;
  reason: string;
  adminEmail?: string;
  createdAt: string;
  createdTimestamp: number;
}

export class FinanceRepository {
  /**
   * Subscribe to Financial Ledger & Wallet Transactions
   */
  static subscribeToTransactions(callback: (txs: WalletTransactionRecord[]) => void): () => void {
    return onSnapshot(collection(db, 'wallet_transactions'), (snapshot) => {
      const list: WalletTransactionRecord[] = snapshot.docs.map((d) => {
        const data = d.data();
        let createdStr = 'الآن';
        let createdTs = Date.now();
        if (data.createdAt?.toDate) {
          const dt = data.createdAt.toDate();
          createdStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
          createdTs = dt.getTime();
        } else if (data.createdAt) {
          const dt = new Date(data.createdAt);
          createdStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
          createdTs = !isNaN(dt.getTime()) ? dt.getTime() : 0;
        }

        return {
          id: d.id,
          targetId: data.targetId || d.id,
          targetName: data.targetName || 'مستخدم مدار',
          targetPhone: data.targetPhone,
          targetRole: data.targetRole || 'driver',
          operationType: data.operationType || 'deposit',
          amountIqd: Number(data.amountIqd || data.amount || 0),
          previousBalanceIqd: Number(data.previousBalanceIqd || 0),
          newBalanceIqd: Number(data.newBalanceIqd || 0),
          reason: data.reason || data.description || 'حركة مالية إدارية',
          adminEmail: data.adminEmail || 'SuperAdmin',
          createdAt: createdStr,
          createdTimestamp: createdTs
        };
      });

      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => {
      console.warn('Wallet transactions stream note:', err.message);
    });
  }

  /**
   * Manually top up or adjust wallet balance for Driver / Customer / Merchant
   */
  static async adjustWalletBalance(params: {
    targetId: string;
    targetName: string;
    targetPhone?: string;
    targetRole: 'driver' | 'customer' | 'merchant';
    operationType: 'deposit' | 'bonus' | 'penalty' | 'debt_cleared';
    amountIqd: number;
    reason: string;
    adminEmail?: string;
  }): Promise<void> {
    const { targetId, targetName, targetPhone, targetRole, operationType, amountIqd, reason, adminEmail } = params;

    let colName = 'users';
    if (targetRole === 'driver') colName = 'drivers';
    else if (targetRole === 'merchant') colName = 'restaurants';

    const targetRef = doc(db, colName, targetId);
    const snap = await getDoc(targetRef);

    let prevBal = 0;
    if (snap.exists()) {
      prevBal = Number(snap.data().walletBalance || snap.data().balance || 0);
    }

    const delta = (operationType === 'penalty') ? -Math.abs(amountIqd) : Math.abs(amountIqd);
    const newBal = prevBal + delta;

    // 1. Update target document
    await updateDoc(targetRef, {
      walletBalance: newBal,
      updatedAt: new Date().toISOString()
    }).catch(async () => {
      await setDoc(targetRef, { walletBalance: newBal }, { merge: true });
    });

    // If driver, also update users collection if duplicate exists
    if (targetRole === 'driver') {
      await updateDoc(doc(db, 'users', targetId), {
        walletBalance: newBal,
        updatedAt: new Date().toISOString()
      }).catch(() => {});
    }

    // 2. Log to `wallet_transactions`
    await addDoc(collection(db, 'wallet_transactions'), {
      targetId,
      targetName,
      targetPhone: targetPhone || '',
      targetRole,
      operationType,
      amountIqd: Math.abs(amountIqd),
      previousBalanceIqd: prevBal,
      newBalanceIqd: newBal,
      reason: reason.trim(),
      adminEmail: adminEmail || 'SuperAdmin',
      createdAt: serverTimestamp(),
      createdDate: new Date().toISOString()
    });

    // 3. Log to audit
    try {
      await AuditRepository.logAction('WALLET_ADJUSTMENT', colName, targetId, {
        operationType,
        amountIqd,
        prevBal,
        newBal,
        reason
      });
    } catch (_) {}
  }

  /**
   * Clear Driver Accumulated App Debt
   */
  static async clearDriverDebt(driverId: string, driverName: string, reason = 'تصفير وتسوية يدوية للديون المستحقة من الكابتن'): Promise<void> {
    const driverRef = doc(db, 'drivers', driverId);
    const snap = await getDoc(driverRef);

    let oldDebt = 0;
    if (snap.exists()) {
      oldDebt = Number(snap.data().appDebt || snap.data().debt || 0);
    }

    // Clear debt in drivers collection
    await updateDoc(driverRef, {
      appDebt: 0,
      debt: 0,
      lastDebtClearedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });

    // Log transaction
    await addDoc(collection(db, 'wallet_transactions'), {
      targetId: driverId,
      targetName: driverName,
      targetRole: 'driver',
      operationType: 'debt_cleared',
      amountIqd: oldDebt,
      previousBalanceIqd: oldDebt,
      newBalanceIqd: 0,
      reason: reason.trim(),
      adminEmail: 'SuperAdmin',
      createdAt: serverTimestamp(),
      createdDate: new Date().toISOString()
    });

    try {
      await AuditRepository.logAction('CLEAR_DRIVER_DEBT', 'drivers', driverId, {
        oldDebt,
        reason
      });
    } catch (_) {}
  }
}
