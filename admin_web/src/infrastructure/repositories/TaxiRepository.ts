import { 
  collection, 
  query, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc, 
  deleteDoc, 
  getDocs,
  where,
  serverTimestamp 
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface TaxiRideEntity {
  rideId: string;
  sourceCollection: string;
  
  // Passenger / Customer
  passengerId?: string;
  passengerName: string;
  passengerPhone?: string;
  passengerAvatar?: string;
  passengerNotes?: string;
  
  // Captain / Driver
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverAvatar?: string;
  vehicleModel?: string;
  vehiclePlate?: string;
  vehicleColor?: string;
  vehicleType?: string;
  
  // Financials & Pricing
  fareIqd: number;
  baseFareIqd?: number;
  distanceKm?: number;
  durationMinutes?: number;
  discountIqd?: number;
  couponCode?: string;
  commissionIqd: number;
  driverNetIqd: number;
  paymentMethod: string;
  
  // Rating & Review (Customer satisfaction & feedback)
  rating?: number; // 1 to 5
  ratingComment?: string;
  ratingReason?: string;
  ratingTags?: string[];
  ratedAt?: string;
  isRated: boolean;
  
  // Route & GPS
  pickupAddress: string;
  pickupLat?: number;
  pickupLng?: number;
  destinationAddress: string;
  destinationLat?: number;
  destinationLng?: number;
  
  // Status & Timelines
  status: 'searching' | 'accepted' | 'arrived' | 'in_trip' | 'completed' | 'cancelled';
  rawStatus: string;
  statusArabic: string;
  createdAt: string;
  createdTimestamp: number;
  acceptedAt?: string;
  completedAt?: string;
  cancellationReason?: string;
  cancelledBy?: 'passenger' | 'driver' | 'admin';
}

export class TaxiRepository {
  /**
   * Subscribe to all Taxi Rides across multiple collections with combined ratings
   */
  static subscribeToTaxiRides(callback: (rides: TaxiRideEntity[]) => void, maxLimit = 300): () => void {
    let requestsList: TaxiRideEntity[] = [];
    let ridesList: TaxiRideEntity[] = [];
    let ordersTaxiList: TaxiRideEntity[] = [];
    let ratingsMap = new Map<string, { rating: number; comment?: string; reason?: string; tags?: string[]; ratedAt?: string }>();

    const notify = () => {
      const map = new Map<string, TaxiRideEntity>();
      
      // Combine all streams deduplicated by ID
      [...requestsList, ...ridesList, ...ordersTaxiList].forEach(ride => {
        // Merge standalone rating from `ratings` collection if available
        const standaloneRating = ratingsMap.get(ride.rideId) || ratingsMap.get(ride.passengerId || '');
        if (standaloneRating && !ride.rating) {
          ride.rating = standaloneRating.rating;
          ride.ratingComment = standaloneRating.comment || ride.ratingComment;
          ride.ratingReason = standaloneRating.reason || ride.ratingReason;
          ride.ratingTags = standaloneRating.tags || ride.ratingTags;
          ride.isRated = true;
        }
        map.set(ride.rideId, ride);
      });

      const merged = Array.from(map.values());
      merged.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(merged);
    };

    const normalizeRide = (docSnap: any, sourceCol: string): TaxiRideEntity => {
      const data = docSnap.data();
      const fare = Number(data.fare || data.price || data.totalPrice || data.estimatedFare || data.cost || 0);
      const commissionRate = Number(data.commissionRate || 12);
      const commission = Number(data.commissionAmount || Math.round(fare * (commissionRate / 100)));
      const net = Math.max(0, fare - commission);

      let createdStr = 'الآن';
      let createdTs = Date.now();
      if (data.createdAt?.toDate) {
        const dt = data.createdAt.toDate();
        createdStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
        createdTs = dt.getTime();
      } else if (data.createdAt) {
        const dt = new Date(data.createdAt);
        createdStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
        createdTs = !isNaN(dt.getTime()) ? dt.getTime() : Date.now();
      }

      // Status mapping
      const raw = (data.status || 'searching').toString().toLowerCase();
      let normStatus: TaxiRideEntity['status'] = 'searching';
      let statusAr = 'بانتظار كابتن ';

      if (raw.includes('complet') || raw.includes('finish') || raw.includes('done') || raw === 'delivered') {
        normStatus = 'completed';
        statusAr = 'مكتملة بنجاح ';
      } else if (raw.includes('cancel') || raw.includes('reject') || raw === 'declined') {
        normStatus = 'cancelled';
        statusAr = 'ملغاة ';
      } else if (raw.includes('trip') || raw.includes('on_way') || raw.includes('delivering') || raw.includes('progress')) {
        normStatus = 'in_trip';
        statusAr = 'على الطريق (في المشوار) ';
      } else if (raw.includes('arrived') || raw.includes('waiting_passenger')) {
        normStatus = 'arrived';
        statusAr = 'الكابتن وصل نقطة الانطلاق ';
      } else if (raw.includes('accept') || raw.includes('assigned')) {
        normStatus = 'accepted';
        statusAr = 'تم قبول الرحلة ';
      }

      // Ratings extraction
      const ratingVal = Number(data.rating || data.stars || data.driverRating || data.passengerRating || 0);
      const ratingComment = data.ratingComment || data.comment || data.review || data.feedback || data.passengerReview;
      const ratingReason = data.ratingReason || data.reason || data.reviewReason;
      const ratingTags = Array.isArray(data.ratingTags) ? data.ratingTags : (Array.isArray(data.tags) ? data.tags : undefined);

      return {
        rideId: docSnap.id,
        sourceCollection: sourceCol,
        passengerId: data.passengerId || data.customerId || data.userId || data.clientUid,
        passengerName: data.passengerName || data.customerName || data.userName || data.clientName || 'راكب مدار',
        passengerPhone: data.passengerPhone || data.customerPhone || data.userPhone || data.phone,
        passengerAvatar: data.passengerAvatar || data.userAvatar || data.customerImage,
        passengerNotes: data.passengerNotes || data.notes || data.specialInstructions,
        driverId: data.driverId || data.captainId,
        driverName: data.driverName || data.captainName || (data.driverId ? 'كابتن معتمد' : undefined),
        driverPhone: data.driverPhone || data.captainPhone,
        driverAvatar: data.driverAvatar || data.captainAvatar,
        vehicleModel: data.vehicleModel || data.carModel || data.carType || 'سيارة أجرة',
        vehiclePlate: data.carPlate || data.plateNumber || data.vehiclePlate,
        vehicleColor: data.carColor || data.vehicleColor,
        vehicleType: data.serviceType || data.rideType || 'صالون عادي',
        fareIqd: fare,
        baseFareIqd: Number(data.baseFare || fare),
        distanceKm: Number(data.distanceKm || data.distance || data.tripDistance || 0),
        durationMinutes: Number(data.durationMinutes || data.duration || data.estimatedDuration || 0),
        discountIqd: Number(data.discount || data.discountAmount || 0),
        couponCode: data.couponCode || data.promoCode,
        commissionIqd: commission,
        driverNetIqd: net,
        paymentMethod: data.paymentMethod || data.paymentType || 'cash',
        rating: ratingVal > 0 ? ratingVal : undefined,
        ratingComment,
        ratingReason,
        ratingTags,
        ratedAt: data.ratedAt?.toDate ? data.ratedAt.toDate().toLocaleDateString('ar-IQ') : undefined,
        isRated: Boolean(ratingVal > 0 || ratingComment || data.isRated),
        pickupAddress: data.pickupAddress || data.startAddress || data.fromAddress || 'نقطة الانطلاق (القائم)',
        pickupLat: Number(data.pickupLat || data.startLat || data.fromLat || 0) || undefined,
        pickupLng: Number(data.pickupLng || data.startLng || data.fromLng || 0) || undefined,
        destinationAddress: data.destinationAddress || data.dropoffAddress || data.toAddress || 'الوجهة (القائم)',
        destinationLat: Number(data.destinationLat || data.dropoffLat || data.toLat || 0) || undefined,
        destinationLng: Number(data.destinationLng || data.dropoffLng || data.toLng || 0) || undefined,
        status: normStatus,
        rawStatus: raw,
        statusArabic: statusAr,
        createdAt: createdStr,
        createdTimestamp: createdTs,
        acceptedAt: data.acceptedAt?.toDate ? data.acceptedAt.toDate().toLocaleTimeString('ar-IQ') : undefined,
        completedAt: data.completedAt?.toDate ? data.completedAt.toDate().toLocaleTimeString('ar-IQ') : undefined,
        cancellationReason: data.cancelReason || data.cancellationReason || data.reason,
        cancelledBy: data.cancelledBy || (raw.includes('cancel') ? 'passenger' : undefined)
      };
    };

    // 1. Listen to `ride_requests`
    const unsubReq = onSnapshot(query(collection(db, 'ride_requests'), limit(maxLimit)), (snap) => {
      requestsList = snap.docs.map(d => normalizeRide(d, 'ride_requests'));
      notify();
    }, (err) => console.warn('ride_requests stream:', err.message));

    // 2. Listen to `rides`
    const unsubRides = onSnapshot(query(collection(db, 'rides'), limit(maxLimit)), (snap) => {
      ridesList = snap.docs.map(d => normalizeRide(d, 'rides'));
      notify();
    }, (err) => console.warn('rides stream:', err.message));

    // 3. Listen to `orders` where sourceType/type is taxi
    const unsubOrders = onSnapshot(query(collection(db, 'orders'), limit(maxLimit)), (snap) => {
      ordersTaxiList = snap.docs
        .filter(d => {
          const data = d.data();
          return data.sourceType === 'taxi_ride' || data.type === 'taxi' || data.type === 'ride' || data.serviceType === 'taxi';
        })
        .map(d => normalizeRide(d, 'orders'));
      notify();
    }, (err) => console.warn('orders taxi stream:', err.message));

    // 4. Listen to standalone `ratings` collection
    const unsubRatings = onSnapshot(query(collection(db, 'ratings'), limit(maxLimit)), (snap) => {
      ratingsMap.clear();
      snap.docs.forEach(d => {
        const data = d.data();
        const refId = data.referenceId || data.rideId || data.orderId || d.id;
        ratingsMap.set(refId, {
          rating: Number(data.rating || 5),
          comment: data.comment,
          reason: data.reason || data.ratingReason,
          tags: Array.isArray(data.tags) ? data.tags : [],
          ratedAt: data.createdAt?.toDate ? data.createdAt.toDate().toLocaleDateString('ar-IQ') : undefined
        });
      });
      notify();
    }, () => {});

    return () => {
      unsubReq();
      unsubRides();
      unsubOrders();
      unsubRatings();
    };
  }

  /**
   * Cancel a Taxi Ride from Admin
   */
  static async cancelRide(ride: TaxiRideEntity, reason: string): Promise<void> {
    const docRef = doc(db, ride.sourceCollection || 'ride_requests', ride.rideId);
    await updateDoc(docRef, {
      status: 'cancelled',
      cancelReason: reason,
      cancellationReason: reason,
      cancelledBy: 'admin',
      cancelledAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });

    try {
      await AuditRepository.logAction('CANCEL_TAXI_RIDE', 'TAXI', ride.rideId, { reason, fare: ride.fareIqd });
    } catch (_) {}
  }

  /**
   * Reassign Captain to a Taxi Ride
   */
  static async assignDriver(ride: TaxiRideEntity, driverId: string, driverName: string, driverPhone?: string, carPlate?: string, vehicleModel?: string): Promise<void> {
    const docRef = doc(db, ride.sourceCollection || 'ride_requests', ride.rideId);
    await updateDoc(docRef, {
      driverId,
      captainId: driverId,
      driverName,
      captainName: driverName,
      driverPhone: driverPhone || '',
      captainPhone: driverPhone || '',
      carPlate: carPlate || '',
      vehicleModel: vehicleModel || '',
      status: 'accepted',
      assignedAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });

    try {
      await AuditRepository.logAction('REASSIGN_TAXI_RIDE', 'TAXI', ride.rideId, { driverId, driverName });
    } catch (_) {}
  }

  /**
   * Delete Taxi Ride Record permanently
   */
  static async deleteRide(ride: TaxiRideEntity): Promise<void> {
    const docRef = doc(db, ride.sourceCollection || 'ride_requests', ride.rideId);
    await deleteDoc(docRef);

    try {
      await AuditRepository.logAction('DELETE_TAXI_RIDE', 'TAXI', ride.rideId, { fare: ride.fareIqd });
    } catch (_) {}
  }
}
