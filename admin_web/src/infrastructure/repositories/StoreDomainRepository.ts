import { 
  collection, 
  onSnapshot, 
  doc, 
  getDocs,
  updateDoc, 
  setDoc, 
  deleteDoc, 
  addDoc,
  serverTimestamp,
  query,
  where,
  limit
} from 'firebase/firestore';
import { db } from '../firebase';
import { StoreEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export interface StoreProductItemEntity {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  imageUrl?: string;
  isAvailable: boolean;
  salesCount: number;
  stockQuantity?: number;
  barcode?: string;
}

export interface StoreCategoryEntity {
  id: string;
  name: string;
  iconCode?: number;
  itemCount?: number;
}

export class StoreDomainRepository {
  /**
   * Subscribe strictly to `stores` collection
   */
  static subscribeToStores(callback: (stores: StoreEntity[]) => void): () => void {
    return onSnapshot(collection(db, 'stores'), (snapshot) => {
      const list: StoreEntity[] = snapshot.docs.map((d) => {
        const data = d.data();
        
        let createdStr = 'الآن';
        let createdTs = 0;
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
          storeId: d.id,
          merchantId: d.id,
          name: data.name || data.storeName || data.title || 'متجر مدار',
          ownerName: data.ownerName || data.managerName || data.contactName || 'صاحب المتجر',
          phone: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
          email: data.email,
          password: data.password,
          address: data.address || data.locationName || 'القائم',
          city: data.city || data.governorate || 'القائم',
          storeCategory: data.storeCategory || data.category || 'سوبرماركت وهايبرماركت',
          subCategory: data.subCategory || data.specialty,
          isOpen: data.isOpen !== false && data.isAvailable !== false,
          commissionRate: Number(data.commissionRate ?? data.commission ?? 10),
          totalOrders: Number(data.totalOrders || data.ordersCount || 0),
          totalRevenueIqd: Number(data.totalRevenue || data.revenue || data.totalSales || 0),
          status: data.status === 'suspended' ? 'suspended' : (data.status === 'pending' ? 'pending' : 'active'),
          createdAt: createdStr,
          createdTimestamp: createdTs,
          logoUrl: data.logoUrl || data.logo || data.imageUrl || data.image,
          coverImageUrl: data.coverImageUrl || data.coverUrl || data.bannerUrl,
          openingTime: data.openingTime || '08:00 ص',
          closingTime: data.closingTime || '11:00 م',
          minimumOrderIqd: Number(data.minimumOrderIqd || 5000)
        };
      });

      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => console.warn('stores stream error:', err.message));
  }

  /**
   * Add new Store to `stores` collection
   */
  static async addStore(payload: {
    name: string;
    storeCategory: string;
    ownerName: string;
    phone: string;
    email?: string;
    password?: string;
    address?: string;
    commissionRate?: number;
  }): Promise<string> {
    const docRef = await addDoc(collection(db, 'stores'), {
      name: payload.name,
      storeName: payload.name,
      storeCategory: payload.storeCategory,
      category: payload.storeCategory,
      ownerName: payload.ownerName,
      phoneNumber: payload.phone,
      phone: payload.phone,
      email: payload.email || '',
      password: payload.password || '123456',
      address: payload.address || 'قضاء القائم',
      city: 'القائم',
      governorate: 'الأنبار',
      commissionRate: payload.commissionRate || 10,
      isOpen: true,
      isAvailable: true,
      status: 'active',
      totalOrders: 0,
      totalRevenue: 0,
      rating: 5.0,
      createdAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: 'CREATE_STORE',
      targetResource: `stores/${docRef.id}`,
      payload: { name: payload.name, category: payload.storeCategory }
    });

    return docRef.id;
  }

  /**
   * Update Store profile
   */
  static async updateStore(storeId: string, updates: Partial<StoreEntity>): Promise<void> {
    const payload: Record<string, any> = { ...updates, updatedAt: serverTimestamp() };
    if (updates.name) payload.storeName = updates.name;
    if (updates.phone) payload.phoneNumber = updates.phone;

    await updateDoc(doc(db, 'stores', storeId), payload);

    AuditRepository.logAction({
      action: 'UPDATE_STORE',
      targetResource: `stores/${storeId}`,
      payload: updates
    });
  }

  /**
   * Toggle Store Open / Closed Status
   */
  static async toggleStoreOpenStatus(storeId: string, isOpen: boolean): Promise<void> {
    await updateDoc(doc(db, 'stores', storeId), {
      isOpen,
      isAvailable: isOpen,
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: isOpen ? 'OPEN_STORE' : 'CLOSE_STORE',
      targetResource: `stores/${storeId}`,
      payload: { isOpen }
    });
  }

  /**
   * Suspend / Activate Store
   */
  static async setStoreStatus(storeId: string, status: 'active' | 'suspended'): Promise<void> {
    await updateDoc(doc(db, 'stores', storeId), {
      status,
      isOpen: status === 'active',
      isAvailable: status === 'active',
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: status === 'active' ? 'ACTIVATE_STORE' : 'SUSPEND_STORE',
      targetResource: `stores/${storeId}`,
      payload: { status }
    });
  }

  /**
   * Delete Store
   */
  static async deleteStore(storeId: string): Promise<void> {
    await deleteDoc(doc(db, 'stores', storeId));

    AuditRepository.logAction({
      action: 'DELETE_STORE',
      targetResource: `stores/${storeId}`,
      payload: { storeId }
    });
  }

  /**
   * Update Store Commission Rate
   */
  static async updateStoreCommission(storeId: string, commissionRate: number): Promise<void> {
    await updateDoc(doc(db, 'stores', storeId), {
      commissionRate,
      commission: commissionRate,
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: 'UPDATE_STORE_COMMISSION',
      targetResource: `stores/${storeId}`,
      payload: { commissionRate }
    });
  }

  /**
   * Update Store Password
   */
  static async updateStorePassword(storeId: string, newPass: string): Promise<void> {
    await updateDoc(doc(db, 'stores', storeId), {
      password: newPass,
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: 'RESET_STORE_PASSWORD',
      targetResource: `stores/${storeId}`,
      payload: { storeId }
    });
  }

  // ──────── PRODUCTS MANAGEMENT (stores/{id}/products) ────────

  /**
   * Subscribe to Store Products
   */
  static subscribeToProducts(storeId: string, callback: (items: StoreProductItemEntity[]) => void): () => void {
    const prodCol = collection(db, 'stores', storeId, 'products');
    return onSnapshot(prodCol, (snapshot) => {
      const items: StoreProductItemEntity[] = snapshot.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name || data.title || 'منتج',
          description: data.description || '',
          price: Number(data.price || 0),
          category: data.category || 'عام',
          imageUrl: data.imageUrl || data.image || data.photoUrl,
          isAvailable: data.isAvailable !== false,
          salesCount: Number(data.salesCount || data.ordersCount || 0),
          stockQuantity: data.stockQuantity !== undefined ? Number(data.stockQuantity) : undefined,
          barcode: data.barcode
        };
      });
      callback(items);
    }, (err) => console.warn('store products stream:', err.message));
  }

  /**
   * Add Product Item
   */
  static async addProduct(storeId: string, item: Omit<StoreProductItemEntity, 'id' | 'salesCount'>): Promise<string> {
    const docRef = await addDoc(collection(db, 'stores', storeId, 'products'), {
      ...item,
      salesCount: 0,
      createdAt: serverTimestamp()
    });
    return docRef.id;
  }

  /**
   * Update Product Item
   */
  static async updateProduct(storeId: string, productId: string, updates: Partial<StoreProductItemEntity>): Promise<void> {
    await updateDoc(doc(db, 'stores', storeId, 'products', productId), {
      ...updates,
      updatedAt: serverTimestamp()
    });
  }

  /**
   * Delete Product Item
   */
  static async deleteProduct(storeId: string, productId: string): Promise<void> {
    await deleteDoc(doc(db, 'stores', storeId, 'products', productId));
  }

  // ──────── CATEGORIES MANAGEMENT (stores/{id}/categories) ────────

  /**
   * Subscribe to Store Categories
   */
  static subscribeToCategories(storeId: string, callback: (cats: StoreCategoryEntity[]) => void): () => void {
    const catsCol = collection(db, 'stores', storeId, 'categories');
    return onSnapshot(catsCol, (snapshot) => {
      const cats: StoreCategoryEntity[] = snapshot.docs.map((d) => ({
        id: d.id,
        name: d.data().name || 'قسم',
        iconCode: d.data().iconCode,
        itemCount: d.data().itemCount
      }));
      callback(cats);
    }, (err) => console.warn('store categories stream:', err.message));
  }

  /**
   * Add Category
   */
  static async addCategory(storeId: string, name: string): Promise<string> {
    const docRef = await addDoc(collection(db, 'stores', storeId, 'categories'), {
      name,
      createdAt: serverTimestamp()
    });
    return docRef.id;
  }

  /**
   * Delete Category
   */
  static async deleteCategory(storeId: string, categoryId: string): Promise<void> {
    await deleteDoc(doc(db, 'stores', storeId, 'categories', categoryId));
  }
}
