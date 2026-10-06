import { 
  collection, 
  onSnapshot, 
  doc, 
  setDoc, 
  updateDoc, 
  deleteDoc, 
  addDoc, 
  serverTimestamp 
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface CouponEntity {
  id: string;
  code: string; // e.g. "MADAR20", "RAMADAN"
  discountType: 'percentage' | 'fixed_amount';
  discountValue: number; // e.g. 15 for 15% or 2000 for 2000 IQD
  minOrderAmountIqd: number; // e.g. 5000 IQD
  maxDiscountCapIqd?: number; // e.g. 5000 IQD maximum discount for percentage
  serviceScope: 'all' | 'food' | 'taxi' | 'stores' | 'parcels';
  targetMerchantId?: string;
  targetMerchantName?: string;
  usageLimitTotal: number; // e.g. 100 times
  usageLimitPerUser: number; // e.g. 1 time
  timesUsed: number;
  totalDiscountGivenIqd: number;
  startDate: string;
  expiryDate: string;
  isActive: boolean;
  notes?: string;
  createdAt: string;
  createdTimestamp: number;
}

export class CouponsRepository {
  /**
   * Subscribe to all Promo Codes & Coupons from Firestore
   */
  static subscribeToCoupons(callback: (coupons: CouponEntity[]) => void): () => void {
    return onSnapshot(collection(db, 'coupons'), (snapshot) => {
      const list: CouponEntity[] = snapshot.docs.map((docSnap) => {
        const data = docSnap.data();

        let createdStr = 'الآن';
        let createdTs = Date.now();
        if (data.createdAt?.toDate) {
          const dt = data.createdAt.toDate();
          createdStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric' });
          createdTs = dt.getTime();
        } else if (data.createdAt) {
          const dt = new Date(data.createdAt);
          createdStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
          createdTs = !isNaN(dt.getTime()) ? dt.getTime() : 0;
        }

        return {
          id: docSnap.id,
          code: (data.code || docSnap.id).toUpperCase().trim(),
          discountType: data.discountType === 'fixed_amount' ? 'fixed_amount' : 'percentage',
          discountValue: Number(data.discountValue || data.discountPercent || data.amount || 10),
          minOrderAmountIqd: Number(data.minOrderAmountIqd || data.minOrder || data.minAmount || 0),
          maxDiscountCapIqd: data.maxDiscountCapIqd ? Number(data.maxDiscountCapIqd) : undefined,
          serviceScope: data.serviceScope || data.scope || 'all',
          targetMerchantId: data.targetMerchantId || data.merchantId,
          targetMerchantName: data.targetMerchantName || data.merchantName,
          usageLimitTotal: Number(data.usageLimitTotal || data.limitTotal || data.maxUsage || 100),
          usageLimitPerUser: Number(data.usageLimitPerUser || data.limitPerUser || 1),
          timesUsed: Number(data.timesUsed || data.usedCount || 0),
          totalDiscountGivenIqd: Number(data.totalDiscountGivenIqd || data.totalDiscount || 0),
          startDate: data.startDate || new Date().toISOString().slice(0, 10),
          expiryDate: data.expiryDate || data.validUntil || '2026-12-31',
          isActive: data.isActive !== false && data.status !== 'inactive',
          notes: data.notes || data.description,
          createdAt: createdStr,
          createdTimestamp: createdTs
        };
      });

      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => {
      console.warn('Coupons stream note:', err.message);
    });
  }

  /**
   * Add a new Coupon / Promo Code
   */
  static async addCoupon(coupon: Omit<CouponEntity, 'id' | 'timesUsed' | 'totalDiscountGivenIqd' | 'createdAt' | 'createdTimestamp'>): Promise<string> {
    const formattedCode = coupon.code.toUpperCase().trim();
    const docRef = doc(db, 'coupons', formattedCode);

    const payload = {
      ...coupon,
      code: formattedCode,
      timesUsed: 0,
      totalDiscountGivenIqd: 0,
      createdAt: serverTimestamp(),
      createdDate: new Date().toISOString(),
      status: coupon.isActive ? 'active' : 'inactive'
    };

    await setDoc(docRef, payload, { merge: true });

    try {
      await AuditRepository.logAction('CREATE_COUPON', 'coupons', formattedCode, {
        discountType: coupon.discountType,
        discountValue: coupon.discountValue
      });
    } catch (_) {}

    return formattedCode;
  }

  /**
   * Toggle Coupon Active Status
   */
  static async toggleCouponStatus(couponId: string, isActive: boolean): Promise<void> {
    const docRef = doc(db, 'coupons', couponId);
    await updateDoc(docRef, {
      isActive: isActive,
      status: isActive ? 'active' : 'inactive',
      updatedAt: new Date().toISOString()
    });

    try {
      await AuditRepository.logAction(
        isActive ? 'ACTIVATE_COUPON' : 'DEACTIVATE_COUPON',
        'coupons',
        couponId,
        { isActive }
      );
    } catch (_) {}
  }

  /**
   * Delete Coupon
   */
  static async deleteCoupon(couponId: string): Promise<void> {
    await deleteDoc(doc(db, 'coupons', couponId));
    try {
      await AuditRepository.logAction('DELETE_COUPON', 'coupons', couponId, {});
    } catch (_) {}
  }
}
