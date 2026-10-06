import { useState, useEffect } from 'react';
import { collection, onSnapshot, query, limit } from 'firebase/firestore';
import { db } from './firebase';

export interface DashboardMetrics {
  // Taxi Domain
  totalTaxiCaptains: number;
  onlineTaxiCaptains: number;
  totalTaxiRides: number;
  activeTaxiRides: number;
  completedTaxiRides: number;
  taxiRidesVolumeIqd: number;

  // Mersal Domain
  totalMersalCouriers: number;
  onlineMersalCouriers: number;
  totalMersalJobs: number;
  activeMersalJobs: number;
  completedMersalJobs: number;
  mersalVolumeIqd: number;

  // Restaurants Domain
  totalRestaurants: number;
  openRestaurants: number;
  totalRestaurantOrders: number;
  activeRestaurantOrders: number;
  completedRestaurantOrders: number;
  restaurantVolumeIqd: number;

  // Stores Domain
  totalStores: number;
  openStores: number;
  totalStoreOrders: number;
  activeStoreOrders: number;
  completedStoreOrders: number;
  storeVolumeIqd: number;

  // Customers & Users
  totalUsers: number;
  activeUsers: number;

  // Aggregate Aliases (for backward compatibility)
  totalCaptains: number;
  onlineCaptains: number;
  pendingCaptains: number;
  blockedCaptains: number;
  totalMerchants: number;
  totalOrders: number;
  activeOrders: number;
  completedOrders: number;
  cancelledOrders: number;
  totalVolumeIqd: number;
  platformCommissionIqd: number;
  totalRides: number;
  activeRides: number;
  completedRides: number;
  totalRidesVolumeIqd: number;

  // System & Infrastructure
  dbConnected: boolean;
  dbLatencyMs: number;
  lastSyncTime: Date;
  systemIncidentsCount: number;

  // Live Streams
  recentOrders: Array<{
    id: string;
    type: 'order' | 'ride' | 'driver' | 'user' | 'mersal';
    title: string;
    customer: string;
    amount: number;
    status: string;
    time: string;
  }>;

  recentIncidents: Array<{
    id: string;
    title: string;
    severity: 'info' | 'warning' | 'critical' | 'healthy';
    engine: string;
    message: string;
    time: string;
  }>;
}

