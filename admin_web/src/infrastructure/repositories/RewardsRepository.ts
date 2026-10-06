import { 
  collection, 
  query, 
  limit, 
  onSnapshot, 
  doc, 
  addDoc,
  setDoc,
  updateDoc, 
  deleteDoc, 
  getDoc,
  getDocs,
  where,
  orderBy,
  serverTimestamp,
  increment,
  runTransaction
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface AdminRewardItem {
  id: string;
  title: string;
  description: string;
  cost: number; // Required points
  rewardType: 'commission_free_trips' | 'commission_discount' | 'fuel_voucher' | 'cash_bonus' | 'badge_gold' | 'custom';
  discountPercent?: number;
  tripsCount?: number;
  cashValueIqd?: number;
  targetAudience: 'drivers' | 'customers' | 'all';
  isActive: boolean;
  timesRedeemed?: number;
  createdAt: string;
}

export interface RewardTransactionRecord {
  id: string;
  driverId: string;
  driverName?: string;
  driverPhone?: string;
  userRole?: string;
  amount: number; // Positive for earned/grant, negative for redeemed
  type: 'earned' | 'redeemed' | 'bonus_admin' | 'penalty';
  reason: string;
  referenceId?: string;
  createdAt: string;
  createdTimestamp: number;
}

export interface CaptainPointsRank {
  driverId: string;
  name: string;
  phone: string;
  vehicleModel?: string;
  plateNumber?: string;
  rewardsPoints: number;
  tier: 'bronze' | 'silver' | 'gold' | 'diamond';
  tierArabic: string;
  tierColor: string;
  totalTrips: number;
  rating: number;
}

export interface AutoPointsRule {
  pointsPerCompletedRide: number;
  pointsPerCompletedOrder: number;
  pointsForFiveStarRating: number;
  peakHourBonusPoints: number;
}

export class RewardsRepository {
  /**
   * Stream all Admin Rewards Catalog items
   */
  static subscribeToRewardsCatalog(callback: (rewards: AdminRewardItem[]) => void): () => void {
    const q = query(collection(db, 'admin_rewards'));
    return onSnapshot(q, (snapshot) => {
      const list: AdminRewardItem[] = snapshot.docs.map((d) => {
        const data = d.data();
        let createdStr = 'الآن';
        if (data.createdAt?.toDate) {
          createdStr = data.createdAt.toDate().toLocaleDateString('ar-IQ');
        }

        return {
          id: d.id,
          title: data.title || 'مكافأة مدار',
          description: data.description || '',
          cost: Number(data.cost || 100),
          rewardType: data.rewardType || 'commission_free_trips',
          discountPercent: Number(data.discountPercent || 100),
          tripsCount: Number(data.tripsCount || 3),
          cashValueIqd: Number(data.cashValueIqd || 0),
          targetAudience: data.targetAudience || 'drivers',
          isActive: data.isActive !== false,
          timesRedeemed: Number(data.timesRedeemed || 0),
          createdAt: createdStr
        };
      });
      list.sort((a, b) => a.cost - b.cost);
      callback(list);
    }, (err) => console.warn('Rewards catalog stream:', err.message));
  }

  /**
   * Stream all Reward Transactions (Points Ledger)
   */
  static subscribeToRewardTransactions(callback: (txs: RewardTransactionRecord[]) => void, maxLimit = 250): () => void {
    const q = query(collection(db, 'reward_transactions'), limit(maxLimit));
    return onSnapshot(q, (snapshot) => {
      const list: RewardTransactionRecord[] = snapshot.docs.map((d) => {
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
          createdTs = !isNaN(dt.getTime()) ? dt.getTime() : Date.now();
        }

        return {
          id: d.id,
          driverId: data.driverId || data.userId || '',
          driverName: data.driverName || data.userName || (data.driverId ? `كابتن #${data.driverId.slice(0, 6)}` : 'عضو مدار'),
          driverPhone: data.driverPhone || data.userPhone,
          userRole: data.userRole || 'driver',
          amount: Number(data.amount || 0),
          type: data.type || (Number(data.amount) > 0 ? 'earned' : 'redeemed'),
          reason: data.reason || 'عملية نقاط',
          referenceId: data.referenceId,
          createdAt: createdStr,
          createdTimestamp: createdTs
        };
      });
      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => console.warn('Reward transactions stream:', err.message));
  }

  /**
   * Add new Reward to Catalog
   */
  static async addReward(payload: Omit<AdminRewardItem, 'id' | 'createdAt' | 'timesRedeemed'>): Promise<string> {
    const docRef = await addDoc(collection(db, 'admin_rewards'), {
      ...payload,
      timesRedeemed: 0,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });

    try {
      await AuditRepository.logAction('CREATE_REWARD', 'REWARDS', docRef.id, { title: payload.title, cost: payload.cost });
    } catch (_) {}

    return docRef.id;
  }

  /**
   * Update an existing Reward
   */
  static async updateReward(rewardId: string, updates: Partial<AdminRewardItem>): Promise<void> {
    const docRef = doc(db, 'admin_rewards', rewardId);
    await updateDoc(docRef, {
      ...updates,
      updatedAt: serverTimestamp()
    });

    try {
      await AuditRepository.logAction('UPDATE_REWARD', 'REWARDS', rewardId, updates);
    } catch (_) {}
  }

  /**
   * Toggle Reward Active Status
   */
  static async toggleRewardStatus(rewardId: string, currentStatus: boolean): Promise<void> {
    const docRef = doc(db, 'admin_rewards', rewardId);
    await updateDoc(docRef, {
      isActive: !currentStatus,
      updatedAt: serverTimestamp()
    });
  }

  /**
   * Delete Reward from Catalog
   */
  static async deleteReward(rewardId: string): Promise<void> {
    await deleteDoc(doc(db, 'admin_rewards', rewardId));
    try {
      await AuditRepository.logAction('DELETE_REWARD', 'REWARDS', rewardId, {});
    } catch (_) {}
  }

  /**
   * Grant or Deduct Points Manually by Admin
   */
  static async grantOrDeductPoints(
    targetId: string,
    targetName: string,
    targetPhone: string,
    points: number,
    type: 'bonus_admin' | 'penalty',
    reason: string
  ): Promise<void> {
    const isDriver = true;
    const targetRef = doc(db, isDriver ? 'drivers' : 'users', targetId);

    await runTransaction(db, async (tx) => {
      // 1. Increment driver/user points
      tx.set(targetRef, {
        rewardsPoints: increment(points)
      }, { merge: true });

      // 2. Add transaction ledger record
      const txRef = doc(collection(db, 'reward_transactions'));
      tx.set(txRef, {
        driverId: targetId,
        driverName: targetName,
        driverPhone: targetPhone,
        amount: points,
        type: type,
        reason: reason.trim() || (points > 0 ? 'مكافأة إدارية تشجيعية' : 'خصم نقاط إداري'),
        createdAt: serverTimestamp()
      });
    });

    try {
      await AuditRepository.logAction('MANUAL_POINTS_ADJUSTMENT', 'REWARDS', targetId, { points, type, reason });
    } catch (_) {}
  }

  /**
   * Get or Set Auto Points Rules (Cached or stored in Firestore `system_config/rewards_rules`)
   */
  static async saveAutoPointsRules(rules: AutoPointsRule): Promise<void> {
    const configRef = doc(db, 'system_config', 'rewards_rules');
    await setDoc(configRef, {
      ...rules,
      updatedAt: serverTimestamp()
    }, { merge: true });

    try {
      await AuditRepository.logAction('UPDATE_REWARDS_RULES', 'SYSTEM_CONFIG', 'rewards_rules', rules);
    } catch (_) {}
  }
}
