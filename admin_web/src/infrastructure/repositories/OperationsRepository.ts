import {
  collection,
  query,
  onSnapshot,
  doc,
  updateDoc,
  deleteDoc,
  orderBy,
  limit,
  serverTimestamp
} from 'firebase/firestore';
import { db } from '../firebase';
import { LiveRideRecord } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export interface DetailedLiveTrip {
  tripId: string;
  type: 'taxi' | 'delivery' | 'food';
  customerId: string;
  customerName: string;
  customerPhone?: string;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverCar?: string;
  driverPlate?: string;
  pickupAddress: string;
  dropoffAddress: string;
  pickupCoordinates?: { lat: number; lng: number };
  dropoffCoordinates?: { lat: number; lng: number };
  priceIqd: number;
  distanceKm: number;
  durationMins?: number;
  status: 'requested' | 'matching' | 'driver_assigned' | 'arriving' | 'arrived' | 'trip_started' | 'completed' | 'cancelled';
  createdAt: string;
  createdTimestamp: number;
}

export class OperationsRepository {
  /**
   * Subscribe to all live ongoing trips & orders in real-time
   */
  static subscribeToLiveTrips(callback: (trips: DetailedLiveTrip[]) => void): () => void {
    let rideRequestsMap: Record<string, DetailedLiveTrip> = {};
    let tripsMap: Record<string, DetailedLiveTrip> = {};
    let ordersMap: Record<string, DetailedLiveTrip> = {};

    const notify = () => {
      const merged = [
        ...Object.values(rideRequestsMap),
        ...Object.values(tripsMap),
        ...Object.values(ordersMap)
      ];

      // Sort by newest active first
      merged.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(merged);
    };

    // 1. Stream ride_requests
    const unsubRides = onSnapshot(
      query(collection(db, 'ride_requests'), limit(60)),
      (snapshot) => {
        rideRequestsMap = {};
        snapshot.docs.forEach((d) => {
          const data = d.data();
          const rawCreated = data.createdAt;
          let createdStr = 'الآن';
          let createdMs = Date.now();

          if (rawCreated?.toDate) {
            const dt = rawCreated.toDate();
            createdStr = dt.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
            createdMs = dt.getTime();
          }

          rideRequestsMap[d.id] = {
            tripId: d.id,
            type: 'taxi',
            customerId: data.passengerId || data.customerId || 'user',
            customerName: data.passengerName || data.customerName || 'راكب تكسي',
            customerPhone: data.passengerPhone || data.customerPhone || data.phone,
            driverId: data.driverId || data.captainId,
            driverName: data.driverName || data.captainName,
            driverPhone: data.driverPhone || data.captainPhone,
            driverCar: data.carType || data.carModel || data.driverCar || 'تكسي مدار',
            driverPlate: data.carNumber || data.plateNumber || data.driverPlate || 'غير محدد',
            pickupAddress: data.pickupAddress || data.startLocationName || 'القائم - المركز',
            dropoffAddress: data.destinationAddress || data.endLocationName || 'الوجهة',
            pickupCoordinates: data.pickupCoordinates || data.startLocation ? {
              lat: data.pickupCoordinates?.lat || data.startLocation?.latitude || 34.3414,
              lng: data.pickupCoordinates?.lng || data.startLocation?.longitude || 41.0776
            } : undefined,
            dropoffCoordinates: data.dropoffCoordinates || data.endLocation ? {
              lat: data.dropoffCoordinates?.lat || data.endLocation?.latitude || 34.3500,
              lng: data.dropoffCoordinates?.lng || data.endLocation?.longitude || 41.0900
            } : undefined,
            priceIqd: Number(data.fare || data.price || data.estimatedFare || 3000),
            distanceKm: Number(data.distanceKm || data.distance || 4.2),
            durationMins: Number(data.durationMins || 8),
            status: data.status || 'requested',
            createdAt: createdStr,
            createdTimestamp: createdMs
          };
        });
        notify();
      },
      (err) => console.warn('Ride requests stream error:', err.message)
    );

    // 2. Stream trips
    const unsubTrips = onSnapshot(
      query(collection(db, 'trips'), limit(60)),
      (snapshot) => {
        tripsMap = {};
        snapshot.docs.forEach((d) => {
          const data = d.data();
          const rawCreated = data.createdAt;
          let createdStr = 'الآن';
          let createdMs = Date.now();

          if (rawCreated?.toDate) {
            const dt = rawCreated.toDate();
            createdStr = dt.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
            createdMs = dt.getTime();
          }

          tripsMap[d.id] = {
            tripId: d.id,
            type: 'taxi',
            customerId: data.passengerId || data.customerId || 'user',
            customerName: data.passengerName || data.customerName || 'عميل مدار',
            customerPhone: data.passengerPhone || data.customerPhone,
            driverId: data.driverId,
            driverName: data.driverName || data.captainName,
            driverPhone: data.driverPhone,
            driverCar: data.driverCar || data.carType || 'سيارة تكسي',
            driverPlate: data.driverCarNumber || data.plateNumber || 'لوحة مسجلة',
            pickupAddress: data.pickupAddress || data.from || 'قضاء القائم',
            dropoffAddress: data.dropoffAddress || data.to || 'الوجهة المطلوبة',
            priceIqd: Number(data.price || data.fare || 3500),
            distanceKm: Number(data.distanceKm || 5),
            status: data.status || 'trip_started',
            createdAt: createdStr,
            createdTimestamp: createdMs
          };
        });
        notify();
      },
      (err) => console.warn('Trips stream error:', err.message)
    );

    // 3. Stream delivery/food orders
    const unsubOrders = onSnapshot(
      query(collection(db, 'orders'), limit(60)),
      (snapshot) => {
        ordersMap = {};
        snapshot.docs.forEach((d) => {
          const data = d.data();
          const rawCreated = data.createdAt;
          let createdStr = 'الآن';
          let createdMs = Date.now();

          if (rawCreated?.toDate) {
            const dt = rawCreated.toDate();
            createdStr = dt.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
            createdMs = dt.getTime();
          }

          ordersMap[d.id] = {
            tripId: d.id,
            type: data.restaurantId ? 'food' : 'delivery',
            customerId: data.customerId || data.userId || 'user',
            customerName: data.customerName || data.userName || 'طلب توصيل',
            customerPhone: data.customerPhone || data.phone,
            driverId: data.driverId || data.deliveryBoyId,
            driverName: data.driverName || data.deliveryBoyName,
            driverPhone: data.driverPhone,
            driverCar: data.driverCar || 'دراجة توصيل',
            driverPlate: data.plateNumber || 'دليفري',
            pickupAddress: data.restaurantName || data.storeName || 'المطعم / المتجر',
            dropoffAddress: data.deliveryAddress || data.address || 'عنوان العميل',
            priceIqd: Number(data.totalAmount || data.price || 5000),
            distanceKm: Number(data.distanceKm || 3),
            status: data.status || 'requested',
            createdAt: createdStr,
            createdTimestamp: createdMs
          };
        });
        notify();
      },
      (err) => console.warn('Orders stream error:', err.message)
    );

    return () => {
      unsubRides();
      unsubTrips();
      unsubOrders();
    };
  }

