import { 
  collection, 
  onSnapshot, 
  doc, 
  updateDoc, 
  deleteDoc, 
  setDoc, 
  getDoc,
  serverTimestamp,
  query,
  limit
} from 'firebase/firestore';
import { db } from '../firebase';

export type RegistrationDomain = 'restaurant' | 'store' | 'taxi_captain' | 'mersal_courier';

export interface RegistrationRequestEntity {
  id: string;
  domain: RegistrationDomain;
  applicantName: string;
  businessOrVehicleTitle: string;
  phoneNumber: string;
  whatsappNumber?: string;
  email?: string;
  city?: string;
  address?: string;
  categoryOrType?: string; // e.g. "مشاوي ومعجنات", "دراجة نارية", "سوبرماركت"
  vehicleTypeCategory?: 'motorcycle' | 'car' | 'taxi';
  vehiclePlate?: string;
  vehicleModel?: string;
  vehicleYear?: string;
  vehicleColor?: string;
  status: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  createdAt: string;
  createdTimestamp: number;
  
  // Documents & Photos
  profilePhotoUrl?: string;
  storefrontPhotoUrl?: string;
  nationalIdUrl?: string;
  licenseUrl?: string;
  vehicleDocUrl?: string;
  commercialRecordUrl?: string;
  
  commissionRate?: number;
  notes?: string;
  rawSourceCollection: string;
}

export class RegistrationRequestsRepository {

