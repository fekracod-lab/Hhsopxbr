import { 
  collection, 
  collectionGroup,
  query, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc,
  where
} from 'firebase/firestore';
import { db } from '../firebase';
import { StoreOrderEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class StoreOrdersRepository {
  /**
   * Stream Store Orders strictly from store subcollections / collectionGroup('madar_orders')
   */
  static subscribeToStoreOrders(
    callback: (orders: StoreOrderEntity[]) => void, 
    storeId?: string,
    maxLimit = 250
  ): () => void {
    let unsubs: Array<() => void> = [];
    let groupOrders: StoreOrderEntity[] = [];
    let directStoreOrders: StoreOrderEntity[] = [];

    const notify = () => {
      const map = new Map<string, StoreOrderEntity>();
      [...groupOrders, ...directStoreOrders].forEach(o => map.set(o.orderId, o));
      const list = Array.from(map.values()).sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    };

    const parseOrderDoc = (d: any): StoreOrderEntity => {
      const data = d.data();
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

      const rawItems: any[] = data.items || data.orderItems || data.products || [];
      const itemsList = rawItems.map((it: any) => ({
        id: it.id || it.productId,
        name: it.name || it.title || 'منتج',
        quantity: Number(it.quantity || it.qty || it.count || 1),
        price: Number(it.price || it.unitPrice || 0),
        options: it.options || it.selectedOptions || [],
        notes: it.notes
      }));

      const itemsSummary = itemsList.length > 0 
        ? itemsList.map(it => `${it.name} (${it.quantity})`).join(' + ')
        : (data.itemsSummary || data.description || 'طلب مسواك متجر');

      const subtotal = Number(data.subtotal || data.itemsTotal || data.productsPrice || data.totalPrice || 0);
      const deliveryFee = Number(data.deliveryFee || data.deliveryPrice || data.fee || 0);
      const total = Number(data.totalPrice || data.total || data.grandTotal || (subtotal + deliveryFee));
      const commission = Number(data.commission || data.platformCommission || (subtotal * 0.1));
      const net = Number(data.storeNet || data.merchantNet || (subtotal - commission));

      return {
        orderId: d.id,
        storeId: data.storeId || storeId || 'unknown_store',
        storeName: data.storeName || data.merchantName || 'متجر مدار',
        storePhone: data.storePhone || data.merchantPhone,
        storeAddress: data.storeAddress || data.merchantAddress,
        customerId: data.customerId || data.userId,
        customerName: data.customerName || data.userName || 'عميل مدار',
        customerPhone: data.customerPhone || data.userPhone,
        courierId: data.driverId || data.courierId,
        courierName: data.driverName || data.courierName,
        courierPhone: data.driverPhone || data.courierPhone,
        totalPriceIqd: total,
        subtotalIqd: subtotal,
        deliveryFeeIqd: deliveryFee,
        discountIqd: Number(data.discount || 0),
        commissionIqd: commission,
        storeNetIqd: net,
        courierNetIqd: Number(data.driverNet || deliveryFee),
        paymentMethod: data.paymentMethod || 'cash_on_delivery',
        status: data.status || 'pending',
        rawStatus: data.rawStatus || data.status || 'pending',
        createdAt: createdStr,
        createdTimestamp: createdTs,
        itemsSummary,
        itemsList,
        deliveryAddress: data.deliveryAddress || data.address || data.dropoffAddress || 'قضاء القائم',
        customerNotes: data.customerNotes || data.notes
      };
    };

    // 1. Listen to collectionGroup `madar_orders`
    try {
      let q = query(collectionGroup(db, 'madar_orders'), limit(maxLimit));
      if (storeId) {
        q = query(collection(db, 'stores', storeId, 'madar_orders'), limit(maxLimit));
      }
      const unsubGroup = onSnapshot(q, (snapshot) => {
        groupOrders = snapshot.docs.map(parseOrderDoc);
        notify();
      }, (err) => console.warn('collectionGroup(madar_orders) stream note:', err.message));
      unsubs.push(unsubGroup);
    } catch (e) {
      console.warn('store orders group query error:', e);
    }

    // 2. Listen to fallback `store_orders` top-level collection if used
    try {
      let q2 = query(collection(db, 'store_orders'), limit(maxLimit));
      if (storeId) {
        q2 = query(collection(db, 'store_orders'), where('storeId', '==', storeId), limit(maxLimit));
      }
      const unsubDirect = onSnapshot(q2, (snapshot) => {
        directStoreOrders = snapshot.docs.map(parseOrderDoc);
        notify();
      }, (err) => console.warn('store_orders top collection note:', err.message));
      unsubs.push(unsubDirect);
    } catch (e) {
      console.warn('store_orders collection error:', e);
    }

    return () => {
      unsubs.forEach(u => u());
    };
  }

  /**
   * Update Store Order Status
   */
  static async updateStoreOrderStatus(storeId: string, orderId: string, status: string): Promise<void> {
    const payload = { status, updatedAt: new Date().toISOString() };

    try {
      await updateDoc(doc(db, 'stores', storeId, 'madar_orders', orderId), payload);
    } catch {
      // Try top-level store_orders
      try {
        await updateDoc(doc(db, 'store_orders', orderId), payload);
      } catch {
        // Ignored
      }
    }

    AuditRepository.logAction({
      action: 'UPDATE_STORE_ORDER_STATUS',
      targetResource: `stores/${storeId}/madar_orders/${orderId}`,
      payload: { status }
    });
  }
}