  /**
   * Admin Manual Dispatch / Assign Driver to Ride
   */
  static async assignDriverManually(
    rideId: string, 
    driver: { id: string; name: string; phone: string; car: string; plate: string }
  ): Promise<void> {
    const updatePayload = {
      driverId: driver.id,
      driverName: driver.name,
      driverPhone: driver.phone,
      carType: driver.car,
      carNumber: driver.plate,
      status: 'driver_assigned',
      assignedByAdmin: true,
      updatedAt: serverTimestamp()
    };

    // Update in ride_requests and trips
    await updateDoc(doc(db, 'ride_requests', rideId), updatePayload).catch(() => {});
    await updateDoc(doc(db, 'trips', rideId), updatePayload).catch(() => {});
    await updateDoc(doc(db, 'orders', rideId), updatePayload).catch(() => {});

    try {
      await AuditRepository.logAction('MANUAL_DISPATCH', 'operations', rideId, {
        driverId: driver.id,
        driverName: driver.name
      });
    } catch (_) {}
  }

  /**
   * Admin Force Cancel Ride / Trip
   */
  static async forceCancelRide(rideId: string, reason: string): Promise<void> {
    const updatePayload = {
      status: 'cancelled',
      cancellationReason: reason,
      cancelledBy: 'admin',
      cancelledAt: serverTimestamp()
    };

    await updateDoc(doc(db, 'ride_requests', rideId), updatePayload).catch(() => {});
    await updateDoc(doc(db, 'trips', rideId), updatePayload).catch(() => {});
    await updateDoc(doc(db, 'orders', rideId), updatePayload).catch(() => {});

    try {
      await AuditRepository.logAction('FORCE_CANCEL_RIDE', 'operations', rideId, { reason });
    } catch (_) {}
  }

  /**
   * Admin Force Complete Trip
   */
  static async forceCompleteRide(rideId: string): Promise<void> {
    const updatePayload = {
      status: 'completed',
      completedBy: 'admin',
      completedAt: serverTimestamp()
    };

    await updateDoc(doc(db, 'ride_requests', rideId), updatePayload).catch(() => {});
    await updateDoc(doc(db, 'trips', rideId), updatePayload).catch(() => {});
    await updateDoc(doc(db, 'orders', rideId), updatePayload).catch(() => {});

    try {
      await AuditRepository.logAction('FORCE_COMPLETE_RIDE', 'operations', rideId, {});
    } catch (_) {}
  }
}
