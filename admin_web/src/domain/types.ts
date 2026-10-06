export type MadarRole =
  | 'super_admin'
  | 'main_admin'
  | 'admin'
  | 'limited_admin'
  | 'complaints_admin'
  | 'support'
  | 'auditor'
  | 'region_manager'
  | 'merchant'
  | 'store'
  | 'restaurant'
  | 'driver'
  | 'taxi_captain'
  | 'delivery'
  | 'customer';

export interface AdminUser {
  uid: string;
  email: string;
  name: string;
  role: MadarRole;
  avatarUrl?: string;
  phoneNumber?: string;
  isApproved: boolean;
  permissions: string[];
}

export interface SystemHealthMetric {
  serviceId: string;
  name: string;
  status: 'healthy' | 'degraded' | 'unhealthy' | 'critical';
  latencyMs: number;
  errorRate: number;
  lastHeartbeat: string;
}

// 1. TAXI DOMAIN ENTITIES
export interface TaxiCaptainEntity {
  driverId: string;
  name: string;
  phoneNumber: string;
  email?: string;
  vehicleCategory: 'taxi' | 'car' | string;
  vehicleModel: string;
  vehicleColor?: string;
  vehicleYear?: string;
  plateNumber: string;
  city?: string;
  governorate?: string;
  isOnline: boolean;
  isBlocked: boolean;
  blockReason?: string;
  kycStatus: 'pending' | 'verified' | 'rejected';
  riskScore: number;
  walletBalance: number;
  appDebt?: number;
  totalEarnings?: number;
  rating: number;
  totalTrips: number;
  createdAt: string;
  createdTimestamp: number;
  nationalIdUrl?: string;
  licenseUrl?: string;
  carDocUrl?: string;
  personalPhotoUrl?: string;
  lastLocation?: {
    lat: number;
    lng: number;
    updatedAt: string;
  };
}

