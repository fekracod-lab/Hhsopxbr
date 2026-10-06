import { 
  collection, 
  onSnapshot, 
  doc, 
  setDoc,
  updateDoc, 
  deleteDoc
} from 'firebase/firestore';
import { db } from '../firebase';
import { TaxiCaptainEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class TaxiCaptainRepository {
  /**
   * Stream real Taxi Captains from Firestore with strict domain isolation
   */
  static subscribeToCaptains(callback: (captains: TaxiCaptainEntity[]) => void): () => void {
    let usersDataMap: Record<string, any> = {};
    let driversDataMap: Record<string, any> = {};
    let requestsDataMap: Record<string, any> = {};

    const recomputeCaptains = () => {
      const allUids = new Set([
        ...Object.keys(usersDataMap),
        ...Object.keys(driversDataMap),
        ...Object.keys(requestsDataMap)
      ]);

      const captainsList: TaxiCaptainEntity[] = [];

      allUids.forEach((uid) => {
        const u = usersDataMap[uid] || {};
        const d = driversDataMap[uid] || {};
        const r = requestsDataMap[uid] || {};

        // Merge sources with priority: drivers > driver_requests > users
        const data = { ...u, ...r, ...d };

        const role = (data.role || data.accountType || '').toString().toLowerCase();
        const subRole = (data.subRole || '').toString().toLowerCase();
        const type = (data.type || '').toString().toLowerCase();
        const vCategory = (data.vehicleCategory || data.vehicleType || '').toString().toLowerCase();
        const vModel = (data.carModel || data.vehicleModel || data.carType || '').toString().toLowerCase();

        // Strict Taxi Captain Discriminator:
        // Must NOT be delivery courier, motorcycle, scooter, or marked isDelivery == true
        const isDeliveryCourier = 
          data.isDelivery === true ||
          role === 'delivery' ||
          subRole === 'delivery' ||
          type === 'delivery' ||
          vCategory === 'motorcycle' ||
          vModel.includes('دراجة') ||
          vModel.includes('ماطور') ||
          vModel.includes('ستوتة') ||
          vModel.includes('bike');

        if (isDeliveryCourier) {
          return; // Exclude delivery couriers
        }

        const isTaxiCaptain = 
          role === 'driver' || 
          role === 'captain' || 
          role === 'taxi_captain' || 
          driversDataMap[uid] !== undefined ||
          (requestsDataMap[uid] !== undefined && !isDeliveryCourier);

        if (isTaxiCaptain) {
          // Extract Registration Date
          const rawCreated = data.createdAt || u.createdAt || d.createdAt || r.createdAt;
          let createdDateStr = 'الآن';
          let createdTimestamp = 0;

          if (rawCreated?.toDate) {
            const dt = rawCreated.toDate();
            createdDateStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
            createdTimestamp = dt.getTime();
          } else if (rawCreated) {
            const dt = new Date(rawCreated);
            createdDateStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
            createdTimestamp = !isNaN(dt.getTime()) ? dt.getTime() : 0;
          }

          // Plate Number
          const rawPlate = 
            data.carNumber || 
            data.plateNumber || 
            data.car_number || 
            data.plate_number || 
            data.carPlate || 
            data.vehiclePlate || 
            (data.vehicle && (data.vehicle.plateNumber || data.vehicle.carNumber)) ||
            (u.carNumber || u.plateNumber) ||
            (d.carNumber || d.plateNumber) ||
            (r.carNumber || r.plateNumber) ||
            '';

          const extractedPlate = rawPlate.toString().trim() || 'غير مسجلة';

          // Vehicle Model
          const cMake = (data.carType || data.car_type || data.vehicleType || u.carType || d.carType || r.carType || '').toString().trim();
          const cModelStr = (data.carModel || data.car_model || data.vehicleModel || u.carModel || d.carModel || r.carModel || '').toString().trim();
          
          let extractedModel = 'سيارة تكسي';
          if (cMake && cModelStr) {
            extractedModel = `${cMake} ${cModelStr}`;
          } else if (cModelStr) {
            extractedModel = cModelStr;
          } else if (cMake) {
            extractedModel = cMake;
          }

          // Online Status
          const isOnline = 
            data.isOnline === true || 
            data.online === true || 
            data.available === true ||
            data.status === 'online' || 
            data.status === 'available';

          // Blocked Status
          const isBlocked = 
            data.isBlocked === true || 
            data.blocked === true || 
            data.status === 'blocked' || 
            data.status === 'suspended';

          // KYC Status
          let kycStatus: 'pending' | 'verified' | 'rejected' = 'verified';
          if (data.isApproved === false || data.kycStatus === 'pending') {
            kycStatus = 'pending';
          } else if (data.isRejected === true || data.kycStatus === 'rejected') {
            kycStatus = 'rejected';
          }

          captainsList.push({
            driverId: uid,
            name: data.name || data.fullName || data.username || data.driverName || 'كابتن تكسي مدار',
            phoneNumber: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
            email: data.email,
            vehicleCategory: 'taxi',
            vehicleModel: extractedModel,
            vehicleColor: data.carColor || data.vehicleColor || 'أصفر / أبيض',
            vehicleYear: (data.carYear || data.modelYear || data.year || '2020').toString(),
            plateNumber: extractedPlate,
            city: data.city || data.governorateName || data.governorate || 'القائم',
            governorate: data.governorate || 'الأنبار',
            isOnline,
            isBlocked,
            blockReason: data.blockReason || data.banReason,
            kycStatus,
            riskScore: Number(data.riskScore || 0),
            walletBalance: Number(data.walletBalance || data.balance || data.wallet || 0),
            appDebt: Number(data.appDebt || data.debt || 0),
            totalEarnings: Number(data.totalEarnings || data.earnings || 0),
            rating: Number(data.rating || data.rate || 5.0),
            totalTrips: Number(data.completedTrips || data.totalTrips || data.tripsCount || 0),
            createdAt: createdDateStr,
            createdTimestamp,
            nationalIdUrl: data.nationalIdUrl || data.idCardUrl || data.idPhoto,
            licenseUrl: data.drivingLicenseUrl || data.licenseUrl || data.licensePhoto,
            carDocUrl: data.carDocUrl || data.carRegistrationUrl || data.registrationPhoto,
            personalPhotoUrl: data.personalPhotoUrl || data.photoUrl || data.avatarUrl || data.profileImage,
            lastLocation: data.lastLocation || (data.latitude && data.longitude ? {
              lat: Number(data.latitude),
              lng: Number(data.longitude),
              updatedAt: new Date().toISOString()
            } : undefined)
          });
        }
      });

      // Sort: Active online first, then by registration date
      captainsList.sort((a, b) => {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return b.createdTimestamp - a.createdTimestamp;
      });

      callback(captainsList);
    };

    // 1. Listen to `users`
    const unsubUsers = onSnapshot(collection(db, 'users'), (snapshot) => {
      usersDataMap = {};
      snapshot.docs.forEach((d) => {
        usersDataMap[d.id] = { ...d.data(), id: d.id };
      });
      recomputeCaptains();
    }, (err) => console.warn('users stream (Taxi):', err.message));

    // 2. Listen to `drivers`
    const unsubDrivers = onSnapshot(collection(db, 'drivers'), (snapshot) => {
      driversDataMap = {};
      snapshot.docs.forEach((d) => {
        driversDataMap[d.id] = { ...d.data(), id: d.id };
      });
      recomputeCaptains();
    }, (err) => console.warn('drivers stream (Taxi):', err.message));

    // 3. Listen to `driver_requests`
    const unsubRequests = onSnapshot(collection(db, 'driver_requests'), (snapshot) => {
      requestsDataMap = {};
      snapshot.docs.forEach((d) => {
        requestsDataMap[d.id] = { ...d.data(), id: d.id };
      });
      recomputeCaptains();
    }, (err) => console.warn('driver_requests stream (Taxi):', err.message));

    return () => {
      unsubUsers();
      unsubDrivers();
      unsubRequests();
    };
  }

  /**
   * Toggle Captain Online Status (Connect / Disconnect)
   */
  static async toggleCaptainOnlineStatus(driverId: string, makeOnline: boolean): Promise<void> {
    const now = new Date().toISOString();
    const updatePayload = {
      isOnline: makeOnline,
      available: makeOnline,
      status: makeOnline ? 'available' : 'offline',
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', driverId), updatePayload);
    } catch {
      await setDoc(doc(db, 'drivers', driverId), updatePayload, { merge: true });
    }

    try {
      await updateDoc(doc(db, 'users', driverId), { isOnline: makeOnline, updatedAt: now });
    } catch {
      // User doc might not exist directly
    }

    try {
      await setDoc(doc(db, 'driver_presence', driverId), {
        isOnline: makeOnline,
        lastHeartbeat: now,
        status: makeOnline ? 'available' : 'offline'
      }, { merge: true });
    } catch {
      // presence doc optional
    }

    AuditRepository.logAction({
      action: makeOnline ? 'CONNECT_TAXI_CAPTAIN' : 'DISCONNECT_TAXI_CAPTAIN',
      targetResource: `drivers/${driverId}`,
      payload: { makeOnline, timestamp: now }
    });
  }

  /**
   * Block or Unblock Captain
   */
  static async toggleCaptainBlock(driverId: string, block: boolean, reason = 'مخالفة معايير الأمان'): Promise<void> {
    const now = new Date().toISOString();
    const payload = {
      isBlocked: block,
      blockReason: block ? reason : null,
      status: block ? 'blocked' : 'active',
      isOnline: block ? false : undefined,
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', driverId), payload);
    } catch {
      await setDoc(doc(db, 'drivers', driverId), payload, { merge: true });
    }

    try {
      await updateDoc(doc(db, 'users', driverId), { isBlocked: block, updatedAt: now });
    } catch {
      // Ignored
    }

    AuditRepository.logAction({
      action: block ? 'BLOCK_TAXI_CAPTAIN' : 'UNBLOCK_TAXI_CAPTAIN',
      targetResource: `drivers/${driverId}`,
      payload: { block, reason }
    });
  }

  /**
   * Update Captain Verification / KYC Status
   */
  static async updateCaptainKyc(driverId: string, status: 'verified' | 'rejected' | 'pending', reason?: string): Promise<void> {
    const now = new Date().toISOString();
    const payload = {
      kycStatus: status,
      isApproved: status === 'verified',
      isRejected: status === 'rejected',
      rejectionReason: reason || null,
      status: status === 'verified' ? 'active' : (status === 'rejected' ? 'rejected' : 'pending'),
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', driverId), payload);
    } catch {
      await setDoc(doc(db, 'drivers', driverId), payload, { merge: true });
    }

    AuditRepository.logAction({
      action: 'UPDATE_TAXI_CAPTAIN_KYC',
      targetResource: `drivers/${driverId}`,
      payload: { status, reason }
    });
  }

  /**
   * Update Captain Details (Phone, Vehicle, City, Balance, Docs)
   */
  static async updateCaptainDetails(driverId: string, updates: Partial<TaxiCaptainEntity>): Promise<void> {
    const now = new Date().toISOString();
    const payload: any = {
      ...updates,
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', driverId), payload);
    } catch {
      await setDoc(doc(db, 'drivers', driverId), payload, { merge: true });
    }

    try {
      const userUpdates: any = {};
      if (updates.name) userUpdates.name = updates.name;
      if (updates.phoneNumber) userUpdates.phoneNumber = updates.phoneNumber;
      if (updates.city) userUpdates.city = updates.city;
      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = now;
        await updateDoc(doc(db, 'users', driverId), userUpdates);
      }
    } catch {
      // User doc update optional
    }

    AuditRepository.logAction({
      action: 'UPDATE_TAXI_CAPTAIN_DETAILS',
      targetResource: `drivers/${driverId}`,
      payload: updates
    });
  }

  /**
   * Delete Captain Record
   */
  static async deleteCaptain(driverId: string): Promise<void> {
    try {
      await deleteDoc(doc(db, 'drivers', driverId));
    } catch {
      // Ignore if not present
    }

    AuditRepository.logAction({
      action: 'DELETE_TAXI_CAPTAIN',
      targetResource: `drivers/${driverId}`,
      payload: { driverId }
    });
  }

  /**
   * Delete Multiple Captains
   */
  static async deleteMultipleCaptains(driverIds: string[]): Promise<void> {
    for (const id of driverIds) {
      await this.deleteCaptain(id);
    }
  }
}
