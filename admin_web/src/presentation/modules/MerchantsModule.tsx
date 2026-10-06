import React, { useState, useEffect, useMemo } from 'react';
import {
  Store,
  UtensilsCrossed,
  ShoppingBag,
  Search,
  CheckCircle,
  AlertCircle,
  Percent,
  TrendingUp,
  DollarSign,
  Loader2,
  Power,
  Trash2,
  Plus,
  ArrowRight,
  Package,
  Layers,
  Edit3,
  X,
  Phone,
  User,
  MapPin,
  Key,
  Eye,
  Lock,
  Calendar,
  DollarSign as DollarIcon,
  MessageCircle,
  Download,
  Receipt,
  Coins,
  FileText,
  Sparkles,
  Clock,
  ExternalLink,
  Car,
  Check,
  ShieldCheck,
  Ban
} from 'lucide-react';
import { MerchantEntity } from '../../domain/types';
import { 
  MerchantsRepository, 
  ProductItemEntity, 
  NewMerchantPayload,
  MerchantOrderRecord 
} from '../../infrastructure/repositories/MerchantsRepository';
import { OrdersRepository, AdminOrderRecord } from '../../infrastructure/repositories/OrdersRepository';

export const MerchantsModule: React.FC = () => {
  const [merchants, setMerchants] = useState<MerchantEntity[]>([]);
  const [allOrders, setAllOrders] = useState<AdminOrderRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedApprovalStatus, setSelectedApprovalStatus] = useState<'verified' | 'pending' | 'suspended' | 'all'>('verified');
  const [activeCategory, setActiveCategory] = useState<'all' | 'restaurant' | 'store' | 'pharmacy'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [editingCommissionId, setEditingCommissionId] = useState<string | null>(null);
  const [newCommissionValue, setNewCommissionValue] = useState<number>(10);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Store Dedicated Orders & Sales State
  const [storeOrdersMerchant, setStoreOrdersMerchant] = useState<MerchantEntity | null>(null);
  const [storeOrders, setStoreOrders] = useState<MerchantOrderRecord[]>([]);
  const [isStoreOrdersLoading, setIsStoreOrdersLoading] = useState(false);
  const [storeOrdersStatusFilter, setStoreOrdersStatusFilter] = useState<'all' | 'delivered' | 'active' | 'cancelled'>('all');
  const [storeOrdersSearch, setStoreOrdersSearch] = useState('');

  // Selected Merchant for Catalog / Menu Management
  const [selectedMerchant, setSelectedMerchant] = useState<MerchantEntity | null>(null);
  const [products, setProducts] = useState<ProductItemEntity[]>([]);
  const [isProductsLoading, setIsProductsLoading] = useState(false);
  const [showAddProductModal, setShowAddProductModal] = useState(false);

  // Details Modal State
  const [detailsMerchant, setDetailsMerchant] = useState<MerchantEntity | null>(null);
  const [showPasswordInDetails, setShowPasswordInDetails] = useState(false);

  // Password Reset Modal State
  const [passwordMerchant, setPasswordMerchant] = useState<MerchantEntity | null>(null);
  const [newPasswordInput, setNewPasswordInput] = useState('');

  // Add Merchant Form State
  const [showAddMerchantModal, setShowAddMerchantModal] = useState(false);
  const [merchantName, setMerchantName] = useState('');
  const [merchantType, setMerchantType] = useState<'restaurant' | 'store'>('restaurant');
  const [merchantSubCategory, setMerchantSubCategory] = useState('مشاوي ومأكولات شرقية');
  const [merchantOwner, setMerchantOwner] = useState('');
  const [merchantPhone, setMerchantPhone] = useState('');
  const [merchantEmail, setMerchantEmail] = useState('');
  const [merchantPassword, setMerchantPassword] = useState('');
  const [merchantCommission, setMerchantCommission] = useState<number>(10);
  const [merchantAddress, setMerchantAddress] = useState('شارع الأطباء - القائم');

  // Edit Merchant Details State
  const [editingMerchant, setEditingMerchant] = useState<MerchantEntity | null>(null);
  const [editName, setEditName] = useState('');
  const [editSubCategory, setEditSubCategory] = useState('');
  const [editOwner, setEditOwner] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editPassword, setEditPassword] = useState('');
  const [editAddress, setEditAddress] = useState('');
  const [editCommission, setEditCommission] = useState<number>(10);

  // Add Product Form State
  const [newProdName, setNewProdName] = useState('');
  const [newProdCategory, setNewProdCategory] = useState('وجبات رئيسية');
  const [newProdPrice, setNewProdPrice] = useState<number>(5000);
  const [newProdDesc, setNewProdDesc] = useState('');

  useEffect(() => {
    setIsLoading(true);
    const unsubscribeMerchants = MerchantsRepository.subscribeToMerchants((data) => {
      setMerchants(data);
      setIsLoading(false);

      if (detailsMerchant) {
        const updated = data.find(m => m.merchantId === detailsMerchant.merchantId);
        if (updated) setDetailsMerchant(updated);
      }
    });

    const unsubscribeOrders = OrdersRepository.subscribeToAllOrders((ordersData) => {
      setAllOrders(ordersData);
    });

    return () => {
      unsubscribeMerchants();
      unsubscribeOrders();
    };
  }, []);

  // Listen to products when a merchant is selected
  useEffect(() => {
    if (!selectedMerchant) return;

    setIsProductsLoading(true);
    const unsub = MerchantsRepository.subscribeToProducts(
      selectedMerchant.merchantId,
      selectedMerchant.category as any,
      (data) => {
        setProducts(data);
        setIsProductsLoading(false);
      }
    );

    return () => unsub();
  }, [selectedMerchant]);

  // Listen to dedicated store orders when a merchant orders view is opened
  useEffect(() => {
    if (!storeOrdersMerchant) {
      setStoreOrders([]);
      return;
    }

    setIsStoreOrdersLoading(true);
    const unsub = MerchantsRepository.subscribeToMerchantOrders(
      storeOrdersMerchant.merchantId,
      storeOrdersMerchant.name,
      (data) => {
        setStoreOrders(data);
        setIsStoreOrdersLoading(false);
      }
    );

    return () => unsub();
  }, [storeOrdersMerchant]);

  // Store Orders Statistics
  const storeOrdersStats = useMemo(() => {
    const totalOrdersCount = storeOrders.length;
    const deliveredOrders = storeOrders.filter(o => 
      o.rawStatus.includes('deliver') || 
      o.rawStatus.includes('complet') || 
      o.rawStatus.includes('تم') ||
      o.status.includes('تم') ||
      o.status.includes('مكتمل')
    );
    const cancelledOrders = storeOrders.filter(o => 
      o.rawStatus.includes('cancel') || 
      o.rawStatus.includes('reject') || 
      o.status.includes('ملغي')
    );
    const activeOrders = storeOrders.filter(o => 
      !deliveredOrders.includes(o) && !cancelledOrders.includes(o)
    );

    const validOrders = storeOrders.filter(o => !cancelledOrders.includes(o));
    const totalGmv = validOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const totalCommission = validOrders.reduce((sum, o) => sum + (o.commissionIqd || 0), 0);
    const totalNetPayout = validOrders.reduce((sum, o) => sum + (o.merchantNetIqd || 0), 0);

    return {
      totalOrdersCount,
      deliveredCount: deliveredOrders.length,
      activeCount: activeOrders.length,
      cancelledCount: cancelledOrders.length,
      totalGmv,
      totalCommission,
      totalNetPayout
    };
  }, [storeOrders]);

  // Filtered Store Orders
  const filteredStoreOrders = useMemo(() => {
    return storeOrders.filter(o => {
      // 1. Status Filter
      if (storeOrdersStatusFilter === 'delivered') {
        const isDeliv = o.rawStatus.includes('deliver') || o.rawStatus.includes('complet') || o.status.includes('تم') || o.status.includes('مكتمل');
        if (!isDeliv) return false;
      } else if (storeOrdersStatusFilter === 'active') {
        const isDeliv = o.rawStatus.includes('deliver') || o.rawStatus.includes('complet') || o.status.includes('تم') || o.status.includes('مكتمل');
        const isCanc = o.rawStatus.includes('cancel') || o.rawStatus.includes('reject') || o.status.includes('ملغي');
        if (isDeliv || isCanc) return false;
      } else if (storeOrdersStatusFilter === 'cancelled') {
        const isCanc = o.rawStatus.includes('cancel') || o.rawStatus.includes('reject') || o.status.includes('ملغي');
        if (!isCanc) return false;
      }

      // 2. Search
      if (!storeOrdersSearch.trim()) return true;
      const q = storeOrdersSearch.toLowerCase().trim();
      return (
        o.orderId.toLowerCase().includes(q) ||
        o.customerName.toLowerCase().includes(q) ||
        (o.customerPhone && o.customerPhone.includes(q)) ||
        o.itemsSummary.toLowerCase().includes(q) ||
        (o.driverName && o.driverName.toLowerCase().includes(q)) ||
        (o.deliveryAddress && o.deliveryAddress.toLowerCase().includes(q))
      );
    });
  }, [storeOrders, storeOrdersStatusFilter, storeOrdersSearch]);

  const handleExportStoreOrdersCSV = () => {
    if (!storeOrdersMerchant || filteredStoreOrders.length === 0) {
      showToast('ماكو طلبات حالياً لتصديرها', 'error');
      return;
    }
    const headers = ['رقم الطلب', 'تاريخ الطلب', 'اسم الزبون', 'رقم الهاتف', 'العنوان', 'الأصناف المطلوبة', 'المبلغ الكلي د.ع', 'عمولة مدار د.ع', 'صافي المتجر د.ع', 'الكابتن المكلف', 'الحالة'];
    const rows = filteredStoreOrders.map(o => [
      `"${o.orderId}"`,
      `"${o.createdAt}"`,
      `"${o.customerName.replace(/"/g, '""')}"`,
      `"${o.customerPhone || ''}"`,
      `"${(o.deliveryAddress || '').replace(/"/g, '""')}"`,
      `"${(o.itemsSummary || '').replace(/"/g, '""')}"`,
      o.totalPriceIqd,
      o.commissionIqd,
      o.merchantNetIqd,
      `"${(o.driverName || 'غير محدد').replace(/"/g, '""')}"`,
      `"${o.status}"`
    ]);
    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `orders_${storeOrdersMerchant.name}_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير كشف مبيعات وطلبات المتجر بنجاح ');
  };

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const handleToggleStatus = async (merchant: MerchantEntity) => {
    const nextState = !merchant.isOpen;
    setActionLoadingId(merchant.merchantId);
    try {
      await MerchantsRepository.toggleMerchantStatus(merchant.merchantId, merchant.category as any, nextState);
      showToast(nextState ? 'تم فتح المتجر لاستقبال الطلبات' : 'تم إغلاق المتجر مؤقتاً');
    } catch (err: any) {
      showToast('تعذر تغيير حالة المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleApproveMerchant = async (merchant: MerchantEntity) => {
    if (!window.confirm(`هل أنت متأكد من اعتماد وتوثيق (${merchant.name}) رسمياً في المنظومة؟`)) return;
    setActionLoadingId(merchant.merchantId);
    try {
      await MerchantsRepository.approveMerchant(merchant.merchantId, merchant.category as any);
      showToast(`تم توثيق واعتماد ${merchant.name} بنجاح `);
    } catch (err: any) {
      showToast('فشل اعتماد المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleSuspendMerchant = async (merchant: MerchantEntity) => {
    const reason = window.prompt(`أدخل سبب إيقاف أو حظر (${merchant.name}):`, 'مخالفة معايير الجودة');
    if (reason === null) return;
    setActionLoadingId(merchant.merchantId);
    try {
      await MerchantsRepository.suspendMerchant(merchant.merchantId, merchant.category as any, reason);
      showToast(`تم إيقاف (${merchant.name}) بنجاح`);
    } catch (err: any) {
      showToast('فشل إيقاف المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleSaveCommission = async (merchant: MerchantEntity) => {
    setActionLoadingId(merchant.merchantId);
    try {
      await MerchantsRepository.updateCommissionRate(merchant.merchantId, merchant.category as any, newCommissionValue);
      showToast(`تم تحديث عمولة ${merchant.name} إلى ${newCommissionValue}%`);
      setEditingCommissionId(null);
    } catch (err: any) {
      showToast('ما قدرنا نحدث العمولة: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleOpenEditMerchant = (merchant: MerchantEntity) => {
    setEditingMerchant(merchant);
    setEditName(merchant.name);
    setEditSubCategory(merchant.subCategory || '');
    setEditOwner(merchant.ownerName);
    setEditPhone(merchant.phone);
    setEditEmail(merchant.email !== 'لا يوجد بريد' ? (merchant.email || '') : '');
    setEditPassword(merchant.password !== 'غير محددة' ? (merchant.password || '') : '');
    setEditAddress(merchant.address || 'قضاء القائم');
    setEditCommission(merchant.commissionRate || 10);
  };

  const handleSaveMerchantDetails = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingMerchant) return;

    setActionLoadingId(editingMerchant.merchantId);
    try {
      await MerchantsRepository.updateMerchantDetails(editingMerchant.merchantId, editingMerchant.category as any, {
        name: editName.trim(),
        subCategory: editSubCategory.trim(),
        ownerName: editOwner.trim(),
        phone: editPhone.trim(),
        email: editEmail.trim() || undefined,
        password: editPassword.trim() || undefined,
        address: editAddress.trim(),
        commissionRate: Number(editCommission) || 10
      });

      showToast(`تم تحديث بيانات وحساب (${editName}) بنجاح دون فقدان أي بيانات `);
      setEditingMerchant(null);
    } catch (err: any) {
      showToast('فشل تحديث بيانات المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleUpdatePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!passwordMerchant || !newPasswordInput.trim()) return;

    if (newPasswordInput.trim().length < 6) {
      showToast('كلمة المرور يجب أن لا تقل عن 6 خانات', 'error');
      return;
    }

    setActionLoadingId(passwordMerchant.merchantId);
    try {
      await MerchantsRepository.updateMerchantPassword(
        passwordMerchant.merchantId,
        passwordMerchant.category as any,
        newPasswordInput.trim()
      );
      showToast(`تم تعيين كلمة المرور الجديدة لـ (${passwordMerchant.name}) بنجاح `);
      setPasswordMerchant(null);
      setNewPasswordInput('');
    } catch (err: any) {
      showToast('فشل تحديث كلمة المرور: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDeleteMerchant = async (merchant: MerchantEntity) => {
    if (!window.confirm(` تحذير: هل أنت متأكد من رغبتك في حذف (${merchant.name}) نهائياً من النظام وقاعدة البيانات؟`)) return;

    setMerchants(prev => prev.filter(m => m.merchantId !== merchant.merchantId));
    setActionLoadingId(merchant.merchantId);

    try {
      await MerchantsRepository.deleteMerchant(merchant.merchantId, merchant.category as any);
      showToast(`تم حذف ${merchant.name} بنجاح من قاعدة البيانات `);
      if (selectedMerchant?.merchantId === merchant.merchantId) setSelectedMerchant(null);
      if (detailsMerchant?.merchantId === merchant.merchantId) setDetailsMerchant(null);
    } catch (err: any) {
      showToast('تعذر حذف المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleAddMerchant = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!merchantName.trim() || !merchantOwner.trim() || !merchantPhone.trim()) {
      showToast('يرجى ملء جميع الحقول المطلوبة', 'error');
      return;
    }

    try {
      await MerchantsRepository.addMerchant({
        name: merchantName,
        category: merchantType,
        subCategory: merchantSubCategory,
        ownerName: merchantOwner,
        phone: merchantPhone,
        email: merchantEmail,
        password: merchantPassword,
        commissionRate: merchantCommission,
        address: merchantAddress
      });

      showToast(`تمت إضافة ${merchantName} بنجاح إلى منظومة مدار `);
      setShowAddMerchantModal(false);
      setMerchantName('');
      setMerchantOwner('');
      setMerchantPhone('');
      setMerchantEmail('');
      setMerchantPassword('');
    } catch (err: any) {
      showToast('فشل إضافة المتجر: ' + (err.message || ''), 'error');
    }
  };

  const handleAddProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMerchant || !newProdName.trim()) return;

    try {
      await MerchantsRepository.addProduct(
        selectedMerchant.merchantId,
        selectedMerchant.category as any,
        {
          name: newProdName.trim(),
          category: newProdCategory.trim() || 'عام',
          price: Number(newProdPrice) || 0,
          description: newProdDesc.trim(),
          isAvailable: true,
          salesCount: 0
        }
      );
      showToast('تمت إضافة الصنف بنجاح إلى قائمة المتجر ');
      setShowAddProductModal(false);
      setNewProdName('');
      setNewProdDesc('');
      setNewProdPrice(5000);
    } catch (err: any) {
      showToast('فشل إضافة الصنف: ' + (err.message || ''), 'error');
    }
  };

  const handleDeleteProduct = async (productId: string, productName: string) => {
    if (!selectedMerchant) return;
    if (!window.confirm(`متأكد تريد تحذف المنتج (${productName}) من قائمة المتجر؟`)) return;

    setProducts(prev => prev.filter(p => p.id !== productId));

    try {
      await MerchantsRepository.deleteProduct(
        selectedMerchant.merchantId,
        selectedMerchant.category as any,
        productId
      );
      showToast(`تم حذف ${productName} من القائمة `);
    } catch (err: any) {
      showToast('فشل حذف المنتج: ' + (err.message || ''), 'error');
    }
  };

  const handleToggleProductAvailability = async (prod: ProductItemEntity) => {
    if (!selectedMerchant) return;
    try {
      await MerchantsRepository.updateProduct(
        selectedMerchant.merchantId,
        selectedMerchant.category as any,
        prod.id,
        { isAvailable: !prod.isAvailable }
      );
      showToast(`تم تغيير توفر (${prod.name})`);
    } catch (err: any) {
      showToast('فشل تحديث المنتج: ' + (err.message || ''), 'error');
    }
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  const getMerchantSalesStats = (merchant: MerchantEntity) => {
    const mId = merchant.merchantId;
    const mName = merchant.name.trim().toLowerCase();
    const mPhone = (merchant.phone || '').trim();

    const matchedOrders = allOrders.filter(o => {
      const oId = o.merchantId;
      const oTitle = (o.merchantOrTitle || '').trim().toLowerCase();
      const oPhone = (o.merchantPhone || '').trim();
      return (
        (oId && oId === mId) ||
        (oTitle && (oTitle === mName || oTitle.includes(mName) || mName.includes(oTitle))) ||
        (mPhone && oPhone && oPhone.length > 5 && (oPhone === mPhone || mPhone.includes(oPhone) || oPhone.includes(mPhone)))
      );
    });

    const totalOrdersCount = Math.max(matchedOrders.length, merchant.totalOrders || 0);
    const completedOrders = matchedOrders.filter(o => 
      o.rawStatus.includes('deliver') || 
      o.rawStatus.includes('complet') || 
      o.status.includes('تم') || 
      o.status.includes('مكتمل')
    );
    const validOrders = matchedOrders.filter(o => !o.rawStatus.includes('cancel') && !o.rawStatus.includes('reject') && !o.status.includes('ملغي'));

    const dynamicSalesIqd = validOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const totalSalesIqd = Math.max(dynamicSalesIqd, merchant.totalRevenueIqd || 0);
    const commissionRate = merchant.commissionRate || 10;
    const totalCommissionIqd = validOrders.reduce((sum, o) => sum + (o.commissionIqd || Math.round((o.totalPriceIqd || 0) * (commissionRate / 100))), 0);
    const totalNetProfitIqd = Math.max(0, totalSalesIqd - (totalCommissionIqd || Math.round(totalSalesIqd * (commissionRate / 100))));

    return {
      totalOrdersCount,
      completedCount: completedOrders.length,
      totalSalesIqd,
      totalCommissionIqd,
      totalNetProfitIqd
    };
  };

  const overallStats = useMemo(() => {
    let gmv = 0;
    let net = 0;
    let ordersCount = 0;

    merchants.forEach(m => {
      const s = getMerchantSalesStats(m);
      gmv += s.totalSalesIqd;
      net += s.totalNetProfitIqd;
      ordersCount += s.totalOrdersCount;
    });

    return {
      totalMerchants: merchants.length,
      restaurantsCount: merchants.filter(m => m.category === 'restaurant').length,
      storesCount: merchants.filter(m => m.category === 'store').length,
      totalGmv: gmv,
      totalNet: net,
      totalOrders: ordersCount
    };
  }, [merchants, allOrders]);

  const verifiedMerchantsCount = useMemo(() => merchants.filter(m => m.status === 'active' || (m.status !== 'pending' && m.status !== 'suspended')).length, [merchants]);
  const pendingMerchantsCount = useMemo(() => merchants.filter(m => m.status === 'pending').length, [merchants]);
  const suspendedMerchantsCount = useMemo(() => merchants.filter(m => m.status === 'suspended').length, [merchants]);

  const filtered = merchants.filter(m => {
    // 1. Approval / Status Filter (Separate Verified vs Waiting List vs Suspended)
    if (selectedApprovalStatus === 'verified' && (m.status === 'pending' || m.status === 'suspended')) return false;
    if (selectedApprovalStatus === 'pending' && m.status !== 'pending') return false;
    if (selectedApprovalStatus === 'suspended' && m.status !== 'suspended') return false;

    // 2. Category
    let matchesCategory = true;
    if (activeCategory === 'restaurant') {
      matchesCategory = m.category === 'restaurant';
    } else if (activeCategory === 'store') {
      matchesCategory = m.category === 'store' && !m.subCategory?.includes('صيدلي');
    } else if (activeCategory === 'pharmacy') {
      matchesCategory = (m.subCategory || '').includes('صيدلي') || (m.name || '').includes('صيدلية');
    }

    const q = searchQuery.toLowerCase().trim();
    if (!q) return matchesCategory;

    const matchesSearch = 
      m.name.toLowerCase().includes(q) || 
      m.ownerName.toLowerCase().includes(q) ||
      m.phone.includes(q) ||
      (m.subCategory && m.subCategory.toLowerCase().includes(q)) ||
      (m.address && m.address.toLowerCase().includes(q));

    return matchesCategory && matchesSearch;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Store size={22} color="#06b6d4" /> إدارة المتاجر والمطاعم (مرتبة حسب الأحدث)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            استعراض وتعديل تفاصيل المتاجر، تغيير كلمات المرور، إدارة الأصناف، وتتبع المبيعات
          </p>
        </div>
        
        <div style={{ display: 'flex', gap: '10px' }}>
          {selectedMerchant ? (
            <button 
              onClick={() => setSelectedMerchant(null)}
              className="btn btn-secondary" 
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}
            >
              <ArrowRight size={14} /> العودة لقائمة المتاجر
            </button>
          ) : (
            <button 
              onClick={() => setShowAddMerchantModal(true)}
              className="btn btn-primary" 
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '700' }}
            >
              <Plus size={16} /> إضافة متجر / مطعم جديد
            </button>
          )}
        </div>
      </div>

      {/* ─── VIEW 1: PRODUCTS & CATALOG MANAGEMENT (When a Merchant is Selected) ─── */}
      {selectedMerchant ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          {/* Merchant Info Banner */}
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'linear-gradient(135deg, rgba(6, 182, 212, 0.1) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: '800', color: '#fff', margin: 0 }}>
                  قائمة أصناف: {selectedMerchant.name}
                </h3>
                <span className={`badge ${selectedMerchant.category === 'restaurant' ? 'badge-warning' : 'badge-info'}`}>
                  {selectedMerchant.category === 'restaurant' ? 'مطعم ' : 'متجر '}
                </span>
                <span className={`badge ${selectedMerchant.isOpen ? 'badge-success' : 'badge-danger'}`}>
                  {selectedMerchant.isOpen ? 'مفتوح للطلبات' : 'مغلق مؤقتاً'}
                </span>
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                المالك: {selectedMerchant.ownerName} | الهاتف: {selectedMerchant.phone} | العمولة: {selectedMerchant.commissionRate}%
              </div>
            </div>

            <button 
              onClick={() => setShowAddProductModal(true)}
              className="btn btn-primary" 
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '700' }}
            >
              <Plus size={16} /> إضافة صنف / منتج جديد
            </button>
          </div>

          {/* Products Table */}
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>الأصناف والمنتجات المسجلة ({products.length})</span>
              <span style={{ fontSize: '12px', color: 'var(--text-dim)' }}>مرتبطة بـ Firestore Subcollection</span>
            </div>

            {isProductsLoading ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                <div>جاري جلب قائمة المنتجات...</div>
              </div>
            ) : products.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Package size={32} color="#64748b" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>ماكو أصناف مضافة لهذا المتجر حالياً</div>
                <div style={{ fontSize: '11px', marginTop: '2px' }}>اضغط على "إضافة صنف / منتج جديد" لإضافة وجبة أو منتج</div>
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>اسم المنتج / الصنف</th>
                      <th>التصنيف / القسم</th>
                      <th>السعر</th>
                      <th>إجمالي المبيعات</th>
                      <th>التوفر</th>
                      <th>الإجراءات</th>
                    </tr>
                  </thead>
                  <tbody>
                    {products.map((prod) => (
                      <tr key={prod.id}>
                        <td>
                          <div style={{ fontWeight: '800', color: '#fff' }}>{prod.name}</div>
                          {prod.description && (
                            <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{prod.description}</div>
                          )}
                        </td>
                        <td>
                          <span className="badge badge-info">{prod.category}</span>
                        </td>
                        <td>
                          <span style={{ fontWeight: '700', color: '#34d399' }}>{formatIqd(prod.price)}</span>
                        </td>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <TrendingUp size={14} color="#38bdf8" />
                            <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>
                              {prod.salesCount} طلب
                            </span>
                          </div>
                        </td>
                        <td>
                          <button
                            onClick={() => handleToggleProductAvailability(prod)}
                            style={{
                              padding: '4px 10px',
                              borderRadius: '6px',
                              fontSize: '11px',
                              fontWeight: '700',
                              cursor: 'pointer',
                              background: prod.isAvailable ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                              color: prod.isAvailable ? '#34d399' : '#f87171',
                              border: `1px solid ${prod.isAvailable ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`
                            }}
                          >
                            {prod.isAvailable ? 'متوفر ' : 'غير متوفر '}
                          </button>
                        </td>
                        <td>
                          <button
                            onClick={() => handleDeleteProduct(prod.id, prod.name)}
                            title="حذف المنتج"
                            style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '6px' }}
                          >
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {/* Add Product Modal */}
          {showAddProductModal && (
            <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
              <div className="glass-panel" style={{ padding: '30px', maxWidth: '480px', width: '100%', borderRadius: '20px', border: '1px solid rgba(6, 182, 212, 0.3)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
                  <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', margin: 0 }}>
                    إضافة صنف / منتج جديد لـ ({selectedMerchant.name})
                  </h3>
                  <button onClick={() => setShowAddProductModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                    
                  </button>
                </div>

                <form onSubmit={handleAddProduct} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      اسم الصنف / المنتج:
                    </label>
                    <input
                      type="text"
                      required
                      value={newProdName}
                      onChange={(e) => setNewProdName(e.target.value)}
                      placeholder="مثال: برغر لحم دبل كلاسيك"
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                    />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        التصنيف / القسم:
                      </label>
                      <input
                        type="text"
                        value={newProdCategory}
                        onChange={(e) => setNewProdCategory(e.target.value)}
                        placeholder="مثال: برغر / مقبلات / مشروبات"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        السعر بالدينار العراقي:
                      </label>
                      <input
                        type="number"
                        step="250"
                        value={newProdPrice}
                        onChange={(e) => setNewProdPrice(Number(e.target.value))}
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      الوصف / المكونات:
                    </label>
                    <textarea
                      rows={2}
                      value={newProdDesc}
                      onChange={(e) => setNewProdDesc(e.target.value)}
                      placeholder="لحم عراقي طازج مع جبن شيدر وصوص خاص..."
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none', resize: 'vertical' }}
                    />
                  </div>

                  <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                    <button type="submit" className="btn btn-primary" style={{ flex: 1, padding: '10px', fontSize: '13px', fontWeight: '700' }}>
                      حفظ وإضافة الصنف
                    </button>
                    <button type="button" onClick={() => setShowAddProductModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>
                      إلغاء
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}

        </div>
      ) : (
        /* ─── VIEW 2: ALL MERCHANTS LIST ─── */
        <>
          {/* 4 Financial & Merchants KPI Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
            <div className="glass-panel" style={{ padding: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي الشركاء المسجلين</span>
                <Store size={18} color="#38bdf8" />
              </div>
              <div style={{ fontSize: '22px', fontWeight: '950', color: '#fff', marginTop: '6px' }}>
                {overallStats.totalMerchants} شريك
              </div>
              <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '3px' }}>
                 {overallStats.restaurantsCount} مطعم | {overallStats.storesCount} متجر
              </div>
            </div>

            <div className="glass-panel" style={{ padding: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي حجم مبيعات المتاجر (GMV)</span>
                <Coins size={18} color="#34d399" />
              </div>
              <div style={{ fontSize: '22px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
                {formatIqd(overallStats.totalGmv)}
              </div>
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
                عبر {overallStats.totalOrders} طلب منفذ في المنظومة
              </div>
            </div>

            <div className="glass-panel" style={{ padding: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>صافي أرباح ومستحقات التجار</span>
                <DollarIcon size={18} color="#fbbf24" />
              </div>
              <div style={{ fontSize: '22px', fontWeight: '950', color: '#fbbf24', marginTop: '6px' }}>
                {formatIqd(overallStats.totalNet)}
              </div>
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
                مستحقات نقدية بعد خصم عمولة مدار
              </div>
            </div>

            <div className="glass-panel" style={{ padding: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي عدد الطلبات المسندة</span>
                <Package size={18} color="#a78bfa" />
              </div>
              <div style={{ fontSize: '22px', fontWeight: '950', color: '#a78bfa', marginTop: '6px' }}>
                {overallStats.totalOrders} طلب
              </div>
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
                رصد فوري لجميع العمليات
              </div>
            </div>
          </div>

          {/* Categories and Search Bar */}
          <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '14px' }}>
            <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
              <button 
                onClick={() => setActiveCategory('all')}
                className={`btn ${activeCategory === 'all' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px' }}
              >
                 الكل ({merchants.length})
              </button>
              <button 
                onClick={() => setActiveCategory('restaurant')}
                className={`btn ${activeCategory === 'restaurant' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
              >
                <UtensilsCrossed size={14} /> المطاعم ({merchants.filter(m => m.category === 'restaurant').length})
              </button>
              <button 
                onClick={() => setActiveCategory('store')}
                className={`btn ${activeCategory === 'store' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
              >
                <ShoppingBag size={14} /> المتاجر والسوبرماركت ({merchants.filter(m => m.category === 'store' && !m.subCategory?.includes('صيدلي')).length})
              </button>
              <button 
                onClick={() => setActiveCategory('pharmacy')}
                className={`btn ${activeCategory === 'pharmacy' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
              >
                 الصيدليات ({merchants.filter(m => (m.subCategory || '').includes('صيدلي') || (m.name || '').includes('صيدلية')).length})
              </button>
            </div>

            <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '280px' }}>
              <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
              <input
                type="text"
                placeholder="ابحث بالاسم، المالك، الهاتف، أو القسم..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{
                  width: '100%',
                  padding: '8px 36px 8px 12px',
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border-color)',
                  borderRadius: '8px',
                  color: '#fff',
                  fontSize: '13px',
                  outline: 'none'
                }}
              />
            </div>

            {/* Row 2: Status Segments (Separating Verified vs Waiting List vs Suspended) */}
            <div style={{ width: '100%', display: 'flex', gap: '8px', overflowX: 'auto', borderTop: '1px solid var(--border-color)', paddingTop: '10px' }}>
              <button 
                onClick={() => setSelectedApprovalStatus('verified')}
                className={`btn ${selectedApprovalStatus === 'verified' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '800' }}
              >
                <ShieldCheck size={14} color="#34d399" />
                <span> المتاجر والمطاعم الموثوقة والمعتمدة ({verifiedMerchantsCount})</span>
              </button>

              <button 
                onClick={() => setSelectedApprovalStatus('pending')}
                className={`btn ${selectedApprovalStatus === 'pending' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ 
                  fontSize: '12px', 
                  padding: '6px 14px', 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '6px', 
                  fontWeight: '800',
                  borderColor: pendingMerchantsCount > 0 ? '#f59e0b' : undefined,
                  color: selectedApprovalStatus === 'pending' ? '#fff' : (pendingMerchantsCount > 0 ? '#fbbf24' : undefined)
                }}
              >
                <AlertCircle size={14} color="#f59e0b" />
                <span> قائمة الانتظار وقيد المراجعة ({pendingMerchantsCount})</span>
              </button>

              <button 
                onClick={() => setSelectedApprovalStatus('suspended')}
                className={`btn ${selectedApprovalStatus === 'suspended' ? 'btn-danger' : 'btn-secondary'}`}
                style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
              >
                <Ban size={14} />
                <span> المحلات المعلقة والمحظورة ({suspendedMerchantsCount})</span>
              </button>

              <button 
                onClick={() => setSelectedApprovalStatus('all')}
                className={`btn ${selectedApprovalStatus === 'all' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <span> عرض الكل ({merchants.length})</span>
              </button>
            </div>
          </div>

          {/* Merchants Table */}
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            {isLoading ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                <div>جاري جلب بيانات المتاجر والمطاعم من Firestore...</div>
              </div>
            ) : filtered.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Store size={32} color="#64748b" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>ماكو متاجر أو مطاعم مسجلة حالياً</div>
                <div style={{ fontSize: '11px', marginTop: '4px' }}>اضغط على "إضافة متجر / مطعم جديد" لإضافة أول شريك</div>
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>اسم المتجر / المطعم</th>
                      <th>النوع والقسم</th>
                      <th>المالك ورقم الهاتف</th>
                      <th>تاريخ التسجيل</th>
                      <th>نسبة العمولة</th>
                      <th>حالة العمل</th>
                      <th>إجمالي المبيعات والأرباح </th>
                      <th>كشف الطلبات </th>
                      <th>الأصناف والمنيو</th>
                      <th>الإجراءات والملف</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map(m => {
                      const salesStats = getMerchantSalesStats(m);

                      return (
                        <tr key={m.merchantId}>
                          <td>
                            <div style={{ fontWeight: '800', color: '#fff' }}>{m.name}</div>
                            <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}> {m.address || 'القائم'}</div>
                          </td>
                          <td>
                            <span className={`badge ${m.category === 'restaurant' ? 'badge-warning' : 'badge-info'}`}>
                              {m.category === 'restaurant' ? 'مطعم ' : 'متجر '}
                            </span>
                            {m.subCategory && (
                              <div style={{ fontSize: '10.5px', color: 'var(--text-muted)', marginTop: '2px' }}>{m.subCategory}</div>
                            )}
                          </td>
                          <td>
                            <div style={{ color: '#fff', fontSize: '12.5px' }}>{m.ownerName}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{m.phone}</div>
                          </td>
                          <td>
                            <div style={{ fontSize: '12px', color: '#cbd5e1' }}>{m.createdAt}</div>
                          </td>
                          <td>
                            {editingCommissionId === m.merchantId ? (
                              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                <input
                                  type="number"
                                  min="0"
                                  max="50"
                                  value={newCommissionValue}
                                  onChange={e => setNewCommissionValue(Number(e.target.value))}
                                  style={{ width: '55px', padding: '4px', background: '#0f172a', border: '1px solid #06b6d4', borderRadius: '4px', color: '#fff', fontSize: '12px', textAlign: 'center' }}
                                />
                                <button onClick={() => handleSaveCommission(m)} className="btn btn-primary" style={{ padding: '2px 6px', fontSize: '10px' }}>حفظ</button>
                                <button onClick={() => setEditingCommissionId(null)} className="btn btn-secondary" style={{ padding: '2px 6px', fontSize: '10px' }}>إلغاء</button>
                              </div>
                            ) : (
                              <div onClick={() => { setEditingCommissionId(m.merchantId); setNewCommissionValue(m.commissionRate); }} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}>
                                <span style={{ fontWeight: '800', color: '#38bdf8' }}>{m.commissionRate}%</span>
                                <span style={{ fontSize: '10px', color: 'var(--text-dim)' }}></span>
                              </div>
                            )}
                          </td>
                          <td>
                            <button
                              onClick={() => handleToggleStatus(m)}
                              disabled={actionLoadingId === m.merchantId}
                              style={{
                                padding: '4px 10px',
                                borderRadius: '6px',
                                fontSize: '11px',
                                fontWeight: '700',
                                cursor: 'pointer',
                                background: m.isOpen ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                                color: m.isOpen ? '#34d399' : '#f87171',
                                border: `1px solid ${m.isOpen ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`
                              }}
                            >
                              {m.isOpen ? 'مفتوح للطلبات ' : 'مغلق مؤقتاً '}
                            </button>
                          </td>

                          {/* Live Dynamic Sales & Profits */}
                          <td>
                            <div style={{ fontWeight: '900', color: salesStats.totalSalesIqd > 0 ? '#34d399' : '#cbd5e1', fontSize: '13.5px' }}>
                              {formatIqd(salesStats.totalSalesIqd)}
                            </div>
                            <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '2px' }}>
                              {salesStats.totalOrdersCount} طلب ({salesStats.completedCount} مكتمل)
                            </div>
                            {salesStats.totalNetProfitIqd > 0 && (
                              <div style={{ fontSize: '10.5px', color: '#fbbf24', marginTop: '1px' }}>
                                صافي المتجر: {formatIqd(salesStats.totalNetProfitIqd)}
                              </div>
                            )}
                          </td>

                          {/* Store Dedicated Orders & Sales */}
                          <td>
                            <button
                              onClick={() => setStoreOrdersMerchant(m)}
                              className="btn btn-primary"
                              style={{ fontSize: '11px', padding: '5px 10px', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8', display: 'flex', alignItems: 'center', gap: '5px', fontWeight: '800' }}
                              title="عرض كشف مبيعات وطلبات هذا المتجر"
                            >
                              <ShoppingBag size={13} />
                              <span>كشف الطلبات </span>
                            </button>
                          </td>

                          {/* Menu / Catalog */}
                          <td>
                            <button
                              onClick={() => setSelectedMerchant(m)}
                              className="btn btn-secondary"
                              style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
                            >
                              <Package size={13} color="#06b6d4" />
                              <span>الأصناف والمنيو</span>
                            </button>
                          </td>

                        {/* Actions */}
                        <td>
                          <div style={{ display: 'flex', gap: '4px' }}>
                            {m.status === 'pending' && (
                              <button
                                onClick={() => handleApproveMerchant(m)}
                                disabled={actionLoadingId === m.merchantId}
                                className="btn btn-primary"
                                style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '3px', background: 'linear-gradient(135deg, #10b981, #059669)', borderColor: '#34d399' }}
                                title="اعتماد وتوثيق الشريك فوراً"
                              >
                                <Check size={13} />
                                <span>اعتماد</span>
                              </button>
                            )}
                            <button
                              onClick={() => setDetailsMerchant(m)}
                              className="btn btn-secondary"
                              style={{ fontSize: '11px', padding: '5px 7px', display: 'flex', alignItems: 'center', gap: '3px' }}
                              title="عرض تفاصيل المتجر"
                            >
                              <Eye size={13} color="#06b6d4" />
                              <span>الملف</span>
                            </button>
                            <button
                              onClick={() => { setPasswordMerchant(m); setNewPasswordInput(''); }}
                              className="btn btn-secondary"
                              style={{ fontSize: '11px', padding: '5px 7px', display: 'flex', alignItems: 'center', gap: '3px', color: '#fbbf24' }}
                              title="تغيير كلمة المرور"
                            >
                              <Key size={13} />
                              <span>الرمز</span>
                            </button>
                            <button
                              onClick={() => handleOpenEditMerchant(m)}
                              className="btn btn-secondary"
                              style={{ fontSize: '11px', padding: '5px 7px', display: 'flex', alignItems: 'center', gap: '3px' }}
                              title="تعديل بيانات المتجر"
                            >
                              <Edit3 size={13} />
                            </button>
                            <button
                              onClick={() => handleDeleteMerchant(m)}
                              disabled={actionLoadingId === m.merchantId}
                              title="حذف المتجر نهائياً"
                              style={{
                                background: 'transparent',
                                border: 'none',
                                color: '#ef4444',
                                cursor: 'pointer',
                                padding: '5px'
                              }}
                            >
                              <Trash2 size={15} />
                            </button>
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

          {/* ─── MODAL 1: FULL MERCHANT DETAILS MODAL ─── */}
          {detailsMerchant && (
            <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
              <div className="glass-panel" style={{ padding: '28px', maxWidth: '620px', width: '100%', borderRadius: '24px', border: '1px solid rgba(6, 182, 212, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-color)', paddingBottom: '14px', marginBottom: '18px' }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>{detailsMerchant.name}</h3>
                      <span className={`badge ${detailsMerchant.category === 'restaurant' ? 'badge-warning' : 'badge-info'}`}>
                        {detailsMerchant.category === 'restaurant' ? 'مطعم ' : 'متجر '}
                      </span>
                    </div>
                    <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginTop: '3px' }}>ID: <code>{detailsMerchant.merchantId}</code> | الانضمام: {detailsMerchant.createdAt}</div>
                  </div>
                  <button onClick={() => setDetailsMerchant(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                    
                  </button>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '20px' }}>
                  <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>صاحب المتجر / المالك</div>
                    <div style={{ fontSize: '13px', fontWeight: '800', color: '#fff', marginTop: '4px' }}>{detailsMerchant.ownerName}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{detailsMerchant.phone}</div>
                  </div>

                  <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>العنوان في القائم</div>
                    <div style={{ fontSize: '13px', fontWeight: '800', color: '#fff', marginTop: '4px' }}> {detailsMerchant.address || 'قضاء القائم'}</div>
                  </div>

                  {/* Email Box */}
                  <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>البريد الإلكتروني للحساب</span>
                      {detailsMerchant.email && (
                        <button
                          onClick={() => {
                            navigator.clipboard.writeText(detailsMerchant.email || '');
                            showToast('تم نسخ البريد الإلكتروني ');
                          }}
                          style={{ background: 'transparent', border: 'none', color: '#38bdf8', cursor: 'pointer', fontSize: '11px' }}
                        >
                          نسخ 
                        </button>
                      )}
                    </div>
                    <div style={{ fontSize: '13px', fontWeight: '800', color: '#38bdf8', marginTop: '4px', wordBreak: 'break-all' }}>
                      {detailsMerchant.email || 'لا يوجد بريد مسجل'}
                    </div>
                  </div>

                  {/* Password Box */}
                  <div style={{ background: 'rgba(251, 191, 36, 0.08)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(251, 191, 36, 0.3)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontSize: '11px', color: '#fbbf24', fontWeight: '700' }}>كلمة المرور / الرمز السري</span>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          onClick={() => setShowPasswordInDetails(!showPasswordInDetails)}
                          style={{ background: 'transparent', border: 'none', color: '#fbbf24', cursor: 'pointer', fontSize: '11px' }}
                        >
                          {showPasswordInDetails ? 'إخفاء ' : 'إظهار '}
                        </button>
                        <button
                          onClick={() => {
                            navigator.clipboard.writeText(detailsMerchant.password || '');
                            showToast('تم نسخ كلمة المرور ');
                          }}
                          style={{ background: 'transparent', border: 'none', color: '#fbbf24', cursor: 'pointer', fontSize: '11px' }}
                        >
                          نسخ 
                        </button>
                      </div>
                    </div>
                    <div style={{ fontSize: '14px', fontWeight: '900', color: '#fff', marginTop: '4px', letterSpacing: showPasswordInDetails ? '1px' : '3px' }}>
                      {showPasswordInDetails ? (detailsMerchant.password || 'غير محددة') : '••••••••'}
                    </div>
                  </div>

                  <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>نسبة عمولة التطبيق</div>
                    <div style={{ fontSize: '14px', fontWeight: '800', color: '#38bdf8', marginTop: '4px' }}>{detailsMerchant.commissionRate}%</div>
                  </div>

                  <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>النشاط والتصنيف</div>
                    <div style={{ fontSize: '13px', fontWeight: '800', color: '#fbbf24', marginTop: '4px' }}>{detailsMerchant.subCategory || 'عام'}</div>
                  </div>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '16px', flexWrap: 'wrap', gap: '10px' }}>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    <button
                      onClick={() => {
                        const m = detailsMerchant;
                        setDetailsMerchant(null);
                        setStoreOrdersMerchant(m);
                      }}
                      className="btn btn-primary"
                      style={{ fontSize: '12px', background: 'linear-gradient(135deg, #0284c7, #0369a1)', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '800' }}
                    >
                      <ShoppingBag size={14} />
                      <span>كشف المبيعات والطلبات </span>
                    </button>
                    <button
                      onClick={() => {
                        const m = detailsMerchant;
                        setDetailsMerchant(null);
                        setSelectedMerchant(m);
                      }}
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                    >
                      <Package size={14} />
                      <span>إدارة الأصناف والمنيو</span>
                    </button>
                    <button
                      onClick={() => {
                        const m = detailsMerchant;
                        setDetailsMerchant(null);
                        setPasswordMerchant(m);
                        setNewPasswordInput('');
                      }}
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', color: '#fbbf24', border: '1px solid #fbbf24', display: 'flex', alignItems: 'center', gap: '6px' }}
                    >
                      <Key size={13} />
                      <span>تغيير كلمة المرور</span>
                    </button>
                  </div>

                  <button
                    onClick={() => handleDeleteMerchant(detailsMerchant)}
                    style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                  >
                    <Trash2 size={14} /> حذف المتجر
                  </button>
                </div>

              </div>
            </div>
          )}

          {/* ─── MODAL: DEDICATED STORE ORDERS & SALES LEDGER ─── */}
          {storeOrdersMerchant && (
            <div style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.85)',
              backdropFilter: 'blur(8px)',
              zIndex: 10000,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              padding: '16px'
            }}>
              <div className="glass-panel" style={{
                width: '100%',
                maxWidth: '1050px',
                maxHeight: '94vh',
                display: 'flex',
                flexDirection: 'column',
                overflow: 'hidden',
                padding: 0,
                borderRadius: '20px',
                border: '1px solid rgba(56, 189, 248, 0.3)',
                boxShadow: '0 25px 70px rgba(0,0,0,0.8)'
              }}>
                
                {/* Header */}
                <div style={{
                  padding: '18px 24px',
                  borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  background: 'rgba(15, 23, 42, 0.85)'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{ padding: '10px', borderRadius: '12px', background: 'rgba(6, 182, 212, 0.2)', color: '#38bdf8' }}>
                      <ShoppingBag size={24} />
                    </div>
                    <div>
                      <h3 style={{ margin: 0, color: '#fff', fontSize: '18px', fontWeight: '900', display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span>كشف مبيعات وسجل طلبات:</span>
                        <span style={{ color: '#38bdf8' }}>{storeOrdersMerchant.name}</span>
                        <span className={`badge ${storeOrdersMerchant.category === 'restaurant' ? 'badge-warning' : 'badge-info'}`} style={{ fontSize: '11px' }}>
                          {storeOrdersMerchant.category === 'restaurant' ? 'مطعم' : 'متجر'}
                        </span>
                      </h3>
                      <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '3px' }}>
                        المالك: <strong>{storeOrdersMerchant.ownerName}</strong> • هاتف: <span dir="ltr">{storeOrdersMerchant.phone}</span> • نسبة العمولة: <strong>{storeOrdersMerchant.commissionRate}%</strong>
                      </div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <button
                      onClick={handleExportStoreOrdersCSV}
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px', padding: '7px 12px' }}
                    >
                      <Download size={14} /> تصدير كشف CSV
                    </button>
                    <button
                      onClick={() => setStoreOrdersMerchant(null)}
                      style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: '6px' }}
                    >
                      <X size={22} />
                    </button>
                  </div>
                </div>

                {/* Body */}
                <div style={{ padding: '20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '18px' }}>
                  
                  {/* 4 Financial & Sales Metric Cards */}
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '12px' }}>
                    
                    {/* GMV Sales */}
                    <div style={{ background: 'rgba(56, 189, 248, 0.08)', border: '1px solid rgba(56, 189, 248, 0.25)', borderRadius: '12px', padding: '14px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي مبيعات المتجر (GMV)</span>
                        <DollarIcon size={16} color="#38bdf8" />
                      </div>
                      <div style={{ fontSize: '19px', fontWeight: '900', color: '#38bdf8', marginTop: '6px' }}>
                        {formatIqd(storeOrdersStats.totalGmv)}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>من {storeOrdersStats.totalOrdersCount} طلب</div>
                    </div>

                    {/* Net Store Payout */}
                    <div style={{ background: 'rgba(16, 185, 129, 0.08)', border: '1px solid rgba(16, 185, 129, 0.25)', borderRadius: '12px', padding: '14px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>صافي أرباح ومستحقات المتجر</span>
                        <Coins size={16} color="#34d399" />
                      </div>
                      <div style={{ fontSize: '19px', fontWeight: '900', color: '#34d399', marginTop: '6px' }}>
                        {formatIqd(storeOrdersStats.totalNetPayout)}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>بعد خصم عمولة مدار</div>
                    </div>

                    {/* Madar Commission Collected */}
                    <div style={{ background: 'rgba(251, 191, 36, 0.08)', border: '1px solid rgba(251, 191, 36, 0.25)', borderRadius: '12px', padding: '14px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>عمولة منصة مدار المحصلة</span>
                        <Percent size={16} color="#fbbf24" />
                      </div>
                      <div style={{ fontSize: '19px', fontWeight: '900', color: '#fbbf24', marginTop: '6px' }}>
                        {formatIqd(storeOrdersStats.totalCommission)}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>نسبة {storeOrdersMerchant.commissionRate}% لكل طلب</div>
                    </div>

                    {/* Orders Breakdown */}
                    <div style={{ background: 'rgba(255, 255, 255, 0.03)', border: '1px solid rgba(255, 255, 255, 0.08)', borderRadius: '12px', padding: '14px' }}>
                      <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>توزيع وحالات الطلبات</div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: '#fff', fontWeight: '700' }}>
                        <span style={{ color: '#34d399' }}> مكتمل: {storeOrdersStats.deliveredCount}</span>
                        <span style={{ color: '#38bdf8' }}> جاري: {storeOrdersStats.activeCount}</span>
                        <span style={{ color: '#f87171' }}> ملغي: {storeOrdersStats.cancelledCount}</span>
                      </div>
                    </div>

                  </div>

                  {/* Filter and Search Bar for Orders */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px', background: 'rgba(255, 255, 255, 0.02)', padding: '10px 14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                    
                    <div style={{ display: 'flex', gap: '6px', overflowX: 'auto' }}>
                      {[
                        { id: 'all', label: ` جميع الطلبات (${storeOrders.length})` },
                        { id: 'delivered', label: ` المكتملة والمسلّمة (${storeOrdersStats.deliveredCount})` },
                        { id: 'active', label: ` الجارية والنشطة (${storeOrdersStats.activeCount})` },
                        { id: 'cancelled', label: ` الملغاة (${storeOrdersStats.cancelledCount})` },
                      ].map(f => (
                        <button
                          key={f.id}
                          onClick={() => setStoreOrdersStatusFilter(f.id as any)}
                          className={`btn ${storeOrdersStatusFilter === f.id ? 'btn-primary' : 'btn-secondary'}`}
                          style={{ fontSize: '11.5px', padding: '5px 12px', borderRadius: '6px' }}
                        >
                          {f.label}
                        </button>
                      ))}
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', background: 'rgba(255, 255, 255, 0.05)', padding: '6px 12px', borderRadius: '8px', border: '1px solid rgba(255, 255, 255, 0.1)', minWidth: '240px' }}>
                      <Search size={14} color="#94a3b8" />
                      <input
                        type="text"
                        placeholder="ابحث برقم الطلب، العميل، أو الوجبة..."
                        value={storeOrdersSearch}
                        onChange={e => setStoreOrdersSearch(e.target.value)}
                        style={{ background: 'transparent', border: 'none', color: '#fff', fontSize: '12.5px', width: '100%', outline: 'none' }}
                      />
                      {storeOrdersSearch && <X size={12} color="#94a3b8" style={{ cursor: 'pointer' }} onClick={() => setStoreOrdersSearch('')} />}
                    </div>

                  </div>

                  {/* Orders Table */}
                  <div style={{ background: 'rgba(0,0,0,0.2)', borderRadius: '12px', border: '1px solid rgba(255, 255, 255, 0.05)', overflow: 'hidden' }}>
                    {isStoreOrdersLoading ? (
                      <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                        <Loader2 size={24} color="#38bdf8" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                        <div>جاري تحميل ومزامنة طلبات المتجر...</div>
                      </div>
                    ) : filteredStoreOrders.length === 0 ? (
                      <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                        <Package size={30} color="#64748b" style={{ margin: '0 auto 8px' }} />
                        <div style={{ fontSize: '13.5px', fontWeight: '700', color: '#fff' }}>ماكو طلبات حالياً مسجلة لهذا المتجر في هذا التصنيف</div>
                      </div>
                    ) : (
                      <div className="data-table-container" style={{ maxHeight: '420px', overflowY: 'auto' }}>
                        <table className="data-table">
                          <thead>
                            <tr>
                              <th>رقم الطلب والوقت</th>
                              <th>الزبون وبيانات التوصيل</th>
                              <th>الوجبات والأصناف المطلوبة</th>
                              <th>المبلغ الكلي</th>
                              <th>عمولة مدار</th>
                              <th>صافي المتجر</th>
                              <th>الكابتن المكلّف</th>
                              <th>الحالة</th>
                            </tr>
                          </thead>
                          <tbody>
                            {filteredStoreOrders.map(o => (
                              <tr key={o.orderId}>
                                <td>
                                  <div style={{ fontWeight: '800', color: '#38bdf8', fontSize: '12px' }}>
                                    #{o.orderId.substring(0, 8)}
                                  </div>
                                  <div style={{ fontSize: '10.5px', color: 'var(--text-muted)' }}>{o.createdAt}</div>
                                </td>
                                <td>
                                  <div style={{ fontWeight: '700', color: '#fff', fontSize: '12.5px' }}>{o.customerName}</div>
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '2px' }}>
                                    {o.customerPhone && (
                                      <a href={`tel:${o.customerPhone}`} style={{ fontSize: '11px', color: '#38bdf8', textDecoration: 'none', direction: 'ltr' }}>
                                        {o.customerPhone} 
                                      </a>
                                    )}
                                    {o.customerPhone && (
                                      <a href={`https://wa.me/${o.customerPhone.replace(/[^0-9]/g, '')}`} target="_blank" rel="noopener noreferrer" style={{ color: '#22c55e' }}>
                                        <MessageCircle size={13} />
                                      </a>
                                    )}
                                  </div>
                                  <div style={{ fontSize: '10.5px', color: 'var(--text-dim)', marginTop: '2px' }}> {o.deliveryAddress}</div>
                                </td>
                                <td>
                                  <div style={{ fontSize: '12px', color: '#fff', fontWeight: '600', maxWidth: '240px' }}>
                                    {o.itemsSummary}
                                  </div>
                                </td>
                                <td>
                                  <div style={{ fontWeight: '900', color: '#fff', fontSize: '13px' }}>
                                    {formatIqd(o.totalPriceIqd)}
                                  </div>
                                </td>
                                <td>
                                  <div style={{ fontWeight: '700', color: '#fbbf24', fontSize: '12px' }}>
                                    {formatIqd(o.commissionIqd)}
                                  </div>
                                </td>
                                <td>
                                  <div style={{ fontWeight: '800', color: '#34d399', fontSize: '12.5px' }}>
                                    {formatIqd(o.merchantNetIqd)}
                                  </div>
                                </td>
                                <td>
                                  {o.driverName ? (
                                    <div>
                                      <div style={{ fontSize: '12px', fontWeight: '700', color: '#fff' }}> {o.driverName}</div>
                                      {o.driverPhone && (
                                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }} dir="ltr">{o.driverPhone}</div>
                                      )}
                                    </div>
                                  ) : (
                                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>بانتظار التكليف</span>
                                  )}
                                </td>
                                <td>
                                  <span className={`badge ${
                                    o.rawStatus.includes('deliver') || o.rawStatus.includes('complet') ? 'badge-success' :
                                    o.rawStatus.includes('cancel') || o.rawStatus.includes('reject') ? 'badge-danger' : 'badge-warning'
                                  }`} style={{ fontSize: '11px' }}>
                                    {o.status}
                                  </span>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>

                </div>

                {/* Footer */}
                <div style={{
                  padding: '14px 24px',
                  borderTop: '1px solid rgba(255, 255, 255, 0.1)',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  background: 'rgba(15, 23, 42, 0.85)'
                }}>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    إجمالي العمليات المعروضة: <strong>{filteredStoreOrders.length}</strong> من أصل {storeOrders.length} طلب
                  </div>
                  <button
                    onClick={() => setStoreOrdersMerchant(null)}
                    className="btn btn-secondary"
                    style={{ fontSize: '12.5px', padding: '7px 18px' }}
                  >
                    إغلاق النافذة
                  </button>
                </div>

              </div>
            </div>
          )}

          {/* ─── MODAL 2: CHANGE PASSWORD MODAL ─── */}
          {passwordMerchant && (
            <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
              <div className="glass-panel" style={{ padding: '28px', maxWidth: '460px', width: '100%', borderRadius: '24px', border: '1px solid rgba(251, 191, 36, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Lock size={18} color="#fbbf24" />
                    <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', margin: 0 }}>
                      تعيين كلمة مرور جديدة: {passwordMerchant.name}
                    </h3>
                  </div>
                  <button onClick={() => setPasswordMerchant(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                    
                  </button>
                </div>

                <form onSubmit={handleUpdatePassword} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)', margin: 0 }}>
                    سيتم تحديث وتعيين كلمة المرور لحساب التاجر ليتمكن من تسجيل الدخول في لوحة تحكم المتجر وتطبيق الشركاء.
                  </p>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#fbbf24', marginBottom: '6px' }}>
                      كلمة المرور الجديدة:
                    </label>
                    <input
                      type="text"
                      required
                      minLength={6}
                      value={newPasswordInput}
                      onChange={e => setNewPasswordInput(e.target.value)}
                      placeholder="أدخل كلمة مرور قوية (6 خانات فأكثر)"
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid #fbbf24', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                    />
                  </div>

                  <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                    <button
                      type="submit"
                      disabled={actionLoadingId === passwordMerchant.merchantId}
                      className="btn btn-primary"
                      style={{ flex: 1, padding: '12px', fontSize: '13px', fontWeight: '800' }}
                    >
                      {actionLoadingId === passwordMerchant.merchantId ? 'جاري التحديث...' : 'تأكيد وحفظ كلمة المرور'}
                    </button>
                    <button
                      type="button"
                      onClick={() => setPasswordMerchant(null)}
                      className="btn btn-secondary"
                      style={{ fontSize: '13px' }}
                    >
                      إلغاء
                    </button>
                  </div>
                </form>

              </div>
            </div>
          )}

          {/* ─── MODAL 3: EDIT MERCHANT DETAILS MODAL ─── */}
          {editingMerchant && (
            <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
              <div className="glass-panel" style={{ padding: '28px', maxWidth: '540px', width: '100%', borderRadius: '24px', border: '1px solid rgba(6, 182, 212, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Edit3 size={18} color="#06b6d4" />
                    <h3 style={{ fontSize: '17px', fontWeight: '800', color: '#fff', margin: 0 }}>
                      تعديل بيانات: {editingMerchant.name}
                    </h3>
                  </div>
                  <button onClick={() => setEditingMerchant(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                    
                  </button>
                </div>

                <form onSubmit={handleSaveMerchantDetails} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  
                  <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        اسم المتجر / المطعم:
                      </label>
                      <input
                        type="text"
                        required
                        value={editName}
                        onChange={e => setEditName(e.target.value)}
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        التصنيف الفرعي:
                      </label>
                      <input
                        type="text"
                        value={editSubCategory}
                        onChange={e => setEditSubCategory(e.target.value)}
                        placeholder="مشاوي / سوبرماركت"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        اسم المالك:
                      </label>
                      <input
                        type="text"
                        required
                        value={editOwner}
                        onChange={e => setEditOwner(e.target.value)}
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        رقم الهاتف:
                      </label>
                      <input
                        type="tel"
                        required
                        dir="ltr"
                        value={editPhone}
                        onChange={e => setEditPhone(e.target.value)}
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        العنوان في القائم:
                      </label>
                      <input
                        type="text"
                        value={editAddress}
                        onChange={e => setEditAddress(e.target.value)}
                        placeholder="شارع الأطباء / حي الجماهير"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#38bdf8', marginBottom: '6px' }}>
                        نسبة العمولة (%):
                      </label>
                      <input
                        type="number"
                        min="0"
                        max="50"
                        value={editCommission}
                        onChange={e => setEditCommission(Number(e.target.value))}
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid #38bdf8', borderRadius: '8px', color: '#38bdf8', fontSize: '13px', fontWeight: '800', outline: 'none' }}
                      />
                    </div>
                  </div>

                  {/* Email & Password Configuration */}
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', background: 'rgba(255,255,255,0.03)', padding: '12px', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.08)' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#38bdf8', marginBottom: '6px' }}>
                        البريد الإلكتروني للحساب:
                      </label>
                      <input
                        type="email"
                        value={editEmail}
                        onChange={e => setEditEmail(e.target.value)}
                        placeholder="مثال: rest@madar.iq"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid #38bdf8', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#fbbf24', marginBottom: '6px' }}>
                        كلمة المرور / الرمز السري:
                      </label>
                      <input
                        type="text"
                        value={editPassword}
                        onChange={e => setEditPassword(e.target.value)}
                        placeholder="كلمة مرور الدخول"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid #fbbf24', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                    <button
                      type="submit"
                      disabled={actionLoadingId === editingMerchant.merchantId}
                      className="btn btn-primary"
                      style={{ flex: 1, padding: '12px', fontSize: '13px', fontWeight: '800' }}
                    >
                      {actionLoadingId === editingMerchant.merchantId ? 'جاري الحفظ...' : 'حفظ وتحديث بيانات المتجر'}
                    </button>
                    <button
                      type="button"
                      onClick={() => setEditingMerchant(null)}
                      className="btn btn-secondary"
                      style={{ fontSize: '13px' }}
                    >
                      إلغاء
                    </button>
                  </div>

                </form>

              </div>
            </div>
          )}

          {/* ─── MODAL 4: ADD MERCHANT MODAL ─── */}
          {showAddMerchantModal && (
            <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
              <div className="glass-panel" style={{ padding: '30px', maxWidth: '520px', width: '100%', borderRadius: '20px', border: '1px solid rgba(6, 182, 212, 0.3)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
                  <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', margin: 0 }}>
                    إضافة متجر أو مطعم شريك جديد
                  </h3>
                  <button onClick={() => setShowAddMerchantModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                    
                  </button>
                </div>

                <form onSubmit={handleAddMerchant} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  
                  {/* Type Selector */}
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      النشاط التجاري:
                    </label>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                      <button
                        type="button"
                        onClick={() => setMerchantType('restaurant')}
                        className={`btn ${merchantType === 'restaurant' ? 'btn-primary' : 'btn-secondary'}`}
                        style={{ fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                      >
                        <UtensilsCrossed size={14} /> مطعم / كافيه
                      </button>
                      <button
                        type="button"
                        onClick={() => setMerchantType('store')}
                        className={`btn ${merchantType === 'store' ? 'btn-primary' : 'btn-secondary'}`}
                        style={{ fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                      >
                        <ShoppingBag size={14} /> متجر / سوبرماركت
                      </button>
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      اسم المطعم / المتجر:
                    </label>
                    <input
                      type="text"
                      required
                      value={merchantName}
                      onChange={(e) => setMerchantName(e.target.value)}
                      placeholder="مثال: مطاعم ومشويات القائم الملكية"
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                    />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        التصنيف الفرعي:
                      </label>
                      <input
                        type="text"
                        value={merchantSubCategory}
                        onChange={(e) => setMerchantSubCategory(e.target.value)}
                        placeholder="مشاوي / حلويات / بقالة"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        نسبة عمولة التطبيق (%):
                      </label>
                      <input
                        type="number"
                        min="0"
                        max="50"
                        value={merchantCommission}
                        onChange={(e) => setMerchantCommission(Number(e.target.value))}
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        اسم صاحب المحل:
                      </label>
                      <input
                        type="text"
                        required
                        value={merchantOwner}
                        onChange={(e) => setMerchantOwner(e.target.value)}
                        placeholder="مثال: أبو فهد"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                        رقم الهاتف:
                      </label>
                      <input
                        type="tel"
                        required
                        dir="ltr"
                        value={merchantPhone}
                        onChange={(e) => setMerchantPhone(e.target.value)}
                        placeholder="07801234567"
                        style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                      />
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      كلمة المرور الابتدائية للحساب:
                    </label>
                    <input
                      type="text"
                      value={merchantPassword}
                      onChange={(e) => setMerchantPassword(e.target.value)}
                      placeholder="مثال: madar1234"
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                    />
                  </div>

                  <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                    <button type="submit" className="btn btn-primary" style={{ flex: 1, padding: '12px', fontSize: '13px', fontWeight: '700' }}>
                      تأكيد وحفظ الشريك في Firestore
                    </button>
                    <button type="button" onClick={() => setShowAddMerchantModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>
                      إلغاء
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </>
      )}

    </div>
  );
};
