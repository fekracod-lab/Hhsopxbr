import { 
  collection, 
  doc, 
  getDoc, 
  setDoc, 
  updateDoc, 
  onSnapshot, 
  addDoc, 
  query, 
  where 
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';
import { AdminUser, MadarRole } from '../../domain/types';

export interface PricingConfig {
  baseFareIqd: number;
  baseDistanceKm: number;
  perKmPriceIqd: number;
  taxiCommissionPercent: number;
  restaurantCommissionPercent: number;
  storeCommissionPercent: number;
  parcelCommissionPercent: number;
  fixedDeliveryFeeIqd: number;
}

export interface RegionRecord {
  id: string;
  name: string;
  governorateName: string;
  status: 'active' | 'inactive';
  usersCount?: number;
  driversCount?: number;
  merchantsCount?: number;
  activeOrdersCount?: number;
  fixedDeliveryFeeIqd?: number;
}

export class GovernanceRepository {
  /**
   * Subscribe to Pricing & Commission Rules from `app_config/pricing`
   */
  static subscribeToPricing(callback: (config: PricingConfig) => void): () => void {
    const docRef = doc(db, 'app_config', 'pricing');

    return onSnapshot(docRef, (snap) => {
      if (snap.exists()) {
        const d = snap.data();
        callback({
          baseFareIqd: Number(d.baseFareIqd || 3000),
          baseDistanceKm: Number(d.baseDistanceKm || 2.0),
          perKmPriceIqd: Number(d.perKmPriceIqd || 650),
          taxiCommissionPercent: Number(d.taxiCommissionPercent || 10),
          restaurantCommissionPercent: Number(d.restaurantCommissionPercent || 10),
          storeCommissionPercent: Number(d.storeCommissionPercent || 7),
          parcelCommissionPercent: Number(d.parcelCommissionPercent || 10),
          fixedDeliveryFeeIqd: Number(d.fixedDeliveryFeeIqd || 2000)
        });
      } else {
        // Defaults if document doesn't exist yet
        callback({
          baseFareIqd: 3000,
          baseDistanceKm: 2.0,
          perKmPriceIqd: 650,
          taxiCommissionPercent: 10,
          restaurantCommissionPercent: 10,
          storeCommissionPercent: 7,
          parcelCommissionPercent: 10,
          fixedDeliveryFeeIqd: 2000
        });
      }
    }, (err) => {
      console.warn('Pricing stream error:', err.message);
    });
  }

  /**
   * Save updated pricing and commission matrix to Firestore
   */
  static async savePricing(config: PricingConfig): Promise<void> {
    const docRef = doc(db, 'app_config', 'pricing');
    await setDoc(docRef, {
      ...config,
      updatedAt: new Date().toISOString()
    }, { merge: true });

    await AuditRepository.logAction('UPDATE_PRICING_CONFIG', 'app_config', 'pricing', config);
  }

  /**
   * Subscribe to Governorates & Regions with real-time actors breakdown
   */
  static subscribeToRegions(callback: (regions: RegionRecord[]) => void): () => void {
    const defaultGovernorates: RegionRecord[] = [
      { id: 'al_qaim', name: 'قضاء القائم (المركز، الكرابلة، حصيبة، العبيدي)', governorateName: 'الأنبار', status: 'active', fixedDeliveryFeeIqd: 2000 },
      { id: 'ramadi', name: 'الرمادي المركز', governorateName: 'الأنبار', status: 'active', fixedDeliveryFeeIqd: 3000 },
      { id: 'fallujah', name: 'الفلوجة والصقلاوية', governorateName: 'الأنبار', status: 'active', fixedDeliveryFeeIqd: 3000 },
      { id: 'baghdad', name: 'بغداد (الكرخ والرصافة)', governorateName: 'بغداد', status: 'active', fixedDeliveryFeeIqd: 4000 },
      { id: 'erbil', name: 'أربيل', governorateName: 'أربيل', status: 'active', fixedDeliveryFeeIqd: 4000 },
      { id: 'karbala', name: 'كربلاء المقدسة', governorateName: 'كربلاء', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'najaf', name: 'النجف الأشرف', governorateName: 'النجف', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'basra', name: 'البصرة', governorateName: 'البصرة', status: 'active', fixedDeliveryFeeIqd: 4000 },
      { id: 'ninawa', name: 'الموصل', governorateName: 'نينوى', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'kirkuk', name: 'كركوك', governorateName: 'كركوك', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'babil', name: 'الحلة', governorateName: 'بابل', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'diyala', name: 'بعقوبة', governorateName: 'ديالى', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'sulaymaniyah', name: 'السليمانية', governorateName: 'السليمانية', status: 'active', fixedDeliveryFeeIqd: 4000 },
      { id: 'duhok', name: 'دهوك', governorateName: 'دهوك', status: 'active', fixedDeliveryFeeIqd: 4000 },
      { id: 'wasit', name: 'الكوت', governorateName: 'واسط', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'maysan', name: 'العمارة', governorateName: 'ميسان', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'dhi_qar', name: 'الناصرية', governorateName: 'ذي قار', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'muthanna', name: 'السماوة', governorateName: 'المثنى', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'qadisiyyah', name: 'الديوانية', governorateName: 'القادسية', status: 'active', fixedDeliveryFeeIqd: 3500 },
      { id: 'salah_al_din', name: 'تكريت وسامراء', governorateName: 'صلاح الدين', status: 'active', fixedDeliveryFeeIqd: 3500 }
    ];

    let firestoreList: RegionRecord[] = [];
    let usersList: any[] = [];
    let driversList: any[] = [];
    let merchantsList: any[] = [];
    let ordersList: any[] = [];

    const notify = () => {
      const base = firestoreList.length > 0 ? firestoreList : defaultGovernorates;
      const enriched = base.map((reg) => {
        const govKey = (reg.governorateName || '').trim().toLowerCase();
        const nameKey = (reg.name || '').trim().toLowerCase();

        // Calculate counts
        const usersCount = usersList.filter(u => {
          const uGov = (u.governorate || u.city || u.address || '').toString().toLowerCase();
          return uGov.includes(govKey) || uGov.includes(nameKey);
        }).length;

        const driversCount = driversList.filter(d => {
          const dGov = (d.governorate || d.city || d.address || '').toString().toLowerCase();
          return dGov.includes(govKey) || dGov.includes(nameKey);
        }).length;

        const merchantsCount = merchantsList.filter(m => {
          const mGov = (m.governorate || m.city || m.address || '').toString().toLowerCase();
          return mGov.includes(govKey) || mGov.includes(nameKey);
        }).length;

        const activeOrdersCount = ordersList.filter(o => {
          const oGov = (o.city || o.address || o.deliveryAddress || '').toString().toLowerCase();
          return oGov.includes(govKey) || oGov.includes(nameKey);
        }).length;

        return {
          ...reg,
          usersCount: (reg.id === 'al_qaim' && usersCount === 0) ? usersList.length : usersCount,
          driversCount: (reg.id === 'al_qaim' && driversCount === 0) ? driversList.length : driversCount,
          merchantsCount: (reg.id === 'al_qaim' && merchantsCount === 0) ? merchantsList.length : merchantsCount,
          activeOrdersCount: (reg.id === 'al_qaim' && activeOrdersCount === 0) ? ordersList.length : activeOrdersCount
        };
      });

      callback(enriched);
    };

    // Subscriptions
    const unsubGov = onSnapshot(collection(db, 'governorates'), (snap) => {
      if (!snap.empty) {
        firestoreList = snap.docs.map(d => ({
          id: d.id,
          name: d.data().name || d.data().title || 'منطقة',
          governorateName: d.data().governorateName || d.data().gov || 'العراق',
          status: d.data().status === 'inactive' ? 'inactive' : 'active',
          fixedDeliveryFeeIqd: Number(d.data().fixedDeliveryFeeIqd || 2500)
        }));
      }
      notify();
    }, () => notify());

    const unsubUsers = onSnapshot(collection(db, 'users'), snap => {
      usersList = snap.docs.map(d => d.data());
      notify();
    }, () => {});

    const unsubDrivers = onSnapshot(collection(db, 'drivers'), snap => {
      driversList = snap.docs.map(d => d.data());
      notify();
    }, () => {});

    const unsubRest = onSnapshot(collection(db, 'restaurants'), snap => {
      merchantsList = snap.docs.map(d => d.data());
      notify();
    }, () => {});

    const unsubOrders = onSnapshot(collection(db, 'orders'), snap => {
      ordersList = snap.docs.map(d => d.data()).filter(o => o.status !== 'delivered' && o.status !== 'cancelled');
      notify();
    }, () => {});

    return () => {
      unsubGov();
      unsubUsers();
      unsubDrivers();
      unsubRest();
      unsubOrders();
    };
  }

  /**
   * Toggle Region / Governorate Status
   */
  static async toggleRegionStatus(regionId: string, status: 'active' | 'inactive'): Promise<void> {
    const docRef = doc(db, 'governorates', regionId);
    await setDoc(docRef, {
      status,
      updatedAt: new Date().toISOString()
    }, { merge: true });
    await AuditRepository.logAction('TOGGLE_REGION_STATUS', 'governorates', regionId, { status });
  }

  /**
   * Subscribe to Admin Users
   */
  static subscribeToAdmins(callback: (admins: AdminUser[]) => void): () => void {
    const q = collection(db, 'users');

    return onSnapshot(q, (snap) => {
      const adminRoles = ['admin', 'super_admin', 'main_admin', 'limited_admin', 'complaints_admin'];
      const list: AdminUser[] = [];

      snap.docs.forEach((d) => {
        const data = d.data();
        const role = (data.role || '').toString().toLowerCase();

        if (adminRoles.includes(role)) {
          list.push({
            uid: d.id,
            email: data.email || 'بدون بريد',
            name: data.name || data.username || 'مشرف',
            role: role as MadarRole,
            isApproved: data.isApproved !== false,
            permissions: Array.isArray(data.permissions) ? data.permissions : ['*'],
            phoneNumber: data.phoneNumber || data.phone
          });
        }
      });

      callback(list);
    }, (err) => {
      console.warn('Admins stream error:', err.message);
      callback([]);
    });
  }

  /**
   * Update Admin Permissions in Firestore
   */
  static async updateAdminPermissions(adminUid: string, permissions: string[], role?: MadarRole): Promise<void> {
    const userRef = doc(db, 'users', adminUid);
    const updateData: any = {
      permissions,
      updatedAt: new Date().toISOString()
    };
    if (role) {
      updateData.role = role;
    }

    await updateDoc(userRef, updateData);
    await AuditRepository.logAction('UPDATE_ADMIN_PERMISSIONS', 'users', adminUid, { permissions, role });
  }
}
