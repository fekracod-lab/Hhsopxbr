import React, { useState, useEffect, useMemo } from 'react';
import { 
  ShoppingBag, 
  Search, 
  Package, 
  Clock, 
  CheckCircle, 
  Car, 
  Loader2, 
  RefreshCw,
  Utensils,
  Store,
  Navigation,
  Send,
  Phone,
  MapPin,
  User,
  DollarSign,
  Printer,
  X,
  ChevronDown,
  AlertTriangle,
  Trash2,
  Filter,
  Download,
  Calendar,
  CheckCircle2,
  XCircle,
  ExternalLink,
  SlidersHorizontal,
  LayoutGrid,
  List,
  Mail,
  Wallet,
  Star,
  ShieldCheck,
  Compass,
  MessageCircle,
  Copy,
  Info,
  TrendingUp,
  Tag,
  Receipt,
  Flame,
  ArrowRightLeft
} from 'lucide-react';
import { OrdersRepository, AdminOrderRecord, OrderItemDetail } from '../../infrastructure/repositories/OrdersRepository';
import { DriversRepository } from '../../infrastructure/repositories/DriversRepository';
import { CustomersRepository, CustomerEntity } from '../../infrastructure/repositories/CustomersRepository';
import { MerchantsRepository } from '../../infrastructure/repositories/MerchantsRepository';
import { DriverEntity, MerchantEntity } from '../../domain/types';
import { OfficialInvoiceModal, OfficialInvoiceData, InvoiceItem } from '../components/OfficialInvoiceModal';

