import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  FileText,
  Printer,
  Download,
  Calendar,
  DollarSign,
  TrendingUp,
  Car,
  Store,
  ShoppingBag,
  Users,
  CheckCircle2,
  XCircle,
  Clock,
  Star,
  Coins,
  Percent,
  Layers,
  ArrowUpRight,
  Filter,
  Search,
  Sparkles,
  BarChart3,
  PieChart,
  Award,
  AlertTriangle,
  RefreshCw,
  Loader2,
  ChevronDown
} from 'lucide-react';
import { OrdersRepository, AdminOrderRecord } from '../../infrastructure/repositories/OrdersRepository';
import { TaxiRepository, TaxiRideEntity } from '../../infrastructure/repositories/TaxiRepository';
import { DriversRepository } from '../../infrastructure/repositories/DriversRepository';
import { MerchantsRepository } from '../../infrastructure/repositories/MerchantsRepository';
import { DriverEntity, MerchantEntity } from '../../domain/types';
import { useAuth } from '../../application/AuthContext';

export const ReportsModule: React.FC = () => {
  const { user } = useAuth();

  // Raw Data State
  const [orders, setOrders] = useState<AdminOrderRecord[]>([]);
  const [rides, setRides] = useState<TaxiRideEntity[]>([]);
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [merchants, setMerchants] = useState<MerchantEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Filter State
  const [reportType, setReportType] = useState<'executive' | 'revenue' | 'captains' | 'merchants' | 'operations'>('executive');
  const [timePreset, setTimePreset] = useState<'today' | 'week' | 'month' | 'custom'>('month');
  const [startDate, setStartDate] = useState<string>(() => {
    const d = new Date();
    d.setDate(d.getDate() - 30);
    return d.toISOString().slice(0, 10);
  });
  const [endDate, setEndDate] = useState<string>(() => new Date().toISOString().slice(0, 10));
  const [searchFilter, setSearchFilter] = useState('');
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const printAreaRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setIsLoading(true);

    const unsubOrders = OrdersRepository.subscribeToAllOrders((data) => {
      setOrders(data);
    });

    const unsubRides = TaxiRepository.subscribeToTaxiRides((data) => {
      setRides(data);
    });

    const unsubDrivers = DriversRepository.subscribeToDrivers((data) => {
      setDrivers(data);
    });

    const unsubMerchants = MerchantsRepository.subscribeToMerchants((data) => {
      setMerchants(data);
      setIsLoading(false);
    });

    return () => {
      unsubOrders();
      unsubRides();
      unsubDrivers();
      unsubMerchants();
    };
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 4000);
  };

  const formatIqd = (val: number) => {
    return new Intl.NumberFormat('ar-IQ').format(Math.round(val)) + ' د.ع';
  };

  // Compute Time Range Timestamps
  const { startTs, endTs, periodLabel } = useMemo(() => {
    const now = new Date();
    let s = 0;
    let e = now.getTime();
    let label = 'آخر 30 يوماً';

    if (timePreset === 'today') {
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      s = todayStart.getTime();
      label = `اليوم (${todayStart.toLocaleDateString('ar-IQ')})`;
    } else if (timePreset === 'week') {
      s = now.getTime() - 7 * 24 * 60 * 60 * 1000;
      label = 'آخر 7 أيام (تقرير أسبوعي)';
    } else if (timePreset === 'month') {
      s = now.getTime() - 30 * 24 * 60 * 60 * 1000;
      label = 'آخر 30 يوماً (تقرير شهري)';
    } else if (timePreset === 'custom') {
      s = new Date(startDate).getTime();
      const endD = new Date(endDate);
      endD.setHours(23, 59, 59, 999);
      e = endD.getTime();
      label = `من ${startDate} إلى ${endDate}`;
    }

    return { startTs: s, endTs: e, periodLabel: label };
  }, [timePreset, startDate, endDate]);

  // Filter Orders in Period
  const filteredOrders = useMemo(() => {
    return orders.filter(o => {
      const t = new Date(o.createdAt).getTime();
      return t >= startTs && t <= endTs;
    });
  }, [orders, startTs, endTs]);

  // Filter Taxi Rides in Period
  const filteredRides = useMemo(() => {
    return rides.filter(r => {
      return r.createdTimestamp >= startTs && r.createdTimestamp <= endTs;
    });
  }, [rides, startTs, endTs]);

  // ─── AGGREGATED METRICS COMPUTATION ───
  const metrics = useMemo(() => {
    // 1. Food & Store Orders
    const foodOrders = filteredOrders.filter(o => o.sourceType === 'food_delivery');
    const storeOrders = filteredOrders.filter(o => o.sourceType === 'store_delivery');
    const mersalOrders = filteredOrders.filter(o => o.sourceType === 'mersal_delivery');

    const completedOrders = filteredOrders.filter(o => o.rawStatus.includes('deliver') || o.rawStatus.includes('complet') || o.status.includes('تم') || o.status.includes('مكتمل'));
    const cancelledOrders = filteredOrders.filter(o => o.rawStatus.includes('cancel') || o.rawStatus.includes('reject') || o.status.includes('ملغي'));

    const foodSalesGmv = foodOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const storeSalesGmv = storeOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const mersalSalesGmv = mersalOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);

    const foodCommission = foodOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round(o.totalPriceIqd * 0.1)), 0);
    const storeCommission = storeOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round(o.totalPriceIqd * 0.07)), 0);
    const mersalCommission = mersalOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round(o.totalPriceIqd * 0.15)), 0);

    // 2. Taxi Rides
    const completedRides = filteredRides.filter(r => r.status === 'completed');
    const cancelledRides = filteredRides.filter(r => r.status === 'cancelled');

    const taxiGmv = completedRides.reduce((sum, r) => sum + (r.fareIqd || 0), 0);
    const taxiCommission = completedRides.reduce((sum, r) => sum + (r.commissionIqd || 0), 0);
    const taxiDriverNet = completedRides.reduce((sum, r) => sum + (r.driverNetIqd || 0), 0);

    // 3. Totals
    const totalSystemGmv = foodSalesGmv + storeSalesGmv + mersalSalesGmv + taxiGmv;
    const totalPlatformCommission = foodCommission + storeCommission + mersalCommission + taxiCommission;
    const totalOperationsCount = filteredOrders.length + filteredRides.length;
    const totalCompletedOperations = completedOrders.length + completedRides.length;
    const totalCancelledOperations = cancelledOrders.length + cancelledRides.length;
    const successRate = totalOperationsCount > 0 ? ((totalCompletedOperations / totalOperationsCount) * 100).toFixed(1) : '100';

    return {
      totalSystemGmv,
      totalPlatformCommission,
      totalOperationsCount,
      totalCompletedOperations,
      totalCancelledOperations,
      successRate,
      foodSalesGmv,
      foodCommission,
      storeSalesGmv,
      storeCommission,
      mersalSalesGmv,
      mersalCommission,
      taxiGmv,
      taxiCommission,
      taxiDriverNet,
      foodOrdersCount: foodOrders.length,
      storeOrdersCount: storeOrders.length,
      mersalOrdersCount: mersalOrders.length,
      taxiRidesCount: filteredRides.length
    };
  }, [filteredOrders, filteredRides]);

  // ─── CAPTAINS PERFORMANCE REPORT DATA ───
  const captainsReport = useMemo(() => {
    return drivers.map(d => {
      const driverOrders = filteredOrders.filter(o => o.driverId === d.driverId || o.driverPhone === d.phoneNumber || (d.name && o.driverName && o.driverName.includes(d.name)));
      const driverRides = filteredRides.filter(r => r.driverId === d.driverId || r.driverPhone === d.phoneNumber || (d.name && r.driverName && r.driverName.includes(d.name)));

      const totalTrips = driverOrders.length + driverRides.length;
      const completedTrips = driverOrders.filter(o => o.rawStatus.includes('deliver') || o.rawStatus.includes('complet')).length + driverRides.filter(r => r.status === 'completed').length;
      
      const ordersGmv = driverOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
      const ridesGmv = driverRides.reduce((sum, r) => sum + (r.fareIqd || 0), 0);
      const totalGmv = ordersGmv + ridesGmv;

      const ordersCommission = driverOrders.reduce((sum, o) => sum + (o.commissionIqd || 0), 0);
      const ridesCommission = driverRides.reduce((sum, r) => sum + (r.commissionIqd || 0), 0);
      const totalCommission = ordersCommission + ridesCommission;

      const netEarnings = Math.max(0, totalGmv - totalCommission);

      return {
        driverId: d.driverId,
        name: d.name,
        phone: d.phoneNumber,
        vehicleModel: d.vehicleModel,
        plateNumber: d.plateNumber,
        serviceType: d.serviceType || 'كابتن توصيل وتكسي',
        walletBalance: d.walletBalance || 0,
        appDebt: d.appDebt || 0,
        rating: d.rating || 5.0,
        totalTrips,
        completedTrips,
        totalGmv,
        totalCommission,
        netEarnings
      };
    }).sort((a, b) => b.completedTrips - a.completedTrips);
  }, [drivers, filteredOrders, filteredRides]);

  // ─── MERCHANTS & STORES SALES REPORT DATA ───
  const merchantsReport = useMemo(() => {
    return merchants.map(m => {
      const mId = m.merchantId;
      const mName = m.name.trim().toLowerCase();
      const mPhone = (m.phone || '').trim();

      const matchedOrders = filteredOrders.filter(o => {
        const oId = o.merchantId;
        const oTitle = (o.merchantOrTitle || '').trim().toLowerCase();
        const oPhone = (o.merchantPhone || '').trim();
        return (
          (oId && oId === mId) ||
          (oTitle && (oTitle === mName || oTitle.includes(mName) || mName.includes(oTitle))) ||
          (mPhone && oPhone && oPhone.length > 5 && (oPhone === mPhone || mPhone.includes(oPhone)))
        );
      });

      const totalOrdersCount = matchedOrders.length;
      const completedOrders = matchedOrders.filter(o => o.rawStatus.includes('deliver') || o.rawStatus.includes('complet'));
      const totalSalesGmv = matchedOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
      const commissionRate = m.commissionRate || (m.category === 'restaurant' ? 10 : 7);
      const totalCommission = matchedOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round((o.totalPriceIqd || 0) * (commissionRate / 100))), 0);
      const merchantNet = Math.max(0, totalSalesGmv - totalCommission);

      return {
        merchantId: m.merchantId,
        name: m.name,
        category: m.category === 'restaurant' ? 'مطعم ' : 'متجر ',
        subCategory: m.subCategory || 'عام',
        ownerName: m.ownerName,
        phone: m.phone,
        address: m.address || 'القائم',
        commissionRate,
        totalOrdersCount,
        completedOrdersCount: completedOrders.length,
        totalSalesGmv,
        totalCommission,
        merchantNet
      };
    }).sort((a, b) => b.totalSalesGmv - a.totalSalesGmv);
  }, [merchants, filteredOrders]);

  // ─── PRINT TO PDF ───
  const handlePrintPdf = () => {
    window.print();
  };

  // ─── EXPORT CSV ───
  const handleExportCsv = () => {
    let headers: string[] = [];
    let rows: any[][] = [];
    let filename = `madar_report_${reportType}_${timePreset}_${new Date().toISOString().slice(0, 10)}.csv`;

    if (reportType === 'captains') {
      headers = ['اسم الكابتن', 'رقم الهاتف', 'المركبة واللوحة', 'إجمالي الطلبات', 'الطلبات المكتملة', 'إجمالي الإيرادات (د.ع)', 'عمولة مدار (د.ع)', 'صافي ربح الكابتن (د.ع)', 'ديون التطبيق (د.ع)', 'التقييم'];
      rows = captainsReport.map(c => [
        `"${c.name}"`,
        `"${c.phone}"`,
        `"${c.vehicleModel} (${c.plateNumber})"`,
        c.totalTrips,
        c.completedTrips,
        c.totalGmv,
        c.totalCommission,
        c.netEarnings,
        c.appDebt,
        c.rating
      ]);
    } else if (reportType === 'merchants') {
      headers = ['اسم المتجر / المطعم', 'التصنيف', 'المالك', 'الهاتف', 'نسبة العمولة %', 'عدد الطلبات', 'الطلبات المكتملة', 'إجمالي المبيعات GMV (د.ع)', 'عمولة مدار (د.ع)', 'صافي مستحقات المتجر (د.ع)'];
      rows = merchantsReport.map(m => [
        `"${m.name}"`,
        `"${m.category} - ${m.subCategory}"`,
        `"${m.ownerName}"`,
        `"${m.phone}"`,
        `${m.commissionRate}%`,
        m.totalOrdersCount,
        m.completedOrdersCount,
        m.totalSalesGmv,
        m.totalCommission,
        m.merchantNet
      ]);
    } else {
      headers = ['البيان / المؤشر', 'القيمة بالدينار العراقي / العدد'];
      rows = [
        ['إجمالي حجم التداول المالي (GMV)', metrics.totalSystemGmv],
        ['إجمالي أرباح وعمولة منصة مدار', metrics.totalPlatformCommission],
        ['إجمالي عدد العمليات والطلبات', metrics.totalOperationsCount],
        ['العمليات المكتملة بنجاح', metrics.totalCompletedOperations],
        ['العمليات الملغاة', metrics.totalCancelledOperations],
        ['نسبة نجاح العمليات', `${metrics.successRate}%`],
        ['مبيعات المطاعم', metrics.foodSalesGmv],
        ['عمولة المطاعم', metrics.foodCommission],
        ['مبيعات المتاجر والسوبرماركت', metrics.storeSalesGmv],
        ['عمولة المتاجر', metrics.storeCommission],
        ['إيرادات تكسي مدار', metrics.taxiGmv],
        ['عمولة تكسي مدار', metrics.taxiCommission],
        ['إيرادات مرسال وتوصيل الطرود', metrics.mersalSalesGmv],
        ['عمولة مرسال', metrics.mersalCommission]
      ];
    }

    const csvContent = 'data:text/csv;charset=utf-8,\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير ملف التقرير CSV بنجاح ');
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {toast && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: toast.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {toast.msg}
        </div>
      )}

      {/* ─── PRINT-ONLY STYLES ─── */}
      <style>{`
        @media print {
          body {
            background: #ffffff !important;
            color: #000000 !important;
          }
          aside, header, nav, .no-print, button, select, input {
            display: none !important;
          }
          .print-container {
            padding: 0 !important;
            margin: 0 !important;
            background: #ffffff !important;
            color: #000000 !important;
            width: 100% !important;
          }
          .print-header {
            display: block !important;
            border-bottom: 2px solid #000000 !important;
            padding-bottom: 12px !important;
            margin-bottom: 20px !important;
          }
          .glass-panel {
            background: #ffffff !important;
            border: 1px solid #cccccc !important;
            box-shadow: none !important;
            color: #000000 !important;
          }
          .data-table {
            color: #000000 !important;
            border: 1px solid #000000 !important;
          }
          .data-table th {
            background: #f1f5f9 !important;
            color: #000000 !important;
            border: 1px solid #000000 !important;
            font-weight: bold !important;
          }
          .data-table td {
            border: 1px solid #cccccc !important;
            color: #000000 !important;
          }
          .print-signature-block {
            display: flex !important;
            justify-content: space-between !important;
            margin-top: 40px !important;
            padding-top: 20px !important;
            border-top: 1px solid #000000 !important;
          }
        }
        .print-header {
          display: none;
        }
        .print-signature-block {
          display: none;
        }
      `}</style>

      {/* Top Controls (Screen View) */}
      <div className="no-print" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '14px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'linear-gradient(135deg, #06b6d4, #0284c7)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <BarChart3 size={22} />
            </div>
            <span>مركز التقارير والإحصائيات الشاملة (Analytics & Reports)</span>
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            تقارير يومية وأسبوعية، أداء الكباتن، مبيعات المتاجر، ونسبة أرباح التطبيق مع إمكانية طباعة PDF وتصدير Excel
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            onClick={handlePrintPdf}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '800', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8' }}
          >
            <Printer size={16} /> طباعة التقرير PDF 
          </button>
          <button
            onClick={handleExportCsv}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '700' }}
          >
            <Download size={15} /> تصدير كشف CSV
          </button>
        </div>
      </div>

      {/* ─── TIME & CATEGORY SELECTORS (Screen View) ─── */}
      <div className="glass-panel no-print" style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
        
        {/* Report Type Tabs */}
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '4px' }}>
          <button
            onClick={() => setReportType('executive')}
            className={`btn ${reportType === 'executive' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <FileText size={14} /> التقرير الإداري الشامل
          </button>
          <button
            onClick={() => setReportType('revenue')}
            className={`btn ${reportType === 'revenue' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <DollarSign size={14} /> أرباح وعمولات التطبيق
          </button>
          <button
            onClick={() => setReportType('captains')}
            className={`btn ${reportType === 'captains' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Car size={14} /> تقارير أداء الكباتن ({captainsReport.length})
          </button>
          <button
            onClick={() => setReportType('merchants')}
            className={`btn ${reportType === 'merchants' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Store size={14} /> مبيعات المتاجر والمطاعم ({merchantsReport.length})
          </button>
          <button
            onClick={() => setReportType('operations')}
            className={`btn ${reportType === 'operations' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <ShoppingBag size={14} /> حركة الطلبات والعمليات
          </button>
        </div>

        {/* Time Period Presets */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px', borderTop: '1px solid var(--border-color)', paddingTop: '12px' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: '700' }}>الفترة الزمنية:</span>
            <button
              onClick={() => setTimePreset('today')}
              className={`btn ${timePreset === 'today' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '11.5px', padding: '5px 12px' }}
            >
               تقرير اليوم
            </button>
            <button
              onClick={() => setTimePreset('week')}
              className={`btn ${timePreset === 'week' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '11.5px', padding: '5px 12px' }}
            >
               تقرير أسبوعي
            </button>
            <button
              onClick={() => setTimePreset('month')}
              className={`btn ${timePreset === 'month' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '11.5px', padding: '5px 12px' }}
            >
               تقرير شهري
            </button>
            <button
              onClick={() => setTimePreset('custom')}
              className={`btn ${timePreset === 'custom' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '11.5px', padding: '5px 12px' }}
            >
               نطاق مخصص
            </button>
          </div>

          {/* Custom Date Inputs */}
          {timePreset === 'custom' && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-dim)' }}>من:</span>
              <input
                type="date"
                value={startDate}
                onChange={e => setStartDate(e.target.value)}
                style={{ padding: '6px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '6px', color: '#fff', fontSize: '12px' }}
              />
              <span style={{ fontSize: '12px', color: 'var(--text-dim)' }}>إلى:</span>
              <input
                type="date"
                value={endDate}
                onChange={e => setEndDate(e.target.value)}
                style={{ padding: '6px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '6px', color: '#fff', fontSize: '12px' }}
              />
            </div>
          )}

        </div>

      </div>

      {/* ─── PRINT CONTAINER (RENDERED ON SCREEN & IN PRINT) ─── */}
      <div ref={printAreaRef} className="print-container" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        
        {/* Official Print Header (Only appears when printing to PDF) */}
        <div className="print-header">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h1 style={{ fontSize: '22px', fontWeight: '900', color: '#000', margin: 0 }}>منظومة مدار — MADAR LOGISTICS</h1>
              <div style={{ fontSize: '13px', color: '#475569', marginTop: '3px' }}>إدارة العمليات والرقابة المركزية • قضاء القائم - الأنبار</div>
            </div>
            <div style={{ textAlign: 'left' }}>
              <div style={{ fontSize: '16px', fontWeight: '900', color: '#0284c7' }}>
                {reportType === 'executive' ? 'التقرير الإداري الشامل' : reportType === 'revenue' ? 'تقرير الإيرادات وعمولات التطبيق' : reportType === 'captains' ? 'تقرير أداء وحسابات الكباتن' : reportType === 'merchants' ? 'تقرير مبيعات المتاجر والمطاعم' : 'تقرير حركة الطلبات والعمليات'}
              </div>
              <div style={{ fontSize: '11px', color: '#64748b' }}>
                الفترة: {periodLabel} | تاريخ الإصدار: {new Date().toLocaleDateString('ar-IQ')} {new Date().toLocaleTimeString('ar-IQ')}
              </div>
            </div>
          </div>
        </div>

        {/* ─── 4 MAIN FINANCIAL SUMMARY CARDS ─── */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
          
          <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(6, 182, 212, 0.1) 0%, rgba(15, 23, 42, 0.6) 100%)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي حجم التداول (GMV)</span>
              <Coins size={18} color="#06b6d4" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#fff', marginTop: '6px' }}>
              {formatIqd(metrics.totalSystemGmv)}
            </div>
            <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '3px' }}>
              عبر {metrics.totalOperationsCount} عملية خلال ({periodLabel})
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(15, 23, 42, 0.6) 100%)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>صافي أرباح وعمولة مدار</span>
              <TrendingUp size={18} color="#34d399" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
              {formatIqd(metrics.totalPlatformCommission)}
            </div>
            <div style={{ fontSize: '11px', color: '#6ee7b7', marginTop: '3px' }}>
              إيرادات التطبيق الصافية المستقطعة
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>العمليات المنجزة بنجاح</span>
              <CheckCircle2 size={18} color="#38bdf8" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#38bdf8', marginTop: '6px' }}>
              {metrics.totalCompletedOperations} طلب / مشوار
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              نسبة نجاح الإنجاز: <span style={{ color: '#34d399', fontWeight: '800' }}>{metrics.successRate}%</span>
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إيرادات مشاوير التكسي</span>
              <Car size={18} color="#f59e0b" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#fbbf24', marginTop: '6px' }}>
              {formatIqd(metrics.taxiGmv)}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              عمولة التكسي: <span style={{ color: '#38bdf8' }}>{formatIqd(metrics.taxiCommission)}</span>
            </div>
          </div>

        </div>

        {/* ─── REPORT VIEW 1: EXECUTIVE OVERVIEW (التقرير الإداري الشامل) ─── */}
        {reportType === 'executive' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            
            {/* Revenue Breakdown by Domain */}
            <div className="glass-panel" style={{ padding: '20px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <PieChart size={17} color="#06b6d4" />
                <span>توزيع الإيرادات والعمولات حسب القطاعات ({periodLabel})</span>
              </h3>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '12px' }}>
                
                {/* Food */}
                <div style={{ padding: '14px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> قطاع المطاعم</span>
                    <span className="badge badge-warning" style={{ fontSize: '10px' }}>{metrics.foodOrdersCount} طلب</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#fbbf24', marginTop: '8px' }}>
                    {formatIqd(metrics.foodSalesGmv)}
                  </div>
                  <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '4px' }}>
                    عمولة مدار: {formatIqd(metrics.foodCommission)}
                  </div>
                </div>

                {/* Stores */}
                <div style={{ padding: '14px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> المتاجر والسوبرماركت</span>
                    <span className="badge badge-info" style={{ fontSize: '10px' }}>{metrics.storeOrdersCount} طلب</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#38bdf8', marginTop: '8px' }}>
                    {formatIqd(metrics.storeSalesGmv)}
                  </div>
                  <div style={{ fontSize: '11px', color: '#34d399', marginTop: '4px' }}>
                    عمولة مدار: {formatIqd(metrics.storeCommission)}
                  </div>
                </div>

                {/* Taxi */}
                <div style={{ padding: '14px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> رحلات التكسي</span>
                    <span className="badge badge-success" style={{ fontSize: '10px' }}>{metrics.taxiRidesCount} مشوار</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#34d399', marginTop: '8px' }}>
                    {formatIqd(metrics.taxiGmv)}
                  </div>
                  <div style={{ fontSize: '11px', color: '#fbbf24', marginTop: '4px' }}>
                    عمولة مدار: {formatIqd(metrics.taxiCommission)}
                  </div>
                </div>

                {/* Mersal */}
                <div style={{ padding: '14px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> مرسال وتوصيل الطرود</span>
                    <span className="badge badge-secondary" style={{ fontSize: '10px' }}>{metrics.mersalOrdersCount} طرد</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: '900', color: '#a78bfa', marginTop: '8px' }}>
                    {formatIqd(metrics.mersalSalesGmv)}
                  </div>
                  <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '4px' }}>
                    عمولة مدار: {formatIqd(metrics.mersalCommission)}
                  </div>
                </div>

              </div>
            </div>

            {/* Top 5 Captains & Top 5 Merchants */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              
              {/* Top Captains */}
              <div className="glass-panel" style={{ padding: '18px' }}>
                <h4 style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Award size={16} color="#fbbf24" /> أعلى 5 كباتن إنجازاً للرحلات
                </h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {captainsReport.slice(0, 5).map((c, idx) => (
                    <div key={c.driverId} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span style={{ width: '20px', height: '20px', borderRadius: '50%', background: idx === 0 ? '#f59e0b' : '#334155', color: '#fff', fontSize: '11px', fontWeight: '900', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          {idx + 1}
                        </span>
                        <div>
                          <div style={{ fontWeight: '800', color: '#fff', fontSize: '12.5px' }}>{c.name}</div>
                          <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>{c.vehicleModel}</div>
                        </div>
                      </div>
                      <div style={{ textAlign: 'left' }}>
                        <div style={{ fontWeight: '900', color: '#34d399', fontSize: '12.5px' }}>{c.completedTrips} رحلة</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>صافي: {formatIqd(c.netEarnings)}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Top Merchants */}
              <div className="glass-panel" style={{ padding: '18px' }}>
                <h4 style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Award size={16} color="#38bdf8" /> أعلى 5 متاجر ومطاعم تحقيقاً للمبيعات
                </h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {merchantsReport.slice(0, 5).map((m, idx) => (
                    <div key={m.merchantId} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span style={{ width: '20px', height: '20px', borderRadius: '50%', background: idx === 0 ? '#0284c7' : '#334155', color: '#fff', fontSize: '11px', fontWeight: '900', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          {idx + 1}
                        </span>
                        <div>
                          <div style={{ fontWeight: '800', color: '#fff', fontSize: '12.5px' }}>{m.name}</div>
                          <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>{m.category} • {m.completedOrdersCount} طلب</div>
                        </div>
                      </div>
                      <div style={{ textAlign: 'left' }}>
                        <div style={{ fontWeight: '900', color: '#38bdf8', fontSize: '12.5px' }}>{formatIqd(m.totalSalesGmv)}</div>
                        <div style={{ fontSize: '10px', color: '#34d399' }}>عمولة: {formatIqd(m.totalCommission)}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

            </div>

          </div>
        )}

        {/* ─── REPORT VIEW 2: REVENUE & COMMISSIONS (أرباح وعمولات التطبيق) ─── */}
        {reportType === 'revenue' && (
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', margin: 0 }}>
                 كشف أرباح ونسب عمولات منصة مدار المفصلة ({periodLabel})
              </h3>
              <span style={{ fontSize: '12px', color: '#34d399', fontWeight: '800' }}>
                الإجمالي الصافي: {formatIqd(metrics.totalPlatformCommission)}
              </span>
            </div>

            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>قطاع الخدمة</th>
                    <th>عدد العمليات</th>
                    <th>حجم التداول المالي (GMV)</th>
                    <th>متوسط نسبة العمولة</th>
                    <th>إجمالي عمولة مدار المحصلة </th>
                    <th>مستحقات الشركاء والكباتن الصافية</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td><span style={{ fontWeight: '800', color: '#fff' }}> طلبات المطاعم والمأكولات</span></td>
                    <td>{metrics.foodOrdersCount} طلب</td>
                    <td style={{ fontWeight: '800', color: '#fbbf24' }}>{formatIqd(metrics.foodSalesGmv)}</td>
                    <td>10.0%</td>
                    <td style={{ fontWeight: '900', color: '#34d399', fontSize: '13.5px' }}>{formatIqd(metrics.foodCommission)}</td>
                    <td style={{ color: '#cbd5e1' }}>{formatIqd(Math.max(0, metrics.foodSalesGmv - metrics.foodCommission))}</td>
                  </tr>
                  <tr>
                    <td><span style={{ fontWeight: '800', color: '#fff' }}> طلبات المتاجر والسوبرماركت</span></td>
                    <td>{metrics.storeOrdersCount} طلب</td>
                    <td style={{ fontWeight: '800', color: '#38bdf8' }}>{formatIqd(metrics.storeSalesGmv)}</td>
                    <td>7.0%</td>
                    <td style={{ fontWeight: '900', color: '#34d399', fontSize: '13.5px' }}>{formatIqd(metrics.storeCommission)}</td>
                    <td style={{ color: '#cbd5e1' }}>{formatIqd(Math.max(0, metrics.storeSalesGmv - metrics.storeCommission))}</td>
                  </tr>
                  <tr>
                    <td><span style={{ fontWeight: '800', color: '#fff' }}> مشاوير وتوصيل التكسي</span></td>
                    <td>{metrics.taxiRidesCount} مشوار</td>
                    <td style={{ fontWeight: '800', color: '#f59e0b' }}>{formatIqd(metrics.taxiGmv)}</td>
                    <td>12.0%</td>
                    <td style={{ fontWeight: '900', color: '#34d399', fontSize: '13.5px' }}>{formatIqd(metrics.taxiCommission)}</td>
                    <td style={{ color: '#cbd5e1' }}>{formatIqd(metrics.taxiDriverNet)}</td>
                  </tr>
                  <tr>
                    <td><span style={{ fontWeight: '800', color: '#fff' }}> خدمات مرسال والطرود الخاصة</span></td>
                    <td>{metrics.mersalOrdersCount} طرد</td>
                    <td style={{ fontWeight: '800', color: '#a78bfa' }}>{formatIqd(metrics.mersalSalesGmv)}</td>
                    <td>15.0%</td>
                    <td style={{ fontWeight: '900', color: '#34d399', fontSize: '13.5px' }}>{formatIqd(metrics.mersalCommission)}</td>
                    <td style={{ color: '#cbd5e1' }}>{formatIqd(Math.max(0, metrics.mersalSalesGmv - metrics.mersalCommission))}</td>
                  </tr>
                  <tr style={{ background: 'rgba(6, 182, 212, 0.1)', fontWeight: '900' }}>
                    <td style={{ color: '#fff', fontSize: '14px' }}>المجموع الكلي للمنظومة </td>
                    <td style={{ color: '#fff' }}>{metrics.totalOperationsCount} عملية</td>
                    <td style={{ color: '#fff', fontSize: '14px' }}>{formatIqd(metrics.totalSystemGmv)}</td>
                    <td>—</td>
                    <td style={{ color: '#34d399', fontSize: '16px' }}>{formatIqd(metrics.totalPlatformCommission)}</td>
                    <td style={{ color: '#38bdf8', fontSize: '14px' }}>{formatIqd(Math.max(0, metrics.totalSystemGmv - metrics.totalPlatformCommission))}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ─── REPORT VIEW 3: CAPTAINS PERFORMANCE (تقارير أداء الكباتن) ─── */}
        {reportType === 'captains' && (
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', margin: 0 }}>
                 كشف أداء وإيرادات أسطول الكباتن ({captainsReport.length} كابتن • {periodLabel})
              </h3>
            </div>

            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>اسم الكابتن</th>
                    <th>رقم الهاتف</th>
                    <th>المركبة واللوحة</th>
                    <th>الرحلات المنفذة</th>
                    <th>إجمالي الإيرادات GMV</th>
                    <th>عمولة مدار المستقطعة</th>
                    <th>صافي ربح الكابتن </th>
                    <th>ديون التطبيق المستحقة</th>
                    <th>التقييم </th>
                  </tr>
                </thead>
                <tbody>
                  {captainsReport.map((c, idx) => (
                    <tr key={c.driverId}>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{c.name}</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>#{c.driverId.slice(0, 6)}</div>
                      </td>
                      <td dir="ltr" style={{ fontSize: '12px' }}>{c.phone}</td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#cbd5e1' }}>{c.vehicleModel}</div>
                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>{c.plateNumber || 'بدون لوحة'}</div>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{c.completedTrips} مكتملة</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>من {c.totalTrips} طلب</div>
                      </td>
                      <td style={{ fontWeight: '800', color: '#fbbf24' }}>{formatIqd(c.totalGmv)}</td>
                      <td style={{ color: '#38bdf8' }}>{formatIqd(c.totalCommission)}</td>
                      <td style={{ fontWeight: '900', color: '#34d399', fontSize: '13px' }}>{formatIqd(c.netEarnings)}</td>
                      <td>
                        <span style={{ color: c.appDebt > 0 ? '#f87171' : '#94a3b8', fontWeight: c.appDebt > 0 ? '800' : 'normal' }}>
                          {formatIqd(c.appDebt)}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                          <Star size={13} color="#facc15" fill="#facc15" />
                          <span style={{ fontWeight: '800', color: '#facc15', fontSize: '12px' }}>{c.rating}</span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ─── REPORT VIEW 4: MERCHANTS SALES (مبيعات المتاجر والمطاعم) ─── */}
        {reportType === 'merchants' && (
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', margin: 0 }}>
                 كشف مبيعات وعمولات المتاجر والمطاعم ({merchantsReport.length} شريك • {periodLabel})
              </h3>
            </div>

            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>اسم المتجر / المطعم</th>
                    <th>النوع والتصنيف</th>
                    <th>المالك ورقم الهاتف</th>
                    <th>نسبة العمولة</th>
                    <th>عدد الطلبات</th>
                    <th>إجمالي المبيعات (GMV) </th>
                    <th>عمولة مدار المحصلة</th>
                    <th>صافي مستحقات التاجر </th>
                  </tr>
                </thead>
                <tbody>
                  {merchantsReport.map((m) => (
                    <tr key={m.merchantId}>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{m.name}</div>
                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}> {m.address}</div>
                      </td>
                      <td>
                        <span className={`badge ${m.category.includes('مطعم') ? 'badge-warning' : 'badge-info'}`} style={{ fontSize: '10.5px' }}>
                          {m.category}
                        </span>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)', marginTop: '2px' }}>{m.subCategory}</div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#fff' }}>{m.ownerName}</div>
                        <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{m.phone}</div>
                      </td>
                      <td style={{ fontWeight: '800', color: '#38bdf8' }}>{m.commissionRate}%</td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{m.completedOrdersCount} مكتمل</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>إجمالي: {m.totalOrdersCount}</div>
                      </td>
                      <td style={{ fontWeight: '900', color: '#fbbf24', fontSize: '13.5px' }}>{formatIqd(m.totalSalesGmv)}</td>
                      <td style={{ color: '#38bdf8', fontWeight: '700' }}>{formatIqd(m.totalCommission)}</td>
                      <td style={{ fontWeight: '900', color: '#34d399', fontSize: '13.5px' }}>{formatIqd(m.merchantNet)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ─── REPORT VIEW 5: OPERATIONS & ORDERS FLOW (حركة الطلبات والعمليات) ─── */}
        {reportType === 'operations' && (
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ fontSize: '15px', fontWeight: '800', color: '#fff', margin: 0 }}>
                 سجل تفاصيل حركة الطلبات والعمليات ({filteredOrders.length + filteredRides.length} سجل • {periodLabel})
              </h3>
            </div>

            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>رقم العملية والتاريخ</th>
                    <th>النوع والخدمة</th>
                    <th>العميل / الراكب</th>
                    <th>المتجر أو مسار المشوار</th>
                    <th>الكابتن المكلف</th>
                    <th>المبلغ الإجمالي</th>
                    <th>عمولة مدار</th>
                    <th>الحالة</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredOrders.slice(0, 100).map(o => (
                    <tr key={o.orderId}>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff', fontSize: '12px' }}>#{o.orderId.slice(0, 8).toUpperCase()}</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>{new Date(o.createdAt).toLocaleDateString('ar-IQ')}</div>
                      </td>
                      <td>
                        <span className={`badge ${o.sourceType === 'food_delivery' ? 'badge-warning' : o.sourceType === 'store_delivery' ? 'badge-info' : 'badge-secondary'}`} style={{ fontSize: '10px' }}>
                          {o.sourceType === 'food_delivery' ? 'مطاعم ' : o.sourceType === 'store_delivery' ? 'متاجر ' : 'مرسال '}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '700', color: '#fff', fontSize: '12px' }}>{o.customerName}</div>
                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }} dir="ltr">{o.customerPhone}</div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#cbd5e1' }}>{o.merchantOrTitle}</div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: o.driverName ? '#fff' : 'var(--text-muted)' }}>
                          {o.driverName || 'غير مسند'}
                        </div>
                      </td>
                      <td style={{ fontWeight: '800', color: '#34d399' }}>{formatIqd(o.totalPriceIqd)}</td>
                      <td style={{ color: '#38bdf8' }}>{formatIqd(o.commissionIqd || 0)}</td>
                      <td>
                        <span className="badge badge-success" style={{ fontSize: '10px' }}>{o.status}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ─── OFFICIAL PRINT SIGNATURE BLOCK (Appears on Printed PDF) ─── */}
        <div className="print-signature-block">
          <div style={{ textAlign: 'center', width: '200px' }}>
            <div style={{ fontSize: '13px', fontWeight: 'bold' }}>المشرف المالي / المدقق</div>
            <div style={{ height: '60px' }}></div>
            <div style={{ borderTop: '1px dotted #000', paddingTop: '4px', fontSize: '12px' }}>التوقيع والتاريخ</div>
          </div>

          <div style={{ textAlign: 'center', width: '200px' }}>
            <div style={{ fontSize: '13px', fontWeight: 'bold' }}>مدير إدارة العمليات</div>
            <div style={{ height: '60px' }}></div>
            <div style={{ borderTop: '1px dotted #000', paddingTop: '4px', fontSize: '12px' }}>التوقيع والاعتماد</div>
          </div>

          <div style={{ textAlign: 'center', width: '200px' }}>
            <div style={{ fontSize: '13px', fontWeight: 'bold' }}>ختم الإدارة العامة (مدار)</div>
            <div style={{ height: '60px', border: '1px dashed #cbd5e1', margin: '6px 0', borderRadius: '8px' }}></div>
          </div>
        </div>

      </div>

    </div>
  );
};