  /**
   * Listen to all registration requests across collections with strict domain separation
   */
  static subscribeToAllRequests(callback: (requests: RegistrationRequestEntity[]) => void) {
    let restaurantRequests: RegistrationRequestEntity[] = [];
    let driverRequests: RegistrationRequestEntity[] = [];
    let storeRequests: RegistrationRequestEntity[] = [];

    const notify = () => {
      const merged = [...restaurantRequests, ...driverRequests, ...storeRequests];
      merged.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(merged);
    };

    // Helper to format date
    const parseDate = (raw: any): { dateStr: string; timestamp: number } => {
      if (raw?.toDate) {
        const dt = raw.toDate();
        return {
          dateStr: dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }),
          timestamp: dt.getTime()
        };
      }
      if (raw) {
        const dt = new Date(raw);
        if (!isNaN(dt.getTime())) {
          return {
            dateStr: dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric' }),
            timestamp: dt.getTime()
          };
        }
      }
      return { dateStr: 'الآن', timestamp: Date.now() };
    };

    // 1. Listen to `restaurant_requests`
    const unsubRest = onSnapshot(collection(db, 'restaurant_requests'), (snapshot) => {
      restaurantRequests = snapshot.docs.map((d) => {
        const data = d.data();
        const { dateStr, timestamp } = parseDate(data.createdAt || data.appliedAt || data.timestamp);

        return {
          id: d.id,
          domain: 'restaurant',
          applicantName: data.ownerName || data.managerName || data.name || data.fullName || 'صاحب المطعم',
          businessOrVehicleTitle: data.restaurantName || data.name || 'مطعم جديد',
          phoneNumber: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
          whatsappNumber: data.whatsapp || data.whatsappNumber || data.phone,
          email: data.email,
          city: data.city || data.governorateName || data.governorate || 'القائم',
          address: data.address || data.locationName || 'القائم',
          categoryOrType: data.cuisineType || data.category || 'مطعم ومأكولات',
          status: (data.status === 'approved' || data.isApproved === true) ? 'approved' : ((data.status === 'rejected' || data.isRejected === true) ? 'rejected' : 'pending'),
          rejectionReason: data.rejectionReason || data.rejectReason,
          createdAt: dateStr,
          createdTimestamp: timestamp,
          profilePhotoUrl: data.logoUrl || data.logo || data.personalPhotoUrl,
          storefrontPhotoUrl: data.coverUrl || data.imageUrl || data.restaurantPhotoUrl,
          commercialRecordUrl: data.healthCertificateUrl || data.licenseUrl || data.commercialRegisterUrl,
          commissionRate: Number(data.commissionRate || 10),
          notes: data.notes || data.description || data.bio,
          rawSourceCollection: 'restaurant_requests'
        };
      });
      notify();
    }, (err) => console.warn('restaurant_requests stream:', err.message));

    // 2. Listen to `driver_requests` and separate Taxi vs Mersal Delivery
    const unsubDrivers = onSnapshot(collection(db, 'driver_requests'), (snapshot) => {
      driverRequests = snapshot.docs.map((d) => {
        const data = d.data();
        const { dateStr, timestamp } = parseDate(data.createdAt || data.appliedAt || data.timestamp);

        const vModel = (data.vehicleModel || data.carModel || data.carType || data.bikeModel || '').toString().trim();
        const isDeliveryCourier = 
          data.isDelivery === true ||
          data.role === 'delivery' ||
          data.subRole === 'delivery' ||
          data.type === 'delivery' ||
          data.vehicleType === 'motorcycle' || 
          data.vehicleCategory === 'motorcycle' ||
          vModel.includes('دراجة') ||
          vModel.includes('ماطور') ||
          vModel.includes('سكوتر') ||
          vModel.includes('ستوتة') ||
          vModel.toLowerCase().includes('bike');

        const domain: RegistrationDomain = isDeliveryCourier ? 'mersal_courier' : 'taxi_captain';

        return {
          id: d.id,
          domain: domain,
          applicantName: data.name || data.fullName || data.driverName || 'مقدم طلب كابتن',
          businessOrVehicleTitle: isDeliveryCourier ? `مندوب توصيل / دراجة (${vModel || 'دراجة'})` : `سيارة تكسي (${vModel || 'صالون'})`,
          phoneNumber: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
          whatsappNumber: data.whatsapp || data.phoneNumber || data.phone,
          email: data.email,
          city: data.city || data.governorateName || data.governorate || 'القائم',
          address: data.address || data.residenceArea || 'القائم',
          categoryOrType: isDeliveryCourier ? ' مندوب توصيل / مرسال' : ' كابتن تكسي مدار',
          vehicleTypeCategory: isDeliveryCourier ? 'motorcycle' : 'taxi',
          vehiclePlate: data.carNumber || data.plateNumber || data.carPlate || 'غير مسجلة',
          vehicleModel: vModel || (isDeliveryCourier ? 'دراجة نارية' : 'سيارة تكسي'),
          vehicleYear: data.carYear || data.modelYear || data.year || '2020',
          vehicleColor: data.carColor || data.vehicleColor || 'أصفر / أبيض',
          status: (data.status === 'approved' || data.isApproved === true) ? 'approved' : ((data.status === 'rejected' || data.isRejected === true) ? 'rejected' : 'pending'),
          rejectionReason: data.rejectionReason || data.rejectReason,
          createdAt: dateStr,
          createdTimestamp: timestamp,
          profilePhotoUrl: data.personalPhotoUrl || data.photoUrl || data.avatarUrl,
          nationalIdUrl: data.nationalIdUrl || data.idCardUrl || data.idPhoto,
          licenseUrl: data.drivingLicenseUrl || data.licensePhoto || data.licenseUrl,
          vehicleDocUrl: data.carDocUrl || data.carRegistrationUrl || data.registrationPhoto,
          notes: data.notes || data.experience || data.workType,
          rawSourceCollection: 'driver_requests'
        };
      });
      notify();
    }, (err) => console.warn('driver_requests stream:', err.message));

    // 3. Listen to `store_requests`
    const unsubStores = onSnapshot(collection(db, 'store_requests'), (snapshot) => {
      storeRequests = snapshot.docs.map((d) => {
        const data = d.data();
        const { dateStr, timestamp } = parseDate(data.createdAt || data.appliedAt || data.timestamp);

        return {
          id: d.id,
          domain: 'store',
          applicantName: data.ownerName || data.managerName || data.name || 'صاحب المتجر',
          businessOrVehicleTitle: data.storeName || data.name || 'متجر جديد',
          phoneNumber: data.phoneNumber || data.phone || data.mobile || 'غير مسجل',
          whatsappNumber: data.whatsapp || data.phone,
          email: data.email,
          city: data.city || data.governorateName || data.governorate || 'القائم',
          address: data.address || data.locationName || 'القائم',
          categoryOrType: data.storeCategory || data.category || 'سوبرماركت ومتجر',
          status: (data.status === 'approved' || data.isApproved === true) ? 'approved' : ((data.status === 'rejected' || data.isRejected === true) ? 'rejected' : 'pending'),
          rejectionReason: data.rejectionReason || data.rejectReason,
          createdAt: dateStr,
          createdTimestamp: timestamp,
          profilePhotoUrl: data.logoUrl || data.logo,
          storefrontPhotoUrl: data.coverUrl || data.imageUrl || data.storePhotoUrl,
          commercialRecordUrl: data.commercialRegisterUrl || data.licenseUrl,
          commissionRate: Number(data.commissionRate || 10),
          notes: data.notes || data.description,
          rawSourceCollection: 'store_requests'
        };
      });
      notify();
    }, (err) => console.warn('store_requests stream:', err.message));

    return () => {
      unsubRest();
      unsubDrivers();
      unsubStores();
    };
  }

  /**
   * Approve and Activate Request across all relevant collections
   */
  static async approveRequest(request: RegistrationRequestEntity): Promise<void> {
    const now = new Date().toISOString();

    // 1. Update the request document in source collection
    try {
      await updateDoc(doc(db, request.rawSourceCollection, request.id), {
        status: 'approved',
        isApproved: true,
        approvedAt: now,
        reviewedBy: 'SuperAdmin'
      });
    } catch {
      await setDoc(doc(db, request.rawSourceCollection, request.id), {
        status: 'approved',
        isApproved: true,
        approvedAt: now
      }, { merge: true });
    }

    // 2. If it's Taxi Captain -> Activate in `drivers` and `users` as Taxi Captain
    if (request.domain === 'taxi_captain') {
      const driverPayload = {
        name: request.applicantName,
        fullName: request.applicantName,
        phone: request.phoneNumber,
        phoneNumber: request.phoneNumber,
        vehicleModel: request.vehicleModel || 'مركبة كابتن',
        carType: request.vehicleModel || 'مركبة كابتن',
        carModel: request.vehicleModel || 'مركبة كابتن',
        plateNumber: request.vehiclePlate || '',
        carNumber: request.vehiclePlate || '',
        carColor: request.vehicleColor || 'أصفر / أبيض',
        carYear: request.vehicleYear || '2020',
        vehicleCategory: 'taxi',
        role: 'driver',
        city: request.city || 'القائم',
        isApproved: true,
        isBlocked: false,
        isOnline: false,
        kycStatus: 'verified',
        status: 'active',
        rating: 5.0,
        totalTrips: 0,
        walletBalance: 0,
        appDebt: 0,
        personalPhotoUrl: request.profilePhotoUrl || '',
        nationalIdUrl: request.nationalIdUrl || '',
        drivingLicenseUrl: request.licenseUrl || '',
        carDocUrl: request.vehicleDocUrl || '',
        updatedAt: now
      };

      await setDoc(doc(db, 'drivers', request.id), driverPayload, { merge: true });
      await setDoc(doc(db, 'users', request.id), {
        role: 'driver',
        isDriver: true,
        isApproved: true,
        status: 'active',
        updatedAt: now
      }, { merge: true });
    }

    // 3. If it's Mersal Courier / Delivery -> Activate in `drivers` and `users` as Delivery Captain
    if (request.domain === 'mersal_courier') {
      const courierPayload = {
        name: request.applicantName,
        fullName: request.applicantName,
        phone: request.phoneNumber,
        phoneNumber: request.phoneNumber,
        vehicleModel: request.vehicleModel || 'دراجة توصيل',
        carType: request.vehicleModel || 'دراجة توصيل',
        carModel: request.vehicleModel || 'دراجة توصيل',
        plateNumber: request.vehiclePlate || '',
        carNumber: request.vehiclePlate || '',
        carColor: request.vehicleColor || 'أحمر / أسود',
        carYear: request.vehicleYear || '2022',
        vehicleCategory: 'motorcycle',
        role: 'delivery_captain',
        subRole: 'delivery',
        type: 'delivery',
        isDelivery: true,
        city: request.city || 'القائم',
        isApproved: true,
        isBlocked: false,
        isOnline: false,
        kycStatus: 'verified',
        status: 'approved',
        rating: 5.0,
        totalTrips: 0,
        walletBalance: 0,
        appDebt: 0,
        personalPhotoUrl: request.profilePhotoUrl || '',
        nationalIdUrl: request.nationalIdUrl || '',
        drivingLicenseUrl: request.licenseUrl || '',
        carDocUrl: request.vehicleDocUrl || '',
        updatedAt: now
      };

      await setDoc(doc(db, 'drivers', request.id), courierPayload, { merge: true });
      await setDoc(doc(db, 'users', request.id), {
        role: 'delivery_captain',
        isDeliveryApproved: true,
        isDriver: true,
        isApproved: true,
        status: 'approved',
        updatedAt: now
      }, { merge: true });
    }

    // 4. If it's a Restaurant -> Activate in `restaurants` and `users`
    if (request.domain === 'restaurant') {
      const restPayload = {
        name: request.businessOrVehicleTitle,
        restaurantName: request.businessOrVehicleTitle,
        ownerName: request.applicantName,
        phone: request.phoneNumber,
        phoneNumber: request.phoneNumber,
        whatsapp: request.whatsappNumber || request.phoneNumber,
        address: request.address || 'القائم',
        city: request.city || 'القائم',
        category: 'restaurant',
        cuisineType: request.categoryOrType || 'مطعم ومأكولات',
        commissionRate: request.commissionRate || 10,
        isOpen: true,
        isAvailable: true,
        status: 'active',
        isApproved: true,
        image: request.storefrontPhotoUrl || '',
        logo: request.storefrontPhotoUrl || '',
        updatedAt: now
      };

      await setDoc(doc(db, 'restaurants', request.id), restPayload, { merge: true });
      await setDoc(doc(db, 'users', request.id), {
        role: 'restaurant',
        isMerchant: true,
        isApproved: true,
        status: 'active',
        updatedAt: now
      }, { merge: true });
    }

    // 5. If it's a Store -> Activate in `stores` and `users`
    if (request.domain === 'store') {
      const storePayload = {
        name: request.businessOrVehicleTitle,
        storeName: request.businessOrVehicleTitle,
        ownerName: request.applicantName,
        phone: request.phoneNumber,
        phoneNumber: request.phoneNumber,
        whatsapp: request.whatsappNumber || request.phoneNumber,
        address: request.address || 'القائم',
        city: request.city || 'القائم',
        category: request.categoryOrType || 'store',
        storeCategory: request.categoryOrType || 'سوبرماركت',
        commissionRate: request.commissionRate || 10,
        isOpen: true,
        isAvailable: true,
        status: 'active',
        isApproved: true,
        image: request.storefrontPhotoUrl || '',
        logo: request.storefrontPhotoUrl || '',
        updatedAt: now
      };

      await setDoc(doc(db, 'stores', request.id), storePayload, { merge: true });
      await setDoc(doc(db, 'users', request.id), {
        role: 'store',
        isMerchant: true,
        isApproved: true,
        status: 'active',
        updatedAt: now
      }, { merge: true });
    }
  }

  /**
   * Reject Request with mandatory reason
   */
  static async rejectRequest(request: RegistrationRequestEntity, reason: string): Promise<void> {
    const now = new Date().toISOString();

    await updateDoc(doc(db, request.rawSourceCollection, request.id), {
      status: 'rejected',
      isApproved: false,
      isRejected: true,
      rejectionReason: reason,
      rejectedAt: now,
      reviewedBy: 'SuperAdmin'
    });

    if (request.domain === 'taxi_captain' || request.domain === 'mersal_courier') {
      try {
        await updateDoc(doc(db, 'drivers', request.id), {
          kycStatus: 'rejected',
          isApproved: false,
          rejectionReason: reason
        });
      } catch {}
    }
  }

  /**
   * Permanently Delete Request
   */
  static async deleteRequest(request: RegistrationRequestEntity): Promise<void> {
    await deleteDoc(doc(db, request.rawSourceCollection, request.id));
  }
}
