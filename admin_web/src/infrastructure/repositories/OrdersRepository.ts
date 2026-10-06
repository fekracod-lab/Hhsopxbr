import { 
  collection, 
  query, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc,
  deleteDoc,
  writeBatch,
  getDocs,
  where
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface OrderItemDetail {
  id?: string;
  name: string;
  quantity: number;
  price: number;
  options?: string[];
  notes?: string;
  image?: string;
}

export interface AdminOrderRecord {
  orderId: string;
  sourceType: 'food_delivery' | 'store_delivery' | 'taxi_ride' | 'mersal_delivery';
  merchantOrTitle: string;
  merchantId?: string;
  merchantPhone?: string;
  merchantAddress?: string;
  customerId?: string;
  customerName: string;
  customerPhone?: string;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverVehiclePlate?: string;
  driverVehicleModel?: string;
  totalPriceIqd: number;
  subtotalIqd?: number;
  deliveryFeeIqd?: number;
  discountIqd?: number;
  commissionIqd?: number;
  merchantNetIqd?: number;
  driverNetIqd?: number;
  paymentMethod?: string;
  status: string;
  rawStatus: string;
  createdAt: string;
  updatedAt?: string;
  itemsSummary?: string;
  itemsList?: OrderItemDetail[];
  deliveryAddress?: string;
  pickupAddress?: string;
  customerNotes?: string;
  cancellationReason?: string;
}

export class OrdersRepository {
  /**
   * Stream real orders, delivery requests, and taxi rides from Firestore (Deduplicated & Cleaned)
   */
  static subscribeToAllOrders(callback: (orders: AdminOrderRecord[]) => void, maxLimit = 250): () => void {
    let ordersList: AdminOrderRecord[] = [];
    let ridesList: AdminOrderRecord[] = [];
    let deliveryList: AdminOrderRecord[] = [];

    const notify = () => {
      // Deduplicate by orderId across all streams
      const map = new Map<string, AdminOrderRecord>();
      
      // Add orders, rides, delivery orders cleanly
      ordersList.forEach(o => map.set(o.orderId, o));
      ridesList.forEach(o => map.set(o.orderId, o));
      deliveryList.forEach(o => map.set(o.orderId, o));

      const combined = Array.from(map.values()).sort((a, b) => {
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      });
      callback(combined);
    };

    // 1. Listen to food/store unified orders
    const ordersQuery = query(collection(db, 'orders'), limit(maxLimit));
    const unsubOrders = onSnapshot(ordersQuery, (snapshot) => {
      ordersList = snapshot.docs.map((d) => {
        const data = d.data();
        
        // Parse items
        let itemsArr: OrderItemDetail[] = [];
        if (Array.isArray(data.items)) {
          itemsArr = data.items.map((i: any) => ({
            id: i.id || i.itemId || '',
            name: i.name || i.title || i.itemName || 'صنف',
            quantity: Number(i.quantity || i.qty || 1),
            price: Number(i.price || i.unitPrice || 0),
            options: Array.isArray(i.options) ? i.options : (i.selectedOptions || []),
            notes: i.notes || i.specialInstructions || '',
            image: i.image || i.imageUrl || ''
          }));
        }

        const itemsStr = itemsArr.map(i => `${i.name} × ${i.quantity}`).join('، ');
        const total = Number(data.totalPrice || data.totalAmount || data.price || 0);
        const delFee = Number(data.deliveryFee || data.deliveryPrice || 0);
        const subtotal = Number(data.subtotal || data.itemsSubtotal || (total - delFee > 0 ? total - delFee : total));
        const commission = Number(data.commissionAmount || (total * 0.1));
        const merchantNet = Number(data.netMerchantAmount || (subtotal - commission > 0 ? subtotal - commission : subtotal));
        const driverNet = Number(data.netDriverAmount || (delFee > 0 ? delFee * 0.9 : 0));

        const isStore = Boolean(data.storeId || data.storeName || data.orderType === 'store');

        return {
          orderId: d.id,
          sourceType: isStore ? 'store_delivery' : 'food_delivery',
          merchantOrTitle: data.restaurantName || data.storeName || data.merchantName || (isStore ? 'متجر مدار' : 'مطعم مدار'),
          merchantId: data.restaurantId || data.storeId || data.merchantId,
          merchantPhone: data.restaurantPhone || data.storePhone || data.merchantPhone,
          merchantAddress: data.restaurantAddress || data.storeAddress || 'القائم',
          customerId: data.customerId || data.userId,
          customerName: data.customerName || data.userName || data.clientName || 'عميل مدار',
          customerPhone: data.customerPhone || data.userPhone || data.phone,
          driverId: data.driverId || data.captainId,
          driverName: data.driverName || data.captainName,
          driverPhone: data.driverPhone || data.captainPhone,
          driverVehiclePlate: data.driverVehiclePlate || data.carPlate || data.plateNumber,
          driverVehicleModel: data.driverVehicleModel || data.carModel || data.vehicleModel,
          totalPriceIqd: total,
          subtotalIqd: subtotal,
          deliveryFeeIqd: delFee,
          discountIqd: Number(data.discount || data.discountAmount || 0),
          commissionIqd: commission,
          merchantNetIqd: merchantNet,
          driverNetIqd: driverNet,
          paymentMethod: data.paymentMethod || data.paymentType || 'cash_on_delivery',
          status: data.status || 'قيد المتابعة',
          rawStatus: (data.status || 'pending').toString().toLowerCase(),
          createdAt: data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : (data.createdAt || new Date().toISOString()),
          updatedAt: data.updatedAt?.toDate ? data.updatedAt.toDate().toISOString() : data.updatedAt,
          itemsSummary: itemsStr || (data.itemsDescription || 'طلبات ووجبات متنوعة'),
          itemsList: itemsArr,
          deliveryAddress: data.deliveryAddress || data.address || data.dropoffAddress || 'القائم',
          pickupAddress: data.pickupAddress || data.restaurantAddress || 'القائم',
          customerNotes: data.notes || data.customerNotes || data.specialInstructions,
          cancellationReason: data.cancellationReason || data.cancelReason
        };
      });
      notify();
    }, (err) => {
      console.warn('Orders stream error:', err.message);
    });

    // 2. Listen to Taxi Ride Requests
    const ridesQuery = query(collection(db, 'ride_requests'), limit(maxLimit));
    const unsubRides = onSnapshot(ridesQuery, (snapshot) => {
      ridesList = snapshot.docs.map((d) => {
        const data = d.data();
        const fare = Number(data.fare || data.price || data.estimatedFare || 0);

        return {
          orderId: d.id,
          sourceType: 'taxi_ride',
          merchantOrTitle: `مشوار تكسي: ${data.pickupAddress || 'نقطة الانطلاق'} ${data.destinationAddress || 'الوجهة'}`,
          customerId: data.passengerId || data.customerId || data.userId,
          customerName: data.passengerName || data.customerName || 'راكب تكسي',
          customerPhone: data.passengerPhone || data.phone,
          driverId: data.driverId || data.captainId,
          driverName: data.driverName || data.captainName,
          driverPhone: data.driverPhone || data.captainPhone,
          driverVehiclePlate: data.carPlate || data.plateNumber,
          driverVehicleModel: data.vehicleModel || data.carModel || 'سيارة أجرة',
          totalPriceIqd: fare,
          subtotalIqd: fare,
          deliveryFeeIqd: 0,
          discountIqd: 0,
          commissionIqd: Number(data.commissionAmount || (fare * 0.15)),
          paymentMethod: data.paymentMethod || 'cash',
          status: data.status || 'نشط',
          rawStatus: (data.status || 'searching').toString().toLowerCase(),
          createdAt: data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : (data.createdAt || new Date().toISOString()),
          updatedAt: data.updatedAt?.toDate ? data.updatedAt.toDate().toISOString() : data.updatedAt,
          itemsSummary: `مشوار تكسي مدار (${data.vehicleModel || data.carType || 'صالون'})`,
          deliveryAddress: data.destinationAddress || 'القائم',
          pickupAddress: data.pickupAddress || 'القائم',
          customerNotes: data.notes || data.passengerNotes,
          cancellationReason: data.cancelReason || data.cancellationReason
        };
      });
      notify();
    }, (err) => {
      console.warn('Rides stream error:', err.message);
    });

    // 3. Listen to Delivery Orders (Mersal / Parcels)
    const deliveryQuery = query(collection(db, 'delivery_orders'), limit(maxLimit));
    const unsubDelivery = onSnapshot(deliveryQuery, (snapshot) => {
      deliveryList = snapshot.docs.map((d) => {
        const data = d.data();
        const cost = Number(data.cost || data.totalPrice || data.fee || 0);

        return {
          orderId: d.id,
          sourceType: 'mersal_delivery',
          merchantOrTitle: `مرسال وتوصيل: ${data.packageType || data.parcelDescription || 'طرد / أمانات'}`,
          customerId: data.senderId || data.customerId,
          customerName: data.senderName || data.customerName || 'مرسل الطرد',
          customerPhone: data.senderPhone || data.customerPhone,
          driverId: data.driverId || data.captainId,
          driverName: data.driverName || data.captainName,
          driverPhone: data.driverPhone,
          driverVehiclePlate: data.carPlate,
          driverVehicleModel: data.vehicleModel,
          totalPriceIqd: cost,
          subtotalIqd: cost,
          status: data.status || 'قيد النقل',
          rawStatus: (data.status || 'pending').toString().toLowerCase(),
          createdAt: data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : (data.createdAt || new Date().toISOString()),
          itemsSummary: data.packageDetails || 'توصيل طرد خاص عبر مرسال',
          deliveryAddress: data.receiverAddress || data.destinationAddress || 'القائم',
          pickupAddress: data.senderAddress || data.pickupAddress || 'القائم'
        };
      });
      notify();
    }, (err) => {
      console.warn('Delivery orders stream error:', err.message);
    });

    return () => {
      unsubOrders();
      unsubRides();
      unsubDelivery();
    };
  }

  /**
   * Update order status in Firestore across all matching collections
   */
  static async updateOrderStatus(
    orderId: string, 
    sourceType: 'food_delivery' | 'store_delivery' | 'taxi_ride' | 'mersal_delivery', 
    newStatus: string
  ): Promise<void> {
    const collectionsToUpdate = ['orders', 'ride_requests', 'delivery_orders', 'rides'];
    
    const updatePromises = collectionsToUpdate.map(async (col) => {
      try {
        await updateDoc(doc(db, col, orderId), {
          status: newStatus,
          updatedAt: new Date().toISOString()
        });
      } catch {}
    });

    await Promise.allSettled(updatePromises);
    await AuditRepository.logAction('UPDATE_ORDER_STATUS', 'orders', orderId, { newStatus });
  }

  /**
   * Assign or Change Driver/Captain for an Order
   */
  static async assignDriverToOrder(
    orderId: string,
    sourceType: 'food_delivery' | 'store_delivery' | 'taxi_ride' | 'mersal_delivery',
    driver: {
      id: string;
      name: string;
      phone?: string;
      carPlate?: string;
      carModel?: string;
    }
  ): Promise<void> {
    const payload = {
      driverId: driver.id,
      driverName: driver.name,
      captainId: driver.id,
      captainName: driver.name,
      driverPhone: driver.phone || '',
      driverVehiclePlate: driver.carPlate || '',
      driverVehicleModel: driver.carModel || '',
      carPlate: driver.carPlate || '',
      carModel: driver.carModel || '',
      status: 'assigned',
      updatedAt: new Date().toISOString()
    };

    const collectionsToUpdate = ['orders', 'ride_requests', 'delivery_orders', 'rides'];
    await Promise.allSettled(
      collectionsToUpdate.map(col => updateDoc(doc(db, col, orderId), payload).catch(() => {}))
    );

    await AuditRepository.logAction('ASSIGN_DRIVER_ORDER', 'orders', orderId, {
      driverId: driver.id,
      driverName: driver.name
    });
  }

  /**
   * Cancel order with structured reason
   */
  static async cancelOrderWithReason(
    orderId: string,
    sourceType: 'food_delivery' | 'store_delivery' | 'taxi_ride' | 'mersal_delivery',
    reason: string
  ): Promise<void> {
    const payload = {
      status: 'cancelled',
      cancellationReason: reason,
      cancelledAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const collectionsToUpdate = ['orders', 'ride_requests', 'delivery_orders', 'rides'];
    await Promise.allSettled(
      collectionsToUpdate.map(col => updateDoc(doc(db, col, orderId), payload).catch(() => {}))
    );

    await AuditRepository.logAction('CANCEL_ORDER', 'orders', orderId, { reason });
  }

  /**
   * Deep Permanent Delete of a Single Order from ALL Collections & Subcollections
   */
  static async deleteOrder(
    orderId: string,
    sourceType?: 'food_delivery' | 'store_delivery' | 'taxi_ride' | 'mersal_delivery',
    customerId?: string,
    merchantId?: string
  ): Promise<void> {
    const collectionsToClean = ['orders', 'ride_requests', 'delivery_orders', 'rides', 'taxi_orders'];
    
    // 1. Delete from root collections
    const promises: Promise<any>[] = collectionsToClean.map(col => 
      deleteDoc(doc(db, col, orderId)).catch(() => {})
    );
    
    // 2. Delete from user and merchant subcollections if IDs exist
    if (customerId) {
      promises.push(deleteDoc(doc(db, 'madar_orders', customerId, 'orders', orderId)).catch(() => {}));
      promises.push(deleteDoc(doc(db, 'users', customerId, 'orders', orderId)).catch(() => {}));
    }
    if (merchantId) {
      promises.push(deleteDoc(doc(db, 'restaurants', merchantId, 'orders', orderId)).catch(() => {}));
      promises.push(deleteDoc(doc(db, 'stores', merchantId, 'orders', orderId)).catch(() => {}));
    }

    await Promise.allSettled(promises);
    await AuditRepository.logAction('DELETE_ORDER', 'all_collections', orderId, { deletedAt: new Date().toISOString() });
  }

  /**
   * Bulk Deep Delete multiple orders from ALL Collections & Subcollections
   */
  static async bulkDeleteOrders(
    orders: Array<{ orderId: string; sourceType?: string; customerId?: string; merchantId?: string }>
  ): Promise<void> {
    const collectionsToClean = ['orders', 'ride_requests', 'delivery_orders', 'rides', 'taxi_orders'];
    const deletePromises: Promise<any>[] = [];

    for (const ord of orders) {
      for (const col of collectionsToClean) {
        deletePromises.push(deleteDoc(doc(db, col, ord.orderId)).catch(() => {}));
      }
      if (ord.customerId) {
        deletePromises.push(deleteDoc(doc(db, 'madar_orders', ord.customerId, 'orders', ord.orderId)).catch(() => {}));
        deletePromises.push(deleteDoc(doc(db, 'users', ord.customerId, 'orders', ord.orderId)).catch(() => {}));
      }
      if (ord.merchantId) {
        deletePromises.push(deleteDoc(doc(db, 'restaurants', ord.merchantId, 'orders', ord.orderId)).catch(() => {}));
        deletePromises.push(deleteDoc(doc(db, 'stores', ord.merchantId, 'orders', ord.orderId)).catch(() => {}));
      }
    }

    await Promise.allSettled(deletePromises);

    await AuditRepository.logAction('BULK_DELETE_ORDERS', 'orders', 'batch', {
      count: orders.length,
      orderIds: orders.map(o => o.orderId)
    });
  }

  /**
   * Purge ALL Cancelled Orders in Firestore Permanently
   */
  static async purgeAllCancelledOrders(allCurrentOrders: AdminOrderRecord[]): Promise<number> {
    const cancelledOrders = allCurrentOrders.filter(o => 
      o.rawStatus.includes('cancel') || o.rawStatus.includes('reject')
    );

    if (cancelledOrders.length === 0) return 0;

    await this.bulkDeleteOrders(cancelledOrders.map(o => ({
      orderId: o.orderId,
      sourceType: o.sourceType,
      customerId: o.customerId,
      merchantId: o.merchantId
    })));

    await AuditRepository.logAction('PURGE_CANCELLED_ORDERS', 'orders', 'all_cancelled', {
      count: cancelledOrders.length
    });

    return cancelledOrders.length;
  }

  /**
   * Bulk Update Status across all collections
   */
  static async bulkUpdateStatus(
    orders: Array<{ orderId: string; sourceType?: string }>,
    newStatus: string
  ): Promise<void> {
    const collectionsToUpdate = ['orders', 'ride_requests', 'delivery_orders', 'rides'];
    const updatePromises: Promise<any>[] = [];

    for (const ord of orders) {
      for (const col of collectionsToUpdate) {
        updatePromises.push(
          updateDoc(doc(db, col, ord.orderId), {
            status: newStatus,
            updatedAt: new Date().toISOString()
          }).catch(() => {})
        );
      }
    }

    await Promise.allSettled(updatePromises);

    await AuditRepository.logAction('BULK_UPDATE_ORDER_STATUS', 'orders', 'batch', {
      count: orders.length,
      newStatus
    });
  }
}
