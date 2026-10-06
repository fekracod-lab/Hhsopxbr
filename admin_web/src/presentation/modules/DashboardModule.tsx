import React, { useState, useEffect, useMemo } from 'react';
import {
  TrendingUp,
  Car,
  ShoppingBag,
  Users,
  Store,
  ShieldCheck,
  AlertTriangle,
  Radio,
  Zap,
  Clock,
  CheckCircle2,
  XCircle,
  Activity,
  ArrowUpRight,
  RefreshCw,
  Server,
  Layers,
  MapPin,
  UtensilsCrossed,
  DollarSign,
  Send,
  Navigation,
  Compass,
  ArrowRight,
  Flame,
  FileText,
  Bell,
  Sparkles,
  Smartphone,
  Wallet,
  ShieldAlert,
  ChevronLeft,
  Coins,
  Star,
  Award,
  Filter,
  Check,
  Tag,
  Gift,
  ExternalLink,
  ChevronRight,
  Sliders,
  BarChart3,
  PieChart,
  UserCheck
} from 'lucide-react';
import { useLiveDashboard } from '../../infrastructure/useLiveDashboard';
import { OrdersRepository, AdminOrderRecord } from '../../infrastructure/repositories/OrdersRepository';
import { TaxiRidesRepository, TaxiRideEntity } from '../../infrastructure/repositories/TaxiRidesRepository';
import { TaxiCaptainRepository } from '../../infrastructure/repositories/TaxiCaptainRepository';
import { MersalCourierRepository } from '../../infrastructure/repositories/MersalCourierRepository';
import { RestaurantDomainRepository } from '../../infrastructure/repositories/RestaurantDomainRepository';
import { StoreDomainRepository } from '../../infrastructure/repositories/StoreDomainRepository';
import { DriverEntity, MerchantEntity } from '../../domain/types';
import { AreaRevenueChart, DonutDistributionChart, ChartDataPoint, DonutSegment } from '../components/InteractiveCharts';
import { AudioAlertService } from '../../infrastructure/services/AudioAlertService';

interface DashboardModuleProps {
  onNavigate?: (module: string) => void;
}

