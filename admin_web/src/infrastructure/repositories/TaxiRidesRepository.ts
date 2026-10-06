import { 
  collection, 
  query, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc
} from 'firebase/firestore';
import { db } from '../firebase';
import { TaxiRideEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class TaxiRidesRepository {
  /**
   * Stream Taxi Rides strictly from `ride_requests` and `rides` collections
   */
  static subscribeToTaxiRides(callback: (rides: TaxiRideEntity[]) => void, maxLimit = 300): () => void {
    let requestsList: TaxiRideEntity[] = [];
    let ridesList: TaxiRideEntity[] = [];

    const notify = () => {
      const map = new Map<string, TaxiRideEntity>();
      [...requestsList, ...ridesList].forEach(ride => {
        map.set(ride.rideId, ride);
      });

      const list = Array.from(map.values()).sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    };

    const parseRideDoc = (d: any, sourceCol: string): TaxiRideEntity => {
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

      const rawStatus = (data.status || 'pending').toString().toLowerCase();
      let status: TaxiRideEntity['status'] = 'searching';
      let statusArabic = 'قيد البحث عن كابتن';

      if (rawStatus === 'accepted' || rawStatus === 'driver_assigned') {
        status = 'accepted';
        statusArabic = 'تم قبول المشوار ';
      } else if (rawStatus === 'arrived' || rawStatus === 'captain_arrived') {
        status = 'arrived';
        statusArabic = 'الكابتن وصل للموقع ';
      } else if (rawStatus === 'in_progress' || rawStatus === 'started' || rawStatus === 'in_trip') {
        status = 'in_trip';
        statusArabic = 'الرحلة جارية الآن ';
      } else if (rawStatus === 'completed' || rawStatus === 'finished') {
        status = 'completed';
        statusArabic = 'مكتملة ومسددة ';
      } else if (rawStatus === 'cancelled' || rawStatus === 'rejected') {
        status = 'cancelled';
        statusArabic = 'ملغية ';
      }

      const fare = Number(data.fare || data.price || data.totalPrice || data.estimatedFare || 0);
      const commission = Number(data.commission || data.platformCommission || (fare * 0.15));
      const driverNet = Number(data.driverNet || (fare - commission));

      return {
        rideId: d.id,
        sourceCollection: sourceCol,
        passengerId: data.userId || data.customerId || data.passengerId,
        passengerName: data.userName || data.customerName || data.passengerName || 'راكب مدار',
        passengerPhone: data.userPhone || data.customerPhone || data.passengerPhone || 'غير مسجل',
        passengerAvatar: data.userAvatar || data.customerAvatar,
        passengerNotes: data.notes || data.passengerNotes,
        driverId: data.driverId || data.captainId,
        driverName: data.driverName || data.captainName || (data.driverId ? 'كابتن مدار' : '—'),
        driverPhone: data.driverPhone || data.captainPhone || '—',
        driverAvatar: data.driverAvatar || data.captainAvatar,
        vehicleModel: data.driverCarModel || data.carModel || data.vehicleModel || 'سيارة تكسي',
        vehiclePlate: data.driverCarPlate || data.carPlate || data.plateNumber || '—',
        vehicleColor: data.driverCarColor || data.carColor || 'أصفر / أبيض',
        vehicleType: data.vehicleType || 'taxi',
        fareIqd: fare,
        baseFareIqd: Number(data.baseFare || 3000),
        distanceKm: Number(data.distanceKm || data.distance || 0),
        durationMinutes: Number(data.durationMinutes || data.duration || 0),
        discountIqd: Number(data.discount || 0),
        couponCode: data.couponCode,
        commissionIqd: commission,
        driverNetIqd: driverNet,
        paymentMethod: data.paymentMethod || 'cash',
        rating: data.rating ? Number(data.rating) : undefined,
        ratingComment: data.ratingComment || data.feedback,
        ratingReason: data.ratingReason,
        ratingTags: data.ratingTags,
        ratedAt: data.ratedAt,
        isRated: !!data.rating,
        pickupAddress: data.pickupAddress || data.pickupLocationName || 'نقطة الانطلاق (القائم)',
        pickupLat: Number(data.pickupLat || (data.pickupLocation && data.pickupLocation.latitude)),
        pickupLng: Number(data.pickupLng || (data.pickupLocation && data.pickupLocation.longitude)),
        destinationAddress: data.destinationAddress || data.dropoffAddress || data.dropoffLocationName || 'الوجهة (القائم)',
        destinationLat: Number(data.destinationLat || data.dropoffLat || (data.destinationLocation && data.destinationLocation.latitude)),
        destinationLng: Number(data.destinationLng || data.dropoffLng || (data.destinationLocation && data.destinationLocation.longitude)),
        status,
        rawStatus,
        statusArabic,
        createdAt: createdStr,
        createdTimestamp: createdTs,
        acceptedAt: data.acceptedAt,
        completedAt: data.completedAt,
        cancellationReason: data.cancellationReason || data.cancelReason,
        cancelledBy: data.cancelledBy
      };
    };

    // 1. Listen to `ride_requests`
    const unsubRequests = onSnapshot(query(collection(db, 'ride_requests'), limit(maxLimit)), (snapshot) => {
      requestsList = snapshot.docs.map(d => parseRideDoc(d, 'ride_requests'));
      notify();
    }, (err) => console.warn('ride_requests stream:', err.message));

    // 2. Listen to `rides`
    const unsubRides = onSnapshot(query(collection(db, 'rides'), limit(maxLimit)), (snapshot) => {
      ridesList = snapshot.docs.map(d => parseRideDoc(d, 'rides'));
      notify();
    }, (err) => console.warn('rides stream:', err.message));

    return () => {
      unsubRequests();
      unsubRides();
    };
  }

  /**
   * Cancel Taxi Ride
   */
  static async cancelTaxiRide(rideId: string, sourceCol: string, reason = 'إلغاء إداري'): Promise<void> {
    await updateDoc(doc(db, sourceCol, rideId), {
      status: 'cancelled',
      cancellationReason: reason,
      cancelledBy: 'admin',
      updatedAt: new Date().toISOString()
    });

    AuditRepository.logAction({
      action: 'CANCEL_TAXI_RIDE',
      targetResource: `${sourceCol}/${rideId}`,
      payload: { reason }
    });
  }

  /**
   * Assign Driver to Ride
   */
  static async assignDriver(
    ride: TaxiRideEntity,
    driverId: string,
    driverName: string,
    driverPhone: string,
    driverPlate: string,
    driverVehicleModel: string
  ): Promise<void> {
    const payload = {
      driverId,
      driverName,
      driverPhone,
      driverCarPlate: driverPlate,
      plateNumber: driverPlate,
      driverCarModel: driverVehicleModel,
      vehicleModel: driverVehicleModel,
      status: 'accepted',
      acceptedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await updateDoc(doc(db, ride.sourceCollection, ride.rideId), payload);
    AuditRepository.logAction({
      action: 'ASSIGN_TAXI_DRIVER',
      targetResource: `${ride.sourceCollection}/${ride.rideId}`,
      payload
    });
  }

  /**
   * Cancel Ride helper
   */
  static async cancelRide(ride: TaxiRideEntity, reason = 'إلغاء إداري'): Promise<void> {
    await this.cancelTaxiRide(ride.rideId, ride.sourceCollection, reason);
  }
}

export type { TaxiRideEntity };