export const OrdersModule: React.FC = () => {
  const [orders, setOrders] = useState<AdminOrderRecord[]>([]);
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [customers, setCustomers] = useState<CustomerEntity[]>([]);
  const [merchants, setMerchants] = useState<MerchantEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Official PDF Invoice Modal State
  const [activeInvoiceData, setActiveInvoiceData] = useState<OfficialInvoiceData | null>(null);

  // Main Domain Section (فصل تام بين المطاعم والمتاجر وبين التكسي ومرسال)
  const [mainDomain, setMainDomain] = useState<'food_stores' | 'taxi_rides' | 'mersal' | 'cancelled_purge'>('food_stores');

  // Sub-Filters within the active Domain
  const [subStatusFilter, setSubStatusFilter] = useState<'all' | 'active' | 'delivered' | 'cancelled'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [paymentFilter, setPaymentFilter] = useState<'all' | 'cash' | 'wallet'>('all');
  const [dateFilter, setDateFilter] = useState<'all' | 'today' | 'week' | 'month'>('all');
  const [sortBy, setSortBy] = useState<'newest' | 'oldest' | 'highest_price' | 'lowest_price'>('newest');
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');

  // Selected Order Deep-Dive Modal
  const [selectedOrder, setSelectedOrder] = useState<AdminOrderRecord | null>(null);
  const [isAssigningDriver, setIsAssigningDriver] = useState(false);
  const [selectedDriverIdToAssign, setSelectedDriverIdToAssign] = useState('');
  
  // Cancel Order Modal
  const [cancellingOrder, setCancellingOrder] = useState<AdminOrderRecord | null>(null);
  const [cancellationReason, setCancellationReason] = useState('');

  // Bulk Selection
  const [selectedOrderIds, setSelectedOrderIds] = useState<string[]>([]);
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Print Receipt State
  const [isPrinting, setIsPrinting] = useState(false);

  useEffect(() => {
    setIsLoading(true);
    const unsubOrders = OrdersRepository.subscribeToAllOrders((data) => {
      setOrders(data);
      setIsLoading(false);

      if (selectedOrder) {
        const updated = data.find(o => o.orderId === selectedOrder.orderId);
        if (updated) setSelectedOrder(updated);
      }
    });

    const unsubDrivers = DriversRepository.subscribeToDrivers((driverData) => {
      setDrivers(driverData);
    });

    const unsubCustomers = CustomersRepository.subscribeToCustomers((custData) => {
      setCustomers(custData);
    });

    const unsubMerchants = MerchantsRepository.subscribeToMerchants((merchData) => {
      setMerchants(merchData);
    });

    return () => {
      unsubOrders();
      unsubDrivers();
      unsubCustomers();
      unsubMerchants();
    };
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 4000);
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    showToast(`تم نسخ ${label} إلى الحافظة `);
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(Math.round(amount)) + ' د.ع';
  };

  const formatDateTime = (dateStr: string) => {
    try {
      const dt = new Date(dateStr);
      return dt.toLocaleDateString('ar-IQ', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return dateStr;
    }
  };

  const openOfficialInvoiceForOrder = (order: AdminOrderRecord) => {
    const isFood = order.sourceType === 'food_delivery';
    const subtotal = Math.max(0, order.totalPriceIqd - (order.deliveryFeeIqd || 0) + (order.discountIqd || 0));
    const invoiceItems: InvoiceItem[] = (order.itemsList && order.itemsList.length > 0)
      ? order.itemsList.map(item => ({
          name: item.name,
          quantity: item.quantity,
          unitPrice: item.price,
          totalPrice: item.price * item.quantity,
          notes: item.options?.join(' • ')
        }))
      : [{
          name: order.itemsSummary || 'طلب وجبة / سلع متنوعة',
          quantity: 1,
          unitPrice: subtotal,
          totalPrice: subtotal
        }];

    const invData: OfficialInvoiceData = {
      documentNumber: `MADAR-INV-${order.orderId.substring(0, 8).toUpperCase()}`,
      documentType: 'order',
      documentTitle: isFood ? 'فاتورة طلب وجبة طعام رسمية' : 'فاتورة طلب تسوق وسلع تجارية',
      date: new Date(order.createdAt).toLocaleDateString('ar-IQ', { year: 'numeric', month: 'long', day: 'numeric' }),
      time: new Date(order.createdAt).toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' }),
      customerName: order.customerName || 'عميل مدار',
      customerPhone: order.customerPhone,
      customerAddress: order.deliveryAddress,
      providerName: order.merchantOrTitle || 'الشريك التجاري',
      providerRole: isFood ? 'مطعم شريك' : 'متجر شريك',
      items: invoiceItems,
      subtotalIqd: subtotal,
      deliveryFeeIqd: order.deliveryFeeIqd || 0,
      discountIqd: order.discountIqd || 0,
      totalIqd: order.totalPriceIqd,
      paymentMethod: order.paymentMethod || 'كاش عند الاستلام',
      paymentStatus: 'paid',
      notes: order.customerNotes
    };

    setActiveInvoiceData(invData);
  };

  const getRelativeTime = (dateStr: string) => {
    try {
      const diffMs = Date.now() - new Date(dateStr).getTime();
      const diffMins = Math.floor(diffMs / (1000 * 60));
      if (diffMins < 1) return 'الآن';
      if (diffMins < 60) return `منذ ${diffMins} دقيقة`;
      const diffHours = Math.floor(diffMins / 60);
      if (diffHours < 24) return `منذ ${diffHours} ساعة`;
      const diffDays = Math.floor(diffHours / 24);
      return `منذ ${diffDays} يوم`;
    } catch {
      return '';
    }
  };

  // Cross-reference matched entities for deep resolution
  const getMatchedCustomer = (order: AdminOrderRecord): CustomerEntity | undefined => {
    return customers.find(c => 
      (order.customerId && c.uid === order.customerId) ||
      (order.customerPhone && c.phone === order.customerPhone) ||
      (c.name.trim().toLowerCase() === order.customerName.trim().toLowerCase())
    );
  };

  const getMatchedMerchant = (order: AdminOrderRecord): MerchantEntity | undefined => {
    return merchants.find(m => 
      (order.merchantId && m.merchantId === order.merchantId) ||
      (m.name.trim().toLowerCase() === order.merchantOrTitle.trim().toLowerCase())
    );
  };

  const getMatchedDriver = (order: AdminOrderRecord): DriverEntity | undefined => {
    return drivers.find(d => 
      (order.driverId && d.driverId === order.driverId) ||
      (order.driverPhone && d.phoneNumber === order.driverPhone) ||
      (order.driverName && d.name.trim().toLowerCase() === order.driverName.trim().toLowerCase())
    );
  };

  // Split Orders strictly by Domain
  const domainOrders = useMemo(() => {
    return orders.filter(o => {
      if (mainDomain === 'food_stores') {
        return o.sourceType === 'food_delivery' || o.sourceType === 'store_delivery';
      }
      if (mainDomain === 'taxi_rides') {
        return o.sourceType === 'taxi_ride';
      }
      if (mainDomain === 'mersal') {
        return o.sourceType === 'mersal_delivery';
      }
      if (mainDomain === 'cancelled_purge') {
        return o.rawStatus.includes('cancel') || o.rawStatus.includes('reject');
      }
      return true;
    });
  }, [orders, mainDomain]);

  // Filter & Sort Logic for Active Domain
  const filteredOrders = useMemo(() => {
    return domainOrders.filter(o => {
      // 1. Search Query
      const q = searchQuery.toLowerCase().trim();
      const matchesSearch = !q || 
        o.orderId.toLowerCase().includes(q) ||
        o.merchantOrTitle.toLowerCase().includes(q) ||
        o.customerName.toLowerCase().includes(q) ||
        (o.customerPhone && o.customerPhone.includes(q)) ||
        (o.driverName && o.driverName.toLowerCase().includes(q)) ||
        (o.deliveryAddress && o.deliveryAddress.toLowerCase().includes(q)) ||
        (o.itemsSummary && o.itemsSummary.toLowerCase().includes(q));

      if (!matchesSearch) return false;

      // 2. Status Filter
      if (mainDomain !== 'cancelled_purge') {
        const isDelivered = o.rawStatus.includes('deliver') || o.rawStatus.includes('complete') || o.rawStatus === 'done';
        const isCancelled = o.rawStatus.includes('cancel') || o.rawStatus.includes('reject');
        const isActive = !isDelivered && !isCancelled;

        if (subStatusFilter === 'active' && !isActive) return false;
        if (subStatusFilter === 'delivered' && !isDelivered) return false;
        if (subStatusFilter === 'cancelled' && !isCancelled) return false;
      }

      // 3. Payment Filter
      if (paymentFilter === 'cash' && o.paymentMethod && !o.paymentMethod.toLowerCase().includes('cash')) return false;
      if (paymentFilter === 'wallet' && (!o.paymentMethod || !o.paymentMethod.toLowerCase().includes('wallet'))) return false;

      // 4. Date Filter
      if (dateFilter !== 'all') {
        const orderDate = new Date(o.createdAt).getTime();
        const now = Date.now();
        const oneDay = 24 * 60 * 60 * 1000;
        if (dateFilter === 'today' && now - orderDate > oneDay) return false;
        if (dateFilter === 'week' && now - orderDate > 7 * oneDay) return false;
        if (dateFilter === 'month' && now - orderDate > 30 * oneDay) return false;
      }

      return true;
    }).sort((a, b) => {
      if (sortBy === 'newest') return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      if (sortBy === 'oldest') return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
      if (sortBy === 'highest_price') return b.totalPriceIqd - a.totalPriceIqd;
      if (sortBy === 'lowest_price') return a.totalPriceIqd - b.totalPriceIqd;
      return 0;
    });
  }, [domainOrders, searchQuery, subStatusFilter, paymentFilter, dateFilter, sortBy, mainDomain]);

  // Real KPI Metrics
  const stats = useMemo(() => {
    const foodOrders = orders.filter(o => o.sourceType === 'food_delivery' || o.sourceType === 'store_delivery');
    const taxiOrders = orders.filter(o => o.sourceType === 'taxi_ride');
    const mersalOrders = orders.filter(o => o.sourceType === 'mersal_delivery');
    const cancelledOrders = orders.filter(o => o.rawStatus.includes('cancel') || o.rawStatus.includes('reject'));

    const foodSales = foodOrders.reduce((acc, curr) => acc + (curr.totalPriceIqd || 0), 0);
    const taxiSales = taxiOrders.reduce((acc, curr) => acc + (curr.totalPriceIqd || 0), 0);

    const activeFood = foodOrders.filter(o => !o.rawStatus.includes('deliver') && !o.rawStatus.includes('complete') && !o.rawStatus.includes('cancel')).length;
    const activeTaxi = taxiOrders.filter(o => !o.rawStatus.includes('deliver') && !o.rawStatus.includes('complete') && !o.rawStatus.includes('cancel')).length;

    return {
      foodCount: foodOrders.length,
      foodSales,
      activeFood,
      taxiCount: taxiOrders.length,
      taxiSales,
      activeTaxi,
      mersalCount: mersalOrders.length,
      cancelledCount: cancelledOrders.length
    };
  }, [orders]);

  // Actions
  const handleUpdateStatus = async (order: AdminOrderRecord, nextStatus: string) => {
    setActionLoading(true);
    try {
      await OrdersRepository.updateOrderStatus(order.orderId, order.sourceType, nextStatus);
      showToast(`تم تغيير حالة الطلب #${order.orderId.substring(0, 6)} إلى (${nextStatus}) بنجاح `);
    } catch (err: any) {
      showToast(`فشل تحديث الحالة: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleAssignDriver = async () => {
    if (!selectedOrder || !selectedDriverIdToAssign) return;

    const chosenDriver = drivers.find(d => d.driverId === selectedDriverIdToAssign);
    if (!chosenDriver) return;

    setActionLoading(true);
    try {
      await OrdersRepository.assignDriverToOrder(selectedOrder.orderId, selectedOrder.sourceType, {
        id: chosenDriver.driverId,
        name: chosenDriver.name,
        phone: chosenDriver.phoneNumber,
        carPlate: chosenDriver.plateNumber,
        carModel: chosenDriver.vehicleModel
      });
      showToast(`تم تعيين الكابتن (${chosenDriver.name}) للطلب بنجاح `);
      setIsAssigningDriver(false);
      setSelectedDriverIdToAssign('');
    } catch (err: any) {
      showToast(`فشل تعيين الكابتن: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleConfirmCancel = async () => {
    if (!cancellingOrder) return;
    setActionLoading(true);
    try {
      await OrdersRepository.cancelOrderWithReason(
        cancellingOrder.orderId, 
        cancellingOrder.sourceType, 
        cancellationReason.trim() || 'تم الإلغاء من قبل الإدارة'
      );
      showToast(`تم إلغاء الطلب #${cancellingOrder.orderId.substring(0, 6)} وتوثيق السبب بنجاح `);
      setCancellingOrder(null);
      setCancellationReason('');
    } catch (err: any) {
      showToast(`فشل إلغاء الطلب: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // DEEP PERMANENT DELETE (Single)
  const handleDeleteOrder = async (order: AdminOrderRecord) => {
    if (!window.confirm(` تحذير نهائي: متأكد تريد تحذف هذا السجل (#${order.orderId.substring(0, 8)}) بشكل دائم من جميع قواعد ومجموعات Firestore؟`)) return;

    setActionLoading(true);
    // Instant local optimistic update
    setOrders(prev => prev.filter(o => o.orderId !== order.orderId));
    
    try {
      await OrdersRepository.deleteOrder(
        order.orderId, 
        order.sourceType, 
        order.customerId, 
        order.merchantId
      );
      showToast(`تم حذف الطلب نهائياً من كافة قواعد البيانات `);
      if (selectedOrder?.orderId === order.orderId) setSelectedOrder(null);
    } catch (err: any) {
      showToast(`فشل حذف الطلب: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // DEEP BULK DELETE
  const handleBulkDelete = async () => {
    if (selectedOrderIds.length === 0) return;
    if (!window.confirm(` تحذير: متأكد تريد تحذف ${selectedOrderIds.length} طلبات محددة نهائياً من كافة مجموعات البيانات؟ لن تعود أبداً.`)) return;

    const targets = orders
      .filter(o => selectedOrderIds.includes(o.orderId))
      .map(o => ({ 
        orderId: o.orderId, 
        sourceType: o.sourceType,
        customerId: o.customerId,
        merchantId: o.merchantId
      }));

    setActionLoading(true);
    // Instant local optimistic update
    setOrders(prev => prev.filter(o => !selectedOrderIds.includes(o.orderId)));
    setSelectedOrderIds([]);

    try {
      await OrdersRepository.bulkDeleteOrders(targets);
      showToast(`تم حذف ${targets.length} طلبات بنجاح تام `);
    } catch (err: any) {
      showToast(`فشل الحذف الجماعي: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // PURGE ALL CANCELLED ORDERS IN ONE CLICK
  const handlePurgeAllCancelled = async () => {
    const count = stats.cancelledCount;
    if (count === 0) {
      showToast('ماكو طلبات حالياً ملغاة لحذفها', 'error');
      return;
    }

    if (!window.confirm(` تنظيف شامل: هل أنت متأكد من تفريغ وحذف جميع الـ ${count} طلبات ومشاريع ملغاة نهائياً من Firestore؟`)) return;

    setActionLoading(true);
    // Instant local optimistic update
    setOrders(prev => prev.filter(o => !o.rawStatus.includes('cancel') && !o.rawStatus.includes('reject')));

    try {
      const purged = await OrdersRepository.purgeAllCancelledOrders(orders);
      showToast(`تم تنظيف وحذف ${purged} طلب ملغي نهائياً من النظام `);
    } catch (err: any) {
      showToast(`فشل تنظيف الملغيات: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleBulkStatusChange = async (newStatus: string) => {
    if (selectedOrderIds.length === 0) return;
    const targets = orders
      .filter(o => selectedOrderIds.includes(o.orderId))
      .map(o => ({ orderId: o.orderId, sourceType: o.sourceType }));

    setActionLoading(true);
    try {
      await OrdersRepository.bulkUpdateStatus(targets, newStatus);
      showToast(`تم تحديث حالة ${targets.length} طلبات إلى (${newStatus}) بنجاح `);
      setSelectedOrderIds([]);
    } catch (err: any) {
      showToast(`فشل التحديث الجماعي: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleExportCSV = () => {
    if (filteredOrders.length === 0) {
      showToast('ماكو بيانات حالياً لتصديرها', 'error');
      return;
    }

    const headers = ['رقم الطلب', 'النوع', 'المتجر / الوجهة', 'العميل', 'رقم العميل', 'الكابتن', 'المبلغ (د.ع)', 'الحالة', 'طريقة الدفع', 'التاريخ', 'العنوان'];
    const rows = filteredOrders.map(o => [
      `"${o.orderId}"`,
      `"${o.sourceType === 'food_delivery' ? 'مطعم' : o.sourceType === 'store_delivery' ? 'متجر' : 'تكسي'}"`,
      `"${o.merchantOrTitle.replace(/"/g, '""')}"`,
      `"${o.customerName.replace(/"/g, '""')}"`,
      `"${o.customerPhone || ''}"`,
      `"${o.driverName || 'غير معين'}"`,
      o.totalPriceIqd,
      `"${o.status}"`,
      `"${o.paymentMethod || 'نقداً'}"`,
      `"${o.createdAt}"`,
      `"${(o.deliveryAddress || '').replace(/"/g, '""')}"`
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `madar_orders_${mainDomain}_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير ملف CSV بنجاح ');
  };

  const handlePrintReceipt = () => {
    setIsPrinting(true);
    setTimeout(() => {
      window.print();
      setIsPrinting(false);
    }, 300);
  };

  const renderStatusBadge = (order: AdminOrderRecord) => {
    const raw = order.rawStatus;
    if (raw.includes('deliver') || raw.includes('complete') || raw === 'done') {
      return <span className="badge badge-success" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><CheckCircle2 size={12} /> مكتمل ومسلّم</span>;
    }
    if (raw.includes('cancel') || raw.includes('reject')) {
      return <span className="badge badge-danger" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><XCircle size={12} /> ملغي</span>;
    }
    if (raw.includes('in_transit') || raw.includes('picked') || raw.includes('assigned') || raw.includes('on_way')) {
      return <span className="badge badge-primary" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', background: 'rgba(6, 182, 212, 0.2)', color: '#06b6d4' }}><Car size={12} /> في الطريق </span>;
    }
    if (raw.includes('prepar') || raw.includes('cook') || raw.includes('accept')) {
      return <span className="badge badge-warning" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><Clock size={12} /> قيد التحضير </span>;
    }
    return <span className="badge badge-info" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><Clock size={12} /> {order.status}</span>;
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {toast && (
        <div style={{
          position: 'fixed',
          bottom: '24px',
          left: '24px',
          zIndex: 9999,
          background: toast.type === 'success' ? '#059669' : '#dc2626',
          color: '#fff',
          padding: '12px 20px',
          borderRadius: '10px',
          boxShadow: '0 8px 24px rgba(0,0,0,0.4)',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          fontWeight: '700',
          fontSize: '13.5px',
          animation: 'slideUp 0.3s ease-out'
        }}>
          {toast.type === 'success' ? <CheckCircle size={18} /> : <AlertTriangle size={18} />}
          <span>{toast.msg}</span>
        </div>
      )}

      {/* Header with Title & Live Realtime Indicator */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ padding: '8px', borderRadius: '10px', background: 'linear-gradient(135deg, #06b6d4, #3b82f6)' }}>
              <ShoppingBag size={22} color="#fff" />
            </div>
            مركز العمليات والتحكم: طلبات المطاعم والمتاجر وتكسي مدار
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            فصل تام بين منظومة توصيل المطاعم والمتاجر وبين أسطول تكسي مدار، مع إظهار الكابتن المكلّف وحذف نهائي شامل للملغيات
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button
            onClick={handleExportCSV}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', padding: '8px 14px' }}
          >
            <Download size={15} /> تصدير CSV
          </button>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '6px 12px',
            borderRadius: '20px',
            background: 'rgba(16, 185, 129, 0.15)',
            border: '1px solid rgba(16, 185, 129, 0.3)',
            color: '#34d399',
            fontSize: '12px',
            fontWeight: '700'
          }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34d399', display: 'inline-block', animation: 'pulse 1.5s infinite' }} />
            تحديث حي Firestore Realtime
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* PRIMARY DOMAIN SEGMENTATION TABS (فصل المطاعم عن التكسي بالكامل) */}
      {/* ========================================================================= */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '12px',
        background: 'rgba(15, 23, 42, 0.6)',
        padding: '8px',
        borderRadius: '14px',
        border: '1px solid rgba(255, 255, 255, 0.08)'
      }}>
        
        {/* Tab 1: Food & Stores */}
        <button
          onClick={() => {
            setMainDomain('food_stores');
            setSubStatusFilter('all');
          }}
          style={{
            background: mainDomain === 'food_stores' 
              ? 'linear-gradient(135deg, rgba(239, 68, 68, 0.25), rgba(249, 115, 22, 0.25))' 
              : 'rgba(255, 255, 255, 0.03)',
            border: mainDomain === 'food_stores' ? '1px solid #f87171' : '1px solid transparent',
            color: '#fff',
            padding: '14px 18px',
            borderRadius: '10px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            transition: 'all 0.2s ease'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(239, 68, 68, 0.2)', color: '#f87171' }}>
              <Utensils size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '14px' }}> طلبات المطاعم والمتاجر</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.activeFood} جارية الآن • {stats.foodCount} مسجل</div>
            </div>
          </div>
          <div style={{ fontSize: '13px', fontWeight: '800', color: '#34d399' }}>
            {formatIqd(stats.foodSales)}
          </div>
        </button>

        {/* Tab 2: Taxi Rides */}
        <button
          onClick={() => {
            setMainDomain('taxi_rides');
            setSubStatusFilter('all');
          }}
          style={{
            background: mainDomain === 'taxi_rides' 
              ? 'linear-gradient(135deg, rgba(245, 158, 11, 0.25), rgba(234, 179, 8, 0.25))' 
              : 'rgba(255, 255, 255, 0.03)',
            border: mainDomain === 'taxi_rides' ? '1px solid #fbbf24' : '1px solid transparent',
            color: '#fff',
            padding: '14px 18px',
            borderRadius: '10px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            transition: 'all 0.2s ease'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(245, 158, 11, 0.2)', color: '#fbbf24' }}>
              <Car size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '14px' }}> مشاوير وتوصيل تكسي مدار</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.activeTaxi} نشطة بالشارع • {stats.taxiCount} مشوار</div>
            </div>
          </div>
          <div style={{ fontSize: '13px', fontWeight: '800', color: '#fbbf24' }}>
            {formatIqd(stats.taxiSales)}
          </div>
        </button>

        {/* Tab 3: Mersal Logistics */}
        <button
          onClick={() => {
            setMainDomain('mersal');
            setSubStatusFilter('all');
          }}
          style={{
            background: mainDomain === 'mersal' 
              ? 'linear-gradient(135deg, rgba(139, 92, 246, 0.25), rgba(99, 102, 241, 0.25))' 
              : 'rgba(255, 255, 255, 0.03)',
            border: mainDomain === 'mersal' ? '1px solid #a78bfa' : '1px solid transparent',
            color: '#fff',
            padding: '14px 18px',
            borderRadius: '10px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            transition: 'all 0.2s ease'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(139, 92, 246, 0.2)', color: '#a78bfa' }}>
              <Send size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '14px' }}> طرود وشحنات مرسال</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.mersalCount} طرد مسجل</div>
            </div>
          </div>
        </button>

        {/* Tab 4: Cancelled & Purge Management */}
        <button
          onClick={() => {
            setMainDomain('cancelled_purge');
          }}
          style={{
            background: mainDomain === 'cancelled_purge' 
              ? 'linear-gradient(135deg, rgba(239, 68, 68, 0.3), rgba(185, 28, 28, 0.3))' 
              : 'rgba(255, 255, 255, 0.03)',
            border: mainDomain === 'cancelled_purge' ? '1px solid #ef4444' : '1px solid transparent',
            color: '#fff',
            padding: '14px 18px',
            borderRadius: '10px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            transition: 'all 0.2s ease'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(239, 68, 68, 0.2)', color: '#f87171' }}>
              <Trash2 size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '14px', color: '#f87171' }}> إدارة وحذف الملغيات</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.cancelledCount} عملية ملغاة في النظام</div>
            </div>
          </div>
          <span className="badge badge-danger" style={{ fontSize: '11px' }}>
            {stats.cancelledCount}
          </span>
        </button>

      </div>

      {/* Secondary Filter & Control Panel */}
      <div className="glass-panel" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
        
        {/* Row 1: Sub-status Tabs (Only if not in Cancelled Purge Mode) */}
        {mainDomain !== 'cancelled_purge' ? (
          <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '4px' }}>
            {[
              { key: 'all', label: ` جميع العمليات (${domainOrders.length})` },
              { key: 'active', label: ` الجارية الحية (${domainOrders.filter(o => !o.rawStatus.includes('deliver') && !o.rawStatus.includes('cancel') && !o.rawStatus.includes('complete')).length})` },
              { key: 'delivered', label: ` المكتملة المسلّمة (${domainOrders.filter(o => o.rawStatus.includes('deliver') || o.rawStatus.includes('complete')).length})` },
              { key: 'cancelled', label: ` الملغاة (${domainOrders.filter(o => o.rawStatus.includes('cancel') || o.rawStatus.includes('reject')).length})` },
            ].map(tab => (
              <button
                key={tab.key}
                onClick={() => setSubStatusFilter(tab.key as any)}
                className={`btn ${subStatusFilter === tab.key ? 'btn-primary' : 'btn-secondary'}`}
                style={{
                  fontSize: '12.5px',
                  padding: '7px 14px',
                  whiteSpace: 'nowrap',
                  borderRadius: '8px'
                }}
              >
                {tab.label}
              </button>
            ))}
          </div>
        ) : (
          /* Prominent Purge All Banner when in Cancelled Purge Mode */
          <div style={{
            background: 'linear-gradient(90deg, rgba(239, 68, 68, 0.2), rgba(185, 28, 28, 0.2))',
            border: '1px solid rgba(239, 68, 68, 0.4)',
            borderRadius: '10px',
            padding: '12px 18px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            flexWrap: 'wrap',
            gap: '12px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#f87171' }}>
              <Flame size={22} />
              <div>
                <strong style={{ fontSize: '14px' }}>تنظيف وحذف نهائي لجميع الطلبات والمشاوير الملغاة</strong>
                <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-muted)' }}>
                  سيتم حذف كافة السجلات الملغاة من جميع مجموعات Firestore ومجموعات المستخدمين والمتاجر بشكل دائم لمنع رجوعها.
                </p>
              </div>
            </div>

            <button
              onClick={handlePurgeAllCancelled}
              className="btn btn-danger"
              style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', padding: '9px 18px', fontWeight: '800' }}
              disabled={actionLoading || stats.cancelledCount === 0}
            >
              <Trash2 size={16} /> تفريغ وحذف جميع الـ ({stats.cancelledCount}) ملغيات نهائياً 
            </button>
          </div>
        )}

        {/* Row 2: Search, Date, Payment, Sort, and View Mode */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap' }}>
          
          {/* Search Box */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            background: 'rgba(255, 255, 255, 0.05)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            borderRadius: '8px',
            padding: '8px 14px',
            flex: 1,
            minWidth: '280px'
          }}>
            <Search size={16} color="#94a3b8" />
            <input
              type="text"
              placeholder={
                mainDomain === 'food_stores' 
                  ? "ابحث برقم الطلب، اسم المطعم، العميل، الهاتف، الكابتن، أو الوجبة..." 
                  : (mainDomain === 'taxi_rides' ? "ابحث برقم المشوار، الراكب، كابتن التكسي، لوحة السيارة، أو الوجهة..." : "ابحث برقم الشحنة، المرسل، أو العنوان...")
              }
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                background: 'transparent',
                border: 'none',
                color: '#fff',
                fontSize: '13px',
                width: '100%',
                outline: 'none'
              }}
            />
            {searchQuery && (
              <X size={14} color="#94a3b8" style={{ cursor: 'pointer' }} onClick={() => setSearchQuery('')} />
            )}
          </div>

          {/* Date Filter */}
          <select
            value={dateFilter}
            onChange={(e) => setDateFilter(e.target.value as any)}
            style={{
              background: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              color: '#fff',
              padding: '8px 12px',
              borderRadius: '8px',
              fontSize: '12.5px',
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            <option value="all" style={{ background: '#1e293b' }}> كل الأوقات</option>
            <option value="today" style={{ background: '#1e293b' }}>اليوم فقط</option>
            <option value="week" style={{ background: '#1e293b' }}>آخر 7 أيام</option>
            <option value="month" style={{ background: '#1e293b' }}>هذا الشهر</option>
          </select>

          {/* Payment Filter */}
          <select
            value={paymentFilter}
            onChange={(e) => setPaymentFilter(e.target.value as any)}
            style={{
              background: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              color: '#fff',
              padding: '8px 12px',
              borderRadius: '8px',
              fontSize: '12.5px',
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            <option value="all" style={{ background: '#1e293b' }}> كل طرق الدفع</option>
            <option value="cash" style={{ background: '#1e293b' }}> نقد عند الاستلام</option>
            <option value="wallet" style={{ background: '#1e293b' }}> محفظة مدار</option>
          </select>

          {/* Sort By */}
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as any)}
            style={{
              background: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              color: '#fff',
              padding: '8px 12px',
              borderRadius: '8px',
              fontSize: '12.5px',
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            <option value="newest" style={{ background: '#1e293b' }}> الأحدث أولاً</option>
            <option value="oldest" style={{ background: '#1e293b' }}> الأقدم أولاً</option>
            <option value="highest_price" style={{ background: '#1e293b' }}> الأعلى سعراً</option>
            <option value="lowest_price" style={{ background: '#1e293b' }}> الأقل سعراً</option>
          </select>

          {/* View Mode Toggle */}
          <div style={{ display: 'flex', background: 'rgba(255, 255, 255, 0.05)', borderRadius: '8px', padding: '3px', border: '1px solid rgba(255, 255, 255, 0.1)' }}>
            <button
              onClick={() => setViewMode('table')}
              style={{
                background: viewMode === 'table' ? '#06b6d4' : 'transparent',
                border: 'none',
                color: '#fff',
                padding: '6px 10px',
                borderRadius: '6px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center'
              }}
              title="عرض الجدول"
            >
              <List size={15} />
            </button>
            <button
              onClick={() => setViewMode('grid')}
              style={{
                background: viewMode === 'grid' ? '#06b6d4' : 'transparent',
                border: 'none',
                color: '#fff',
                padding: '6px 10px',
                borderRadius: '6px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center'
              }}
              title="عرض البطاقات"
            >
              <LayoutGrid size={15} />
            </button>
          </div>

        </div>

        {/* Row 3: Bulk Actions Bar (When Selected) */}
        {selectedOrderIds.length > 0 && (
          <div style={{
            background: 'linear-gradient(90deg, rgba(6, 182, 212, 0.15), rgba(59, 130, 246, 0.15))',
            border: '1px solid rgba(6, 182, 212, 0.3)',
            borderRadius: '8px',
            padding: '10px 16px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '12px',
            flexWrap: 'wrap'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#38bdf8', fontWeight: '700', fontSize: '13px' }}>
              <CheckCircle size={16} />
              <span>تم تحديد {selectedOrderIds.length} عنصر</span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <button
                onClick={() => handleBulkStatusChange('delivered')}
                className="btn btn-secondary"
                style={{ fontSize: '12px', padding: '6px 12px', background: 'rgba(16, 185, 129, 0.2)', color: '#34d399', borderColor: '#10b981' }}
                disabled={actionLoading}
              >
                 تعيين كمكتمل للجميع
              </button>
              <button
                onClick={handleBulkDelete}
                className="btn btn-danger"
                style={{ fontSize: '12px', padding: '6px 12px' }}
                disabled={actionLoading}
              >
                <Trash2 size={14} /> حذف نهائي للمحدد 
              </button>
              <button
                onClick={() => setSelectedOrderIds([])}
                style={{ background: 'transparent', border: 'none', color: '#94a3b8', fontSize: '12px', cursor: 'pointer' }}
              >
                إلغاء التحديد
              </button>
            </div>
          </div>
        )}

      </div>

      {/* Main Content: Table or Grid View */}
      <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '80px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={36} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 14px' }} />
            <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff' }}>جاري استيراد ومزامنة البيانات من Firestore...</div>
          </div>
        ) : filteredOrders.length === 0 ? (
          <div style={{ padding: '80px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <ShoppingBag size={42} color="#64748b" style={{ margin: '0 auto 14px' }} />
            <div style={{ fontSize: '16px', fontWeight: '700', color: '#fff' }}>ماكو بيانات حالياً مطابقة في هذا القسم</div>
            <div style={{ fontSize: '12.5px', marginTop: '6px' }}>جرب تغيير نص البحث أو اختيار تبويب آخر</div>
          </div>
        ) : viewMode === 'table' ? (
          /* ======================== TABLE VIEW (CUSTOMIZED PER DOMAIN) ======================== */
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th style={{ width: '40px', textAlign: 'center' }}>
                    <input
                      type="checkbox"
                      checked={selectedOrderIds.length === filteredOrders.length && filteredOrders.length > 0}
                      onChange={() => {
                        if (selectedOrderIds.length === filteredOrders.length) setSelectedOrderIds([]);
                        else setSelectedOrderIds(filteredOrders.map(o => o.orderId));
                      }}
                      style={{ cursor: 'pointer' }}
                    />
                  </th>
                  <th>{mainDomain === 'taxi_rides' ? 'رقم المشوار' : 'رقم الطلب'}</th>
                  
                  {mainDomain === 'taxi_rides' ? (
                    <>
                      <th>نقطة الانطلاق الوجهة</th>
                      <th>الراكب والاتصال</th>
                      <th> كابتن التكسي المكلّف</th>
                      <th>الأجرة</th>
                    </>
                  ) : (
                    <>
                      <th>المتجر / المطعم</th>
                      <th>الوجبات والأصناف</th>
                      <th>العميل وعنوان التوصيل</th>
                      <th> كابتن التوصيل المكلّف</th>
                      <th>المبلغ الكلي</th>
                    </>
                  )}

                  <th>الدفع</th>
                  <th>الحالة</th>
                  <th>الوقت</th>
                  <th style={{ textAlign: 'center' }}>الإجراءات</th>
                </tr>
              </thead>
              <tbody>
                {filteredOrders.map((o) => {
                  const isSelected = selectedOrderIds.includes(o.orderId);
                  const cust = getMatchedCustomer(o);
                  const merch = getMatchedMerchant(o);
                  const dvr = getMatchedDriver(o);

                  return (
                    <tr 
                      key={o.orderId}
                      style={{ background: isSelected ? 'rgba(6, 182, 212, 0.08)' : undefined }}
                    >
                      <td style={{ textAlign: 'center' }}>
                        <input
                          type="checkbox"
                          checked={isSelected}
                          onChange={() => {
                            setSelectedOrderIds(prev => 
                              prev.includes(o.orderId) ? prev.filter(i => i !== o.orderId) : [...prev, o.orderId]
                            );
                          }}
                          style={{ cursor: 'pointer' }}
                        />
                      </td>

                      {/* ID */}
                      <td>
                        <div 
                          onClick={() => setSelectedOrder(o)}
                          style={{ cursor: 'pointer', display: 'flex', flexDirection: 'column' }}
                        >
                          <code style={{ color: '#38bdf8', fontWeight: '700', fontSize: '12.5px' }}>
                            #{o.orderId.substring(0, 8)}
                          </code>
                          <span style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>
                            {getRelativeTime(o.createdAt)}
                          </span>
                        </div>
                      </td>

                      {/* Domain-specific Columns */}
                      {mainDomain === 'taxi_rides' ? (
                        <>
                          {/* Route */}
                          <td>
                            <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <span> {o.pickupAddress || 'نقطة الانطلاق'}</span>
                              <span style={{ color: '#fbbf24' }}></span>
                              <span> {o.deliveryAddress || 'الوجهة'}</span>
                            </div>
                            {o.customerNotes && (
                              <div style={{ fontSize: '11px', color: '#fbbf24', marginTop: '2px' }}>
                                ملاحظة: {o.customerNotes}
                              </div>
                            )}
                          </td>

                          {/* Passenger */}
                          <td>
                            <div style={{ color: '#fff', fontWeight: '600', fontSize: '12.5px' }}>{o.customerName}</div>
                            {o.customerPhone && (
                              <div style={{ fontSize: '11px', color: 'var(--text-dim)', direction: 'ltr', textAlign: 'right' }}>
                                {o.customerPhone} 
                              </div>
                            )}
                          </td>

                          {/* Taxi Captain */}
                          <td>
                            {o.driverName ? (
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10b981' }} />
                                <div>
                                  <div style={{ color: '#fbbf24', fontSize: '12.5px', fontWeight: '700' }}>{o.driverName}</div>
                                  <div style={{ fontSize: '11px', color: '#94a3b8' }}>
                                    {o.driverVehicleModel || dvr?.vehicleModel || 'تكسي'} ({o.driverVehiclePlate || dvr?.plateNumber || 'لوحة'})
                                  </div>
                                  {o.driverPhone && (
                                    <div style={{ fontSize: '10.5px', color: '#38bdf8', direction: 'ltr', textAlign: 'right' }}>
                                      {o.driverPhone}
                                    </div>
                                  )}
                                </div>
                              </div>
                            ) : (
                              <button
                                onClick={() => {
                                  setSelectedOrder(o);
                                  setIsAssigningDriver(true);
                                }}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 8px', color: '#f59e0b', borderColor: 'rgba(245, 158, 11, 0.4)' }}
                              >
                                + تعيين كابتن تكسي 
                              </button>
                            )}
                          </td>

                          {/* Fare */}
                          <td>
                            <strong style={{ color: '#fbbf24', fontSize: '13.5px' }}>
                              {formatIqd(o.totalPriceIqd)}
                            </strong>
                          </td>
                        </>
                      ) : (
                        <>
                          {/* Merchant */}
                          <td>
                            <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                              {o.sourceType === 'food_delivery' ? '' : ''} {o.merchantOrTitle}
                            </div>
                            <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                              {merch?.phone || o.merchantPhone ? ` ${merch?.phone || o.merchantPhone}` : 'القائم'}
                            </div>
                          </td>

                          {/* Items */}
                          <td>
                            <div style={{ color: '#e2e8f0', fontSize: '12px', maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              {o.itemsSummary}
                            </div>
                            {o.itemsList && o.itemsList.length > 0 && (
                              <div style={{ fontSize: '10.5px', color: '#06b6d4' }}>
                                {o.itemsList.length} أصناف في الطلب
                              </div>
                            )}
                          </td>

                          {/* Customer & Address */}
                          <td>
                            <div style={{ color: '#fff', fontWeight: '600', fontSize: '12.5px' }}>{o.customerName}</div>
                            {o.customerPhone && (
                              <div style={{ fontSize: '11px', color: 'var(--text-dim)', direction: 'ltr', textAlign: 'right' }}>
                                {o.customerPhone} 
                              </div>
                            )}
                            <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '2px' }}>
                               {o.deliveryAddress || 'القائم'}
                            </div>
                          </td>

                          {/* Delivery Captain */}
                          <td>
                            {o.driverName ? (
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10b981' }} />
                                <div>
                                  <div style={{ color: '#38bdf8', fontSize: '12.5px', fontWeight: '700' }}>{o.driverName}</div>
                                  <div style={{ fontSize: '11px', color: '#94a3b8' }}>
                                    {o.driverVehicleModel || dvr?.vehicleModel || 'دراجة/سيارة'} ({o.driverVehiclePlate || dvr?.plateNumber || 'لوحة'})
                                  </div>
                                  {o.driverPhone && (
                                    <div style={{ fontSize: '10.5px', color: '#38bdf8', direction: 'ltr', textAlign: 'right' }}>
                                      {o.driverPhone}
                                    </div>
                                  )}
                                </div>
                              </div>
                            ) : (
                              <button
                                onClick={() => {
                                  setSelectedOrder(o);
                                  setIsAssigningDriver(true);
                                }}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 8px', color: '#f59e0b', borderColor: 'rgba(245, 158, 11, 0.4)' }}
                              >
                                + تعيين كابتن توصيل 
                              </button>
                            )}
                          </td>

                          {/* Total Bill */}
                          <td>
                            <strong style={{ color: '#34d399', fontSize: '13.5px' }}>
                              {formatIqd(o.totalPriceIqd)}
                            </strong>
                          </td>
                        </>
                      )}

                      {/* Payment */}
                      <td>
                        <span style={{ fontSize: '11.5px', color: o.paymentMethod?.includes('wallet') ? '#a78bfa' : '#94a3b8' }}>
                          {o.paymentMethod?.includes('wallet') ? ' محفظة مدار' : ' نقد COD'}
                        </span>
                      </td>

                      {/* Status */}
                      <td>
                        {renderStatusBadge(o)}
                      </td>

                      {/* Time */}
                      <td style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                        {formatDateTime(o.createdAt)}
                      </td>

                      {/* Actions */}
                      <td style={{ textAlign: 'center' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
                          <button
                            onClick={() => setSelectedOrder(o)}
                            className="btn btn-primary"
                            style={{ padding: '5px 10px', fontSize: '11.5px' }}
                            title="عرض التفاصيل والفاتورة"
                          >
                            تفاصيل 
                          </button>
                          
                          {mainDomain !== 'cancelled_purge' && (
                            <button
                              onClick={() => setCancellingOrder(o)}
                              className="btn btn-secondary"
                              style={{ padding: '5px 8px', fontSize: '11.5px', color: '#f87171' }}
                              title="إلغاء الطلب"
                            >
                              إلغاء 
                            </button>
                          )}

                          <button
                            onClick={() => handleDeleteOrder(o)}
                            style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '4px' }}
                            title="حذف نهائي من Firestore"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          /* ======================== GRID CARDS VIEW ======================== */
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
            gap: '16px',
            padding: '20px'
          }}>
            {filteredOrders.map((o) => (
              <div
                key={o.orderId}
                className="glass-panel"
                style={{
                  padding: '16px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  position: 'relative'
                }}
              >
                {/* Card Top */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <code style={{ color: '#38bdf8', fontWeight: '700', fontSize: '12px' }}>
                      #{o.orderId.substring(0, 8)}
                    </code>
                    <div style={{ fontWeight: '700', color: '#fff', fontSize: '14px', marginTop: '2px' }}>
                      {o.merchantOrTitle}
                    </div>
                  </div>
                  {renderStatusBadge(o)}
                </div>

                {/* Items or Route Summary */}
                <div style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  padding: '8px 12px',
                  borderRadius: '8px',
                  fontSize: '12px',
                  color: 'var(--text-muted)',
                  lineHeight: '1.4'
                }}>
                  {o.itemsSummary}
                </div>

                {/* Info Rows */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-muted)' }}>
                    <span>العميل / الراكب:</span>
                    <strong style={{ color: '#fff' }}>{o.customerName} ({o.customerPhone || 'بدون هاتف'})</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-muted)' }}>
                    <span>الكابتن المكلّف:</span>
                    <strong style={{ color: o.driverName ? '#38bdf8' : '#f59e0b' }}>
                      {o.driverName || 'لم يُعيّن كابتن بعد'}
                    </strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-muted)' }}>
                    <span>العنوان / الوجهة:</span>
                    <span style={{ color: '#e2e8f0', maxWidth: '180px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {o.deliveryAddress || 'القائم'}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-muted)' }}>
                    <span>الوقت:</span>
                    <span>{getRelativeTime(o.createdAt)}</span>
                  </div>
                </div>

                {/* Price & Action Bar */}
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  paddingTop: '10px',
                  borderTop: '1px solid rgba(255, 255, 255, 0.08)'
                }}>
                  <div style={{ fontSize: '16px', fontWeight: '800', color: mainDomain === 'taxi_rides' ? '#fbbf24' : '#34d399' }}>
                    {formatIqd(o.totalPriceIqd)}
                  </div>

                  <div style={{ display: 'flex', gap: '6px' }}>
                    <button
                      onClick={() => setSelectedOrder(o)}
                      className="btn btn-primary"
                      style={{ fontSize: '11.5px', padding: '5px 12px' }}
                    >
                      تفاصيل شاملة 
                    </button>
                    <button
                      onClick={() => handleDeleteOrder(o)}
                      className="btn btn-danger"
                      style={{ fontSize: '11.5px', padding: '5px 8px' }}
                      title="حذف نهائي"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>

              </div>
            ))}
          </div>
        )}
      </div>

      {/* ========================================================================= */}
      {/* 360° HOLISTIC ORDER DOSSIER & INVOICE MODAL */}
      {/* ========================================================================= */}
      {selectedOrder && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.85)',
          backdropFilter: 'blur(10px)',
          zIndex: 1000,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          padding: '16px'
        }}>
          <div className="glass-panel" style={{
            width: '100%',
            maxWidth: '960px',
            maxHeight: '94vh',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            padding: 0,
            animation: 'fadeIn 0.25s ease-out'
          }}>
            
            {/* Modal Header */}
            <div style={{
              padding: '18px 24px',
              borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              background: 'rgba(15, 23, 42, 0.8)'
            }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <h3 style={{ margin: 0, color: '#fff', fontSize: '19px', fontWeight: '800' }}>
                    كشف تفصيلي شامل للطلب والفاتورة
                  </h3>
                  <code 
                    onClick={() => copyToClipboard(selectedOrder.orderId, 'معرف الطلب')}
                    style={{ color: '#38bdf8', fontSize: '13px', background: 'rgba(56, 189, 248, 0.12)', padding: '3px 8px', borderRadius: '6px', cursor: 'pointer' }}
                    title="اضغط لنسخ معرف الطلب"
                  >
                    #{selectedOrder.orderId} 
                  </code>
                </div>
                <p style={{ margin: '4px 0 0 0', color: 'var(--text-muted)', fontSize: '12px' }}>
                  تاريخ الإنشاء: <strong>{formatDateTime(selectedOrder.createdAt)}</strong> ({getRelativeTime(selectedOrder.createdAt)})
                </p>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <button
                  onClick={handlePrintReceipt}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', padding: '7px 14px' }}
                >
                  <Printer size={15} /> طباعة الفاتورة والإيصال
                </button>
                <button
                  onClick={() => {
                    setSelectedOrder(null);
                    setIsAssigningDriver(false);
                  }}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: 'var(--text-muted)',
                    cursor: 'pointer',
                    padding: '6px'
                  }}
                >
                  <X size={22} />
                </button>
              </div>
            </div>

            {/* Modal Body (Scrollable with rich 360 view) */}
            <div style={{ padding: '24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* Status & Quick Action Bar */}
              <div style={{
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.08)',
                borderRadius: '12px',
                padding: '16px 20px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: '12px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>الحالة التشغيلية:</span>
                  {renderStatusBadge(selectedOrder)}
                  <span style={{ fontSize: '11.5px', color: 'var(--text-dim)', borderRight: '1px solid rgba(255,255,255,0.1)', paddingRight: '12px' }}>
                    النوع: <strong>{selectedOrder.sourceType === 'food_delivery' ? 'توصيل طعام ' : (selectedOrder.sourceType === 'store_delivery' ? 'توصيل متجر ' : 'مشوار تكسي ')}</strong>
                  </span>
                </div>

                <div style={{ display: 'flex', gap: '8px' }}>
                  <button
                    onClick={() => handleUpdateStatus(selectedOrder, 'preparing')}
                    className="btn btn-secondary"
                    style={{ fontSize: '11.5px', padding: '6px 12px' }}
                    disabled={actionLoading}
                  >
                     قيد التحضير
                  </button>
                  <button
                    onClick={() => handleUpdateStatus(selectedOrder, 'in_transit')}
                    className="btn btn-secondary"
                    style={{ fontSize: '11.5px', padding: '6px 12px', color: '#06b6d4', borderColor: '#06b6d4' }}
                    disabled={actionLoading}
                  >
                     في الطريق
                  </button>
                  <button
                    onClick={() => handleUpdateStatus(selectedOrder, 'delivered')}
                    className="btn btn-secondary"
                    style={{ fontSize: '11.5px', padding: '6px 12px', color: '#34d399', borderColor: '#10b981' }}
                    disabled={actionLoading}
                  >
                     تم التسليم
                  </button>
                  <button
                    onClick={() => setCancellingOrder(selectedOrder)}
                    className="btn btn-secondary"
                    style={{ fontSize: '11.5px', padding: '6px 12px', color: '#f87171', borderColor: '#ef4444' }}
                    disabled={actionLoading}
                  >
                     إلغاء
                  </button>
                </div>
              </div>

              {/* 3 Full Dossier Cards: Customer, Merchant, Driver */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
                
                {/* 1. CUSTOMER DEEP DOSSIER */}
                <div style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid rgba(56, 189, 248, 0.2)',
                  borderRadius: '12px',
                  padding: '18px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255, 255, 255, 0.06)', paddingBottom: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#38bdf8', fontSize: '14px', fontWeight: '800' }}>
                      <User size={18} /> ملف العميل (الزبون)
                    </div>
                  </div>

                  <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>
                    {selectedOrder.customerName}
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px' }}>
                    {selectedOrder.customerPhone && (
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ color: 'var(--text-muted)' }}>الهاتف:</span>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <a 
                            href={`tel:${selectedOrder.customerPhone}`}
                            style={{ color: '#38bdf8', direction: 'ltr', textDecoration: 'none', fontWeight: '700' }}
                          >
                            {selectedOrder.customerPhone} 
                          </a>
                          <a 
                            href={`https://wa.me/${selectedOrder.customerPhone.replace(/[^0-9]/g, '')}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            style={{ color: '#22c55e', textDecoration: 'none' }}
                          >
                            <MessageCircle size={15} />
                          </a>
                        </div>
                      </div>
                    )}

                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ color: 'var(--text-muted)' }}>رصيد المحفظة:</span>
                      <strong style={{ color: '#34d399' }}>{formatIqd(getMatchedCustomer(selectedOrder)?.walletBalance || 0)}</strong>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '2px', marginTop: '4px', borderTop: '1px solid rgba(255, 255, 255, 0.05)', paddingTop: '6px' }}>
                      <span style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>العنوان:</span>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <strong style={{ color: '#fff', fontSize: '12px' }}>{selectedOrder.deliveryAddress || 'القائم'}</strong>
                        <a
                          href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(selectedOrder.deliveryAddress || 'Al-Qaim, Iraq')}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          style={{ display: 'inline-flex', alignItems: 'center', gap: '3px', color: '#06b6d4', fontSize: '11px', textDecoration: 'none' }}
                        >
                          <Compass size={13} /> الخريطة
                        </a>
                      </div>
                    </div>
                  </div>
                </div>

                {/* 2. MERCHANT / STORE (OR ROUTE INFO IF TAXI) */}
                <div style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid rgba(16, 185, 129, 0.2)',
                  borderRadius: '12px',
                  padding: '18px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255, 255, 255, 0.06)', paddingBottom: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#34d399', fontSize: '14px', fontWeight: '800' }}>
                      {selectedOrder.sourceType === 'taxi_ride' ? <Navigation size={18} /> : <Store size={18} />}
                      {selectedOrder.sourceType === 'taxi_ride' ? 'مسار المشوار' : 'المتجر / المطعم'}
                    </div>
                  </div>

                  <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>
                    {selectedOrder.merchantOrTitle}
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px' }}>
                    {selectedOrder.sourceType !== 'taxi_ride' && (
                      <>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ color: 'var(--text-muted)' }}>موقع المتجر:</span>
                          <strong style={{ color: '#fff' }}>{selectedOrder.pickupAddress || 'القائم'}</strong>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ color: 'var(--text-muted)' }}>نسبة عمولة المتجر:</span>
                          <strong style={{ color: '#38bdf8' }}>{getMatchedMerchant(selectedOrder)?.commissionRate || 10}%</strong>
                        </div>
                      </>
                    )}

                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ color: 'var(--text-muted)' }}>طريقة الدفع:</span>
                      <strong style={{ color: '#fff' }}>{selectedOrder.paymentMethod || 'نقداً عند الاستلام'}</strong>
                    </div>
                  </div>
                </div>

                {/* 3. CAPTAIN & FLEET DEEP DOSSIER */}
                <div style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid rgba(245, 158, 11, 0.25)',
                  borderRadius: '12px',
                  padding: '18px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255, 255, 255, 0.06)', paddingBottom: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#fbbf24', fontSize: '14px', fontWeight: '800' }}>
                      <Car size={18} /> الكابتن المكلّف بالتنفيذ
                    </div>
                    <button
                      onClick={() => setIsAssigningDriver(!isAssigningDriver)}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        color: '#38bdf8',
                        fontSize: '11px',
                        cursor: 'pointer',
                        fontWeight: '700'
                      }}
                    >
                      {isAssigningDriver ? 'إلغاء' : 'تغيير / تعيين كابتن'}
                    </button>
                  </div>

                  {isAssigningDriver ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '4px' }}>
                      <select
                        value={selectedDriverIdToAssign}
                        onChange={(e) => setSelectedDriverIdToAssign(e.target.value)}
                        style={{
                          background: '#1e293b',
                          border: '1px solid #3b82f6',
                          color: '#fff',
                          padding: '8px 10px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          outline: 'none'
                        }}
                      >
                        <option value="">اختر كابتن من قائمة الأسطول...</option>
                        <optgroup label=" كباتن دراجات التوصيل السريع">
                          {drivers.filter(d => d.vehicleCategory === 'motorcycle').map(d => (
                            <option key={d.driverId} value={d.driverId}>
                               {d.name} ({d.vehicleModel} - {d.plateNumber})
                            </option>
                          ))}
                        </optgroup>
                        <optgroup label=" كباتن وسيارات تكسي مدار">
                          {drivers.filter(d => d.vehicleCategory !== 'motorcycle').map(d => (
                            <option key={d.driverId} value={d.driverId}>
                               {d.name} ({d.vehicleModel} - {d.plateNumber})
                            </option>
                          ))}
                        </optgroup>
                      </select>
                      <button
                        onClick={handleAssignDriver}
                        className="btn btn-primary"
                        style={{ fontSize: '11.5px', padding: '8px' }}
                        disabled={!selectedDriverIdToAssign || actionLoading}
                      >
                        تأكيد إسناد المهمة للكابتن 
                      </button>
                    </div>
                  ) : selectedOrder.driverName ? (
                    <>
                      <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>
                        {selectedOrder.driverName}
                      </div>

                      <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px' }}>
                        {selectedOrder.driverPhone && (
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ color: 'var(--text-muted)' }}>هاتف الكابتن:</span>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <a href={`tel:${selectedOrder.driverPhone}`} style={{ color: '#38bdf8', textDecoration: 'none', direction: 'ltr', fontWeight: '700' }}>
                                {selectedOrder.driverPhone} 
                              </a>
                            </div>
                          </div>
                        )}

                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ color: 'var(--text-muted)' }}>المركبة واللوحة:</span>
                          <strong style={{ color: '#fff' }}>
                            {selectedOrder.driverVehicleModel || getMatchedDriver(selectedOrder)?.vehicleModel || 'مركبة'} ({selectedOrder.driverVehiclePlate || getMatchedDriver(selectedOrder)?.plateNumber || 'بدون لوحة'})
                          </strong>
                        </div>

                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ color: 'var(--text-muted)' }}>التقييم:</span>
                          <span style={{ color: '#fbbf24', display: 'flex', alignItems: 'center', gap: '3px' }}>
                            <Star size={12} fill="#fbbf24" /> {getMatchedDriver(selectedOrder)?.rating || 5.0}
                          </span>
                        </div>
                      </div>
                    </>
                  ) : (
                    <div style={{ padding: '16px 10px', textAlign: 'center', color: '#f59e0b', fontSize: '12.5px' }}>
                      لم يتم تعيين كابتن بعد
                      <div style={{ marginTop: '8px' }}>
                        <button
                          onClick={() => setIsAssigningDriver(true)}
                          className="btn btn-secondary"
                          style={{ fontSize: '11px', padding: '4px 10px', color: '#f59e0b', borderColor: '#f59e0b' }}
                        >
                          + تعيين كابتن الآن
                        </button>
                      </div>
                    </div>
                  )}
                </div>

              </div>

              {/* Items Breakdown Table (For Food & Stores) */}
              {selectedOrder.sourceType !== 'taxi_ride' && (
                <div style={{
                  background: 'rgba(255, 255, 255, 0.02)',
                  border: '1px solid rgba(255, 255, 255, 0.08)',
                  borderRadius: '12px',
                  overflow: 'hidden'
                }}>
                  <div style={{ padding: '14px 18px', background: 'rgba(255, 255, 255, 0.04)', fontWeight: '700', fontSize: '13.5px', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <Package size={17} color="#06b6d4" /> الأصناف والوجبات المطلوبة في الفاتورة
                    </div>
                  </div>
                  
                  {selectedOrder.itemsList && selectedOrder.itemsList.length > 0 ? (
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '12.5px' }}>
                      <thead>
                        <tr style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.06)', color: 'var(--text-muted)', textAlign: 'right' }}>
                          <th style={{ padding: '12px 18px' }}>الصنف / الوجبة</th>
                          <th style={{ padding: '12px 18px', textAlign: 'center' }}>الكمية</th>
                          <th style={{ padding: '12px 18px', textAlign: 'left' }}>سعر الوحدة</th>
                          <th style={{ padding: '12px 18px', textAlign: 'left' }}>المجموع</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedOrder.itemsList.map((item, idx) => (
                          <tr key={idx} style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.04)' }}>
                            <td style={{ padding: '12px 18px' }}>
                              <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px' }}>{item.name}</div>
                              {item.options && item.options.length > 0 && (
                                <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '2px' }}>
                                   الإضافات: {item.options.join(' + ')}
                                </div>
                              )}
                            </td>
                            <td style={{ padding: '12px 18px', textAlign: 'center', fontWeight: '700', color: '#fff' }}>
                              × {item.quantity}
                            </td>
                            <td style={{ padding: '12px 18px', textAlign: 'left', color: 'var(--text-muted)' }}>
                              {formatIqd(item.price)}
                            </td>
                            <td style={{ padding: '12px 18px', textAlign: 'left', fontWeight: '700', color: '#34d399' }}>
                              {formatIqd(item.price * item.quantity)}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  ) : (
                    <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '13px' }}>
                      {selectedOrder.itemsSummary}
                    </div>
                  )}
                </div>
              )}

              {/* Complete Financial Ledger */}
              <div style={{
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.08)',
                borderRadius: '12px',
                padding: '18px 22px',
                display: 'flex',
                flexDirection: 'column',
                gap: '10px'
              }}>
                <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Receipt size={17} color="#34d399" /> الحسابات والتسوية المالية
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginTop: '4px' }}>
                  <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>المبلغ الأساسي (Subtotal)</div>
                    <div style={{ fontSize: '14.5px', fontWeight: '700', color: '#fff', marginTop: '2px' }}>
                      {formatIqd(selectedOrder.subtotalIqd || selectedOrder.totalPriceIqd)}
                    </div>
                  </div>

                  <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>عمولة منصة مدار</div>
                    <div style={{ fontSize: '14.5px', fontWeight: '700', color: '#38bdf8', marginTop: '2px' }}>
                      {formatIqd(selectedOrder.commissionIqd || (selectedOrder.totalPriceIqd * 0.1))}
                    </div>
                  </div>

                  <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '10px 14px', borderRadius: '8px' }}>
                    <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>صافي المستحق للجهة المنفذة</div>
                    <div style={{ fontSize: '14.5px', fontWeight: '700', color: '#34d399', marginTop: '2px' }}>
                      {formatIqd(selectedOrder.merchantNetIqd || (selectedOrder.totalPriceIqd * 0.9))}
                    </div>
                  </div>
                </div>

                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  fontSize: '17px',
                  fontWeight: '800',
                  color: '#34d399',
                  paddingTop: '12px',
                  borderTop: '1px solid rgba(255, 255, 255, 0.1)',
                  marginTop: '6px'
                }}>
                  <span>المبلغ الإجمالي النهائي:</span>
                  <span>{formatIqd(selectedOrder.totalPriceIqd)}</span>
                </div>
              </div>

            </div>

            {/* Modal Footer */}
            <div style={{
              padding: '16px 24px',
              borderTop: '1px solid rgba(255, 255, 255, 0.1)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              background: 'rgba(15, 23, 42, 0.8)'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <button
                  onClick={() => openOfficialInvoiceForOrder(selectedOrder)}
                  className="btn btn-primary"
                  style={{ fontSize: '12.5px', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  <Printer size={15} /> طباعة فاتورة رسمية معتمدة (Official PDF)
                </button>
                <button
                  onClick={() => handleDeleteOrder(selectedOrder)}
                  className="btn btn-danger"
                  style={{ fontSize: '12px', padding: '8px 14px' }}
                  disabled={actionLoading}
                >
                  <Trash2 size={15} /> حذف 
                </button>
              </div>

              <button
                onClick={() => {
                  setSelectedOrder(null);
                  setIsAssigningDriver(false);
                }}
                className="btn btn-secondary"
                style={{ fontSize: '12.5px', padding: '8px 20px' }}
              >
                إغلاق
              </button>
            </div>

          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* CANCEL ORDER MODAL WITH REASON */}
      {/* ========================================================================= */}
      {cancellingOrder && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.85)',
          backdropFilter: 'blur(8px)',
          zIndex: 1100,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          padding: '20px'
        }}>
          <div className="glass-panel" style={{
            width: '100%',
            maxWidth: '480px',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '16px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#f87171' }}>
              <AlertTriangle size={24} />
              <h3 style={{ margin: 0, fontSize: '17px', fontWeight: '800' }}>إلغاء الطلب وتوثيق السبب</h3>
            </div>

            <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>
              متأكد تريد تلغي الطلب #{cancellingOrder.orderId.substring(0, 8)} للعميل ({cancellingOrder.customerName})؟
            </p>

            <div>
              <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>
                سبب الإلغاء (يُحفظ في سجل التدقيق):
              </label>
              <textarea
                value={cancellationReason}
                onChange={(e) => setCancellationReason(e.target.value)}
                placeholder="مثال: عدم توفر الوجبة في المطعم / العميل ألغى الطلب / تعذر الوصول للعنوان..."
                rows={3}
                style={{
                  width: '100%',
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '8px',
                  color: '#fff',
                  padding: '10px',
                  fontSize: '13px',
                  outline: 'none',
                  resize: 'none'
                }}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
              <button
                onClick={() => {
                  setCancellingOrder(null);
                  setCancellationReason('');
                }}
                className="btn btn-secondary"
                style={{ fontSize: '12px' }}
                disabled={actionLoading}
              >
                تراجع
              </button>
              <button
                onClick={handleConfirmCancel}
                className="btn btn-danger"
                style={{ fontSize: '12px', padding: '8px 16px' }}
                disabled={actionLoading}
              >
                تأكيد الإلغاء 
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* PRINT-ONLY THERMAL RECEIPT STYLES */}
      {/* ========================================================================= */}
      {selectedOrder && (
        <div id="print-receipt-section" style={{ display: 'none' }}>
          <style>{`
            @media print {
              body * { visibility: hidden !important; }
              #print-receipt-section, #print-receipt-section * { visibility: visible !important; }
              #print-receipt-section {
                position: absolute !important;
                left: 0 !important;
                top: 0 !important;
                width: 100% !important;
                display: block !important;
                background: #fff !important;
                color: #000 !important;
                padding: 20px !important;
                font-family: 'IBM Plex Sans Arabic', sans-serif !important;
              }
            }
          `}</style>
          <div style={{ textAlign: 'center', borderBottom: '2px dashed #000', paddingBottom: '12px', marginBottom: '14px' }}>
            <h2 style={{ margin: 0, fontSize: '20px' }}>منصة مدار - MADAR</h2>
            <div style={{ fontSize: '12px', marginTop: '4px' }}>فاتورة طلب رقم: #{selectedOrder.orderId}</div>
            <div style={{ fontSize: '11px' }}>التاريخ: {formatDateTime(selectedOrder.createdAt)}</div>
          </div>

          <div style={{ fontSize: '12px', marginBottom: '12px' }}>
            <div><strong>الجهة / المطعم:</strong> {selectedOrder.merchantOrTitle}</div>
            <div><strong>العميل / الراكب:</strong> {selectedOrder.customerName} ({selectedOrder.customerPhone || 'بدون هاتف'})</div>
            <div><strong>العنوان / الوجهة:</strong> {selectedOrder.deliveryAddress || 'القائم'}</div>
            <div><strong>الكابتن:</strong> {selectedOrder.driverName || 'غير محدد'} ({selectedOrder.driverVehiclePlate || ''})</div>
          </div>

          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '12px', marginBottom: '12px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #000', textAlign: 'right' }}>
                <th>الصنف / المشوار</th>
                <th style={{ textAlign: 'center' }}>الكمية</th>
                <th style={{ textAlign: 'left' }}>المبلغ</th>
              </tr>
            </thead>
            <tbody>
              {selectedOrder.itemsList?.map((it, idx) => (
                <tr key={idx} style={{ borderBottom: '1px dashed #ccc' }}>
                  <td>{it.name}</td>
                  <td style={{ textAlign: 'center' }}>{it.quantity}</td>
                  <td style={{ textAlign: 'left' }}>{it.price * it.quantity} د.ع</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div style={{ borderTop: '2px solid #000', paddingTop: '8px', fontSize: '13px', textAlign: 'left' }}>
            <div><strong>المجموع الكلي:</strong> {selectedOrder.totalPriceIqd} د.ع</div>
            <div><strong>طريقة الدفع:</strong> {selectedOrder.paymentMethod || 'نقداً COD'}</div>
          </div>

          <div style={{ textAlign: 'center', marginTop: '20px', fontSize: '11px', borderTop: '1px dashed #000', paddingTop: '10px' }}>
            شكراً لاختياركم منصة مدار - قضاء القائم
          </div>
        </div>
      )}

      {/* Official Madar PDF Invoice & Receipt Modal */}
      {activeInvoiceData && (
        <OfficialInvoiceModal
          data={activeInvoiceData}
          onClose={() => setActiveInvoiceData(null)}
        />
      )}

    </div>
  );
};