export interface TaxiRideEntity {
  rideId: string;
  sourceCollection: string;
  passengerId?: string;
  passengerName: string;
  passengerPhone?: string;
  passengerAvatar?: string;
  passengerNotes?: string;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverAvatar?: string;
  vehicleModel?: string;
  vehiclePlate?: string;
  vehicleColor?: string;
  vehicleType?: string;
  fareIqd: number;
  baseFareIqd?: number;
  distanceKm?: number;
  durationMinutes?: number;
  discountIqd?: number;
  couponCode?: string;
  commissionIqd: number;
  driverNetIqd: number;
  paymentMethod: string;
  rating?: number;
  ratingComment?: string;
  ratingReason?: string;
  ratingTags?: string[];
  ratedAt?: string;
  isRated: boolean;
  pickupAddress: string;
  pickupLat?: number;
  pickupLng?: number;
  destinationAddress: string;
  destinationLat?: number;
  destinationLng?: number;
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

// 2. MERSAL / COURIER DOMAIN ENTITIES
export interface MersalCourierEntity {
  courierId: string;
  driverId: string; // compatibility alias
  name: string;
  phoneNumber: string;
  email?: string;
  vehicleCategory: 'motorcycle' | string;
  vehicleModel: string;
  vehicleColor?: string;
  vehicleYear?: string;
  plateNumber: string;
  city?: string;
  governorate?: string;
  isOnline: boolean;
  isBlocked: boolean;
  blockReason?: string;
  kycStatus: 'pending' | 'verified' | 'rejected';
  riskScore: number;
  walletBalance: number;
  appDebt?: number;
  totalEarnings?: number;
  rating: number;
  totalDeliveries: number;
  totalTrips: number; // compatibility alias
  createdAt: string;
  createdTimestamp: number;
  nationalIdUrl?: string;
  licenseUrl?: string;
  bikeDocUrl?: string;
  carDocUrl?: string; // compatibility alias
  personalPhotoUrl?: string;
  lastLocation?: {
    lat: number;
    lng: number;
    updatedAt: string;
  };
}

export interface MersalJobEntity {
  jobId: string;
  senderId?: string;
  senderName: string;
  senderPhone?: string;
  recipientName: string;
  recipientPhone: string;
  courierId?: string;
  courierName?: string;
  courierPhone?: string;
  packageDescription: string;
  packageValueIqd?: number;
  deliveryFeeIqd: number;
  commissionIqd: number;
  courierNetIqd: number;
  pickupAddress: string;
  pickupLat?: number;
  pickupLng?: number;
  dropoffAddress: string;
  dropoffLat?: number;
  dropoffLng?: number;
  status: 'pending' | 'accepted' | 'picked_up' | 'delivered' | 'cancelled';
  rawStatus: string;
  statusArabic: string;
  createdAt: string;
  createdTimestamp: number;
  paymentMethod: string;
  notes?: string;
}

// 3. RESTAURANTS DOMAIN ENTITIES
export interface RestaurantEntity {
  restaurantId: string;
  merchantId: string; // compatibility alias
  name: string;
  ownerName: string;
  phone: string;
  email?: string;
  password?: string;
  address?: string;
  city?: string;
  cuisineType: string;
  subCategory?: string;
  isOpen: boolean;
  commissionRate: number;
  totalOrders: number;
  totalRevenueIqd: number;
  status: 'active' | 'suspended' | 'pending';
  createdAt: string;
  createdTimestamp: number;
  logoUrl?: string;
  coverImageUrl?: string;
  openingTime?: string;
  closingTime?: string;
  estimatedPrepMinutes?: number;
  minimumOrderIqd?: number;
}

export interface RestaurantOrderEntity {
  orderId: string;
  restaurantId: string;
  restaurantName: string;
  restaurantPhone?: string;
  restaurantAddress?: string;
  merchantId?: string; // compatibility alias
  merchantOrTitle?: string; // compatibility alias
  merchantPhone?: string; // compatibility alias
  customerId?: string;
  customerName: string;
  customerPhone?: string;
  courierId?: string;
  courierName?: string;
  courierPhone?: string;
  totalPriceIqd: number;
  subtotalIqd: number;
  deliveryFeeIqd: number;
  discountIqd?: number;
  commissionIqd: number;
  restaurantNetIqd: number;
  courierNetIqd: number;
  paymentMethod: string;
  status: string;
  rawStatus: string;
  createdAt: string;
  createdTimestamp: number;
  itemsSummary: string;
  itemsList: Array<{
    id?: string;
    name: string;
    quantity: number;
    price: number;
    options?: string[];
    notes?: string;
  }>;
  deliveryAddress?: string;
  customerNotes?: string;
}

// 4. STORES DOMAIN ENTITIES
export interface StoreEntity {
  storeId: string;
  merchantId: string; // compatibility alias
  name: string;
  ownerName: string;
  phone: string;
  email?: string;
  password?: string;
  address?: string;
  city?: string;
  storeCategory: string; // 'supermarket', 'pharmacy', 'electronics', 'clothing', etc.
  subCategory?: string;
  isOpen: boolean;
  commissionRate: number;
  totalOrders: number;
  totalRevenueIqd: number;
  status: 'active' | 'suspended' | 'pending';
  createdAt: string;
  createdTimestamp: number;
  logoUrl?: string;
  coverImageUrl?: string;
  openingTime?: string;
  closingTime?: string;
  minimumOrderIqd?: number;
}

export interface StoreOrderEntity {
  orderId: string;
  storeId: string;
  storeName: string;
  storePhone?: string;
  storeAddress?: string;
  merchantId?: string; // compatibility alias
  merchantOrTitle?: string; // compatibility alias
  merchantPhone?: string; // compatibility alias
  customerId?: string;
  customerName: string;
  customerPhone?: string;
  courierId?: string;
  courierName?: string;
  courierPhone?: string;
  totalPriceIqd: number;
  subtotalIqd: number;
  deliveryFeeIqd: number;
  discountIqd?: number;
  commissionIqd: number;
  storeNetIqd: number;
  courierNetIqd: number;
  paymentMethod: string;
  status: string;
  rawStatus: string;
  createdAt: string;
  createdTimestamp: number;
  itemsSummary: string;
  itemsList: Array<{
    id?: string;
    name: string;
    quantity: number;
    price: number;
    options?: string[];
    notes?: string;
  }>;
  deliveryAddress?: string;
  customerNotes?: string;
}

// COMPATIBILITY ALIASES (Refactored consumers consume discrete types)
export type DriverEntity = {
  driverId: string;
  courierId?: string;
  name: string;
  phoneNumber: string;
  email?: string;
  vehicleCategory?: 'taxi' | 'car' | 'motorcycle' | string;
  vehicleModel: string;
  vehicleColor?: string;
  vehicleYear?: string;
  plateNumber: string;
  city?: string;
  governorate?: string;
  isOnline: boolean;
  isBlocked: boolean;
  blockReason?: string;
  kycStatus: 'pending' | 'verified' | 'rejected';
  riskScore: number;
  walletBalance: number;
  appDebt?: number;
  totalEarnings?: number;
  rating: number;
  totalTrips?: number;
  totalDeliveries?: number;
  createdAt: string;
  createdTimestamp: number;
  nationalIdUrl?: string;
  licenseUrl?: string;
  bikeDocUrl?: string;
  carDocUrl?: string;
  personalPhotoUrl?: string;
  lastLocation?: {
    lat: number;
    lng: number;
    updatedAt: string;
  };
  serviceType?: 'taxi' | 'delivery' | 'both';
};

export type LiveRideRecord = TaxiRideEntity;

export type MerchantEntity = { 
  merchantId: string;
  storeId?: string;
  restaurantId?: string;
  name: string;
  ownerName: string;
  phone: string;
  email?: string;
  password?: string;
  address?: string;
  city?: string;
  category?: 'restaurant' | 'store' | 'pharmacy' | 'sweets';
  subCategory?: string;
  cuisineType?: string;
  storeCategory?: string;
  isOpen: boolean;
  commissionRate: number;
  totalOrders: number;
  totalRevenueIqd: number;
  status: 'active' | 'suspended' | 'pending';
  createdAt: string;
  createdTimestamp: number;
  logoUrl?: string;
  coverImageUrl?: string;
  openingTime?: string;
  closingTime?: string;
  minimumOrderIqd?: number;
  estimatedPrepMinutes?: number;
};

export interface SecurityEventEntity {
  eventId: string;
  eventType: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  actorUserId: string;
  description: string;
  resource?: string;
  timestamp: string;
  traceId?: string;
}

export interface AuditLogEntity {
  auditId: string;
  adminUid: string;
  adminName: string;
  adminRole: string;
  action: string;
  targetResource: string;
  timestamp: string;
  ipAddress?: string;
  payload?: Record<string, any>;
  integrityHash?: string;
}

export interface FinancialSummary {
  totalPlatformVolumeIqd: number;
  todayRevenueIqd: number;
  activeEscrowIqd: number;
  pendingPayoutsIqd: number;
  negativeBalanceViolationsCount: number;
  refundsTodayCount: number;
}
