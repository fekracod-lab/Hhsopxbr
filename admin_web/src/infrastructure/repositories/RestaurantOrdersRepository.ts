import { 
  collection, 
  query, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc,
  where
} from 'firebase/firestore';
import { db } from '../firebase';
import { RestaurantOrderEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class RestaurantOrdersRepository {
  /**
   * Stream Restaurant Food Orders strictly from `orders` collection
   */
  static subscribeToRestaurantOrders(
    callback: (orders: RestaurantOrderEntity[]) => void, 
    restaurantId?: string,
    maxLimit = 250
  ): () => void {
    let q = query(collection(db, 'orders'), limit(maxLimit));
    if (restaurantId) {
      q = query(collection(db, 'orders'), where('restaurantId', '==', restaurantId), limit(maxLimit));
    }

    return onSnapshot(q, (snapshot) => {
      const list: RestaurantOrderEntity[] = snapshot.docs
        .map((d) => {
          const data = d.data();

          // Exclude store orders or taxi/mersal if any are mistakenly in /orders
          if (data.isStoreOrder === true || data.storeId || data.orderSource === 'store') {
            return null;
          }

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

          // Items list extraction
          const rawItems: any[] = data.items || data.orderItems || data.products || [];
          const itemsList = rawItems.map((it: any) => ({
            id: it.id || it.productId || it.itemId,
            name: it.name || it.title || 'وجبة طعام',
            quantity: Number(it.quantity || it.qty || it.count || 1),
            price: Number(it.price || it.unitPrice || 0),
            options: it.options || it.selectedOptions || [],
            notes: it.notes || it.comment
          }));

          const itemsSummary = itemsList.length > 0 
            ? itemsList.map(it => `${it.name} (${it.quantity})`).join(' + ')
            : (data.itemsSummary || data.description || 'طلب وجبات مطعم');

          const subtotal = Number(data.subtotal || data.itemsTotal || data.foodPrice || data.totalPrice || 0);
          const deliveryFee = Number(data.deliveryFee || data.deliveryPrice || data.fee || 0);
          const total = Number(data.totalPrice || data.total || data.grandTotal || (subtotal + deliveryFee));
          const commission = Number(data.commission || data.platformCommission || (subtotal * 0.1));
          const net = Number(data.restaurantNet || data.merchantNet || (subtotal - commission));

          return {
            orderId: d.id,
            restaurantId: data.restaurantId || data.merchantId || 'unknown_rest',
            restaurantName: data.restaurantName || data.merchantName || 'مطعم مدار',
            restaurantPhone: data.restaurantPhone || data.merchantPhone,
            restaurantAddress: data.restaurantAddress || data.merchantAddress,
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
            restaurantNetIqd: net,
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
        })
        .filter((o): o is RestaurantOrderEntity => o !== null);

      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => console.warn('restaurant orders stream error:', err.message));
  }

  /**
   * Update Restaurant Order Status
   */
  static async updateOrderStatus(orderId: string, status: string, cancelReason?: string): Promise<void> {
    const payload: Record<string, any> = { status, updatedAt: new Date().toISOString() };
    if (cancelReason) payload.cancellationReason = cancelReason;

    await updateDoc(doc(db, 'orders', orderId), payload);

    AuditRepository.logAction({
      action: 'UPDATE_RESTAURANT_ORDER_STATUS',
      targetResource: `orders/${orderId}`,
      payload: { status, cancelReason }
    });
  }
}
