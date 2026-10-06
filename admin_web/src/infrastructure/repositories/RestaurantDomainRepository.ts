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
import { RestaurantEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export interface RestaurantMenuItemEntity {
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

export interface RestaurantMenuCategoryEntity {
  id: string;
  name: string;
  iconCode?: number;
  itemCount?: number;
}

export class RestaurantDomainRepository {
  /**
   * Subscribe strictly to `restaurants` collection
   */
  static subscribeToRestaurants(callback: (restaurants: RestaurantEntity[]) => void): () => void {
    return onSnapshot(collection(db, 'restaurants'), (snapshot) => {
      const list: RestaurantEntity[] = snapshot.docs.map((d) => {
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
          restaurantId: d.id,
          merchantId: d.id,
          name: data.name || data.restaurantName || data.title || 'مطعم مدار',
          ownerName: data.ownerName || data.managerName || data.contactName || 'صاحب المطعم',
          phone: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
          email: data.email,
          password: data.password,
          address: data.address || data.locationName || 'القائم',
          city: data.city || data.governorate || 'القائم',
          cuisineType: data.cuisineType || data.category || 'مأكولات ومشاوي',
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
          openingTime: data.openingTime || '09:00 ص',
          closingTime: data.closingTime || '11:30 م',
          estimatedPrepMinutes: Number(data.estimatedPrepMinutes || 25),
          minimumOrderIqd: Number(data.minimumOrderIqd || 3000)
        };
      });

      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => console.warn('restaurants stream error:', err.message));
  }

  /**
   * Add new Restaurant to `restaurants` collection
   */
  static async addRestaurant(payload: {
    name: string;
    cuisineType: string;
    ownerName: string;
    phone: string;
    email?: string;
    password?: string;
    address?: string;
    commissionRate?: number;
  }): Promise<string> {
    const docRef = await addDoc(collection(db, 'restaurants'), {
      name: payload.name,
      restaurantName: payload.name,
      cuisineType: payload.cuisineType,
      category: payload.cuisineType,
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
      action: 'CREATE_RESTAURANT',
      targetResource: `restaurants/${docRef.id}`,
      payload: { name: payload.name, cuisine: payload.cuisineType }
    });

    return docRef.id;
  }

  /**
   * Update Restaurant profile
   */
  static async updateRestaurant(restaurantId: string, updates: Partial<RestaurantEntity>): Promise<void> {
    const payload: Record<string, any> = { ...updates, updatedAt: serverTimestamp() };
    if (updates.name) payload.restaurantName = updates.name;
    if (updates.phone) payload.phoneNumber = updates.phone;

    await updateDoc(doc(db, 'restaurants', restaurantId), payload);

    AuditRepository.logAction({
      action: 'UPDATE_RESTAURANT',
      targetResource: `restaurants/${restaurantId}`,
      payload: updates
    });
  }

  /**
   * Toggle Restaurant Open / Closed Status
   */
  static async toggleRestaurantOpenStatus(restaurantId: string, isOpen: boolean): Promise<void> {
    await updateDoc(doc(db, 'restaurants', restaurantId), {
      isOpen,
      isAvailable: isOpen,
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: isOpen ? 'OPEN_RESTAURANT' : 'CLOSE_RESTAURANT',
      targetResource: `restaurants/${restaurantId}`,
      payload: { isOpen }
    });
  }

  /**
   * Suspend / Activate Restaurant
   */
  static async setRestaurantStatus(restaurantId: string, status: 'active' | 'suspended'): Promise<void> {
    await updateDoc(doc(db, 'restaurants', restaurantId), {
      status,
      isOpen: status === 'active',
      isAvailable: status === 'active',
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: status === 'active' ? 'ACTIVATE_RESTAURANT' : 'SUSPEND_RESTAURANT',
      targetResource: `restaurants/${restaurantId}`,
      payload: { status }
    });
  }

  /**
   * Delete Restaurant
   */
  static async deleteRestaurant(restaurantId: string): Promise<void> {
    await deleteDoc(doc(db, 'restaurants', restaurantId));

    AuditRepository.logAction({
      action: 'DELETE_RESTAURANT',
      targetResource: `restaurants/${restaurantId}`,
      payload: { restaurantId }
    });
  }

  /**
   * Update Restaurant Commission Rate
   */
  static async updateRestaurantCommission(restaurantId: string, commissionRate: number): Promise<void> {
    await updateDoc(doc(db, 'restaurants', restaurantId), {
      commissionRate,
      commission: commissionRate,
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: 'UPDATE_RESTAURANT_COMMISSION',
      targetResource: `restaurants/${restaurantId}`,
      payload: { commissionRate }
    });
  }

  /**
   * Update Restaurant Password
   */
  static async updateRestaurantPassword(restaurantId: string, newPass: string): Promise<void> {
    await updateDoc(doc(db, 'restaurants', restaurantId), {
      password: newPass,
      updatedAt: serverTimestamp()
    });

    AuditRepository.logAction({
      action: 'RESET_RESTAURANT_PASSWORD',
      targetResource: `restaurants/${restaurantId}`,
      payload: { restaurantId }
    });
  }

  /**
   * Subscribe to Restaurant Menu items and Categories with discovery fallback
   */
  static subscribeToRestaurantMenuAndCategories(
    restaurantId: string,
    restaurantName: string,
    callback: (res: { products: RestaurantMenuItemEntity[]; categories: RestaurantMenuCategoryEntity[] }) => void
  ): () => void {
    let unsubs: Array<() => void> = [];
    let menuItems: RestaurantMenuItemEntity[] = [];
    let categoriesList: RestaurantMenuCategoryEntity[] = [];

    const notify = () => {
      callback({ products: menuItems, categories: categoriesList });
    };

    // 1. Listen to subcollection `restaurants/{id}/menu`
    try {
      const unsubMenu = onSnapshot(collection(db, 'restaurants', restaurantId, 'menu'), (snap) => {
        menuItems = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            name: data.name || data.title || 'وجبة طعام',
            description: data.description || '',
            price: Number(data.price || 0),
            category: data.category || 'أطباق رئيسية',
            imageUrl: data.imageUrl || data.image || data.photoUrl,
            isAvailable: data.isAvailable !== false,
            salesCount: Number(data.salesCount || data.ordersCount || 0),
            sizes: data.sizes,
            extras: data.extras
          };
        });
        notify();
      }, (err) => console.warn('menu subcollection stream:', err.message));
      unsubs.push(unsubMenu);
    } catch (e) {
      console.warn('menu subcollection error:', e);
    }

    // 2. Listen to subcollection `restaurants/{id}/categories`
    try {
      const unsubCats = onSnapshot(collection(db, 'restaurants', restaurantId, 'categories'), (snap) => {
        categoriesList = snap.docs.map((d) => ({
          id: d.id,
          name: d.data().name || 'قسم',
          iconCode: d.data().iconCode,
          itemCount: d.data().itemCount
        }));
        notify();
      }, (err) => console.warn('categories subcollection stream:', err.message));
      unsubs.push(unsubCats);
    } catch (e) {
      console.warn('categories subcollection error:', e);
    }

    return () => {
      unsubs.forEach(u => u());
    };
  }

  // ──────── MENU MANAGEMENT (restaurants/{id}/menu) ────────

  /**
   * Subscribe to Restaurant Menu items
   */
  static subscribeToMenu(restaurantId: string, callback: (items: RestaurantMenuItemEntity[]) => void): () => void {
    const menuCol = collection(db, 'restaurants', restaurantId, 'menu');
    return onSnapshot(menuCol, (snapshot) => {
      const items: RestaurantMenuItemEntity[] = snapshot.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name || data.title || 'وجبة طعام',
          description: data.description || '',
          price: Number(data.price || 0),
          category: data.category || 'أطباق رئيسية',
          imageUrl: data.imageUrl || data.image || data.photoUrl,
          isAvailable: data.isAvailable !== false,
          salesCount: Number(data.salesCount || data.ordersCount || 0),
          sizes: data.sizes,
          extras: data.extras
        };
      });
      callback(items);
    }, (err) => console.warn('restaurant menu stream:', err.message));
  }

  /**
   * Add Menu Item
   */
  static async addMenuItem(restaurantId: string, item: Omit<RestaurantMenuItemEntity, 'id' | 'salesCount'>): Promise<string> {
    const docRef = await addDoc(collection(db, 'restaurants', restaurantId, 'menu'), {
      ...item,
      salesCount: 0,
      createdAt: serverTimestamp()
    });
    return docRef.id;
  }

  /**
   * Update Menu Item
   */
  static async updateMenuItem(restaurantId: string, itemId: string, updates: Partial<RestaurantMenuItemEntity>): Promise<void> {
    await updateDoc(doc(db, 'restaurants', restaurantId, 'menu', itemId), {
      ...updates,
      updatedAt: serverTimestamp()
    });
  }

  /**
   * Delete Menu Item
   */
  static async deleteMenuItem(restaurantId: string, itemId: string): Promise<void> {
    await deleteDoc(doc(db, 'restaurants', restaurantId, 'menu', itemId));
  }

  // ──────── CATEGORIES MANAGEMENT (restaurants/{id}/categories) ────────

  /**
   * Subscribe to Restaurant Categories
   */
  static subscribeToCategories(restaurantId: string, callback: (cats: RestaurantMenuCategoryEntity[]) => void): () => void {
    const catsCol = collection(db, 'restaurants', restaurantId, 'categories');
    return onSnapshot(catsCol, (snapshot) => {
      const cats: RestaurantMenuCategoryEntity[] = snapshot.docs.map((d) => ({
        id: d.id,
        name: d.data().name || 'قسم',
        iconCode: d.data().iconCode,
        itemCount: d.data().itemCount
      }));
      callback(cats);
    }, (err) => console.warn('restaurant categories stream:', err.message));
  }

  /**
   * Add Category
   */
  static async addCategory(restaurantId: string, name: string): Promise<string> {
    const docRef = await addDoc(collection(db, 'restaurants', restaurantId, 'categories'), {
      name,
      createdAt: serverTimestamp()
    });
    return docRef.id;
  }

  /**
   * Delete Category
   */
  static async deleteCategory(restaurantId: string, categoryId: string): Promise<void> {
    await deleteDoc(doc(db, 'restaurants', restaurantId, 'categories', categoryId));
  }
}
