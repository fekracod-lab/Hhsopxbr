import { 
  collection, 
  onSnapshot, 
  doc, 
  setDoc,
  updateDoc, 
  deleteDoc
} from 'firebase/firestore';
import { db } from '../firebase';
import { MersalCourierEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class MersalCourierRepository {
  /**
   * Stream real Mersal / Delivery Couriers from Firestore with strict domain isolation
   */
  static subscribeToCouriers(callback: (couriers: MersalCourierEntity[]) => void): () => void {
    let usersDataMap: Record<string, any> = {};
    let driversDataMap: Record<string, any> = {};
    let requestsDataMap: Record<string, any> = {};

    const recomputeCouriers = () => {
      const allUids = new Set([
        ...Object.keys(usersDataMap),
        ...Object.keys(driversDataMap),
        ...Object.keys(requestsDataMap)
      ]);

      const couriersList: MersalCourierEntity[] = [];

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

        // Strict Mersal / Delivery Courier Discriminator:
        const isDeliveryCourier = 
          data.isDelivery === true ||
          role === 'delivery' ||
          role === 'delivery_captain' ||
          subRole === 'delivery' ||
          type === 'delivery' ||
          vCategory === 'motorcycle' ||
          vModel.includes('دراجة') ||
          vModel.includes('ماطور') ||
          vModel.includes('سكوتر') ||
          vModel.includes('ستوتة') ||
          vModel.includes('bike');

        if (!isDeliveryCourier) {
          return; // Exclude non-delivery drivers
        }

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
          '';

        const extractedPlate = rawPlate.toString().trim() || 'غير مسجلة';

        // Vehicle Model
        const cModelStr = (data.carModel || data.vehicleModel || data.carType || '').toString().trim();
        let extractedModel = cModelStr || 'دراجة نارية توصيل (مرسال)';

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

        couriersList.push({
          courierId: uid,
          driverId: uid,
          name: data.name || data.fullName || data.username || data.driverName || 'مندوب توصيل مرسال',
          phoneNumber: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
          email: data.email,
          vehicleCategory: 'motorcycle',
          vehicleModel: extractedModel,
          vehicleColor: data.carColor || data.vehicleColor || 'أسود / أحمر',
          vehicleYear: (data.carYear || data.modelYear || data.year || '2022').toString(),
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
          totalDeliveries: Number(data.completedTrips || data.totalTrips || data.deliveriesCount || 0),
          totalTrips: Number(data.completedTrips || data.totalTrips || data.deliveriesCount || 0),
          createdAt: createdDateStr,
          createdTimestamp,
          nationalIdUrl: data.nationalIdUrl || data.idCardUrl || data.idPhoto,
          licenseUrl: data.drivingLicenseUrl || data.licenseUrl || data.licensePhoto,
          bikeDocUrl: data.carDocUrl || data.carRegistrationUrl || data.registrationPhoto,
          carDocUrl: data.carDocUrl || data.carRegistrationUrl || data.registrationPhoto,
          personalPhotoUrl: data.personalPhotoUrl || data.photoUrl || data.avatarUrl || data.profileImage,
          lastLocation: data.lastLocation || (data.latitude && data.longitude ? {
            lat: Number(data.latitude),
            lng: Number(data.longitude),
            updatedAt: new Date().toISOString()
          } : undefined)
        });
      });

      // Sort: Active online first, then by registration date
      couriersList.sort((a, b) => {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return b.createdTimestamp - a.createdTimestamp;
      });

      callback(couriersList);
    };

    // 1. Listen to `users`
    const unsubUsers = onSnapshot(collection(db, 'users'), (snapshot) => {
      usersDataMap = {};
      snapshot.docs.forEach((d) => {
        usersDataMap[d.id] = { ...d.data(), id: d.id };
      });
      recomputeCouriers();
    }, (err) => console.warn('users stream (Mersal):', err.message));

    // 2. Listen to `drivers`
    const unsubDrivers = onSnapshot(collection(db, 'drivers'), (snapshot) => {
      driversDataMap = {};
      snapshot.docs.forEach((d) => {
        driversDataMap[d.id] = { ...d.data(), id: d.id };
      });
      recomputeCouriers();
    }, (err) => console.warn('drivers stream (Mersal):', err.message));

    // 3. Listen to `driver_requests`
    const unsubRequests = onSnapshot(collection(db, 'driver_requests'), (snapshot) => {
      requestsDataMap = {};
      snapshot.docs.forEach((d) => {
        requestsDataMap[d.id] = { ...d.data(), id: d.id };
      });
      recomputeCouriers();
    }, (err) => console.warn('driver_requests stream (Mersal):', err.message));

    return () => {
      unsubUsers();
      unsubDrivers();
      unsubRequests();
    };
  }

  /**
   * Toggle Courier Online Status (Connect / Disconnect)
   */
  static async toggleCourierOnlineStatus(courierId: string, makeOnline: boolean): Promise<void> {
    const now = new Date().toISOString();
    const updatePayload = {
      isOnline: makeOnline,
      available: makeOnline,
      status: makeOnline ? 'available' : 'offline',
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', courierId), updatePayload);
    } catch {
      await setDoc(doc(db, 'drivers', courierId), updatePayload, { merge: true });
    }

    try {
      await updateDoc(doc(db, 'users', courierId), { isOnline: makeOnline, updatedAt: now });
    } catch {
      // User doc might not exist directly
    }

    AuditRepository.logAction({
      action: makeOnline ? 'CONNECT_MERSAL_COURIER' : 'DISCONNECT_MERSAL_COURIER',
      targetResource: `drivers/${courierId}`,
      payload: { makeOnline, timestamp: now }
    });
  }

  /**
   * Block or Unblock Courier
   */
  static async toggleCourierBlock(courierId: string, block: boolean, reason = 'مخالفة معايير التوصيل'): Promise<void> {
    const now = new Date().toISOString();
    const payload = {
      isBlocked: block,
      blockReason: block ? reason : null,
      status: block ? 'blocked' : 'active',
      isOnline: block ? false : undefined,
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', courierId), payload);
    } catch {
      await setDoc(doc(db, 'drivers', courierId), payload, { merge: true });
    }

    try {
      await updateDoc(doc(db, 'users', courierId), { isBlocked: block, updatedAt: now });
    } catch {
      // Ignored
    }

    AuditRepository.logAction({
      action: block ? 'BLOCK_MERSAL_COURIER' : 'UNBLOCK_MERSAL_COURIER',
      targetResource: `drivers/${courierId}`,
      payload: { block, reason }
    });
  }

  /**
   * Update Courier Verification / KYC Status
   */
  static async updateCourierKyc(courierId: string, status: 'verified' | 'rejected' | 'pending', reason?: string): Promise<void> {
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
      await updateDoc(doc(db, 'drivers', courierId), payload);
    } catch {
      await setDoc(doc(db, 'drivers', courierId), payload, { merge: true });
    }

    AuditRepository.logAction({
      action: 'UPDATE_MERSAL_COURIER_KYC',
      targetResource: `drivers/${courierId}`,
      payload: { status, reason }
    });
  }

  /**
   * Update Courier Details (Phone, Vehicle, City, Balance, Docs)
   */
  static async updateCourierDetails(courierId: string, updates: Partial<MersalCourierEntity>): Promise<void> {
    const now = new Date().toISOString();
    const payload: any = {
      ...updates,
      updatedAt: now
    };

    try {
      await updateDoc(doc(db, 'drivers', courierId), payload);
    } catch {
      await setDoc(doc(db, 'drivers', courierId), payload, { merge: true });
    }

    try {
      const userUpdates: any = {};
      if (updates.name) userUpdates.name = updates.name;
      if (updates.phoneNumber) userUpdates.phoneNumber = updates.phoneNumber;
      if (updates.city) userUpdates.city = updates.city;
      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = now;
        await updateDoc(doc(db, 'users', courierId), userUpdates);
      }
    } catch {
      // Optional user doc
    }

    AuditRepository.logAction({
      action: 'UPDATE_MERSAL_COURIER_DETAILS',
      targetResource: `drivers/${courierId}`,
      payload: updates
    });
  }

  /**
   * Delete Courier Record
   */
  static async deleteCourier(courierId: string): Promise<void> {
    try {
      await deleteDoc(doc(db, 'drivers', courierId));
    } catch {
      // Ignore if not present
    }

    AuditRepository.logAction({
      action: 'DELETE_MERSAL_COURIER',
      targetResource: `drivers/${courierId}`,
      payload: { courierId }
    });
  }

  /**
   * Delete Multiple Couriers
   */
  static async deleteMultipleCouriers(courierIds: string[]): Promise<void> {
    for (const id of courierIds) {
      await this.deleteCourier(id);
    }
  }
}
