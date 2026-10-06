import { 
  collection, 
  onSnapshot, 
  doc, 
  getDoc,
  getDocs,
  updateDoc,
  setDoc,
  deleteDoc,
  addDoc,
  serverTimestamp,
  query,
  where,
  limit,
  arrayUnion,
  arrayRemove
} from 'firebase/firestore';
import { db } from '../firebase';
import { MerchantEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export interface ProductItemEntity {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  imageUrl?: string;
  isAvailable: boolean;
  salesCount: number;
  sizes?: Array<{ name: string; price: number }>;
  extras?: Array<{ name: string; price: number }>;
}

export interface MenuCategoryEntity {
  id: string;
  name: string;
  iconCode?: number;
  itemCount?: number;
  sectionId?: string;
  itemId?: string;
}

export interface NewMerchantPayload {
  name: string;
  category: 'restaurant' | 'store';
  subCategory?: string;
  ownerName: string;
  phone: string;
  email?: string;
  password?: string;
  commissionRate?: number;
  address?: string;
}

export interface MerchantOrderRecord {
  orderId: string;
  customerName: string;
  customerPhone?: string;
  deliveryAddress?: string;
  itemsSummary: string;
  itemsList?: Array<{ name: string; quantity: number; price: number; options?: string[] }>;
  totalPriceIqd: number;
  subtotalIqd: number;
  commissionIqd: number;
  merchantNetIqd: number;
  driverName?: string;
  driverPhone?: string;
  status: string;
  rawStatus: string;
  createdAt: string;
  createdTimestamp: number;
  paymentMethod?: string;
}

export class MerchantsRepository {
  /**
   * Subscribe to ALL restaurants, stores, pharmacies, and shops from Firestore (Newest to Oldest)
   */
  static subscribeToMerchants(callback: (merchants: MerchantEntity[]) => void): () => void {
    let restList: MerchantEntity[] = [];
    let storesList: MerchantEntity[] = [];
    let pharmaciesList: MerchantEntity[] = [];
    let shopsList: MerchantEntity[] = [];
    let genericMerchantsList: MerchantEntity[] = [];
    let merchantUsersList: MerchantEntity[] = [];

    const notify = () => {
      // Map deduplication by ID
      const map = new Map<string, MerchantEntity>();
      [
        ...restList, 
        ...storesList, 
        ...pharmaciesList, 
        ...shopsList,
        ...genericMerchantsList,
        ...merchantUsersList
      ].forEach(m => {
        if (m.merchantId && !map.has(m.merchantId)) {
          map.set(m.merchantId, m);
        }
      });
      const merged = Array.from(map.values());
      // Sort newest to oldest
      merged.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(merged);
    };

    // Helper to format date
    const parseDate = (rawCreated: any) => {
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
      return { createdStr, createdTs };
    };

    // 1. Listen to restaurants
    const unsubRest = onSnapshot(
      collection(db, 'restaurants'),
      (snapshot) => {
        restList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { createdStr, createdTs } = parseDate(data.createdAt || data.timestamp);

          return {
            merchantId: docSnap.id,
            name: data.name || data.restaurantName || 'مطعم بدون اسم',
            category: 'restaurant' as const,
            subCategory: data.subCategory || data.category || data.cuisineType || 'مشاوي ومأكولات شرقية',
            ownerName: data.ownerName || data.owner || data.managerName || 'صاحب المطعم',
            phone: data.phone || data.phoneNumber || data.mobile || 'غير متوفر',
            email: data.email || data.ownerEmail || data.contactEmail || 'لا يوجد بريد',
            password: data.password || data.initialPassword || data.plainPassword || data.newPasswordTemporary || data.tempPassword || data.pinCode || data.code || 'غير محددة',
            address: data.address || data.locationDescription || 'قضاء القائم',
            city: data.city || data.town || 'القائم',
            isOpen: data.isOpen !== false && data.isAvailable !== false,
            commissionRate: Number(data.commissionRate || 10),
            totalOrders: Number(data.totalOrders || data.ordersCount || 0),
            totalRevenueIqd: Number(data.totalRevenue || data.revenue || data.totalSales || 0),
            status: data.isApproved === false ? 'pending' : (data.status === 'suspended' ? 'suspended' : 'active'),
            createdAt: createdStr,
            createdTimestamp: createdTs,
            logoUrl: data.logoUrl || data.image || data.logo || data.coverUrl,
            coverImageUrl: data.coverImageUrl || data.coverImage || data.image
          };
        });
        notify();
      },
      (err) => console.warn('Restaurants stream note:', err.message)
    );

    // 2. Listen to stores
    const unsubStores = onSnapshot(
      collection(db, 'stores'),
      (snapshot) => {
        storesList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { createdStr, createdTs } = parseDate(data.createdAt || data.timestamp);

          return {
            merchantId: docSnap.id,
            name: data.name || data.storeName || 'متجر / سوبرماركت',
            category: 'store' as const,
            subCategory: data.subCategory || data.category || data.storeCategory || 'سوبرماركت وبقالة',
            ownerName: data.ownerName || data.owner || data.managerName || 'صاحب المتجر',
            phone: data.phone || data.phoneNumber || data.mobile || 'غير متوفر',
            email: data.email || data.ownerEmail || data.contactEmail || 'لا يوجد بريد',
            password: data.password || data.initialPassword || data.plainPassword || data.newPasswordTemporary || data.tempPassword || data.pinCode || data.code || 'غير محددة',
            address: data.address || data.locationDescription || 'قضاء القائم',
            city: data.city || data.town || 'القائم',
            isOpen: data.isOpen !== false && data.isAvailable !== false,
            commissionRate: Number(data.commissionRate || 7),
            totalOrders: Number(data.totalOrders || data.ordersCount || 0),
            totalRevenueIqd: Number(data.totalRevenue || data.revenue || data.totalSales || 0),
            status: data.isApproved === false ? 'pending' : (data.status === 'suspended' ? 'suspended' : 'active'),
            createdAt: createdStr,
            createdTimestamp: createdTs,
            logoUrl: data.logoUrl || data.image || data.logo || data.coverUrl,
            coverImageUrl: data.coverImageUrl || data.coverImage || data.image
          };
        });
        notify();
      },
      (err) => console.warn('Stores stream note:', err.message)
    );

    // 3. Listen to pharmacies
    const unsubPharmacies = onSnapshot(
      collection(db, 'pharmacies'),
      (snapshot) => {
        pharmaciesList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { createdStr, createdTs } = parseDate(data.createdAt);
          return {
            merchantId: docSnap.id,
            name: data.name || data.pharmacyName || 'صيدلية',
            category: 'store' as const,
            subCategory: 'صيدليات ومستلزمات طبية',
            ownerName: data.ownerName || 'الصيدلاني المسؤول',
            phone: data.phone || data.phoneNumber || 'غير متوفر',
            email: data.email || 'لا يوجد بريد',
            password: data.password || 'غير محددة',
            address: data.address || 'القائم',
            city: data.city || 'القائم',
            isOpen: data.isOpen !== false,
            commissionRate: Number(data.commissionRate || 5),
            totalOrders: Number(data.totalOrders || 0),
            totalRevenueIqd: Number(data.totalRevenue || 0),
            status: 'active',
            createdAt: createdStr,
            createdTimestamp: createdTs,
            logoUrl: data.logoUrl || data.image
          };
        });
        notify();
      },
      () => {}
    );

    // 4. Listen to shops
    const unsubShops = onSnapshot(
      collection(db, 'shops'),
      (snapshot) => {
        shopsList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { createdStr, createdTs } = parseDate(data.createdAt);
          return {
            merchantId: docSnap.id,
            name: data.name || data.shopName || 'محل تجاري',
            category: 'store' as const,
            subCategory: data.category || 'محلات تجارية',
            ownerName: data.ownerName || 'صاحب المحل',
            phone: data.phone || 'غير متوفر',
            email: data.email || 'لا يوجد بريد',
            password: data.password || 'غير محددة',
            address: data.address || 'القائم',
            city: data.city || 'القائم',
            isOpen: data.isOpen !== false,
            commissionRate: Number(data.commissionRate || 7),
            totalOrders: Number(data.totalOrders || 0),
            totalRevenueIqd: Number(data.totalRevenue || 0),
            status: 'active',
            createdAt: createdStr,
            createdTimestamp: createdTs,
            logoUrl: data.image || data.logo
          };
        });
        notify();
      },
      () => {}
    );

    // 5. Listen to merchants collection
    const unsubMerchants = onSnapshot(
      collection(db, 'merchants'),
      (snapshot) => {
        genericMerchantsList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { createdStr, createdTs } = parseDate(data.createdAt || data.timestamp);
          const isRest = (data.type || data.category || '').toLowerCase().includes('rest') || (data.name || '').includes('مطعم');
          return {
            merchantId: docSnap.id,
            name: data.name || data.merchantName || data.storeName || 'متجر مدار',
            category: isRest ? ('restaurant' as const) : ('store' as const),
            subCategory: data.subCategory || data.category || 'متاجر وخدمات',
            ownerName: data.ownerName || data.fullName || 'التاجر المسؤول',
            phone: data.phone || data.phoneNumber || 'غير متوفر',
            email: data.email || 'لا يوجد بريد',
            password: data.password || 'غير محددة',
            address: data.address || 'القائم',
            city: data.city || 'القائم',
            isOpen: data.isOpen !== false && data.isAvailable !== false,
            commissionRate: Number(data.commissionRate || 7),
            totalOrders: Number(data.totalOrders || data.ordersCount || 0),
            totalRevenueIqd: Number(data.totalRevenue || data.revenue || 0),
            status: data.isApproved === false ? 'pending' : (data.status === 'suspended' ? 'suspended' : 'active'),
            createdAt: createdStr,
            createdTimestamp: createdTs,
            logoUrl: data.logoUrl || data.image || data.logo
          };
        });
        notify();
      },
      () => {}
    );

    // 6. Listen to users with merchant/store/restaurant roles
    const unsubUsers = onSnapshot(
      collection(db, 'users'),
      (snapshot) => {
        merchantUsersList = [];
        snapshot.docs.forEach((docSnap) => {
          const data = docSnap.data();
          const role = (data.role || '').toString().toLowerCase();
          if (['merchant', 'store', 'restaurant', 'seller', 'trader'].includes(role)) {
            const { createdStr, createdTs } = parseDate(data.createdAt);
            const isRest = role === 'restaurant' || (data.storeName || data.name || '').includes('مطعم');
            merchantUsersList.push({
              merchantId: docSnap.id,
              name: data.storeName || data.restaurantName || data.shopName || data.name || data.fullName || 'متجر شريك',
              category: isRest ? ('restaurant' as const) : ('store' as const),
              subCategory: data.category || (isRest ? 'مطاعم ومأكولات' : 'متاجر وتسوق'),
              ownerName: data.fullName || data.name || 'صاحب الحساب',
              phone: data.phoneNumber || data.phone || 'غير متوفر',
              email: data.email || 'لا يوجد بريد',
              password: data.password || 'غير محددة',
              address: data.address || 'القائم',
              city: data.city || 'القائم',
              isOpen: data.isOpen !== false && data.isAvailable !== false,
              commissionRate: Number(data.commissionRate || (isRest ? 10 : 7)),
              totalOrders: Number(data.totalOrders || data.ordersCount || 0),
              totalRevenueIqd: Number(data.totalRevenue || data.revenue || 0),
              status: data.isApproved === false ? 'pending' : (data.status === 'suspended' ? 'suspended' : 'active'),
              createdAt: createdStr,
              createdTimestamp: createdTs,
              logoUrl: data.logoUrl || data.image || data.profileImage
            });
          }
        });
        notify();
      },
      () => {}
    );

    return () => {
      unsubRest();
      unsubStores();
      unsubPharmacies();
      unsubShops();
      unsubMerchants();
      unsubUsers();
    };
  }

  /**
   * Subscribe to all orders specifically belonging to this merchant
   */
  static subscribeToMerchantOrders(
    merchantId: string,
    merchantName: string,
    callback: (orders: MerchantOrderRecord[]) => void
  ): () => void {
    let globalOrders: MerchantOrderRecord[] = [];
    let subOrders: MerchantOrderRecord[] = [];

    const notify = () => {
      const map = new Map<string, MerchantOrderRecord>();
      [...globalOrders, ...subOrders].forEach(o => map.set(o.orderId, o));
      const merged = Array.from(map.values());
      merged.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(merged);
    };

    const normalizeOrder = (docSnap: any): MerchantOrderRecord => {
      const data = docSnap.data();
      const rawPrice = Number(data.totalPrice || data.totalAmount || data.price || data.amount || 0);
      const deliveryFee = Number(data.deliveryFee || data.deliveryPrice || 0);
      const subtotal = Number(data.subtotal || data.itemsTotal || (rawPrice - deliveryFee) || rawPrice);
      const commissionRate = Number(data.commissionRate || 10);
      const commission = Number(data.commissionAmount || Math.round(subtotal * (commissionRate / 100)));
      const net = Math.max(0, subtotal - commission);

      let createdStr = 'الآن';
      let createdTs = 0;
      if (data.createdAt?.toDate) {
        const dt = data.createdAt.toDate();
        createdStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
        createdTs = dt.getTime();
      } else if (data.createdAt) {
        const dt = new Date(data.createdAt);
        createdStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
        createdTs = !isNaN(dt.getTime()) ? dt.getTime() : 0;
      }

      // Items list
      let itemsList: any[] = [];
      if (Array.isArray(data.items)) {
        itemsList = data.items.map((it: any) => ({
          name: it.name || it.title || it.productName || 'وجبة/صنف',
          quantity: Number(it.quantity || it.count || 1),
          price: Number(it.price || it.unitPrice || 0),
          options: Array.isArray(it.options) ? it.options : (it.selectedOptions || [])
        }));
      }

      return {
        orderId: docSnap.id,
        customerName: data.customerName || data.userName || data.clientName || 'زبون مدار',
        customerPhone: data.customerPhone || data.userPhone || data.phone,
        deliveryAddress: data.deliveryAddress || data.address || 'القائم',
        itemsSummary: data.itemsSummary || (itemsList.length > 0 ? itemsList.map(i => `${i.name} (×${i.quantity})`).join(', ') : 'طلب مأكولات'),
        itemsList,
        totalPriceIqd: rawPrice,
        subtotalIqd: subtotal,
        commissionIqd: commission,
        merchantNetIqd: net,
        driverName: data.driverName || data.captainName,
        driverPhone: data.driverPhone || data.captainPhone,
        status: data.status || 'قيد التحضير',
        rawStatus: (data.status || 'pending').toString().toLowerCase(),
        createdAt: createdStr,
        createdTimestamp: createdTs,
        paymentMethod: data.paymentMethod || 'cash'
      };
    };

    // 1. Listen to root orders collection
    const unsubGlobal = onSnapshot(collection(db, 'orders'), (snapshot) => {
      globalOrders = snapshot.docs
        .filter((d) => {
          const data = d.data();
          const rId = data.restaurantId || data.storeId || data.merchantId || data.vendorId || data.sellerId || data.restaurant_id || data.store_id || data.merchant_id;
          const rName = (data.restaurantName || data.storeName || data.merchantName || data.merchantOrTitle || data.restaurant_name || data.store_name || data.shopName || '').toString().trim().toLowerCase();
          const targetName = merchantName.trim().toLowerCase();

          return (
            rId === merchantId ||
            (rName && (rName === targetName || rName.includes(targetName) || targetName.includes(rName))) ||
            (Array.isArray(data.items) && data.items.some((it: any) => it.restaurantId === merchantId || it.storeId === merchantId || it.merchantId === merchantId))
          );
        })
        .map(normalizeOrder);
      notify();
    }, (err) => console.warn('Merchant root orders stream:', err.message));

    // 2. Listen to subcollection `restaurants/{id}/orders`
    const unsubRestSub = onSnapshot(collection(db, 'restaurants', merchantId, 'orders'), (snapshot) => {
      subOrders = snapshot.docs.map(normalizeOrder);
      notify();
    }, () => {});

    // 3. Listen to subcollection `stores/{id}/orders`
    const unsubStoreSub = onSnapshot(collection(db, 'stores', merchantId, 'orders'), (snapshot) => {
      subOrders = [...subOrders, ...snapshot.docs.map(normalizeOrder)];
      notify();
    }, () => {});

    // 4. Listen to subcollection `stores/{id}/madar_orders`
    const unsubStoreMadar = onSnapshot(collection(db, 'stores', merchantId, 'madar_orders'), (snapshot) => {
      subOrders = [...subOrders, ...snapshot.docs.map(normalizeOrder)];
      notify();
    }, () => {});

    return () => {
      unsubGlobal();
      unsubRestSub();
      unsubStoreSub();
      unsubStoreMadar();
    };
  }

  /**
   * Add a new merchant (Restaurant or Store) directly from Admin
   */
  static async addMerchant(payload: NewMerchantPayload): Promise<string> {
    const colName = payload.category === 'restaurant' ? 'restaurants' : 'stores';
    const colRef = collection(db, colName);

    const isRest = payload.category === 'restaurant';
    const cuisineValue = payload.subCategory || 'مشاوي ومأكولات شرقية';

    const docRef = await addDoc(colRef, {
      name: payload.name.trim(),
      restaurantName: isRest ? payload.name.trim() : undefined,
      storeName: !isRest ? payload.name.trim() : undefined,
      category: isRest ? 'restaurant' : (payload.subCategory || 'متاجر'),
      subCategory: cuisineValue,
      cuisineType: isRest ? cuisineValue : undefined,
      cuisine: isRest ? cuisineValue : undefined,
      categories: isRest ? [cuisineValue] : undefined,
      ownerName: payload.ownerName.trim(),
      phone: payload.phone.trim(),
      phoneNumber: payload.phone.trim(),
      email: payload.email?.trim(),
      initialPassword: payload.password?.trim(),
      isOpen: true,
      isAvailable: true,
      isApproved: true,
      status: 'active',
      commissionRate: payload.commissionRate || (isRest ? 10 : 7),
      address: payload.address || 'قضاء القائم - الأنبار',
      city: 'القائم',
      governorate: 'الأنبار',
      createdAt: serverTimestamp(),
      totalOrders: 0,
      totalRevenue: 0
    });

    try {
      await AuditRepository.logAction(
        'ADD_MERCHANT',
        payload.category,
        docRef.id,
        { name: payload.name, category: payload.category }
      );
    } catch (_) {}

    return docRef.id;
  }

  /**
   * Update Merchant Password / Credentials
   */
  static async updateMerchantPassword(
    merchantId: string, 
    category: 'restaurant' | 'store', 
    newPassword: string
  ): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : 'stores';
    const merchantRef = doc(db, colName, merchantId);

    const payload = {
      password: newPassword.trim(),
      passwordUpdated: true,
      newPasswordTemporary: newPassword.trim(),
      updatedAt: new Date().toISOString()
    };

    await updateDoc(merchantRef, payload).catch(() => {});
    await updateDoc(doc(db, 'users', merchantId), payload).catch(() => {});

    try {
      await AuditRepository.logAction('UPDATE_MERCHANT_PASSWORD', category, merchantId, {
        updatedAt: new Date().toISOString()
      });
    } catch (_) {}
  }

  /**
   * Non-destructive profile update for Restaurant/Store preserving FCM tokens, menu, and notifications
   */
  static async updateMerchantProfile(
    merchantId: string,
    category: 'restaurant' | 'store' | 'pharmacy',
    data: {
      name: string;
      subCategory?: string;
      ownerName: string;
      phone: string;
      email?: string;
      password?: string;
      commissionRate: number;
      address?: string;
      city?: string;
    }
  ): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : (category === 'pharmacy' ? 'pharmacies' : 'stores');
    const merchantRef = doc(db, colName, merchantId);

    // Fetch existing document to guarantee preserving FCM tokens, notifications, and menu
    const existingSnap = await getDoc(merchantRef);
    const existingData = existingSnap.exists() ? existingSnap.data() : {};

    const isRest = category === 'restaurant';
    const cuisineValue = data.subCategory || existingData.subCategory || existingData.cuisineType || 'مشاوي ومأكولات';

    const payload: any = {
      name: data.name.trim(),
      restaurantName: data.name.trim(),
      storeName: data.name.trim(),
      subCategory: cuisineValue,
      category: isRest ? 'restaurant' : (category === 'pharmacy' ? 'pharmacy' : 'store'),
      ownerName: data.ownerName.trim(),
      phone: data.phone.trim(),
      phoneNumber: data.phone.trim(),
      commissionRate: Number(data.commissionRate) || (isRest ? 10 : 7),
      address: data.address || existingData.address || 'القائم',
      city: data.city || existingData.city || 'القائم',
      updatedAt: serverTimestamp()
    };

    if (isRest) {
      payload.cuisineType = cuisineValue;
      payload.cuisine = cuisineValue;
      payload.categories = [cuisineValue];
    }

    if (data.email && data.email.trim()) {
      payload.email = data.email.trim();
    }

    if (data.password && data.password.trim()) {
      payload.password = data.password.trim();
      payload.passwordUpdated = true;
      payload.newPasswordTemporary = data.password.trim();
    }

    // Preserve FCM and push notification tokens safely
    if (existingData.fcmToken) payload.fcmToken = existingData.fcmToken;
    if (existingData.fcmTokens) payload.fcmTokens = existingData.fcmTokens;
    if (existingData.token) payload.token = existingData.token;
    if (existingData.notificationSettings) payload.notificationSettings = existingData.notificationSettings;
    if (existingData.logoUrl) payload.logoUrl = existingData.logoUrl;
    if (existingData.image) payload.image = existingData.image;

    // Use setDoc with merge: true for safe non-destructive update
    await setDoc(merchantRef, payload, { merge: true });

    // Also update in users collection if duplicate exists
    const userRef = doc(db, 'users', merchantId);
    const userSnap = await getDoc(userRef);
    if (userSnap.exists()) {
      const userPayload: any = {
        name: data.name.trim(),
        username: data.ownerName.trim(),
        phone: data.phone.trim(),
        address: data.address || 'القائم',
        updatedAt: serverTimestamp()
      };
      if (data.email && data.email.trim()) userPayload.email = data.email.trim();
      if (data.password && data.password.trim()) userPayload.password = data.password.trim();
      await setDoc(userRef, userPayload, { merge: true });
    }

    try {
      await AuditRepository.logAction(
        'UPDATE_MERCHANT_PROFILE',
        category,
        merchantId,
        { name: data.name, email: data.email, owner: data.ownerName, phone: data.phone }
      );
    } catch (_) {}
  }

  /**
   * Quick update Restaurant Cuisine Category
   */
  static async updateRestaurantCuisineCategory(restaurantId: string, newCuisine: string): Promise<void> {
    const ref = doc(db, 'restaurants', restaurantId);
    await updateDoc(ref, {
      subCategory: newCuisine,
      cuisineType: newCuisine,
      cuisine: newCuisine,
      categories: [newCuisine],
      updatedAt: serverTimestamp()
    });
    try {
      await AuditRepository.logAction('UPDATE_RESTAURANT_CUISINE', 'restaurants', restaurantId, { newCuisine });
    } catch (_) {}
  }

  /**
   * Toggle merchant open/close status in Firestore
   */
  static async toggleMerchantStatus(merchantId: string, category: 'restaurant' | 'store', isOpen: boolean): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : 'stores';
    const merchantRef = doc(db, colName, merchantId);

    await updateDoc(merchantRef, {
      isOpen: isOpen,
      isAvailable: isOpen,
      updatedAt: new Date().toISOString()
    });

    try {
      await AuditRepository.logAction(
        isOpen ? 'OPEN_MERCHANT' : 'CLOSE_MERCHANT',
        category,
        merchantId,
        { isOpen }
      );
    } catch (_) {}
  }

  /**
   * Update custom commission rate for a merchant
   */
  static async updateCommissionRate(merchantId: string, category: 'restaurant' | 'store', rate: number): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : 'stores';
    const merchantRef = doc(db, colName, merchantId);

    await updateDoc(merchantRef, {
      commissionRate: rate,
      updatedAt: new Date().toISOString()
    });

    try {
      await AuditRepository.logAction(
        'UPDATE_COMMISSION_RATE',
        category,
        merchantId,
        { commissionRate: rate }
      );
    } catch (_) {}
  }

  /**
   * Approve a waiting list / pending merchant (Restaurant, Store, Pharmacy)
   */
  static async approveMerchant(merchantId: string, category: 'restaurant' | 'store' | 'pharmacy' | 'sweets'): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : (category === 'pharmacy' ? 'pharmacies' : 'stores');
    const merchantRef = doc(db, colName, merchantId);

    await updateDoc(merchantRef, {
      isApproved: true,
      status: 'active',
      isOpen: true,
      updatedAt: new Date().toISOString()
    });

    try {
      await updateDoc(doc(db, 'merchants', merchantId), { isApproved: true, status: 'active', isOpen: true, updatedAt: new Date().toISOString() });
    } catch (_) {}

    try {
      await updateDoc(doc(db, 'users', merchantId), { isApproved: true, status: 'active', updatedAt: new Date().toISOString() });
    } catch (_) {}

    try {
      await AuditRepository.logAction(
        'APPROVE_MERCHANT',
        category,
        merchantId,
        { isApproved: true, status: 'active' }
      );
    } catch (_) {}
  }

  /**
   * Suspend / Reject a merchant
   */
  static async suspendMerchant(merchantId: string, category: 'restaurant' | 'store' | 'pharmacy' | 'sweets', reason?: string): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : (category === 'pharmacy' ? 'pharmacies' : 'stores');
    const merchantRef = doc(db, colName, merchantId);

    await updateDoc(merchantRef, {
      status: 'suspended',
      isOpen: false,
      suspensionReason: reason || 'موقوف إدارياً',
      updatedAt: new Date().toISOString()
    });

    try {
      await updateDoc(doc(db, 'merchants', merchantId), { status: 'suspended', isOpen: false, updatedAt: new Date().toISOString() });
    } catch (_) {}

    try {
      await updateDoc(doc(db, 'users', merchantId), { status: 'suspended', isBlocked: true, updatedAt: new Date().toISOString() });
    } catch (_) {}

    try {
      await AuditRepository.logAction(
        'SUSPEND_MERCHANT',
        category,
        merchantId,
        { status: 'suspended', reason }
      );
    } catch (_) {}
  }

  /**
   * Delete a merchant completely (Restaurant or Store)
   */
  static async deleteMerchant(merchantId: string, category: 'restaurant' | 'store'): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : 'stores';
    const merchantRef = doc(db, colName, merchantId);

    // 1. Delete primary doc
    await deleteDoc(merchantRef).catch(() => {});

    // 2. Also delete in the alternate collection if dual-registered
    const altCol = category === 'restaurant' ? 'stores' : 'restaurants';
    await deleteDoc(doc(db, altCol, merchantId)).catch(() => {});

    // 3. Mark or delete associated user account
    await deleteDoc(doc(db, 'users', merchantId)).catch(() => {});

    try {
      await AuditRepository.logAction(
        'DELETE_MERCHANT',
        category,
        merchantId,
        { category }
      );
    } catch (_) {}
  }

  /**
   * Update Merchant Name, Subcategory, Contact, Email, & Password without losing data
   */
  static async updateMerchantDetails(
    merchantId: string, 
    category: 'restaurant' | 'store', 
    details: { 
      name?: string; 
      subCategory?: string; 
      ownerName?: string;
      phone?: string; 
      email?: string;
      password?: string;
      address?: string;
      city?: string;
      commissionRate?: number; 
    }
  ): Promise<void> {
    const colName = category === 'restaurant' ? 'restaurants' : 'stores';
    const merchantRef = doc(db, colName, merchantId);

    const payload: Record<string, any> = {
      updatedAt: new Date().toISOString()
    };

    if (details.name !== undefined) {
      payload.name = details.name;
      if (category === 'restaurant') payload.restaurantName = details.name;
      if (category === 'store') payload.storeName = details.name;
    }
    if (details.subCategory !== undefined) payload.subCategory = details.subCategory;
    if (details.ownerName !== undefined) payload.ownerName = details.ownerName;
    if (details.phone !== undefined) {
      payload.phone = details.phone;
      payload.phoneNumber = details.phone;
    }
    if (details.email !== undefined) {
      payload.email = details.email;
      payload.ownerEmail = details.email;
    }
    if (details.password !== undefined && details.password.trim().length > 0) {
      payload.password = details.password.trim();
      payload.initialPassword = details.password.trim();
      payload.newPasswordTemporary = details.password.trim();
    }
    if (details.address !== undefined) payload.address = details.address;
    if (details.city !== undefined) payload.city = details.city;
    if (details.commissionRate !== undefined) payload.commissionRate = details.commissionRate;

    // Use updateDoc to strictly update fields safely without wiping any existing data
    await updateDoc(merchantRef, payload);

    // Also sync email & password to user account if exists
    try {
      const userPayload: Record<string, any> = {};
      if (payload.email) userPayload.email = payload.email;
      if (payload.password) {
        userPayload.password = payload.password;
        userPayload.passwordUpdated = true;
      }
      if (Object.keys(userPayload).length > 0) {
        await updateDoc(doc(db, 'users', merchantId), userPayload).catch(() => {});
      }
    } catch (_) {}

    try {
      await AuditRepository.logAction(
        'UPDATE_MERCHANT_DETAILS',
        category,
        merchantId,
        details
      );
    } catch (_) {}
  }

  /**
   * Helper: Find all section item document references for a given merchant/restaurant ID
   */
  static async findSectionItemRefs(merchantId: string, restaurantName?: string): Promise<Array<{ sectionId: string; itemId: string; ref: any }>> {
    const results: Array<{ sectionId: string; itemId: string; ref: any }> = [];
    try {
      const sectionsSnap = await getDocs(collection(db, 'sections'));
      for (const secDoc of sectionsSnap.docs) {
        const itemsRef = collection(db, 'sections', secDoc.id, 'items');
        
        // 1. Query by ownerId
        const qOwner = query(itemsRef, where('ownerId', '==', merchantId));
        const snapOwner = await getDocs(qOwner);
        for (const itemDoc of snapOwner.docs) {
          results.push({ sectionId: secDoc.id, itemId: itemDoc.id, ref: itemDoc.ref });
        }

        // 2. Direct document ID match
        const directDocRef = doc(db, 'sections', secDoc.id, 'items', merchantId);
        const directDocSnap = await getDoc(directDocRef);
        if (directDocSnap.exists() && !results.some(r => r.itemId === merchantId && r.sectionId === secDoc.id)) {
          results.push({ sectionId: secDoc.id, itemId: merchantId, ref: directDocRef });
        }

        // 3. Match by name if provided
        if (restaurantName) {
          const qName = query(itemsRef, where('pageName', '==', restaurantName));
          const snapName = await getDocs(qName);
          for (const itemDoc of snapName.docs) {
            if (!results.some(r => r.itemId === itemDoc.id && r.sectionId === secDoc.id)) {
              results.push({ sectionId: secDoc.id, itemId: itemDoc.id, ref: itemDoc.ref });
            }
          }
        }
      }
    } catch (e) {
      console.warn('Error discovering section items:', e);
    }
    return results;
  }

  /**
   * Dual-Source Live Subscriber for Restaurant Menu Meals and Sections/Categories
   */
  static subscribeToRestaurantMenuAndCategories(
    restaurantId: string,
    restaurantName: string | undefined,
    callback: (data: { products: ProductItemEntity[]; categories: MenuCategoryEntity[] }) => void
  ): () => void {
    let directProducts: ProductItemEntity[] = [];
    let sectionProducts: ProductItemEntity[] = [];
    let directCategories: MenuCategoryEntity[] = [];
    let sectionCategories: MenuCategoryEntity[] = [];
    let embeddedProducts: ProductItemEntity[] = [];
    let embeddedCategories: MenuCategoryEntity[] = [];

    const unsubs: Array<() => void> = [];

    const emit = () => {
      // Merge unique products by ID / normalized name
      const prodMap = new Map<string, ProductItemEntity>();
      
      [...directProducts, ...sectionProducts, ...embeddedProducts].forEach((p) => {
        const key = p.id || p.name.trim().toLowerCase();
        if (!prodMap.has(key)) {
          prodMap.set(key, p);
        } else {
          const existing = prodMap.get(key)!;
          prodMap.set(key, { ...existing, ...p, id: existing.id || p.id });
        }
      });

      const finalProducts = Array.from(prodMap.values());

      // Merge unique categories by name
      const catMap = new Map<string, MenuCategoryEntity>();
      
      [...directCategories, ...sectionCategories, ...embeddedCategories].forEach((c) => {
        const name = c.name.trim();
        if (name && !catMap.has(name.toLowerCase())) {
          catMap.set(name.toLowerCase(), {
            ...c,
            itemCount: finalProducts.filter(p => (p.category || '').toLowerCase() === name.toLowerCase()).length
          });
        }
      });

      // Also extract categories from products if not listed in categories
      finalProducts.forEach((p) => {
        const catName = (p.category || '').trim();
        if (catName && !catMap.has(catName.toLowerCase())) {
          catMap.set(catName.toLowerCase(), {
            id: `cat_${catName}`,
            name: catName,
            itemCount: finalProducts.filter(item => (item.category || '').toLowerCase() === catName.toLowerCase()).length
          });
        }
      });

      const finalCategories = Array.from(catMap.values());
      callback({ products: finalProducts, categories: finalCategories });
    };

    // 1. Direct listeners on restaurants/{restaurantId}/menu and categories
    const menuRef = collection(db, 'restaurants', restaurantId, 'menu');
    unsubs.push(
      onSnapshot(menuRef, (snap) => {
        directProducts = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            name: data.name || data.mealName || data.title || 'وجبة',
            description: data.description || '',
            price: Number(data.price || data.mealPrice || data.cost || 0),
            category: data.category || data.section || 'وجبات رئيسية',
            imageUrl: data.image || data.imageUrl || data.mealImage || data.photoUrl,
            isAvailable: data.isAvailable !== false && data.inStock !== false,
            salesCount: Number(data.salesCount || data.ordersCount || 0),
            sizes: Array.isArray(data.sizes) ? data.sizes : [],
            extras: Array.isArray(data.extras) ? data.extras : []
          };
        });
        emit();
      }, (err) => console.warn('Direct menu stream error:', err.message))
    );

    const catRef = collection(db, 'restaurants', restaurantId, 'categories');
    unsubs.push(
      onSnapshot(catRef, (snap) => {
        directCategories = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            name: data.name || data.title || 'قسم',
            iconCode: data.iconCode
          };
        });
        emit();
      }, (err) => console.warn('Direct categories stream error:', err.message))
    );

    // 2. Direct restaurant document listener for embedded menu/categories
    const restDocRef = doc(db, 'restaurants', restaurantId);
    unsubs.push(
      onSnapshot(restDocRef, (snap) => {
        if (snap.exists()) {
          const data = snap.data() || {};
          if (Array.isArray(data.menu)) {
            embeddedProducts = data.menu.map((m: any, idx: number) => ({
              id: m.id || `embedded_${idx}`,
              name: m.name || m.mealName || 'وجبة',
              description: m.description || '',
              price: Number(m.price || 0),
              category: m.category || 'وجبات رئيسية',
              imageUrl: m.imageUrl || m.image,
              isAvailable: m.isAvailable !== false,
              salesCount: Number(m.salesCount || 0)
            }));
          }
          if (Array.isArray(data.categories)) {
            embeddedCategories = data.categories.map((c: any, idx: number) => 
              typeof c === 'string' ? { id: `cat_${idx}`, name: c } : { id: c.id || `cat_${idx}`, name: c.name || 'قسم', iconCode: c.iconCode }
            );
          }
          emit();
        }
      }, (err) => console.warn('Restaurant doc stream error:', err.message))
    );

    // 3. Sections Discovery & Listeners (Sync with Merchant App items)
    this.findSectionItemRefs(restaurantId, restaurantName).then((refs) => {
      for (const item of refs) {
        // Menu subcollection inside sections
        const secMenuRef = collection(db, 'sections', item.sectionId, 'items', item.itemId, 'menu');
        unsubs.push(
          onSnapshot(secMenuRef, (snap) => {
            sectionProducts = snap.docs.map((d) => {
              const data = d.data();
              return {
                id: d.id,
                name: data.name || data.mealName || data.title || 'وجبة',
                description: data.description || '',
                price: Number(data.price || data.mealPrice || 0),
                category: data.category || data.section || 'وجبات رئيسية',
                imageUrl: data.image || data.imageUrl || data.mealImage,
                isAvailable: data.isAvailable !== false && data.inStock !== false,
                salesCount: Number(data.salesCount || 0),
                sizes: Array.isArray(data.sizes) ? data.sizes : [],
                extras: Array.isArray(data.extras) ? data.extras : []
              };
            });
            emit();
          }, (err) => console.warn('Section menu stream error:', err.message))
        );

        // Categories subcollection inside sections
        const secCatRef = collection(db, 'sections', item.sectionId, 'items', item.itemId, 'categories');
        unsubs.push(
          onSnapshot(secCatRef, (snap) => {
            sectionCategories = snap.docs.map((d) => {
              const data = d.data();
              return {
                id: d.id,
                name: data.name || data.title || 'قسم',
                iconCode: data.iconCode,
                sectionId: item.sectionId,
                itemId: item.itemId
              };
            });
            emit();
          }, (err) => console.warn('Section categories stream error:', err.message))
        );
      }
    });

    return () => {
      unsubs.forEach((u) => u());
    };
  }

  /**
   * Add Category / Section to Restaurant (Dual-synced to restaurants and sections)
   */
  static async addRestaurantMenuCategory(
    restaurantId: string,
    restaurantName: string | undefined,
    categoryName: string
  ): Promise<string> {
    const trimmed = categoryName.trim();
    if (!trimmed) throw new Error('اسم القسم مطلوب');

    // 1. Add to restaurants/{id}/categories
    const catCol = collection(db, 'restaurants', restaurantId, 'categories');
    const docRef = await addDoc(catCol, {
      name: trimmed,
      iconCode: 0xe2aa,
      createdAt: serverTimestamp()
    });

    // 2. Also append to categories array on restaurant doc
    try {
      const restDocRef = doc(db, 'restaurants', restaurantId);
      await updateDoc(restDocRef, {
        categories: arrayUnion(trimmed),
        updatedAt: serverTimestamp()
      });
    } catch (_) {}

    // 3. Sync to sections items
    try {
      const refs = await this.findSectionItemRefs(restaurantId, restaurantName);
      for (const item of refs) {
        const secCatCol = collection(db, 'sections', item.sectionId, 'items', item.itemId, 'categories');
        const qExist = query(secCatCol, where('name', '==', trimmed));
        const existSnap = await getDocs(qExist);
        if (existSnap.docs.length === 0) {
          await addDoc(secCatCol, {
            name: trimmed,
            iconCode: 0xe2aa,
            createdAt: serverTimestamp()
          });
        }
      }
    } catch (e) {
      console.warn('Sync add category error:', e);
    }

    try {
      await AuditRepository.logAction('ADD_MENU_CATEGORY', 'restaurants', `${restaurantId}/${docRef.id}`, { categoryName: trimmed });
    } catch (_) {}

    return docRef.id;
  }

  /**
   * Delete Category / Section from Restaurant
   */
  static async deleteRestaurantMenuCategory(
    restaurantId: string,
    restaurantName: string | undefined,
    categoryId: string,
    categoryName: string
  ): Promise<void> {
    // 1. Delete from restaurants/{id}/categories
    try {
      const ref = doc(db, 'restaurants', restaurantId, 'categories', categoryId);
      await deleteDoc(ref);
    } catch (_) {}

    // 2. Remove from categories array on restaurant doc
    try {
      const restDocRef = doc(db, 'restaurants', restaurantId);
      await updateDoc(restDocRef, {
        categories: arrayRemove(categoryName),
        updatedAt: serverTimestamp()
      });
    } catch (_) {}

    // 3. Delete from sections items
    try {
      const refs = await this.findSectionItemRefs(restaurantId, restaurantName);
      for (const item of refs) {
        const secCatCol = collection(db, 'sections', item.sectionId, 'items', item.itemId, 'categories');
        const qExist = query(secCatCol, where('name', '==', categoryName));
        const existSnap = await getDocs(qExist);
        for (const d of existSnap.docs) {
          await deleteDoc(d.ref);
        }
      }
    } catch (e) {
      console.warn('Sync delete category error:', e);
    }

    try {
      await AuditRepository.logAction('DELETE_MENU_CATEGORY', 'restaurants', `${restaurantId}/${categoryId}`, { categoryName });
    } catch (_) {}
  }

  /**
   * Subscribe to real products / menu items of a store or generic merchant
   */
  static subscribeToProducts(
    merchantId: string, 
    category: 'restaurant' | 'store', 
    callback: (products: ProductItemEntity[]) => void
  ): () => void {
    if (category === 'restaurant') {
      return this.subscribeToRestaurantMenuAndCategories(merchantId, undefined, ({ products }) => {
        callback(products);
      });
    }

    const parentCol = 'stores';
    const subCol = 'products';
    const q = collection(db, parentCol, merchantId, subCol);

    return onSnapshot(
      q,
      (snapshot) => {
        const list: ProductItemEntity[] = snapshot.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            name: data.name || data.title || 'منتج',
            description: data.description || '',
            price: Number(data.price || data.cost || 0),
            category: data.category || data.section || 'عام',
            imageUrl: data.image || data.imageUrl || data.photoUrl,
            isAvailable: data.isAvailable !== false && data.inStock !== false,
            salesCount: Number(data.salesCount || data.ordersCount || data.soldCount || 0),
            sizes: Array.isArray(data.sizes) ? data.sizes : [],
            extras: Array.isArray(data.extras) ? data.extras : []
          };
        });

        callback(list);
      },
      (err) => {
        console.warn(`Products stream error for ${merchantId}:`, err.message);
        callback([]);
      }
    );
  }

  /**
   * Add a new product / menu item to a merchant (Dual-synced)
   */
  static async addProduct(
    merchantId: string, 
    category: 'restaurant' | 'store', 
    product: Omit<ProductItemEntity, 'id'>,
    restaurantName?: string
  ): Promise<string> {
    const parentCol = category === 'restaurant' ? 'restaurants' : 'stores';
    const subCol = category === 'restaurant' ? 'menu' : 'products';

    // 1. Write to direct collection
    const subColRef = collection(db, parentCol, merchantId, subCol);
    const docRef = await addDoc(subColRef, {
      ...product,
      mealName: product.name,
      mealPrice: product.price,
      mealImage: product.imageUrl || '',
      createdAt: serverTimestamp(),
      salesCount: 0
    });

    // 2. Dual-sync to sections if it's a restaurant
    if (category === 'restaurant') {
      try {
        const refs = await this.findSectionItemRefs(merchantId, restaurantName);
        for (const item of refs) {
          const secMenuDocRef = doc(db, 'sections', item.sectionId, 'items', item.itemId, 'menu', docRef.id);
          await setDoc(secMenuDocRef, {
            name: product.name,
            mealName: product.name,
            price: product.price,
            mealPrice: product.price,
            category: product.category,
            description: product.description,
            imageUrl: product.imageUrl || '',
            mealImage: product.imageUrl || '',
            isAvailable: product.isAvailable,
            createdAt: serverTimestamp()
          });

          // Ensure category exists
          if (product.category && product.category !== 'الكل') {
            const secCatCol = collection(db, 'sections', item.sectionId, 'items', item.itemId, 'categories');
            const qExist = query(secCatCol, where('name', '==', product.category));
            const snapExist = await getDocs(qExist);
            if (snapExist.docs.length === 0) {
              await addDoc(secCatCol, {
                name: product.category,
                iconCode: 0xe2aa,
                createdAt: serverTimestamp()
              });
            }
          }
        }
      } catch (e) {
        console.warn('Sync add meal to section error:', e);
      }
    }

    try {
      await AuditRepository.logAction(
        'ADD_PRODUCT',
        category,
        `${merchantId}/${docRef.id}`,
        { name: product.name, price: product.price, category: product.category }
      );
    } catch (_) {}

    return docRef.id;
  }

  /**
   * Update an existing product (Dual-synced)
   */
  static async updateProduct(
    merchantId: string, 
    category: 'restaurant' | 'store', 
    productId: string, 
    data: Partial<ProductItemEntity>,
    restaurantName?: string
  ): Promise<void> {
    const parentCol = category === 'restaurant' ? 'restaurants' : 'stores';
    const subCol = category === 'restaurant' ? 'menu' : 'products';

    // 1. Update direct doc
    const productRef = doc(db, parentCol, merchantId, subCol, productId);
    await setDoc(productRef, {
      ...data,
      mealName: data.name,
      mealPrice: data.price,
      mealImage: data.imageUrl,
      updatedAt: serverTimestamp()
    }, { merge: true });

    // 2. Dual-sync update to sections
    if (category === 'restaurant') {
      try {
        const refs = await this.findSectionItemRefs(merchantId, restaurantName);
        for (const item of refs) {
          const secMenuDocRef = doc(db, 'sections', item.sectionId, 'items', item.itemId, 'menu', productId);
          await setDoc(secMenuDocRef, {
            ...data,
            mealName: data.name,
            mealPrice: data.price,
            mealImage: data.imageUrl,
            updatedAt: serverTimestamp()
          }, { merge: true });
        }
      } catch (e) {
        console.warn('Sync update meal error:', e);
      }
    }

    try {
      await AuditRepository.logAction(
        'UPDATE_PRODUCT',
        category,
        `${merchantId}/${productId}`,
        data
      );
    } catch (_) {}
  }

  /**
   * Delete a product from a merchant's menu/catalog (Dual-synced)
   */
  static async deleteProduct(
    merchantId: string, 
    category: 'restaurant' | 'store', 
    productId: string,
    restaurantName?: string
  ): Promise<void> {
    const parentCol = category === 'restaurant' ? 'restaurants' : 'stores';
    const subCol = category === 'restaurant' ? 'menu' : 'products';

    // 1. Delete direct doc
    try {
      const productRef = doc(db, parentCol, merchantId, subCol, productId);
      await deleteDoc(productRef);
    } catch (_) {}

    // 2. Dual-sync delete from sections
    if (category === 'restaurant') {
      try {
        const refs = await this.findSectionItemRefs(merchantId, restaurantName);
        for (const item of refs) {
          const secMenuDocRef = doc(db, 'sections', item.sectionId, 'items', item.itemId, 'menu', productId);
          await deleteDoc(secMenuDocRef);
        }
      } catch (e) {
        console.warn('Sync delete meal error:', e);
      }
    }

    try {
      await AuditRepository.logAction(
        'DELETE_PRODUCT',
        category,
        `${merchantId}/${productId}`,
        { productId }
      );
    } catch (_) {}
  }

  /**
   * Toggle product availability (inStock / isAvailable) (Dual-synced)
   */
  static async toggleProductAvailability(
    merchantId: string,
    category: 'restaurant' | 'store',
    productId: string,
    isAvailable: boolean,
    restaurantName?: string
  ): Promise<void> {
    const parentCol = category === 'restaurant' ? 'restaurants' : 'stores';
    const subCol = category === 'restaurant' ? 'menu' : 'products';

    try {
      const productRef = doc(db, parentCol, merchantId, subCol, productId);
      await setDoc(productRef, {
        isAvailable,
        inStock: isAvailable,
        updatedAt: serverTimestamp()
      }, { merge: true });
    } catch (_) {}

    if (category === 'restaurant') {
      try {
        const refs = await this.findSectionItemRefs(merchantId, restaurantName);
        for (const item of refs) {
          const secMenuDocRef = doc(db, 'sections', item.sectionId, 'items', item.itemId, 'menu', productId);
          await setDoc(secMenuDocRef, {
            isAvailable,
            inStock: isAvailable,
            updatedAt: serverTimestamp()
          }, { merge: true });
        }
      } catch (_) {}
    }
  }
}