export function useLiveDashboard() {
  const [metrics, setMetrics] = useState<DashboardMetrics>({
    totalTaxiCaptains: 0,
    onlineTaxiCaptains: 0,
    totalTaxiRides: 0,
    activeTaxiRides: 0,
    completedTaxiRides: 0,
    taxiRidesVolumeIqd: 0,

    totalMersalCouriers: 0,
    onlineMersalCouriers: 0,
    totalMersalJobs: 0,
    activeMersalJobs: 0,
    completedMersalJobs: 0,
    mersalVolumeIqd: 0,

    totalRestaurants: 0,
    openRestaurants: 0,
    totalRestaurantOrders: 0,
    activeRestaurantOrders: 0,
    completedRestaurantOrders: 0,
    restaurantVolumeIqd: 0,

    totalStores: 0,
    openStores: 0,
    totalStoreOrders: 0,
    activeStoreOrders: 0,
    completedStoreOrders: 0,
    storeVolumeIqd: 0,

    totalUsers: 0,
    activeUsers: 0,

    totalCaptains: 0,
    onlineCaptains: 0,
    pendingCaptains: 0,
    blockedCaptains: 0,
    totalMerchants: 0,
    totalOrders: 0,
    activeOrders: 0,
    completedOrders: 0,
    cancelledOrders: 0,
    totalVolumeIqd: 0,
    platformCommissionIqd: 0,
    totalRides: 0,
    activeRides: 0,
    completedRides: 0,
    totalRidesVolumeIqd: 0,

    dbConnected: true,
    dbLatencyMs: 0,
    lastSyncTime: new Date(),
    systemIncidentsCount: 0,

    recentOrders: [],
    recentIncidents: []
  });

  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const unsubs: Array<() => void> = [];
    const startTime = performance.now();

    // 1. Listen to Users collection
    try {
      const unsubUsers = onSnapshot(collection(db, 'users'), (snap) => {
        const total = snap.size;
        let customersCount = 0;

        snap.docs.forEach((d) => {
          const data = d.data();
          const role = (data.role || data.accountType || '').toString().toLowerCase();
          if (role !== 'driver' && role !== 'captain') {
            customersCount++;
          }
        });

        setMetrics((prev) => ({
          ...prev,
          totalUsers: total,
          activeUsers: customersCount || total,
          dbLatencyMs: Math.round(performance.now() - startTime),
          lastSyncTime: new Date()
        }));
      }, (err) => console.warn('Users stream note:', err.message));
      unsubs.push(unsubUsers);
    } catch (e) {
      console.warn('Users collection error:', e);
    }

    // 2. Listen to Drivers collection (Separating Taxi vs Mersal)
    try {
      const unsubDrivers = onSnapshot(collection(db, 'drivers'), (snap) => {
        let taxiCount = 0;
        let taxiOnline = 0;
        let mersalCount = 0;
        let mersalOnline = 0;
        let pending = 0;
        let blocked = 0;

        snap.docs.forEach((d) => {
          const data = d.data();
          const subRole = (data.subRole || '').toString().toLowerCase();
          const type = (data.type || '').toString().toLowerCase();
          const role = (data.role || '').toString().toLowerCase();
          const vCategory = (data.vehicleCategory || data.vehicleType || '').toString().toLowerCase();
          const vModel = (data.carModel || data.vehicleModel || data.carType || '').toString().toLowerCase();

          const isDelivery = 
            data.isDelivery === true ||
            role === 'delivery' ||
            subRole === 'delivery' ||
            type === 'delivery' ||
            vCategory === 'motorcycle' ||
            vModel.includes('دراجة') ||
            vModel.includes('ماطور') ||
            vModel.includes('bike');

          const isOnline = data.isOnline === true || data.status === 'online' || data.available === true;

          if (isDelivery) {
            mersalCount++;
            if (isOnline) mersalOnline++;
          } else {
            taxiCount++;
            if (isOnline) taxiOnline++;
          }

          if (data.isApproved === false || data.kycStatus === 'pending') pending++;
          if (data.isBlocked === true || data.status === 'blocked') blocked++;
        });

        setMetrics((prev) => ({
          ...prev,
          totalTaxiCaptains: taxiCount,
          onlineTaxiCaptains: taxiOnline,
          totalMersalCouriers: mersalCount,
          onlineMersalCouriers: mersalOnline,
          totalCaptains: snap.size,
          onlineCaptains: taxiOnline + mersalOnline,
          pendingCaptains: pending,
          blockedCaptains: blocked
        }));
      }, (err) => console.warn('Drivers stream note:', err.message));
      unsubs.push(unsubDrivers);
    } catch (e) {
      console.warn('Drivers collection error:', e);
    }

    // 3. Listen to Restaurants collection
    try {
      const unsubRest = onSnapshot(collection(db, 'restaurants'), (snap) => {
        let openCount = 0;
        snap.docs.forEach((d) => {
          const data = d.data();
          if (data.isOpen !== false && data.isAvailable !== false) openCount++;
        });

        setMetrics((prev) => ({
          ...prev,
          totalRestaurants: snap.size,
          openRestaurants: openCount,
          totalMerchants: snap.size + prev.totalStores
        }));
      }, (err) => console.warn('Restaurants stream note:', err.message));
      unsubs.push(unsubRest);
    } catch (e) {
      console.warn('Restaurants collection error:', e);
    }

    // 4. Listen to Stores collection
    try {
      const unsubStores = onSnapshot(collection(db, 'stores'), (snap) => {
        let openCount = 0;
        snap.docs.forEach((d) => {
          const data = d.data();
          if (data.isOpen !== false && data.isAvailable !== false) openCount++;
        });

        setMetrics((prev) => ({
          ...prev,
          totalStores: snap.size,
          openStores: openCount,
          totalMerchants: snap.size + prev.totalRestaurants
        }));
      }, (err) => console.warn('Stores stream note:', err.message));
      unsubs.push(unsubStores);
    } catch (e) {
      console.warn('Stores collection error:', e);
    }

    // 5. Listen to Orders collection (Food Orders)
    try {
      const unsubOrders = onSnapshot(query(collection(db, 'orders'), limit(150)), (snap) => {
        let active = 0;
        let completed = 0;
        let cancelled = 0;
        let totalVal = 0;

        const liveList: DashboardMetrics['recentOrders'] = [];

        snap.docs.forEach((d) => {
          const data = d.data();
          const st = (data.status || 'pending').toString().toLowerCase();
          const amt = Number(data.totalPrice || data.total || 0);

          if (st === 'pending' || st === 'accepted' || st === 'preparing' || st === 'on_the_way' || st === 'in_transit') {
            active++;
          } else if (st === 'completed' || st === 'delivered') {
            completed++;
            totalVal += amt;
          } else if (st === 'cancelled') {
            cancelled++;
          }

          let tStr = 'الآن';
          if (data.createdAt?.toDate) {
            tStr = data.createdAt.toDate().toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
          }

          liveList.push({
            id: d.id,
            type: 'order',
            title: `طلب مطعم: ${data.restaurantName || 'مطعم مدار'}`,
            customer: data.customerName || data.userName || 'عميل مدار',
            amount: amt,
            status: st,
            time: tStr
          });
        });

        setMetrics((prev) => ({
          ...prev,
          totalRestaurantOrders: snap.size,
          activeRestaurantOrders: active,
          completedRestaurantOrders: completed,
          restaurantVolumeIqd: totalVal,
          totalOrders: snap.size,
          activeOrders: active,
          completedOrders: completed,
          cancelledOrders: cancelled,
          totalVolumeIqd: totalVal,
          platformCommissionIqd: Math.round(totalVal * 0.1),
          recentOrders: liveList.slice(0, 10)
        }));
      }, (err) => console.warn('Orders stream note:', err.message));
      unsubs.push(unsubOrders);
    } catch (e) {
      console.warn('Orders collection error:', e);
    }

    // 6. Listen to Taxi Rides (ride_requests)
    try {
      const unsubRides = onSnapshot(query(collection(db, 'ride_requests'), limit(150)), (snap) => {
        let active = 0;
        let completed = 0;
        let vol = 0;

        snap.docs.forEach((d) => {
          const data = d.data();
          const st = (data.status || 'pending').toString().toLowerCase();
          const fare = Number(data.fare || data.price || 0);

          if (st === 'accepted' || st === 'arrived' || st === 'in_trip' || st === 'in_progress') {
            active++;
          } else if (st === 'completed') {
            completed++;
            vol += fare;
          }
        });

        setMetrics((prev) => ({
          ...prev,
          totalTaxiRides: snap.size,
          activeTaxiRides: active,
          completedTaxiRides: completed,
          taxiRidesVolumeIqd: vol,
          totalRides: snap.size,
          activeRides: active,
          completedRides: completed,
          totalRidesVolumeIqd: vol
        }));
      }, (err) => console.warn('Ride requests stream note:', err.message));
      unsubs.push(unsubRides);
    } catch (e) {
      console.warn('Ride requests collection error:', e);
    }

    // 7. Listen to Mersal Jobs (mersal_requests)
    try {
      const unsubMersal = onSnapshot(query(collection(db, 'mersal_requests'), limit(150)), (snap) => {
        let active = 0;
        let completed = 0;
        let vol = 0;

        snap.docs.forEach((d) => {
          const data = d.data();
          const st = (data.status || 'pending').toString().toLowerCase();
          const fee = Number(data.deliveryFee || data.price || 0);

          if (st === 'accepted' || st === 'picked_up' || st === 'in_transit') {
            active++;
          } else if (st === 'delivered' || st === 'completed') {
            completed++;
            vol += fee;
          }
        });

        setMetrics((prev) => ({
          ...prev,
          totalMersalJobs: snap.size,
          activeMersalJobs: active,
          completedMersalJobs: completed,
          mersalVolumeIqd: vol
        }));
      }, (err) => console.warn('Mersal requests stream note:', err.message));
      unsubs.push(unsubMersal);
    } catch (e) {
      console.warn('Mersal requests collection error:', e);
    }

    setIsLoading(false);

    return () => {
      unsubs.forEach((u) => u());
    };
  }, []);

  return { metrics, isLoading };
}