export const DashboardModule: React.FC<DashboardModuleProps> = ({ onNavigate }) => {
  const { metrics: liveMetrics, isLoading: isLiveLoading } = useLiveDashboard();

  // Active Dashboard Domain View
  const [selectedDomain, setSelectedDomain] = useState<'overview' | 'taxi' | 'restaurants' | 'stores' | 'fleet'>('overview');
  const [radarFilter, setRadarFilter] = useState<'all' | 'taxi' | 'food' | 'store'>('all');

  // Multi-collection live states
  const [orders, setOrders] = useState<AdminOrderRecord[]>([]);
  const [rides, setRides] = useState<TaxiRideEntity[]>([]);
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [merchants, setMerchants] = useState<MerchantEntity[]>([]);
  const [isDataLoaded, setIsDataLoaded] = useState(false);

  // Audio alert tracking refs
  const prevOrdersCountRef = React.useRef<number | null>(null);
  const prevRidesCountRef = React.useRef<number | null>(null);

  useEffect(() => {
    const unsubOrders = OrdersRepository.subscribeToAllOrders((data) => {
      if (prevOrdersCountRef.current !== null && data.length > prevOrdersCountRef.current) {
        AudioAlertService.playNewOrderChime();
      }
      prevOrdersCountRef.current = data.length;
      setOrders(data);
    });

    const unsubRides = TaxiRidesRepository.subscribeToTaxiRides((data) => {
      if (prevRidesCountRef.current !== null && data.length > prevRidesCountRef.current) {
        AudioAlertService.playNewRideChime();
      }
      prevRidesCountRef.current = data.length;
      setRides(data);
    });

    let captains: DriverEntity[] = [];
    let couriers: DriverEntity[] = [];
    const unsubCaptains = TaxiCaptainRepository.subscribeToCaptains((cData) => {
      captains = cData;
      setDrivers([...captains, ...couriers]);
    });
    const unsubCouriers = MersalCourierRepository.subscribeToCouriers((mData) => {
      couriers = mData;
      setDrivers([...captains, ...couriers]);
    });

    let restList: MerchantEntity[] = [];
    let storeList: MerchantEntity[] = [];
    const unsubRestaurants = RestaurantDomainRepository.subscribeToRestaurants((rData) => {
      restList = rData;
      setMerchants([...restList, ...storeList]);
      setIsDataLoaded(true);
    });
    const unsubStores = StoreDomainRepository.subscribeToStores((sData) => {
      storeList = sData;
      setMerchants([...restList, ...storeList]);
      setIsDataLoaded(true);
    });

    return () => {
      unsubOrders();
      unsubRides();
      unsubCaptains();
      unsubCouriers();
      unsubRestaurants();
      unsubStores();
    };
  }, []);

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(Math.round(amount)) + ' د.ع';
  };

  const handleNav = (moduleKey: string) => {
    if (onNavigate) {
      onNavigate(moduleKey);
    }
  };

  // ─── 1. TAXI DOMAIN METRICS ───
  const taxiMetrics = useMemo(() => {
    const active = rides.filter(r => r.status === 'in_trip' || r.status === 'accepted' || r.status === 'arrived');
    const pending = rides.filter(r => r.status === 'searching');
    const completed = rides.filter(r => r.status === 'completed');
    const cancelled = rides.filter(r => r.status === 'cancelled');

    const totalFare = completed.reduce((sum, r) => sum + (r.fareIqd || 0), 0);
    const totalCommission = completed.reduce((sum, r) => sum + (r.commissionIqd || 0), 0);
    const totalDriverNet = completed.reduce((sum, r) => sum + (r.driverNetIqd || 0), 0);

    const ratedRides = rides.filter(r => r.rating && r.rating > 0);
    const avgRating = ratedRides.length > 0 
      ? (ratedRides.reduce((sum, r) => sum + (r.rating || 5), 0) / ratedRides.length).toFixed(1)
      : '5.0';

    return {
      totalRides: rides.length,
      activeCount: active.length,
      pendingCount: pending.length,
      completedCount: completed.length,
      cancelledCount: cancelled.length,
      totalFare,
      totalCommission,
      totalDriverNet,
      avgRating,
      activeRidesList: active.slice(0, 5),
      recentRides: rides.slice(0, 6)
    };
  }, [rides]);

  // ─── 2. RESTAURANTS DOMAIN METRICS ───
  const restaurantMetrics = useMemo(() => {
    const restaurantList = merchants.filter(m => m.category === 'restaurant');
    const openRestaurants = restaurantList.filter(m => m.isOpen && m.status === 'active');
    const closedRestaurants = restaurantList.filter(m => !m.isOpen && m.status === 'active');
    const pendingRestaurants = restaurantList.filter(m => m.status === 'pending');

    const foodOrders = orders.filter(o => o.sourceType === 'food_delivery');
    const completedFoodOrders = foodOrders.filter(o => o.rawStatus.includes('deliver') || o.rawStatus.includes('complet'));
    const totalFoodSales = foodOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const totalFoodCommission = foodOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round((o.totalPriceIqd || 0) * 0.1)), 0);

    return {
      totalCount: restaurantList.length,
      openCount: openRestaurants.length,
      closedCount: closedRestaurants.length,
      pendingCount: pendingRestaurants.length,
      totalOrders: foodOrders.length,
      completedOrders: completedFoodOrders.length,
      totalSales: totalFoodSales,
      totalCommission: totalFoodCommission,
      recentFoodOrders: foodOrders.slice(0, 6),
      topRestaurants: restaurantList.slice(0, 5)
    };
  }, [merchants, orders]);

  // ─── 3. STORES & SHOPPING DOMAIN METRICS ───
  const storeMetrics = useMemo(() => {
    const storeList = merchants.filter(m => m.category === 'store');
    const supermarkets = storeList.filter(m => !m.subCategory?.includes('صيدلي'));
    const pharmacies = merchants.filter(m => (m.subCategory || '').includes('صيدلي') || (m.name || '').includes('صيدلية'));
    const pendingStores = storeList.filter(m => m.status === 'pending');

    const storeOrders = orders.filter(o => o.sourceType === 'store_delivery');
    const completedStoreOrders = storeOrders.filter(o => o.rawStatus.includes('deliver') || o.rawStatus.includes('complet'));
    const totalStoreSales = storeOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const totalStoreCommission = storeOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round((o.totalPriceIqd || 0) * 0.07)), 0);

    return {
      totalCount: storeList.length,
      supermarketCount: supermarkets.length,
      pharmacyCount: pharmacies.length,
      pendingCount: pendingStores.length,
      totalOrders: storeOrders.length,
      completedOrders: completedStoreOrders.length,
      totalSales: totalStoreSales,
      totalCommission: totalStoreCommission,
      recentStoreOrders: storeOrders.slice(0, 6)
    };
  }, [merchants, orders]);

  // ─── 4. FLEET & CAPTAINS DOMAIN METRICS ───
  const fleetMetrics = useMemo(() => {
    const verified = drivers.filter(d => d.kycStatus === 'verified' && !d.isBlocked);
    const pendingKyc = drivers.filter(d => d.kycStatus === 'pending' && !d.isBlocked);
    const blocked = drivers.filter(d => d.isBlocked);
    const online = drivers.filter(d => d.isOnline && !d.isBlocked);

    const motorcycles = drivers.filter(d => d.vehicleCategory === 'motorcycle' && !d.isBlocked);
    const taxiCars = drivers.filter(d => d.vehicleCategory !== 'motorcycle' && !d.isBlocked);

    return {
      totalCount: drivers.length,
      verifiedCount: verified.length,
      pendingKycCount: pendingKyc.length,
      blockedCount: blocked.length,
      onlineCount: online.length,
      motorcycleCount: motorcycles.length,
      taxiCarCount: taxiCars.length,
      topCaptains: verified.slice(0, 5)
    };
  }, [drivers]);

  // ─── 5. AGGREGATED SYSTEM TOTALS ───
  const systemTotals = useMemo(() => {
    const totalGmv = restaurantMetrics.totalSales + storeMetrics.totalSales + taxiMetrics.totalFare;
    const totalPlatformCommission = restaurantMetrics.totalCommission + storeMetrics.totalCommission + taxiMetrics.totalCommission;
    const totalOperations = orders.length + rides.length;
    const totalCompleted = restaurantMetrics.completedOrders + storeMetrics.completedOrders + taxiMetrics.completedCount;
    const totalPendingWaitingList = fleetMetrics.pendingKycCount + restaurantMetrics.pendingCount + storeMetrics.pendingCount;

    return {
      totalGmv,
      totalPlatformCommission,
      totalOperations,
      totalCompleted,
      totalPendingWaitingList
    };
  }, [restaurantMetrics, storeMetrics, taxiMetrics, fleetMetrics, orders, rides]);

  // ─── 5.1 DYNAMIC 7-DAY REVENUE & ORDERS CHART DATA ───
  const chartData = useMemo(() => {
    const daysMap: Record<string, { label: string; gmv: number; ordersCount: number }> = {};
    const dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    // Initialize past 7 days
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      const dayLabel = i === 0 ? 'اليوم' : dayNames[d.getDay()];
      daysMap[key] = { label: dayLabel, gmv: 0, ordersCount: 0 };
    }

    // Accumulate orders
    orders.forEach(o => {
      const dayKey = (o.createdAt || '').slice(0, 10);
      if (daysMap[dayKey]) {
        daysMap[dayKey].gmv += o.totalPriceIqd || 0;
        daysMap[dayKey].ordersCount += 1;
      }
    });

    // Accumulate rides
    rides.forEach(r => {
      const dayKey = (r.createdAt || '').slice(0, 10);
      if (daysMap[dayKey]) {
        daysMap[dayKey].gmv += r.fareIqd || 0;
        daysMap[dayKey].ordersCount += 1;
      }
    });

    const trendPoints: ChartDataPoint[] = Object.values(daysMap).map(d => ({
      label: d.label,
      value: d.gmv
    }));

    const donutSegments: DonutSegment[] = [
      { label: 'طلبات المطاعم ', value: restaurantMetrics.completedOrders, color: '#F97316' },
      { label: 'مشاوير التكسي ', value: taxiMetrics.completedCount, color: '#0284C7' },
      { label: 'مشتريات المتاجر ', value: storeMetrics.completedOrders, color: '#00BFA5' },
    ];

    return {
      trendPoints,
      donutSegments
    };
  }, [orders, rides, restaurantMetrics, taxiMetrics, storeMetrics]);

  // ─── 6. REAL-TIME MULTI-DOMAIN RADAR STREAM ───
  const liveRadarItems = useMemo(() => {
    const combined: Array<{
      id: string;
      domain: 'taxi' | 'food' | 'store';
      domainArabic: string;
      domainIcon: any;
      domainColor: string;
      title: string;
      customer: string;
      phone?: string;
      target: string;
      amount: number;
      status: string;
      time: string;
      timestamp: number;
    }> = [];

    // Deduplicate items by ID
    const seenIds = new Set<string>();
    const uniqueCombined: typeof combined = [];

    // Add rides
    rides.slice(0, 20).forEach(r => {
      if (!seenIds.has(r.rideId)) {
        seenIds.add(r.rideId);
        uniqueCombined.push({
          id: r.rideId,
          domain: 'taxi',
          domainArabic: 'تكسي ',
          domainIcon: Car,
          domainColor: '#f59e0b',
          title: `مشوار: ${r.pickupAddress} ${r.destinationAddress}`,
          customer: r.passengerName,
          phone: r.passengerPhone,
          target: r.driverName ? `كابتن: ${r.driverName}` : 'بانتظار قبول السائق',
          amount: r.fareIqd,
          status: r.statusArabic,
          time: r.createdAt,
          timestamp: r.createdTimestamp
        });
      }
    });

    // Add food & store orders
    orders.slice(0, 30).forEach(o => {
      if (!seenIds.has(o.orderId)) {
        seenIds.add(o.orderId);
        const isFood = o.sourceType === 'food_delivery';
        uniqueCombined.push({
          id: o.orderId,
          domain: isFood ? 'food' : 'store',
          domainArabic: isFood ? 'مطعم ' : 'متجر ',
          domainIcon: isFood ? UtensilsCrossed : ShoppingBag,
          domainColor: isFood ? '#fbbf24' : '#38bdf8',
          title: `${isFood ? 'طلب وجبة' : 'طلب تسوق'} (${o.itemsSummary || o.merchantOrTitle})`,
          customer: o.customerName,
          phone: o.customerPhone,
          target: o.merchantOrTitle,
          amount: o.totalPriceIqd,
          status: o.status,
          time: new Date(o.createdAt).toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' }),
          timestamp: new Date(o.createdAt).getTime()
        });
      }
    });

    uniqueCombined.sort((a, b) => b.timestamp - a.timestamp);

    return uniqueCombined.filter(item => {
      if (radarFilter === 'all') return true;
      return item.domain === radarFilter;
    });
  }, [rides, orders, radarFilter]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '22px' }}>
      
      {/* ─── 1. TOP EXECUTIVE COMMAND HERO BANNER ─── */}
      <div
        className="glass-panel"
        style={{
          padding: '22px 28px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '16px',
          background: 'linear-gradient(135deg, rgba(15, 23, 42, 0.95) 0%, rgba(30, 41, 59, 0.9) 50%, rgba(6, 182, 212, 0.15) 100%)',
          border: '1px solid rgba(6, 182, 212, 0.3)',
          boxShadow: '0 12px 36px rgba(0,0,0,0.35)',
          position: 'relative',
          overflow: 'hidden'
        }}
      >
        <div style={{ position: 'relative', zIndex: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '6px' }}>
            <div style={{ padding: '8px', borderRadius: '10px', background: 'linear-gradient(135deg, #06b6d4, #0284c7)' }}>
              <Compass size={24} color="#fff" />
            </div>
            <div>
              <h1 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', margin: 0 }}>
                مركز القيادة والتحكم الشامل — منظومة «مدار»
              </h1>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '4px' }}>
                <span style={{ fontSize: '12px', color: '#94a3b8' }}>
                  إدارة عمليات التكسي، طلبات المطاعم، متاجر التسوق، والأسطول الميداني في قضاء القائم
                </span>
                <span
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '5px',
                    padding: '2px 8px',
                    borderRadius: '12px',
                    background: 'rgba(16, 185, 129, 0.15)',
                    border: '1px solid rgba(16, 185, 129, 0.3)',
                    color: '#34d399',
                    fontSize: '11px',
                    fontWeight: '700'
                  }}
                >
                  <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#34d399', animation: 'pulse 1.5s infinite' }} />
                  بث مباشر متصل (Live Sync)
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Quick Top Actions */}
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center', zIndex: 2 }}>
          {systemTotals.totalPendingWaitingList > 0 && (
            <button
              onClick={() => handleNav('registration_requests')}
              className="btn btn-secondary"
              style={{
                background: 'linear-gradient(135deg, rgba(245, 158, 11, 0.2), rgba(217, 119, 6, 0.2))',
                border: '1px solid #f59e0b',
                color: '#fbbf24',
                fontSize: '12px',
                fontWeight: '800',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 14px'
              }}
            >
              <AlertTriangle size={14} />
              <span>{systemTotals.totalPendingWaitingList} طلب بقائمة الانتظار</span>
            </button>
          )}

          <button
            onClick={() => handleNav('reports')}
            className="btn btn-primary"
            style={{
              background: 'linear-gradient(135deg, #0284c7, #0369a1)',
              borderColor: '#38bdf8',
              fontSize: '12px',
              fontWeight: '800',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '8px 14px'
            }}
          >
            <BarChart3 size={15} />
            <span>التقارير و PDF </span>
          </button>
        </div>
      </div>

      {/* ─── 2. DOMAIN SWITCHER TABS ─── */}
      <div className="glass-panel" style={{ padding: '8px 12px', display: 'flex', gap: '8px', overflowX: 'auto' }}>
        <button
          onClick={() => setSelectedDomain('overview')}
          className={`btn ${selectedDomain === 'overview' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px' }}
        >
          <Compass size={16} /> المركز الإداري الشامل
        </button>
        <button
          onClick={() => setSelectedDomain('taxi')}
          className={`btn ${selectedDomain === 'taxi' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px', color: selectedDomain === 'taxi' ? '#070B12' : '#FBBF24' }}
        >
          <Car size={16} /> كباتن التكسي ({taxiMetrics.totalRides})
        </button>
        <button
          onClick={() => setSelectedDomain('delivery_couriers' as any)}
          className={`btn ${selectedDomain === ('delivery_couriers' as any) ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px', color: selectedDomain === ('delivery_couriers' as any) ? '#070B12' : '#00BFA5' }}
        >
          <Navigation size={16} /> مندوبي ودراجات التوصيل ({fleetMetrics.motorcycleCount})
        </button>
        <button
          onClick={() => setSelectedDomain('restaurants')}
          className={`btn ${selectedDomain === 'restaurants' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px', color: selectedDomain === 'restaurants' ? '#070B12' : '#F97316' }}
        >
          <UtensilsCrossed size={16} /> المطاعم والمأكولات ({restaurantMetrics.totalCount})
        </button>
        <button
          onClick={() => setSelectedDomain('stores')}
          className={`btn ${selectedDomain === 'stores' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px', color: selectedDomain === 'stores' ? '#070B12' : '#0284C7' }}
        >
          <ShoppingBag size={16} /> المتاجر والتسوق ({storeMetrics.totalCount})
        </button>
      </div>

      {/* ─── 3. OVERALL 5 MAIN FINANCIAL & FLEET SUMMARY CARDS ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '14px' }}>
        
        <div className="glass-panel" style={{ padding: '18px', background: 'linear-gradient(135deg, rgba(0, 191, 165, 0.12) 0%, rgba(10, 17, 26, 0.7) 100%)', border: '1px solid rgba(0, 191, 165, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي حجم التداول المالي (GMV)</span>
            <Coins size={18} color="#00BFA5" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '950', color: '#fff', marginTop: '8px' }}>
            {formatIqd(systemTotals.totalGmv)}
          </div>
          <div style={{ fontSize: '11px', color: '#00BFA5', marginTop: '4px' }}>
            عبر {systemTotals.totalOperations} عملية في قضاء القائم
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '18px', background: 'linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(10, 17, 26, 0.7) 100%)', border: '1px solid rgba(245, 158, 11, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>صافي أرباح وعمولة مدار</span>
            <TrendingUp size={18} color="#FBBF24" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '950', color: '#FBBF24', marginTop: '8px' }}>
            {formatIqd(systemTotals.totalPlatformCommission)}
          </div>
          <div style={{ fontSize: '11px', color: '#FDE68A', marginTop: '4px' }}>
            إيرادات المنظومة المحصلة من كافة الخدمات
          </div>
        </div>

        {/* Dedicated Taxi Cars Card */}
        <div className="glass-panel" style={{ padding: '18px', border: '1px solid rgba(245, 158, 11, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>سيارات كباتن التكسي </span>
            <Car size={18} color="#F59E0B" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '950', color: '#FBBF24', marginTop: '8px' }}>
            {fleetMetrics.taxiCarCount} سيارة تكسي
          </div>
          <div style={{ fontSize: '11px', color: '#34D399', marginTop: '4px' }}>
            {taxiMetrics.activeCount} مشوار ركاب نشط الآن
          </div>
        </div>

        {/* Dedicated Delivery Motorcycles Card */}
        <div className="glass-panel" style={{ padding: '18px', border: '1px solid rgba(0, 191, 165, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>دراجات ومندوبي التوصيل </span>
            <Navigation size={18} color="#00BFA5" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '950', color: '#00BFA5', marginTop: '8px' }}>
            {fleetMetrics.motorcycleCount} دراجة توصيل
          </div>
          <div style={{ fontSize: '11px', color: '#38BDF8', marginTop: '4px' }}>
            توصيل المطاعم والمتاجر ومرسال
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>العمليات المنفذة بنجاح</span>
            <CheckCircle2 size={18} color="#34D399" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '950', color: '#34D399', marginTop: '8px' }}>
            {systemTotals.totalCompleted} طلب / مشوار
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
            من أصل {systemTotals.totalOperations} عملية مسجلة
          </div>
        </div>

      </div>

      {/* ─── 3.1 INTERACTIVE VISUAL ANALYTICS SECTION ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 1fr', gap: '16px' }}>
        
        {/* Revenue Trend Area Curve */}
        <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', border: '1px solid rgba(0, 191, 165, 0.25)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <div>
              <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <TrendingUp size={18} color="#00BFA5" /> منحنى تدفق المبيعات والإيرادات (الأيام الـ 7 الأخيرة)
              </div>
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>
                حساب حي لحجم التداول اليومي GMV بالدينار العراقي
              </div>
            </div>
            <span className="badge badge-primary">تحديث لحظي</span>
          </div>

          <div style={{ width: '100%', marginTop: '8px' }}>
            <AreaRevenueChart data={chartData.trendPoints} height={160} color="#00BFA5" />
          </div>
        </div>

        {/* Orders Distribution Breakdown */}
        <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', border: '1px solid rgba(56, 189, 248, 0.25)' }}>
          <div style={{ marginBottom: '12px' }}>
            <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <PieChart size={18} color="#38BDF8" /> توزيع العمليات بين الخدمات
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>
              نسبة اكتمال العمليات حسب القطاع
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '8px 0' }}>
            <DonutDistributionChart 
              segments={chartData.donutSegments} 
              size={135} 
              centerText={String(systemTotals.totalCompleted)}
              centerSub="عملية منجزة"
            />
          </div>
        </div>

      </div>

      {/* ─── 4. DOMAIN HUBS CARDS GRID (When in Overview) ─── */}
      {selectedDomain === 'overview' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '16px' }}>
          
          {/* TAXI COMMAND CARD */}
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', gap: '14px', border: '1px solid rgba(245, 158, 11, 0.3)', background: 'linear-gradient(135deg, rgba(245, 158, 11, 0.05) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(245, 158, 11, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#f59e0b' }}>
                    <Car size={20} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>منظومة رحلات التكسي</h3>
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>{taxiMetrics.totalRides} مشوار مسجل</span>
                  </div>
                </div>
                <button onClick={() => handleNav('rides')} className="btn btn-secondary" style={{ fontSize: '11px', padding: '4px 10px', color: '#fbbf24' }}>
                  إدارة التكسي 
                </button>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '14px' }}>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>المشاوير النشطة الآن</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#34d399', marginTop: '2px' }}>{taxiMetrics.activeCount} مشوار</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>بانتظار قبول السائق</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#fbbf24', marginTop: '2px' }}>{taxiMetrics.pendingCount} طلب</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>إجمالي إيرادات التكسي</div>
                  <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', marginTop: '2px' }}>{formatIqd(taxiMetrics.totalFare)}</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>تقييم الركاب العام</div>
                  <div style={{ fontSize: '16px', fontWeight: '900', color: '#facc15', marginTop: '2px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Star size={14} fill="#facc15" /> {taxiMetrics.avgRating}
                  </div>
                </div>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px' }}>
              <span style={{ color: 'var(--text-muted)' }}>عمولة مدار المستقطعة:</span>
              <span style={{ color: '#34d399', fontWeight: '800' }}>{formatIqd(taxiMetrics.totalCommission)}</span>
            </div>
          </div>

          {/* RESTAURANTS COMMAND CARD */}
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', gap: '14px', border: '1px solid rgba(249, 115, 22, 0.3)', background: 'linear-gradient(135deg, rgba(249, 115, 22, 0.05) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(249, 115, 22, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fbbf24' }}>
                    <UtensilsCrossed size={20} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>قطاع المطاعم والمأكولات</h3>
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>{restaurantMetrics.totalCount} مطعم مسجل</span>
                  </div>
                </div>
                <button onClick={() => handleNav('restaurants')} className="btn btn-secondary" style={{ fontSize: '11px', padding: '4px 10px', color: '#fbbf24' }}>
                  المطاعم 
                </button>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '14px' }}>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>المطاعم المفتوحة الآن</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#34d399', marginTop: '2px' }}>{restaurantMetrics.openCount} مطعم </div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>بانتظار موافقة التسجيل</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#fbbf24', marginTop: '2px' }}>{restaurantMetrics.pendingCount} مطعم </div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>إجمالي مبيعات المطاعم</div>
                  <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', marginTop: '2px' }}>{formatIqd(restaurantMetrics.totalSales)}</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>الوجبات المكتملة</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#38bdf8', marginTop: '2px' }}>{restaurantMetrics.completedOrders} طلب</div>
                </div>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px' }}>
              <span style={{ color: 'var(--text-muted)' }}>عمولة مدار من المطاعم (10%):</span>
              <span style={{ color: '#34d399', fontWeight: '800' }}>{formatIqd(restaurantMetrics.totalCommission)}</span>
            </div>
          </div>

          {/* STORES & SHOPPING COMMAND CARD */}
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', gap: '14px', border: '1px solid rgba(56, 189, 248, 0.3)', background: 'linear-gradient(135deg, rgba(56, 189, 248, 0.05) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(56, 189, 248, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#38bdf8' }}>
                    <ShoppingBag size={20} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>قطاع المتاجر والتسوق</h3>
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>{storeMetrics.totalCount} متجر وسوبرماركت</span>
                  </div>
                </div>
                <button onClick={() => handleNav('stores')} className="btn btn-secondary" style={{ fontSize: '11px', padding: '4px 10px', color: '#38bdf8' }}>
                  المتاجر 
                </button>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '14px' }}>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>السوبرماركت والبقالة</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#38bdf8', marginTop: '2px' }}>{storeMetrics.supermarketCount} متجر</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>الصيدليات ومتاجر الأدوية</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#a78bfa', marginTop: '2px' }}>{storeMetrics.pharmacyCount} صيدلية</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>مبيعات المتاجر الإجمالية</div>
                  <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', marginTop: '2px' }}>{formatIqd(storeMetrics.totalSales)}</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>الطلبات المنفذة</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#34d399', marginTop: '2px' }}>{storeMetrics.completedOrders} طلب</div>
                </div>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px' }}>
              <span style={{ color: 'var(--text-muted)' }}>عمولة مدار من المتاجر (7%):</span>
              <span style={{ color: '#34d399', fontWeight: '800' }}>{formatIqd(storeMetrics.totalCommission)}</span>
            </div>
          </div>

          {/* DELIVERY COURIERS & MOTORCYCLES COMMAND CARD */}
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between', gap: '14px', border: '1px solid rgba(0, 191, 165, 0.3)', background: 'linear-gradient(135deg, rgba(0, 191, 165, 0.05) 0%, rgba(10, 17, 26, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(0, 191, 165, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#00BFA5' }}>
                    <Navigation size={20} />
                  </div>
                  <div>
                    <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>مندوبي ودراجات التوصيل (مرسال)</h3>
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>{fleetMetrics.motorcycleCount} دراجة ومندوب توصيل</span>
                  </div>
                </div>
                <button onClick={() => handleNav('delivery_couriers')} className="btn btn-secondary" style={{ fontSize: '11px', padding: '4px 10px', color: '#00BFA5' }}>
                  كباتن التوصيل 
                </button>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '14px' }}>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>دراجات التوصيل النشطة</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#00BFA5', marginTop: '2px' }}>{fleetMetrics.motorcycleCount} دراجة </div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>طلبات التوصيل المنفذة</div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#38BDF8', marginTop: '2px' }}>{restaurantMetrics.completedOrders + storeMetrics.completedOrders} طلب</div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>قطاع التوصيل الرئيسي</div>
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#F97316', marginTop: '2px' }}>وجبات المطاعم </div>
                </div>
                <div style={{ padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>خدمات الطرود السريعة</div>
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#FBBF24', marginTop: '2px' }}>طرود مرسال </div>
                </div>
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px' }}>
              <span style={{ color: 'var(--text-muted)' }}>نطاق العمليات:</span>
              <span style={{ color: '#00BFA5', fontWeight: '800' }}>قضاء القائم وكافة أحيائها</span>
            </div>
          </div>

        </div>
      )}

      {/* ─── 5. FOCUSED DOMAIN DEEP-DIVE (When a specific domain tab is clicked) ─── */}
      {selectedDomain === 'taxi' && (
        <div className="glass-panel" style={{ padding: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Car size={20} color="#f59e0b" />
              <span>إدارة كافة حالات رحلات التكسي (Taxi Operations Live)</span>
            </h3>
            <button onClick={() => handleNav('rides')} className="btn btn-primary" style={{ fontSize: '12px', padding: '6px 14px' }}>
              فتح شاشة إدارة التكسي الكاملة 
            </button>
          </div>

          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>رقم المشوار</th>
                  <th>الراكب</th>
                  <th>الكابتن المكلف</th>
                  <th>مسار الرحلة</th>
                  <th>الأجرة (د.ع)</th>
                  <th>عمولة مدار</th>
                  <th>الحالة</th>
                  <th>التقييم </th>
                </tr>
              </thead>
              <tbody>
                {taxiMetrics.recentRides.map((r, idx) => (
                  <tr key={`taxi_ride_${r.rideId}_${idx}`}>
                    <td><span style={{ fontWeight: '800', color: '#fff' }}>#{r.rideId.slice(0, 7)}</span></td>
                    <td>{r.passengerName} <div style={{ fontSize: '10px', color: 'var(--text-dim)' }} dir="ltr">{r.passengerPhone}</div></td>
                    <td>{r.driverName || 'بانتظار سائق'}</td>
                    <td><div style={{ fontSize: '12px' }}>{r.pickupAddress} {r.destinationAddress}</div></td>
                    <td style={{ fontWeight: '800', color: '#34d399' }}>{formatIqd(r.fareIqd)}</td>
                    <td style={{ color: '#38bdf8' }}>{formatIqd(r.commissionIqd)}</td>
                    <td><span className="badge badge-warning">{r.statusArabic}</span></td>
                    <td>{r.rating ? ` ${r.rating}` : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {selectedDomain === 'restaurants' && (
        <div className="glass-panel" style={{ padding: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <UtensilsCrossed size={20} color="#fbbf24" />
              <span>إدارة المطاعم وطلبات المأكولات السريعة</span>
            </h3>
            <button onClick={() => handleNav('restaurants')} className="btn btn-primary" style={{ fontSize: '12px', padding: '6px 14px' }}>
              فتح شاشة إدارة المطاعم الكاملة 
            </button>
          </div>

          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>اسم المطعم</th>
                  <th>التصنيف</th>
                  <th>المالك والهاتف</th>
                  <th>حالة الفتح</th>
                  <th>إجمالي المبيعات GMV</th>
                  <th>نسبة العمولة</th>
                  <th>الطلبات المكتملة</th>
                </tr>
              </thead>
              <tbody>
                {restaurantMetrics.topRestaurants.map((m, idx) => (
                  <tr key={`rest_top_${m.merchantId}_${idx}`}>
                    <td style={{ fontWeight: '800', color: '#fff' }}>{m.name}</td>
                    <td><span className="badge badge-warning">{m.subCategory || 'مطاعم ومأكولات'}</span></td>
                    <td>{m.ownerName} <div style={{ fontSize: '10px', color: 'var(--text-dim)' }} dir="ltr">{m.phone}</div></td>
                    <td><span className={`badge ${m.isOpen ? 'badge-success' : 'badge-danger'}`}>{m.isOpen ? 'مفتوح ' : 'مغلق '}</span></td>
                    <td style={{ fontWeight: '800', color: '#34d399' }}>{formatIqd(m.totalRevenueIqd || 0)}</td>
                    <td>{m.commissionRate}%</td>
                    <td>{m.totalOrders || 0} طلب</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {selectedDomain === 'stores' && (
        <div className="glass-panel" style={{ padding: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <ShoppingBag size={20} color="#38bdf8" />
              <span>إدارة كافة متاجر التسوق والسوبرماركت والصيدليات</span>
            </h3>
            <button onClick={() => handleNav('stores')} className="btn btn-primary" style={{ fontSize: '12px', padding: '6px 14px' }}>
              فتح شاشة إدارة المتاجر الكاملة 
            </button>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '14px', marginBottom: '20px' }}>
            <div style={{ padding: '14px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}> السوبرماركت والمواد الغذائية</div>
              <div style={{ fontSize: '20px', fontWeight: '900', color: '#38bdf8', marginTop: '4px' }}>{storeMetrics.supermarketCount} متجر</div>
            </div>
            <div style={{ padding: '14px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}> الصيدليات ومستلزمات العناية</div>
              <div style={{ fontSize: '20px', fontWeight: '900', color: '#a78bfa', marginTop: '4px' }}>{storeMetrics.pharmacyCount} صيدلية</div>
            </div>
          </div>
        </div>
      )}

      {(selectedDomain === ('delivery_couriers' as any) || selectedDomain === 'fleet') && (
        <div className="glass-panel" style={{ padding: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Navigation size={20} color="#00BFA5" />
              <span>مندوبي ودراجات التوصيل السريع (المطاعم، المتاجر، ومرسال )</span>
            </h3>
            <button onClick={() => handleNav('delivery_couriers')} className="btn btn-primary" style={{ fontSize: '12px', padding: '6px 14px' }}>
              فتح شاشة إدارة مندوبي التوصيل الكاملة 
            </button>
          </div>

          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>اسم المندوب</th>
                  <th>نوع الدراجة واللوحة</th>
                  <th>رقم الهاتف</th>
                  <th>حالة التوثيق KYC</th>
                  <th>حالة الاتصال</th>
                  <th>الطلبات المنفذة</th>
                  <th>التقييم </th>
                </tr>
              </thead>
              <tbody>
                {drivers.filter(d => d.vehicleCategory === 'motorcycle').slice(0, 10).map((d, idx) => (
                  <tr key={`cap_top_${d.driverId}_${idx}`}>
                    <td style={{ fontWeight: '800', color: '#fff' }}>{d.name}</td>
                    <td> دراجة توصيل ({d.vehicleModel || 'دراجة نارية'})</td>
                    <td dir="ltr">{d.phoneNumber}</td>
                    <td><span className="badge badge-success">موثق معتمد </span></td>
                    <td><span className={`badge ${d.isOnline ? 'badge-success' : 'badge-info'}`}>{d.isOnline ? 'متصل ومتاح ' : 'غير متصل '}</span></td>
                    <td>{d.totalTrips || 0}</td>
                    <td> {d.rating || 5.0}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── 6. LIVE RADAR STREAM & QUICK LAUNCHPAD ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: '16px' }}>
        
        {/* Live Operations Feed */}
        <div className="glass-panel" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px', flexWrap: 'wrap', gap: '10px' }}>
            <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Radio size={18} color="#06b6d4" style={{ animation: 'pulse 1.5s infinite' }} />
              <span>شريط البث الحي للعمليات اللحظية (Live Feed)</span>
            </h3>
            
            <div style={{ display: 'flex', gap: '6px' }}>
              <button onClick={() => setRadarFilter('all')} className={`btn ${radarFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '3px 8px' }}>الكل</button>
              <button onClick={() => setRadarFilter('taxi')} className={`btn ${radarFilter === 'taxi' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '3px 8px', color: '#f59e0b' }}>تكسي</button>
              <button onClick={() => setRadarFilter('food')} className={`btn ${radarFilter === 'food' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '3px 8px', color: '#fbbf24' }}>مطاعم</button>
              <button onClick={() => setRadarFilter('store')} className={`btn ${radarFilter === 'store' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '3px 8px', color: '#38bdf8' }}>متاجر</button>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '420px', overflowY: 'auto' }}>
            {liveRadarItems.slice(0, 10).map((item, idx) => {
              const IconComp = item.domainIcon;
              return (
                <div
                  key={`radar_item_${item.domain}_${item.id}_${idx}`}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    padding: '10px 14px',
                    background: 'rgba(255, 255, 255, 0.02)',
                    borderRadius: '10px',
                    border: '1px solid rgba(255, 255, 255, 0.06)'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div style={{ width: '32px', height: '32px', borderRadius: '8px', background: `${item.domainColor}20`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: item.domainColor }}>
                      <IconComp size={16} />
                    </div>
                    <div>
                      <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{item.title}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        الزبون: {item.customer} • {item.target}
                      </div>
                    </div>
                  </div>

                  <div style={{ textAlign: 'left' }}>
                    <div style={{ fontWeight: '900', color: '#34d399', fontSize: '13px' }}>{formatIqd(item.amount)}</div>
                    <div style={{ fontSize: '10px', color: item.domainColor }}>{item.status} • {item.time}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Quick Actions Launchpad */}
        <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Zap size={18} color="#fbbf24" />
            <span>مركز الاختصارات والإجراءات السريعة</span>
          </h3>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '10px' }}>
            <button
              onClick={() => handleNav('broadcast')}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', borderRadius: '10px', fontSize: '13px', fontWeight: '700' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Bell size={16} color="#38bdf8" />
                <span> إرسال إشعار جماعي فوري (FCM)</span>
              </div>
              <ChevronLeft size={16} color="#94a3b8" />
            </button>

            <button
              onClick={() => handleNav('coupons')}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', borderRadius: '10px', fontSize: '13px', fontWeight: '700' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Tag size={16} color="#fbbf24" />
                <span> إنشاء قسائم وكوبونات الخصم</span>
              </div>
              <ChevronLeft size={16} color="#94a3b8" />
            </button>

            <button
              onClick={() => handleNav('rewards')}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', borderRadius: '10px', fontSize: '13px', fontWeight: '700' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Gift size={16} color="#f59e0b" />
                <span> نظام المكافآت ونقاط الولاء</span>
              </div>
              <ChevronLeft size={16} color="#94a3b8" />
            </button>

            <button
              onClick={() => handleNav('finance')}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', borderRadius: '10px', fontSize: '13px', fontWeight: '700' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Wallet size={16} color="#34d399" />
                <span> شحن المحافظ والتسويات المالية</span>
              </div>
              <ChevronLeft size={16} color="#94a3b8" />
            </button>

            <button
              onClick={() => handleNav('reports')}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', borderRadius: '10px', fontSize: '13px', fontWeight: '700' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <FileText size={16} color="#06b6d4" />
                <span> طباعة التقارير الرسمية PDF</span>
              </div>
              <ChevronLeft size={16} color="#94a3b8" />
            </button>
          </div>
        </div>

      </div>

    </div>
  );
};
