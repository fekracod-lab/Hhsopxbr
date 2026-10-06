import React, { useState, useEffect, useMemo } from 'react';
import {
  Car,
  Search,
  Star,
  MapPin,
  Phone,
  User,
  DollarSign,
  Clock,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Navigation,
  ExternalLink,
  Download,
  Calendar,
  MessageCircle,
  ShieldCheck,
  RotateCcw,
  Sparkles,
  Info,
  ChevronDown,
  Layers,
  ArrowRightLeft,
  Loader2,
  Tag,
  Coins,
  TrendingUp,
  Receipt,
  Printer,
  X
} from 'lucide-react';
import { TaxiRidesRepository, TaxiRideEntity } from '../../infrastructure/repositories/TaxiRidesRepository';
import { TaxiCaptainRepository } from '../../infrastructure/repositories/TaxiCaptainRepository';
import { TaxiCaptainEntity as DriverEntity } from '../../domain/types';
import { OfficialInvoiceModal, OfficialInvoiceData, InvoiceItem } from '../components/OfficialInvoiceModal';

export const TaxiRidesModule: React.FC = () => {
  const [rides, setRides] = useState<TaxiRideEntity[]>([]);
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Official PDF Receipt State
  const [activeInvoiceData, setActiveInvoiceData] = useState<OfficialInvoiceData | null>(null);

  // Filters State
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'pending' | 'completed' | 'cancelled' | 'rated'>('all');
  const [ratingFilter, setRatingFilter] = useState<'all' | '5' | 'good' | 'low'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [paymentFilter, setPaymentFilter] = useState<'all' | 'cash' | 'wallet'>('all');
  const [dateFilter, setDateFilter] = useState<'all' | 'today' | 'week' | 'month'>('all');

  // Selected Ride Modal
  const [selectedRide, setSelectedRide] = useState<TaxiRideEntity | null>(null);

  // Reassign Driver Modal
  const [reassignRide, setReassignRide] = useState<TaxiRideEntity | null>(null);
  const [selectedDriverId, setSelectedDriverId] = useState('');
  const [isReassigning, setIsReassigning] = useState(false);

  // Cancel Ride Modal
  const [cancellingRide, setCancellingRide] = useState<TaxiRideEntity | null>(null);
  const [cancelReasonInput, setCancelReasonInput] = useState('');
  const [isCancelling, setIsCancelling] = useState(false);

  // Toast
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const openOfficialReceiptForRide = (ride: TaxiRideEntity) => {
    const invoiceItems: InvoiceItem[] = [
      {
        name: `مشوار تكسي مدار: من ${ride.pickupAddress || 'نقطة الانطلاق'} إلى ${ride.destinationAddress || 'نقطة الوصول'}`,
        quantity: 1,
        unitPrice: ride.fareIqd,
        totalPrice: ride.fareIqd,
        notes: `المسافة: ${ride.distanceKm ? ride.distanceKm + ' كم' : 'مسار محدد'} • الوقت: ${ride.durationMinutes ? ride.durationMinutes + ' دقيقة' : 'فوري'}`
      }
    ];

    const invData: OfficialInvoiceData = {
      documentNumber: `MADAR-TAXI-${ride.rideId.substring(0, 8).toUpperCase()}`,
      documentType: 'taxi_ride',
      documentTitle: 'سند مشوار تكسي رسمي معتمد',
      date: new Date(ride.createdAt).toLocaleDateString('ar-IQ', { year: 'numeric', month: 'long', day: 'numeric' }),
      time: new Date(ride.createdAt).toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' }),
      customerName: ride.passengerName || 'الراكب',
      customerPhone: ride.passengerPhone,
      customerAddress: ride.pickupAddress,
      providerName: ride.driverName ? `كابتن ${ride.driverName} (${ride.vehicleModel || 'سيارة تكسي'})` : 'كابتن تكسي مدار',
      providerPhone: ride.driverPhone,
      providerRole: 'كابتن تكسي مدار',
      items: invoiceItems,
      subtotalIqd: ride.fareIqd,
      deliveryFeeIqd: 0,
      discountIqd: 0,
      totalIqd: ride.fareIqd,
      paymentMethod: ride.paymentMethod || 'كاش عند الوصول',
      paymentStatus: ride.status === 'completed' ? 'paid' : 'pending',
      notes: `رقم اللوحة: ${ride.vehiclePlate || 'مسجلة بالمنظومة'} • عمولة المنظومة: ${ride.commissionIqd || 0} د.ع`
    };

    setActiveInvoiceData(invData);
  };

  useEffect(() => {
    setIsLoading(true);
    const unsubRides = TaxiRidesRepository.subscribeToTaxiRides((data) => {
      setRides(data);
      setIsLoading(false);

      if (selectedRide) {
        const updated = data.find(r => r.rideId === selectedRide.rideId);
        if (updated) setSelectedRide(updated);
      }
    });

    const unsubDrivers = TaxiCaptainRepository.subscribeToCaptains((data) => {
      setDrivers(data);
    });

    return () => {
      unsubRides();
      unsubDrivers();
    };
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 4000);
  };

  const formatIqd = (val: number) => {
    return new Intl.NumberFormat('ar-IQ').format(val) + ' د.ع';
  };

  // Filtered Rides
  const filteredRides = useMemo(() => {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const oneWeekAgo = now.getTime() - (7 * 24 * 60 * 60 * 1000);
    const oneMonthAgo = now.getTime() - (30 * 24 * 60 * 60 * 1000);

    return rides.filter(r => {
      // Status Filter
      if (statusFilter === 'active') {
        if (r.status !== 'in_trip' && r.status !== 'arrived' && r.status !== 'accepted') return false;
      } else if (statusFilter === 'pending') {
        if (r.status !== 'searching') return false;
      } else if (statusFilter === 'completed') {
        if (r.status !== 'completed') return false;
      } else if (statusFilter === 'cancelled') {
        if (r.status !== 'cancelled') return false;
      } else if (statusFilter === 'rated') {
        if (!r.isRated && !r.rating && !r.ratingComment) return false;
      }

      // Rating Filter
      if (ratingFilter === '5') {
        if (r.rating !== 5) return false;
      } else if (ratingFilter === 'good') {
        if (!r.rating || r.rating < 3 || r.rating >= 5) return false;
      } else if (ratingFilter === 'low') {
        if (!r.rating || r.rating > 2) return false;
      }

      // Payment Filter
      if (paymentFilter !== 'all') {
        if (paymentFilter === 'cash' && r.paymentMethod !== 'cash') return false;
        if (paymentFilter === 'wallet' && r.paymentMethod === 'cash') return false;
      }

      // Date Filter
      if (dateFilter === 'today') {
        if (r.createdTimestamp < startOfToday) return false;
      } else if (dateFilter === 'week') {
        if (r.createdTimestamp < oneWeekAgo) return false;
      } else if (dateFilter === 'month') {
        if (r.createdTimestamp < oneMonthAgo) return false;
      }

      // Search Query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const match = 
          r.rideId.toLowerCase().includes(q) ||
          r.passengerName.toLowerCase().includes(q) ||
          (r.passengerPhone && r.passengerPhone.includes(q)) ||
          (r.driverName && r.driverName.toLowerCase().includes(q)) ||
          (r.driverPhone && r.driverPhone.includes(q)) ||
          (r.vehiclePlate && r.vehiclePlate.includes(q)) ||
          (r.vehicleModel && r.vehicleModel.toLowerCase().includes(q)) ||
          (r.pickupAddress && r.pickupAddress.toLowerCase().includes(q)) ||
          (r.destinationAddress && r.destinationAddress.toLowerCase().includes(q)) ||
          (r.ratingComment && r.ratingComment.toLowerCase().includes(q)) ||
          (r.ratingReason && r.ratingReason.toLowerCase().includes(q));
        if (!match) return false;
      }

      return true;
    });
  }, [rides, statusFilter, ratingFilter, paymentFilter, dateFilter, searchQuery]);

  // Overall Top Statistics
  const stats = useMemo(() => {
    let totalFare = 0;
    let totalCommission = 0;
    let totalDriverNet = 0;
    let activeTrips = 0;
    let completedTrips = 0;
    let cancelledTrips = 0;
    let ratedCount = 0;
    let ratingSum = 0;

    rides.forEach(r => {
      if (r.status === 'completed') {
        totalFare += r.fareIqd;
        totalCommission += r.commissionIqd;
        totalDriverNet += r.driverNetIqd;
        completedTrips++;
      } else if (r.status === 'in_trip' || r.status === 'arrived' || r.status === 'accepted') {
        activeTrips++;
      } else if (r.status === 'cancelled') {
        cancelledTrips++;
      }

      if (r.rating && r.rating > 0) {
        ratingSum += r.rating;
        ratedCount++;
      }
    });

    const avgRating = ratedCount > 0 ? (ratingSum / ratedCount).toFixed(1) : '5.0';

    return {
      totalRides: rides.length,
      activeTrips,
      completedTrips,
      cancelledTrips,
      totalFare,
      totalCommission,
      totalDriverNet,
      ratedCount,
      avgRating
    };
  }, [rides]);

  // Export CSV
  const handleExportCsv = () => {
    if (filteredRides.length === 0) {
      showToast('ماكو رحلات حالياً لتصديرها', 'error');
      return;
    }

    const headers = [
      'معرف الرحلة',
      'تاريخ الطلب',
      'اسم الراكب',
      'هاتف الراكب',
      'اسم الكابتن',
      'هاتف الكابتن',
      'السيارة واللوحة',
      'نقطة الانطلاق',
      'الوجهة',
      'أجرة المشوار (د.ع)',
      'عمولة مدار (د.ع)',
      'صافي الكابتن (د.ع)',
      'طريقة الدفع',
      'الحالة',
      'التقييم',
      'سبب التقييم / الملاحظات',
      'سبب الإلغاء'
    ];

    const rows = filteredRides.map(r => [
      r.rideId,
      r.createdAt,
      `"${r.passengerName}"`,
      `"${r.passengerPhone || ''}"`,
      `"${r.driverName || 'غير مسند'}"`,
      `"${r.driverPhone || ''}"`,
      `"${r.vehicleModel || ''} (${r.vehiclePlate || ''})"`,
      `"${r.pickupAddress}"`,
      `"${r.destinationAddress}"`,
      r.fareIqd,
      r.commissionIqd,
      r.driverNetIqd,
      r.paymentMethod === 'cash' ? 'نقدي' : 'محفظة مدار',
      r.statusArabic,
      r.rating ? `${r.rating} نجوم` : 'بدون تقييم',
      `"${r.ratingComment || r.ratingReason || ''}"`,
      `"${r.cancellationReason || ''}"`
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `madar_taxi_rides_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير كشف رحلات التكسي بنجاح ');
  };

  // Reassign Driver
  const handleConfirmReassign = async () => {
    if (!reassignRide || !selectedDriverId) {
      showToast('يرجى اختيار الكابتن أولاً', 'error');
      return;
    }
    const driver = drivers.find(d => d.driverId === selectedDriverId);
    if (!driver) return;

    setIsReassigning(true);
    try {
      await TaxiRidesRepository.assignDriver(
        reassignRide,
        driver.driverId,
        driver.name,
        driver.phoneNumber,
        driver.plateNumber,
        driver.vehicleModel
      );
      showToast(`تم إسناد الرحلة للكابتن (${driver.name}) بنجاح`);
      setReassignRide(null);
      setSelectedDriverId('');
    } catch (err: any) {
      showToast('فشل إسناد الكابتن: ' + (err.message || ''), 'error');
    } finally {
      setIsReassigning(false);
    }
  };

  // Cancel Ride
  const handleConfirmCancel = async () => {
    if (!cancellingRide) return;
    setIsCancelling(true);
    try {
      await TaxiRidesRepository.cancelRide(cancellingRide, cancelReasonInput.trim() || 'إلغاء من المشرف الإداري');
      showToast('تم إلغاء الرحلة وتوثيق السبب في السجل');
      setCancellingRide(null);
      setCancelReasonInput('');
    } catch (err: any) {
      showToast('فشل إلغاء الرحلة: ' + (err.message || ''), 'error');
    } finally {
      setIsCancelling(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {toast && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: toast.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {toast.msg}
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <Car size={22} />
            </div>
            <span>إدارة مشاوير وتوصيل التكسي (Taxi Operations 360°)</span>
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            رصد الزبائن، الأجرة المالية، التقييمات وأسبابها، مسارات GPS الحية، وإسناد الكباتن
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            onClick={handleExportCsv}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '700' }}
          >
            <Download size={15} /> تصدير السجل CSV
          </button>
        </div>
      </div>

      {/* ─── 5 KPI STATS CARDS ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: '14px' }}>
        
        {/* 1. Active & In-Trip */}
        <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(15, 23, 42, 0.6) 100%)', border: '1px solid rgba(245, 158, 11, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>رحلات جارية وعلى الطريق</span>
            <Car size={18} color="#f59e0b" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#fbbf24', marginTop: '6px' }}>
            {stats.activeTrips} رحلة 
          </div>
          <div style={{ fontSize: '11px', color: '#fef08a', marginTop: '3px' }}>
            كباتن في طريقهم أو داخل المشوار
          </div>
        </div>

        {/* 2. Total Fare Gross */}
        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي إيرادات التكسي (GMV)</span>
            <Coins size={18} color="#34d399" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
            {formatIqd(stats.totalFare)}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            من {stats.completedTrips} مشوار مكتمل بنجاح
          </div>
        </div>

        {/* 3. Madar Commission */}
        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>عمولة مدار المحصلة</span>
            <DollarSign size={18} color="#38bdf8" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#38bdf8', marginTop: '6px' }}>
            {formatIqd(stats.totalCommission)}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            صافي ربح الكباتن: {formatIqd(stats.totalDriverNet)}
          </div>
        </div>

        {/* 4. Customer Ratings ( Explicit Request) */}
        <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(234, 179, 8, 0.12) 0%, rgba(15, 23, 42, 0.6) 100%)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>معدل تقييم الركاب للخدمة</span>
            <Star size={18} color="#eab308" fill="#eab308" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#facc15', marginTop: '6px', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span>{stats.avgRating}</span>
            <span style={{ fontSize: '14px', color: '#fef08a' }}>/ 5.0 </span>
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            من إجمالي {stats.ratedCount} تقييم مسجل
          </div>
        </div>

        {/* 5. Total Rides Count */}
        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي طلبات المشاوير</span>
            <Navigation size={18} color="#a78bfa" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#a78bfa', marginTop: '6px' }}>
            {stats.totalRides} طلب
          </div>
          <div style={{ fontSize: '11px', color: '#f87171', marginTop: '3px' }}>
            {stats.cancelledTrips} مشوار ملغي
          </div>
        </div>

      </div>

      {/* ─── FILTERS AND SEARCH BAR ─── */}
      <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
        
        {/* Main Status Tabs */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
          <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '4px' }}>
            <button
              onClick={() => setStatusFilter('all')}
              className={`btn ${statusFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px' }}
            >
               جميع المشاوير ({rides.length})
            </button>
            <button
              onClick={() => setStatusFilter('active')}
              className={`btn ${statusFilter === 'active' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '5px' }}
            >
              <Car size={13} /> جارية وعلى الطريق ({stats.activeTrips})
            </button>
            <button
              onClick={() => setStatusFilter('pending')}
              className={`btn ${statusFilter === 'pending' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px' }}
            >
               بانتظار قبول ({rides.filter(r => r.status === 'searching').length})
            </button>
            <button
              onClick={() => setStatusFilter('completed')}
              className={`btn ${statusFilter === 'completed' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px' }}
            >
               مكتملة ({stats.completedTrips})
            </button>
            <button
              onClick={() => setStatusFilter('cancelled')}
              className={`btn ${statusFilter === 'cancelled' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px' }}
            >
               ملغاة ({stats.cancelledTrips})
            </button>
            <button
              onClick={() => setStatusFilter('rated')}
              className={`btn ${statusFilter === 'rated' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
            >
              <Star size={13} color="#facc15" fill="#facc15" /> كشف التقييمات والآراء ({stats.ratedCount})
            </button>
          </div>

          {/* Rating filter dropdown */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>فلترة النجوم:</span>
            <select
              value={ratingFilter}
              onChange={e => setRatingFilter(e.target.value as any)}
              style={{ padding: '6px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px', outline: 'none' }}
            >
              <option value="all">كافة التقييمات</option>
              <option value="5"> 5 نجوم (ممتازة)</option>
              <option value="good"> 3-4 نجوم (متوسطة)</option>
              <option value="low"> 1-2 نجمة (تقييم سلبي / شكوى)</option>
            </select>
          </div>
        </div>

        {/* Search, Payment and Date */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', flex: 1, minWidth: '300px' }}>
            <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
            <input
              type="text"
              placeholder="ابحث باسم الراكب، رقم الهاتف، الكابتن، رقم اللوحة، المكان، أو تعليق التقييم..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              style={{
                width: '100%',
                padding: '9px 38px 9px 12px',
                background: 'var(--bg-surface)',
                border: '1px solid var(--border-color)',
                borderRadius: '8px',
                color: '#fff',
                fontSize: '13px',
                outline: 'none'
              }}
            />
          </div>

          <div style={{ display: 'flex', gap: '8px' }}>
            <select
              value={paymentFilter}
              onChange={e => setPaymentFilter(e.target.value as any)}
              style={{ padding: '8px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px', outline: 'none' }}
            >
              <option value="all">جميع طرق الدفع</option>
              <option value="cash">دفع نقدي كاش </option>
              <option value="wallet">محفظة مدار </option>
            </select>

            <select
              value={dateFilter}
              onChange={e => setDateFilter(e.target.value as any)}
              style={{ padding: '8px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px', outline: 'none' }}
            >
              <option value="all">كل الأوقات</option>
              <option value="today">مشاوير اليوم</option>
              <option value="week">آخر 7 أيام</option>
              <option value="month">آخر 30 يوماً</option>
            </select>
          </div>
        </div>

      </div>

      {/* ─── MAIN TAXI RIDES TABLE ─── */}
      <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={26} color="#f59e0b" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 10px' }} />
            <div>جاري جلب وتحديث رحلات التكسي لحظياً من Firestore...</div>
          </div>
        ) : filteredRides.length === 0 ? (
          <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Car size={36} color="#64748b" style={{ margin: '0 auto 10px' }} />
            <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>ماكو مشاوير تطابق الفلتر المحدد</div>
            <div style={{ fontSize: '12px', marginTop: '4px' }}>جرب تغيير حالة الفلتر أو البحث عن رقم أو اسم آخر</div>
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>رقم المشوار والتاريخ</th>
                  <th>الراكب (الزبون) </th>
                  <th>الكابتن والسيارة </th>
                  <th>مسار الرحلة (الانطلاق الوجهة) </th>
                  <th>الأجرة والعمولة </th>
                  <th>التقييم والملاحظات </th>
                  <th>الحالة</th>
                  <th>الإجراءات</th>
                </tr>
              </thead>
              <tbody>
                {filteredRides.map(r => {
                  return (
                    <tr key={r.rideId}>
                      {/* ID & Date */}
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff', fontSize: '12.5px' }}>
                          #{r.rideId.slice(0, 8).toUpperCase()}
                        </div>
                        <div style={{ fontSize: '10.5px', color: 'var(--text-muted)', marginTop: '2px' }}>
                          {r.createdAt}
                        </div>
                        <span className="badge badge-info" style={{ fontSize: '9.5px', marginTop: '4px' }}>
                          {r.vehicleType || 'تكسي مدار'}
                        </span>
                      </td>

                      {/* Passenger */}
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{r.passengerName}</div>
                        {r.passengerPhone && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '3px' }}>
                            <a href={`tel:${r.passengerPhone}`} style={{ color: '#38bdf8', fontSize: '11px', textDecoration: 'none' }} dir="ltr">
                               {r.passengerPhone}
                            </a>
                            <a href={`https://wa.me/${r.passengerPhone.replace(/[^0-9]/g, '')}`} target="_blank" rel="noreferrer" style={{ color: '#34d399', fontSize: '11px', textDecoration: 'none' }} title="محادثة واتساب">
                              
                            </a>
                          </div>
                        )}
                        {r.passengerNotes && (
                          <div style={{ fontSize: '10px', color: '#fbbf24', marginTop: '2px' }} title={r.passengerNotes}>
                             {r.passengerNotes.slice(0, 25)}...
                          </div>
                        )}
                      </td>

                      {/* Driver & Car */}
                      <td>
                        {r.driverName ? (
                          <div>
                            <div style={{ fontWeight: '800', color: '#fff', fontSize: '12.5px' }}>{r.driverName}</div>
                            {r.driverPhone && (
                              <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">
                                 {r.driverPhone}
                              </div>
                            )}
                            <div style={{ fontSize: '10.5px', color: '#94a3b8', marginTop: '2px' }}>
                               {r.vehicleModel || 'سيارة أجرة'} {r.vehiclePlate ? `• ${r.vehiclePlate}` : ''}
                            </div>
                          </div>
                        ) : (
                          <div>
                            <span className="badge badge-warning" style={{ fontSize: '10px' }}>بانتظار كابتن </span>
                            <div style={{ marginTop: '4px' }}>
                              <button
                                onClick={() => { setReassignRide(r); setSelectedDriverId(''); }}
                                className="btn btn-secondary"
                                style={{ fontSize: '10px', padding: '2px 6px', color: '#38bdf8' }}
                              >
                                + إسناد كابتن
                              </button>
                            </div>
                          </div>
                        )}
                      </td>

                      {/* Route & GPS */}
                      <td style={{ maxWidth: '240px' }}>
                        <div style={{ fontSize: '11.5px', color: '#34d399', display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <span> من:</span>
                          <span style={{ color: '#fff', fontWeight: '600' }}>{r.pickupAddress}</span>
                        </div>
                        <div style={{ fontSize: '11.5px', color: '#f87171', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '4px' }}>
                          <span> إلى:</span>
                          <span style={{ color: '#fff', fontWeight: '600' }}>{r.destinationAddress}</span>
                        </div>
                        
                        {/* Google Maps link if coordinates available */}
                        {r.pickupLat && r.pickupLng && (
                          <div style={{ marginTop: '4px' }}>
                            <a
                              href={`https://www.google.com/maps/dir/?api=1&origin=${r.pickupLat},${r.pickupLng}&destination=${r.destinationLat || r.pickupLat},${r.destinationLng || r.pickupLng}`}
                              target="_blank"
                              rel="noreferrer"
                              style={{ fontSize: '10px', color: '#38bdf8', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: '3px' }}
                            >
                              <ExternalLink size={10} /> فتح مسار الخريطة GPS
                            </a>
                          </div>
                        )}
                      </td>

                      {/* Fare & Commission */}
                      <td>
                        <div style={{ fontWeight: '900', color: '#34d399', fontSize: '13.5px' }}>
                          {formatIqd(r.fareIqd)}
                        </div>
                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)', marginTop: '2px' }}>
                          عمولة مدار: <span style={{ color: '#38bdf8' }}>{formatIqd(r.commissionIqd)}</span>
                        </div>
                        <div style={{ fontSize: '10.5px', color: '#fbbf24', marginTop: '1px' }}>
                          صافي الكابتن: {formatIqd(r.driverNetIqd)}
                        </div>
                        <span className="badge" style={{ fontSize: '9.5px', marginTop: '4px', background: r.paymentMethod === 'cash' ? 'rgba(52, 211, 153, 0.15)' : 'rgba(56, 189, 248, 0.15)', color: r.paymentMethod === 'cash' ? '#34d399' : '#38bdf8' }}>
                          {r.paymentMethod === 'cash' ? 'كاش ' : 'محفظة مدار '}
                        </span>
                      </td>

                      {/* Rating & Reason ( User requirement) */}
                      <td style={{ maxWidth: '200px' }}>
                        {r.rating ? (
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                              {Array.from({ length: 5 }).map((_, i) => (
                                <Star
                                  key={i}
                                  size={13}
                                  color={i < (r.rating || 0) ? '#facc15' : '#475569'}
                                  fill={i < (r.rating || 0) ? '#facc15' : 'transparent'}
                                />
                              ))}
                              <span style={{ fontSize: '11px', fontWeight: '800', color: '#facc15', marginRight: '4px' }}>
                                {r.rating}/5
                              </span>
                            </div>

                            {/* Comment or Reason */}
                            {(r.ratingComment || r.ratingReason) && (
                              <div style={{ fontSize: '11px', color: '#cbd5e1', marginTop: '4px', fontStyle: 'italic', background: 'rgba(255,255,255,0.03)', padding: '4px 6px', borderRadius: '4px' }}>
                                "{r.ratingComment || r.ratingReason}"
                              </div>
                            )}

                            {/* Rating Tags */}
                            {r.ratingTags && r.ratingTags.length > 0 && (
                              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '3px', marginTop: '4px' }}>
                                {r.ratingTags.map((tag, idx) => (
                                  <span key={idx} style={{ fontSize: '9.5px', background: 'rgba(234, 179, 8, 0.15)', color: '#fde047', padding: '1px 5px', borderRadius: '4px' }}>
                                     {tag}
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        ) : (
                          <div style={{ fontSize: '11px', color: 'var(--text-dim)' }}>
                            لم يتم التقييم بعد
                          </div>
                        )}
                      </td>

                      {/* Status */}
                      <td>
                        <span
                          className={`badge ${
                            r.status === 'completed'
                              ? 'badge-success'
                              : r.status === 'cancelled'
                              ? 'badge-danger'
                              : r.status === 'in_trip' || r.status === 'arrived'
                              ? 'badge-warning'
                              : 'badge-info'
                          }`}
                          style={{ fontSize: '11px' }}
                        >
                          {r.statusArabic}
                        </span>

                        {r.cancellationReason && (
                          <div style={{ fontSize: '10px', color: '#f87171', marginTop: '3px' }} title={r.cancellationReason}>
                            السبب: {r.cancellationReason.slice(0, 20)}...
                          </div>
                        )}
                      </td>

                      {/* Actions */}
                      <td>
                        <div style={{ display: 'flex', gap: '4px' }}>
                          <button
                            onClick={() => setSelectedRide(r)}
                            className="btn btn-primary"
                            style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '3px' }}
                            title="تفاصيل المشوار الكاملة"
                          >
                            <Info size={13} />
                            <span>التفاصيل</span>
                          </button>

                          {r.status !== 'completed' && r.status !== 'cancelled' && (
                            <>
                              <button
                                onClick={() => { setReassignRide(r); setSelectedDriverId(r.driverId || ''); }}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '5px 7px', color: '#38bdf8' }}
                                title="تغيير / إسناد كابتن"
                              >
                                <ArrowRightLeft size={13} />
                              </button>
                              <button
                                onClick={() => { setCancellingRide(r); setCancelReasonInput(''); }}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '5px 7px', color: '#ef4444' }}
                                title="إلغاء الرحلة"
                              >
                                <XCircle size={13} />
                              </button>
                            </>
                          )}
                        </div>
                      </td>

                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ─── MODAL 1: FULL 360° RIDE DETAILS ─── */}
      {selectedRide && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '680px', width: '100%', borderRadius: '24px', border: '1px solid rgba(245, 158, 11, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.8)', maxHeight: '90vh', overflowY: 'auto' }}>
            
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '14px', marginBottom: '18px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '12px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
                  <Car size={22} />
                </div>
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>
                    تفاصيل مشوار التكسي #{selectedRide.rideId.slice(0, 8).toUpperCase()}
                  </h3>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                    تاريخ الطلب: {selectedRide.createdAt} | المصدر: {selectedRide.sourceCollection}
                  </div>
                </div>
              </div>
              <button onClick={() => setSelectedRide(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: '4px' }}>
                <X size={20} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>

              {/* Status Banner */}
              <div style={{ padding: '12px 16px', borderRadius: '12px', background: selectedRide.status === 'completed' ? 'rgba(16, 185, 129, 0.15)' : selectedRide.status === 'cancelled' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(245, 158, 11, 0.15)', border: `1px solid ${selectedRide.status === 'completed' ? '#10b981' : selectedRide.status === 'cancelled' ? '#ef4444' : '#f59e0b'}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontWeight: '800', color: '#fff', fontSize: '14px' }}>
                    حالة الرحلة: {selectedRide.statusArabic}
                  </div>
                  {selectedRide.cancellationReason && (
                    <div style={{ fontSize: '12px', color: '#f87171', marginTop: '2px' }}>
                      سبب الإلغاء: {selectedRide.cancellationReason}
                    </div>
                  )}
                </div>
                <div style={{ fontSize: '16px', fontWeight: '900', color: '#34d399' }}>
                  {formatIqd(selectedRide.fareIqd)}
                </div>
              </div>

              {/* Route Card */}
              <div className="glass-panel" style={{ padding: '16px' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#38bdf8', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Navigation size={15} /> مسار ومواقع الانطلاق والوصول
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '8px' }}>
                    <span style={{ padding: '2px 6px', background: 'rgba(52, 211, 153, 0.2)', color: '#34d399', borderRadius: '4px', fontSize: '11px', fontWeight: '800' }}>نقطة الانطلاق</span>
                    <span style={{ fontSize: '13px', color: '#fff', fontWeight: '600' }}>{selectedRide.pickupAddress}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '8px' }}>
                    <span style={{ padding: '2px 6px', background: 'rgba(248, 113, 113, 0.2)', color: '#f87171', borderRadius: '4px', fontSize: '11px', fontWeight: '800' }}>نقطة الوصول</span>
                    <span style={{ fontSize: '13px', color: '#fff', fontWeight: '600' }}>{selectedRide.destinationAddress}</span>
                  </div>
                </div>

                {selectedRide.pickupLat && selectedRide.pickupLng && (
                  <div style={{ marginTop: '12px', borderTop: '1px solid var(--border-color)', paddingTop: '10px' }}>
                    <a
                      href={`https://www.google.com/maps/dir/?api=1&origin=${selectedRide.pickupLat},${selectedRide.pickupLng}&destination=${selectedRide.destinationLat || selectedRide.pickupLat},${selectedRide.destinationLng || selectedRide.pickupLng}`}
                      target="_blank"
                      rel="noreferrer"
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#38bdf8' }}
                    >
                      <ExternalLink size={14} /> تتبع المسار الكامل على خرائط Google Maps
                    </a>
                  </div>
                )}
              </div>

              {/* 2-Columns: Passenger & Driver */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                
                {/* Passenger Details */}
                <div className="glass-panel" style={{ padding: '14px' }}>
                  <div style={{ fontSize: '12px', fontWeight: '800', color: '#38bdf8', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <User size={14} /> بيانات الراكب (الزبون)
                  </div>
                  <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{selectedRide.passengerName}</div>
                  {selectedRide.passengerPhone && (
                    <div style={{ fontSize: '12px', color: '#cbd5e1', marginTop: '4px' }} dir="ltr">
                       {selectedRide.passengerPhone}
                    </div>
                  )}
                  {selectedRide.passengerNotes && (
                    <div style={{ fontSize: '11px', color: '#fbbf24', marginTop: '6px', background: 'rgba(251, 191, 36, 0.1)', padding: '6px', borderRadius: '6px' }}>
                      ملاحظة الراكب: {selectedRide.passengerNotes}
                    </div>
                  )}
                  {selectedRide.passengerPhone && (
                    <div style={{ display: 'flex', gap: '6px', marginTop: '10px' }}>
                      <a href={`tel:${selectedRide.passengerPhone}`} className="btn btn-secondary" style={{ flex: 1, fontSize: '11px', textAlign: 'center' }}>
                        اتصال
                      </a>
                      <a href={`https://wa.me/${selectedRide.passengerPhone.replace(/[^0-9]/g, '')}`} target="_blank" rel="noreferrer" className="btn btn-secondary" style={{ flex: 1, fontSize: '11px', textAlign: 'center', color: '#34d399' }}>
                        واتساب
                      </a>
                    </div>
                  )}
                </div>

                {/* Driver Details */}
                <div className="glass-panel" style={{ padding: '14px' }}>
                  <div style={{ fontSize: '12px', fontWeight: '800', color: '#f59e0b', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Car size={14} /> بيانات الكابتن والسيارة
                  </div>
                  {selectedRide.driverName ? (
                    <div>
                      <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{selectedRide.driverName}</div>
                      {selectedRide.driverPhone && (
                        <div style={{ fontSize: '12px', color: '#cbd5e1', marginTop: '4px' }} dir="ltr">
                           {selectedRide.driverPhone}
                        </div>
                      )}
                      <div style={{ fontSize: '11.5px', color: '#94a3b8', marginTop: '4px' }}>
                         {selectedRide.vehicleModel || 'أجرة'} {selectedRide.vehiclePlate ? `• رقم اللوحة: ${selectedRide.vehiclePlate}` : ''}
                      </div>
                      {selectedRide.driverPhone && (
                        <div style={{ display: 'flex', gap: '6px', marginTop: '10px' }}>
                          <a href={`tel:${selectedRide.driverPhone}`} className="btn btn-secondary" style={{ flex: 1, fontSize: '11px', textAlign: 'center' }}>
                            اتصال بالكابتن
                          </a>
                        </div>
                      )}
                    </div>
                  ) : (
                    <div style={{ color: 'var(--text-muted)', fontSize: '12px' }}>
                      لم يتم إسناد كابتن لهذه الرحلة حتى الآن
                    </div>
                  )}
                </div>

              </div>

              {/* Financial Breakdown Card */}
              <div className="glass-panel" style={{ padding: '16px' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#34d399', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Receipt size={15} /> الكشف المالي وتفصيل الأجرة
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px', textAlign: 'center' }}>
                  <div style={{ padding: '10px', background: 'rgba(255,255,255,0.03)', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>أجرة المشوار الإجمالية</div>
                    <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', marginTop: '4px' }}>
                      {formatIqd(selectedRide.fareIqd)}
                    </div>
                  </div>
                  <div style={{ padding: '10px', background: 'rgba(255,255,255,0.03)', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>عمولة منصة مدار</div>
                    <div style={{ fontSize: '15px', fontWeight: '900', color: '#38bdf8', marginTop: '4px' }}>
                      {formatIqd(selectedRide.commissionIqd)}
                    </div>
                  </div>
                  <div style={{ padding: '10px', background: 'rgba(255,255,255,0.03)', borderRadius: '8px' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>صافي أرباح الكابتن</div>
                    <div style={{ fontSize: '15px', fontWeight: '900', color: '#34d399', marginTop: '4px' }}>
                      {formatIqd(selectedRide.driverNetIqd)}
                    </div>
                  </div>
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '8px', textAlign: 'center' }}>
                  طريقة الدفع: <span style={{ color: '#fff', fontWeight: '700' }}>{selectedRide.paymentMethod === 'cash' ? 'دفع نقدي كاش ' : 'رصيد محفظة مدار الإلكترونية '}</span>
                </div>
              </div>

              {/* Rating & Review Breakdown (Explicit Requirement) */}
              <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(234, 179, 8, 0.08) 0%, rgba(15, 23, 42, 0.8) 100%)', border: '1px solid rgba(234, 179, 8, 0.25)' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#facc15', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Star size={15} color="#facc15" fill="#facc15" /> تقييم الراكب وملاحظات جودة الخدمة
                </div>
                {selectedRide.rating ? (
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      {Array.from({ length: 5 }).map((_, i) => (
                        <Star
                          key={i}
                          size={18}
                          color={i < (selectedRide.rating || 0) ? '#facc15' : '#475569'}
                          fill={i < (selectedRide.rating || 0) ? '#facc15' : 'transparent'}
                        />
                      ))}
                      <span style={{ fontSize: '14px', fontWeight: '900', color: '#facc15', marginRight: '6px' }}>
                        ({selectedRide.rating} من 5 نجوم)
                      </span>
                    </div>

                    {(selectedRide.ratingComment || selectedRide.ratingReason) && (
                      <div style={{ marginTop: '10px', padding: '10px', background: 'rgba(0,0,0,0.3)', borderRadius: '8px', borderRight: '3px solid #facc15' }}>
                        <div style={{ fontSize: '11px', color: '#94a3b8' }}>تعليق الراكب الصريح / سبب التقييم:</div>
                        <div style={{ fontSize: '13px', color: '#fff', fontWeight: '600', marginTop: '2px' }}>
                          "{selectedRide.ratingComment || selectedRide.ratingReason}"
                        </div>
                      </div>
                    )}

                    {selectedRide.ratingTags && selectedRide.ratingTags.length > 0 && (
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '10px' }}>
                        {selectedRide.ratingTags.map((tag, idx) => (
                          <span key={idx} style={{ fontSize: '11px', background: 'rgba(234, 179, 8, 0.2)', color: '#fef08a', padding: '3px 8px', borderRadius: '6px', fontWeight: '700' }}>
                             {tag}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                ) : (
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    لم يقم الراكب بتقديم تقييم لهذه الرحلة بعد.
                  </div>
                )}
              </div>

            </div>

            {/* Modal Footer */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '20px' }}>
              <button
                onClick={() => openOfficialReceiptForRide(selectedRide)}
                className="btn btn-primary"
                style={{ padding: '8px 18px', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <Printer size={15} /> طباعة سند مشوار رسمي (Official Receipt)
              </button>

              <button onClick={() => setSelectedRide(null)} className="btn btn-secondary" style={{ padding: '8px 24px', fontSize: '13px' }}>
                إغلاق
              </button>
            </div>

          </div>
        </div>
      )}

      {/* ─── MODAL 2: REASSIGN DRIVER MODAL ─── */}
      {reassignRide && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '24px', maxWidth: '480px', width: '100%', borderRadius: '20px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <h3 style={{ fontSize: '17px', fontWeight: '800', color: '#fff', marginBottom: '8px' }}>
              إسناد / تغيير كابتن الرحلة
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '16px' }}>
              مشوار: {reassignRide.pickupAddress} {reassignRide.destinationAddress}
            </p>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '6px' }}>
                اختر الكابتن من الأسطول:
              </label>
              <select
                value={selectedDriverId}
                onChange={e => setSelectedDriverId(e.target.value)}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
              >
                <option value="">-- اختر الكابتن --</option>
                {drivers.map(d => (
                  <option key={d.driverId} value={d.driverId}>
                    {d.name} ({d.phoneNumber}) • {d.vehicleModel || 'سيارة'} ({d.plateNumber || 'بدون لوحة'})
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={handleConfirmReassign}
                disabled={isReassigning || !selectedDriverId}
                className="btn btn-primary"
                style={{ fontSize: '13px', fontWeight: '700', padding: '8px 20px' }}
              >
                {isReassigning ? 'جاري الإسناد...' : 'تأكيد إسناد الكابتن'}
              </button>
              <button
                onClick={() => setReassignRide(null)}
                className="btn btn-secondary"
                style={{ fontSize: '13px' }}
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL 3: CANCEL RIDE MODAL ─── */}
      {cancellingRide && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '24px', maxWidth: '460px', width: '100%', borderRadius: '20px', border: '1px solid rgba(239, 68, 68, 0.4)' }}>
            <h3 style={{ fontSize: '17px', fontWeight: '800', color: '#f87171', marginBottom: '8px' }}>
              إلغاء مشوار التكسي
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '16px' }}>
              سيتم إلغاء الرحلة وإشعار الطرفين وتوثيق سبب الإلغاء في سجل العمليات.
            </p>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '6px' }}>
                سبب الإلغاء:
              </label>
              <textarea
                rows={3}
                placeholder="اكتب سبب إلغاء المشوار (مثلاً: عدم توفر كابتن قريب، طلب الراكب، خطأ في الموقع)..."
                value={cancelReasonInput}
                onChange={e => setCancelReasonInput(e.target.value)}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
              />
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                onClick={handleConfirmCancel}
                disabled={isCancelling}
                className="btn btn-primary"
                style={{ background: '#ef4444', borderColor: '#f87171', fontSize: '13px', fontWeight: '700', padding: '8px 20px' }}
              >
                {isCancelling ? 'جاري الإلغاء...' : 'تأكيد الإلغاء'}
              </button>
              <button
                onClick={() => setCancellingRide(null)}
                className="btn btn-secondary"
                style={{ fontSize: '13px' }}
              >
                تراجع
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Official Madar PDF Receipt Modal */}
      {activeInvoiceData && (
        <OfficialInvoiceModal
          data={activeInvoiceData}
          onClose={() => setActiveInvoiceData(null)}
        />
      )}

    </div>
  );
};
