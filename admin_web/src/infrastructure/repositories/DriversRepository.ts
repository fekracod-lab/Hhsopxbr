import { 
  collection, 
  query, 
  onSnapshot, 
  doc, 
  setDoc,
  updateDoc, 
  deleteDoc,
  where 
} from 'firebase/firestore';
import { db } from '../firebase';
import { DriverEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class DriversRepository {
  /**
   * Subscribe to real drivers from Firestore (Merging users, drivers, and driver_requests)
   */
  static subscribeToDrivers(callback: (drivers: DriverEntity[]) => void): () => void {
    let usersDataMap: Record<string, any> = {};
    let driversDataMap: Record<string, any> = {};
    let requestsDataMap: Record<string, any> = {};

    const recomputeDrivers = () => {
      const allUids = new Set([
        ...Object.keys(usersDataMap),
        ...Object.keys(driversDataMap),
        ...Object.keys(requestsDataMap)
      ]);

      const driversList: DriverEntity[] = [];

      allUids.forEach((uid) => {
        const u = usersDataMap[uid] || {};
        const d = driversDataMap[uid] || {};
        const r = requestsDataMap[uid] || {};

        // Merge all sources with priority: drivers > driver_requests > users
        const data = { ...u, ...r, ...d };

        const role = (data.role || data.accountType || '').toString().toLowerCase();

        // Check if this UID is a driver/captain
        const isDriver = 
          role === 'driver' || 
          role === 'captain' || 
          role === 'taxi_captain' || 
          role === 'delivery' || 
          role === 'delivery_captain' ||
          driversDataMap[uid] !== undefined ||
          requestsDataMap[uid] !== undefined;

        if (isDriver) {
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

          // Comprehensive Plate Number extraction across all Firestore variants
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

          // Comprehensive Vehicle Brand & Model extraction
          const cMake = (data.carType || data.car_type || data.vehicleType || u.carType || d.carType || r.carType || '').toString().trim();
          const cModel = (data.carModel || data.car_model || data.vehicleModel || u.carModel || d.carModel || r.carModel || '').toString().trim();
          
          let extractedModel = 'سيارة تكسي';
          if (cMake && cModel) {
            extractedModel = cMake.includes(cModel) ? cMake : `${cMake} ${cModel}`;
          } else if (cMake) {
            extractedModel = cMake;
          } else if (cModel) {
            extractedModel = cModel;
          } else if (data.vehicle && data.vehicle.model) {
            extractedModel = `${data.vehicle.make || ''} ${data.vehicle.model || ''}`.trim();
          }

          // Comprehensive Color extraction
          const extractedColor = 
            data.carColor || 
            data.car_color || 
            data.vehicleColor || 
            (data.vehicle ? data.vehicle.color : '') || 
            u.carColor ||
            d.carColor ||
            r.carColor ||
            'أصفر / أبيض';

          // Comprehensive Year extraction
          const extractedYear = 
            data.carYear || 
            data.car_year || 
            data.modelYear || 
            data.vehicleYear || 
            data.year || 
            (data.vehicle ? data.vehicle.year : '') || 
            u.carYear ||
            d.carYear ||
            r.carYear ||
            '';

          // Car Image & Avatar
          const carPhoto = data.carImage || data.carPhoto || data.vehiclePhotoUrl || data.vehicleImage || d.carImage || r.carImage;
          const userAvatar = data.photoUrl || data.avatarUrl || data.profileImage || data.personalPhotoUrl || u.photoUrl || d.photoUrl;

          // Categorize vehicle & service strictly (دراجات توصيل vs سيارات تكسي)
          const isMotorcycle = 
            data.vehicleCategory === 'motorcycle' ||
            data.vehicleType === 'motorcycle' || 
            data.vehicleType === 'bike' ||
            data.driverType === 'delivery' ||
            role === 'delivery' ||
            role === 'delivery_captain' ||
            extractedModel.includes('دراجة') ||
            extractedModel.includes('ماطور') ||
            extractedModel.includes('سكوتر') ||
            extractedModel.includes('ستوتة') ||
            extractedModel.includes('ستوته') ||
            extractedModel.toLowerCase().includes('bike') ||
            extractedModel.toLowerCase().includes('motorcycle');

          const vehicleCategory: 'motorcycle' | 'taxi' = isMotorcycle ? 'motorcycle' : 'taxi';
          const serviceType: 'taxi' | 'delivery' | 'both' = isMotorcycle ? 'delivery' : (role === 'delivery' ? 'delivery' : (role === 'taxi_captain' ? 'taxi' : 'both'));

          driversList.push({
            driverId: uid,
            name: data.name || data.fullName || data.driverName || data.username || 'كابتن مدار',
            phoneNumber: data.phoneNumber || data.phone || data.userPhone || 'غير مسجل',
            email: data.email || u.email,
            vehicleCategory: vehicleCategory,
            serviceType: serviceType,
            vehicleModel: extractedModel,
            vehicleColor: extractedColor,
            vehicleYear: extractedYear ? extractedYear.toString() : '',
            plateNumber: extractedPlate,
            city: data.city || data.town || 'القائم',
            governorate: data.governorate || 'الأنبار',
            isOnline: data.isOnline === true || data.status === 'online',
            isBlocked: data.isBlocked === true || data.status === 'banned' || data.status === 'blocked',
            blockReason: data.blockReason || data.banReason,
            kycStatus: data.kycStatus || (data.isApproved === true ? 'verified' : (data.isApproved === false ? 'rejected' : 'pending')),
            riskScore: Number(data.riskScore || 0),
            walletBalance: Number(data.walletBalance || data.balance || 0),
            appDebt: Number(data.appDebt || data.debt || data.commissionDebt || 0),
            totalEarnings: Number(data.totalEarnings || data.earnings || 0),
            rating: Number(data.rating || 5.0),
            totalTrips: Number(data.totalTrips || data.tripsCount || data.completedTrips || 0),
            createdAt: createdDateStr,
            createdTimestamp: createdTimestamp,
            nationalIdUrl: data.nationalIdUrl || data.idCardUrl || data.idPhoto || data.identityUrl,
            licenseUrl: data.drivingLicenseUrl || data.licensePhoto || data.licenseUrl || data.drivingLicensePhoto,
            carDocUrl: data.carDocUrl || data.carRegistrationUrl || data.registrationPhoto || data.carDocumentUrl,
            personalPhotoUrl: userAvatar || carPhoto,
            lastLocation: data.location ? {
              lat: data.location.latitude || data.location.lat,
              lng: data.location.longitude || data.location.lng,
              updatedAt: data.location.updatedAt ? new Date(data.location.updatedAt).toISOString() : 'الآن'
            } : undefined
          });
        }
      });

      // Sort descending: Newest registration to oldest
      driversList.sort((a, b) => b.createdTimestamp - a.createdTimestamp);

      callback(driversList);
    };

    // 1. Listen to users collection
    const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
      usersDataMap = {};
      snap.docs.forEach((docSnap) => {
        usersDataMap[docSnap.id] = docSnap.data();
      });
      recomputeDrivers();
    }, (err) => console.warn('Users stream error:', err.message));

    // 2. Listen to drivers collection
    const unsubDrivers = onSnapshot(collection(db, 'drivers'), (snap) => {
      driversDataMap = {};
      snap.docs.forEach((docSnap) => {
        driversDataMap[docSnap.id] = docSnap.data();
      });
      recomputeDrivers();
    }, (err) => console.warn('Drivers stream error:', err.message));

    // 3. Listen to driver_requests collection
    const unsubRequests = onSnapshot(collection(db, 'driver_requests'), (snap) => {
      requestsDataMap = {};
      snap.docs.forEach((docSnap) => {
        requestsDataMap[docSnap.id] = docSnap.data();
      });
      recomputeDrivers();
    }, (err) => console.warn('Driver requests stream error:', err.message));

    return () => {
      unsubUsers();
      unsubDrivers();
      unsubRequests();
    };
  }

  /**
   * Update Driver & Vehicle details in Firestore
   */
  static async updateDriverDetails(
    driverId: string,
    details: {
      name?: string;
      phoneNumber?: string;
      vehicleModel?: string;
      plateNumber?: string;
      vehicleColor?: string;
      vehicleYear?: string;
      city?: string;
      walletBalance?: number;
      appDebt?: number;
      personalPhotoUrl?: string;
      nationalIdUrl?: string;
      licenseUrl?: string;
      carDocUrl?: string;
    }
  ): Promise<void> {
    const payload: Record<string, any> = {
      updatedAt: new Date().toISOString()
    };

    if (details.name !== undefined) {
      payload.name = details.name;
      payload.fullName = details.name;
    }
    if (details.phoneNumber !== undefined) {
      payload.phone = details.phoneNumber;
      payload.phoneNumber = details.phoneNumber;
    }
    if (details.vehicleModel !== undefined) {
      payload.carType = details.vehicleModel;
      payload.carModel = details.vehicleModel;
      payload.vehicleModel = details.vehicleModel;
    }
    if (details.plateNumber !== undefined) {
      payload.carNumber = details.plateNumber;
      payload.plateNumber = details.plateNumber;
      payload.car_number = details.plateNumber;
    }
    if (details.vehicleColor !== undefined) {
      payload.carColor = details.vehicleColor;
      payload.vehicleColor = details.vehicleColor;
    }
    if (details.vehicleYear !== undefined) {
      payload.carYear = details.vehicleYear;
      payload.vehicleYear = details.vehicleYear;
    }
    if (details.city !== undefined) {
      payload.city = details.city;
    }
    if (details.walletBalance !== undefined) {
      payload.walletBalance = details.walletBalance;
      payload.balance = details.walletBalance;
    }
    if (details.appDebt !== undefined) {
      payload.appDebt = details.appDebt;
      payload.debt = details.appDebt;
    }
    if (details.personalPhotoUrl !== undefined) {
      payload.photoUrl = details.personalPhotoUrl;
      payload.avatarUrl = details.personalPhotoUrl;
      payload.profileImage = details.personalPhotoUrl;
      payload.personalPhotoUrl = details.personalPhotoUrl;
    }
    if (details.nationalIdUrl !== undefined) {
      payload.nationalIdUrl = details.nationalIdUrl;
      payload.idCardUrl = details.nationalIdUrl;
    }
    if (details.licenseUrl !== undefined) {
      payload.drivingLicenseUrl = details.licenseUrl;
      payload.licenseUrl = details.licenseUrl;
    }
    if (details.carDocUrl !== undefined) {
      payload.carDocUrl = details.carDocUrl;
      payload.carRegistrationUrl = details.carDocUrl;
    }

    await updateDoc(doc(db, 'users', driverId), payload).catch(() => {});
    await updateDoc(doc(db, 'drivers', driverId), payload).catch(() => {});
    await updateDoc(doc(db, 'driver_requests', driverId), payload).catch(() => {});

    try {
      await AuditRepository.logAction('UPDATE_DRIVER_DETAILS', 'driver', driverId, details);
    } catch (_) {}
  }

  /**
   * Block or Unblock a driver in Firestore
   */
  static async toggleBlockDriver(driverId: string, block: boolean, reason?: string): Promise<void> {
    const updateData = {
      isBlocked: block,
      status: block ? 'banned' : 'active',
      blockReason: block ? (reason || 'حظر بقرار إداري') : null
    };

    // Update in users
    await updateDoc(doc(db, 'users', driverId), updateData).catch(() => {});
    // Update in drivers if present
    await updateDoc(doc(db, 'drivers', driverId), updateData).catch(() => {});

    try {
      await AuditRepository.logAction(
        block ? 'BLOCK_DRIVER' : 'UNBLOCK_DRIVER',
        'driver',
        driverId,
        { isBlocked: block, reason }
      );
    } catch (_) {}
  }

  /**
   * Approve driver KYC
   */
  static async approveDriverKyc(driverId: string): Promise<void> {
    const updateData = {
      isApproved: true,
      kycStatus: 'verified',
      approvedAt: new Date().toISOString()
    };

    await updateDoc(doc(db, 'users', driverId), updateData).catch(() => {});
    await updateDoc(doc(db, 'drivers', driverId), updateData).catch(() => {});

    try {
      await AuditRepository.logAction('APPROVE_DRIVER_KYC', 'driver', driverId, { isApproved: true });
    } catch (_) {}
  }

  /**
   * Reject driver KYC
   */
  static async rejectDriverKyc(driverId: string, reason: string): Promise<void> {
    const updateData = {
      isApproved: false,
      kycStatus: 'rejected',
      rejectionReason: reason
    };

    await updateDoc(doc(db, 'users', driverId), updateData).catch(() => {});
    await updateDoc(doc(db, 'drivers', driverId), updateData).catch(() => {});

    try {
      await AuditRepository.logAction('REJECT_DRIVER_KYC', 'driver', driverId, { isApproved: false, reason });
    } catch (_) {}
  }

  /**
   * Delete a driver record from Firestore
   */
  static async deleteDriver(driverId: string): Promise<void> {
    await deleteDoc(doc(db, 'users', driverId)).catch(() => {});
    await deleteDoc(doc(db, 'drivers', driverId)).catch(() => {});
    await deleteDoc(doc(db, 'driver_requests', driverId)).catch(() => {});

    try {
      await AuditRepository.logAction('DELETE_DRIVER', 'driver', driverId, {});
    } catch (_) {}
  }

  /**
   * Delete multiple drivers simultaneously (Bulk Delete)
   */
  static async deleteMultipleDrivers(driverIds: string[]): Promise<void> {
    const deleteTasks = driverIds.map(async (id) => {
      await deleteDoc(doc(db, 'users', id)).catch(() => {});
      await deleteDoc(doc(db, 'drivers', id)).catch(() => {});
      await deleteDoc(doc(db, 'driver_requests', id)).catch(() => {});
    });

    await Promise.all(deleteTasks);

    try {
      await AuditRepository.logAction('BULK_DELETE_DRIVERS', 'driver', 'batch', {
        count: driverIds.length,
        driverIds
      });
    } catch (_) {}
  }

  /**
   * Toggle or force driver Online/Offline status across Firestore
   */
  static async toggleDriverOnlineStatus(driverId: string, makeOnline: boolean): Promise<void> {
    const payload = {
      isOnline: makeOnline,
      available: makeOnline,
      status: makeOnline ? 'online' : 'offline',
      lastSeen: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    // Update in drivers, users, and driver_presence
    await setDoc(doc(db, 'drivers', driverId), payload, { merge: true }).catch(() => {});
    await setDoc(doc(db, 'users', driverId), payload, { merge: true }).catch(() => {});
    await setDoc(doc(db, 'driver_presence', driverId), {
      driverId,
      isOnline: makeOnline,
      status: makeOnline ? 'online' : 'offline',
      lastHeartbeat: new Date().toISOString()
    }, { merge: true }).catch(() => {});

    try {
      await AuditRepository.logAction(
        makeOnline ? 'DRIVER_SET_ONLINE' : 'DRIVER_SET_OFFLINE',
        'driver',
        driverId,
        { isOnline: makeOnline }
      );
    } catch (_) {}
  }
}
