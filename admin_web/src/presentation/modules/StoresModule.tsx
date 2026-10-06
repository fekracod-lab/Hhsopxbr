import React, { useState, useEffect, useMemo } from 'react';
import {
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
  Ban,
  Store
} from 'lucide-react';
import { StoreEntity } from '../../domain/types';
import { 
  StoreDomainRepository, 
  StoreProductItemEntity as ProductItemEntity 
} from '../../infrastructure/repositories/StoreDomainRepository';
import { StoreOrdersRepository } from '../../infrastructure/repositories/StoreOrdersRepository';
import { StoreOrderEntity } from '../../domain/types';

export const StoresModule: React.FC = () => {
  const [stores, setStores] = useState<StoreEntity[]>([]);
  const [allOrders, setAllOrders] = useState<StoreOrderEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedApprovalStatus, setSelectedApprovalStatus] = useState<'verified' | 'pending' | 'suspended' | 'all'>('verified');
  const [storeCategoryFilter, setStoreCategoryFilter] = useState<'all' | 'supermarket' | 'pharmacy'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Dedicated Orders & Sales State for a specific Store
  const [ordersStore, setOrdersStore] = useState<StoreEntity | null>(null);
  const [storeOrders, setStoreOrders] = useState<StoreOrderEntity[]>([]);
  const [isStoreOrdersLoading, setIsStoreOrdersLoading] = useState(false);

  // Selected Store for Product Catalog Management
  const [selectedStore, setSelectedStore] = useState<StoreEntity | null>(null);
  const [products, setProducts] = useState<ProductItemEntity[]>([]);
  const [isProductsLoading, setIsProductsLoading] = useState(false);
  const [showAddProductModal, setShowAddProductModal] = useState(false);

  // Details Modal State
  const [detailsStore, setDetailsStore] = useState<StoreEntity | null>(null);

  // Password Reset Modal State
  const [passwordStore, setPasswordStore] = useState<StoreEntity | null>(null);
  const [newPasswordInput, setNewPasswordInput] = useState('');

  // Add Store Form State
  const [showAddModal, setShowAddModal] = useState(false);
  const [storeName, setStoreName] = useState('');
  const [storeSubCategory, setStoreSubCategory] = useState('سوبرماركت ومواد غذائية');
  const [storeOwner, setStoreOwner] = useState('');
  const [storePhone, setStorePhone] = useState('');
  const [storeEmail, setStoreEmail] = useState('');
  const [storePassword, setStorePassword] = useState('');
  const [storeCommission, setStoreCommission] = useState<number>(7);
  const [storeAddress, setStoreAddress] = useState('سوق القائم المركزي');

  // Edit Store State
  const [editingStore, setEditingStore] = useState<StoreEntity | null>(null);
  const [editName, setEditName] = useState('');
  const [editSubCategory, setEditSubCategory] = useState('');
  const [editOwner, setEditOwner] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editPassword, setEditPassword] = useState('');
  const [editCommission, setEditCommission] = useState<number>(7);
  const [editAddress, setEditAddress] = useState('');

  // Add Product Form State
  const [newProdName, setNewProdName] = useState('');
  const [newProdCategory, setNewProdCategory] = useState('منتجات عامة');
  const [newProdPrice, setNewProdPrice] = useState<number>(2500);
  const [newProdDesc, setNewProdDesc] = useState('');

  useEffect(() => {
    setIsLoading(true);
    const unsubscribeStores = StoreDomainRepository.subscribeToStores((data) => {
      setStores(data);
      setIsLoading(false);

      if (detailsStore) {
        const updated = data.find(m => m.storeId === detailsStore.storeId);
        if (updated) setDetailsStore(updated);
      }
    });

    const unsubscribeOrders = StoreOrdersRepository.subscribeToStoreOrders((data) => {
      setAllOrders(data);
    });

    return () => {
      unsubscribeStores();
      unsubscribeOrders();
    };
  }, []);

  // Fetch Products when a Store is selected
  useEffect(() => {
    if (!selectedStore) return;
    setIsProductsLoading(true);
    const unsubscribe = StoreDomainRepository.subscribeToProducts(
      selectedStore.storeId,
      (items) => {
        setProducts(items);
        setIsProductsLoading(false);
      }
    );
    return () => unsubscribe();
  }, [selectedStore]);

  // Fetch Orders when View Orders is opened
  useEffect(() => {
    if (!ordersStore) {
      setStoreOrders([]);
      return;
    }
    setIsStoreOrdersLoading(true);
    const unsubscribe = StoreOrdersRepository.subscribeToStoreOrders(
      (ordersList) => {
        setStoreOrders(ordersList);
        setIsStoreOrdersLoading(false);
      },
      ordersStore.storeId
    );
    return () => unsubscribe();
  }, [ordersStore]);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Toggle Store Open/Closed Status
  const handleToggleStatus = async (store: StoreEntity) => {
    const nextState = !store.isOpen;
    setActionLoadingId(store.storeId);
    try {
      await StoreDomainRepository.toggleStoreOpenStatus(store.storeId, nextState);
      showToast(nextState ? 'تم فتح المتجر لاستقبال الطلبات ' : 'تم إغلاق المتجر مؤقتاً ');
    } catch (err: any) {
      showToast('تعذر تغيير حالة المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Approve Store
  const handleApprove = async (store: StoreEntity) => {
    if (!window.confirm(`هل أنت متأكد من اعتماد وتوثيق متجر (${store.name}) رسمياً؟`)) return;
    setActionLoadingId(store.storeId);
    try {
      await StoreDomainRepository.setStoreStatus(store.storeId, 'active');
      showToast(`تم توثيق واعتماد متجر ${store.name} بنجاح `);
    } catch (err: any) {
      showToast('فشل اعتماد المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Suspend Store
  const handleSuspend = async (store: StoreEntity) => {
    const reason = window.prompt(`أدخل سبب إيقاف (${store.name}):`, 'مخالفة معايير الجودة');
    if (reason === null) return;
    setActionLoadingId(store.storeId);
    try {
      await StoreDomainRepository.setStoreStatus(store.storeId, 'suspended');
      showToast(`تم إيقاف متجر (${store.name})`);
    } catch (err: any) {
      showToast('فشل إيقاف المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Delete Store
  const handleDeleteStore = async (store: StoreEntity) => {
    if (!window.confirm(` تحذير: متأكد تريد تحذف متجر (${store.name}) نهائياً؟`)) return;
    setActionLoadingId(store.storeId);
    try {
      await StoreDomainRepository.deleteStore(store.storeId);
      showToast(`تم حذف ${store.name} نهائياً`);
      setDetailsStore(null);
    } catch (err: any) {
      showToast('تعذر حذف المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Add Store Submit
  const handleAddStore = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!storeName.trim() || !storeOwner.trim() || !storePhone.trim()) {
      showToast('يرجى ملء جميع الحقول المطلوبة', 'error');
      return;
    }

    try {
      await StoreDomainRepository.addStore({
        name: storeName.trim(),
        storeCategory: storeSubCategory.trim(),
        ownerName: storeOwner.trim(),
        phone: storePhone.trim(),
        email: storeEmail.trim() || undefined,
        password: storePassword.trim() || undefined,
        commissionRate: storeCommission,
        address: storeAddress.trim()
      });

      showToast(`تمت إضافة متجر ${storeName} بنجاح إلى منظومة مدار `);
      setShowAddModal(false);
      setStoreName('');
      setStoreOwner('');
      setStorePhone('');
      setStoreEmail('');
      setStorePassword('');
    } catch (err: any) {
      showToast('فشل إضافة المتجر: ' + (err.message || ''), 'error');
    }
  };

  // Open Edit Store Modal
  const handleOpenEdit = (store: StoreEntity) => {
    setEditingStore(store);
    setEditName(store.name);
    setEditSubCategory(store.storeCategory || store.subCategory || 'سوبرماركت ومواد غذائية');
    setEditOwner(store.ownerName);
    setEditPhone(store.phone);
    setEditEmail(store.email && store.email !== 'لا يوجد بريد' ? store.email : '');
    setEditPassword('');
    setEditCommission(store.commissionRate || 7);
    setEditAddress(store.address || 'القائم');
  };

  // Submit Edit Store Profile
  const handleUpdateStoreSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingStore || !editName.trim() || !editOwner.trim() || !editPhone.trim()) {
      showToast('يرجى ملء الحقول المطلوبة', 'error');
      return;
    }

    setActionLoadingId(editingStore.storeId);
    try {
      await StoreDomainRepository.updateStore(editingStore.storeId, {
        name: editName.trim(),
        storeCategory: editSubCategory.trim(),
        ownerName: editOwner.trim(),
        phone: editPhone.trim(),
        email: editEmail.trim() || undefined,
        password: editPassword.trim() || undefined,
        commissionRate: editCommission,
        address: editAddress.trim()
      });

      showToast(`تم حفظ وتحديث بيانات متجر (${editName}) بأمان تام `);
      setEditingStore(null);
    } catch (err: any) {
      showToast('ما قدرنا نحدث بيانات المتجر: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Add Product to Store Catalog
  const handleAddProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedStore || !newProdName.trim()) return;

    try {
      await StoreDomainRepository.addProduct(
        selectedStore.storeId,
        {
          name: newProdName.trim(),
          category: newProdCategory.trim() || 'منتجات عامة',
          price: Number(newProdPrice) || 0,
          description: newProdDesc.trim(),
          isAvailable: true
        }
      );
      showToast('تمت إضافة الصنف بنجاح إلى كتالوج المتجر ');
      setShowAddProductModal(false);
      setNewProdName('');
      setNewProdDesc('');
      setNewProdPrice(2500);
    } catch (err: any) {
      showToast('فشل إضافة الصنف: ' + (err.message || ''), 'error');
    }
  };

  // Toggle Product Availability
  const handleToggleProductAvailability = async (prod: ProductItemEntity) => {
    if (!selectedStore) return;
    try {
      await StoreDomainRepository.updateProduct(
        selectedStore.storeId,
        prod.id,
        { isAvailable: !prod.isAvailable }
      );
      showToast(prod.isAvailable ? 'تم إيقاف توفر المنتج مؤقتاً' : 'تم تفعيل توفر المنتج للزبائن');
    } catch (err: any) {
      showToast('فشل تغيير حالة المنتج', 'error');
    }
  };

  // Delete Product
  const handleDeleteProduct = async (productId: string, productName: string) => {
    if (!selectedStore) return;
    if (!window.confirm(`متأكد تريد تحذف (${productName}) من الكتالوج؟`)) return;

    setProducts(prev => prev.filter(p => p.id !== productId));
    try {
      await StoreDomainRepository.deleteProduct(selectedStore.storeId, productId);
      showToast(`تم حذف ${productName} من القائمة `);
    } catch (err: any) {
      showToast('فشل حذف المنتج: ' + (err.message || ''), 'error');
    }
  };

  // Change Password
  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!passwordStore || !newPasswordInput.trim()) return;

    setActionLoadingId(passwordStore.storeId);
    try {
      await StoreDomainRepository.updateStorePassword(
        passwordStore.storeId,
        newPasswordInput.trim()
      );
      showToast(`تم تحديث كلمة مرور متجر ${passwordStore.name} بنجاح `);
      setPasswordStore(null);
      setNewPasswordInput('');
    } catch (err: any) {
      showToast('ما قدرنا نحدث كلمة المرور: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Calculate Sales & Profits for a Store
  const getStoreSalesStats = (store: StoreEntity) => {
    const mId = store.storeId;
    const mName = store.name.trim().toLowerCase();
    const mPhone = (store.phone || '').trim();

    const matchedOrders = allOrders.filter(o => {
      const oId = o.storeId || o.merchantId;
      const oTitle = (o.storeName || o.merchantOrTitle || '').trim().toLowerCase();
      const oPhone = (o.storePhone || o.merchantPhone || '').trim();
      return (
        (oId && oId === mId) ||
        (oTitle && (oTitle === mName || oTitle.includes(mName) || mName.includes(oTitle))) ||
        (mPhone && oPhone && oPhone.length > 5 && (oPhone === mPhone || mPhone.includes(oPhone)))
      );
    });

    const totalOrdersCount = Math.max(matchedOrders.length, store.totalOrders || 0);
    const completedOrders = matchedOrders.filter(o => 
      o.rawStatus.includes('deliver') || o.rawStatus.includes('complet') || o.status.includes('تم') || o.status.includes('مكتمل')
    );
    const validOrders = matchedOrders.filter(o => !o.rawStatus.includes('cancel') && !o.rawStatus.includes('reject') && !o.status.includes('ملغي'));

    const dynamicSalesIqd = validOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const totalSalesIqd = Math.max(dynamicSalesIqd, store.totalRevenueIqd || 0);
    const commissionRate = store.commissionRate || 7;
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

  // Overall Statistics
  const stats = useMemo(() => {
    let gmv = 0;
    let net = 0;
    let ordersCount = 0;

    stores.forEach(s => {
      const st = getStoreSalesStats(s);
      gmv += st.totalSalesIqd;
      net += st.totalNetProfitIqd;
      ordersCount += st.totalOrdersCount;
    });

    const supermarkets = stores.filter(s => !s.subCategory?.includes('صيدلي'));
    const pharmacies = stores.filter(s => (s.subCategory || '').includes('صيدلي') || (s.name || '').includes('صيدلية'));

    const openCount = stores.filter(s => s.isOpen && s.status === 'active').length;
    const closedCount = stores.filter(s => !s.isOpen && s.status === 'active').length;
    const pendingCount = stores.filter(s => s.status === 'pending').length;
    const suspendedCount = stores.filter(s => s.status === 'suspended').length;
    const verifiedCount = stores.filter(s => s.status === 'active' || (s.status !== 'pending' && s.status !== 'suspended')).length;

    return {
      total: stores.length,
      supermarketCount: supermarkets.length,
      pharmacyCount: pharmacies.length,
      verifiedCount,
      openCount,
      closedCount,
      pendingCount,
      suspendedCount,
      gmv,
      net,
      ordersCount
    };
  }, [stores, allOrders]);

  // Filtered list
  const filtered = useMemo(() => {
    return stores.filter(s => {
      if (selectedApprovalStatus === 'verified' && (s.status === 'pending' || s.status === 'suspended')) return false;
      if (selectedApprovalStatus === 'pending' && s.status !== 'pending') return false;
      if (selectedApprovalStatus === 'suspended' && s.status !== 'suspended') return false;

      if (storeCategoryFilter === 'supermarket' && s.subCategory?.includes('صيدلي')) return false;
      if (storeCategoryFilter === 'pharmacy' && !s.subCategory?.includes('صيدلي') && !s.name.includes('صيدلية')) return false;

      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;

      return (
        s.name.toLowerCase().includes(q) ||
        s.ownerName.toLowerCase().includes(q) ||
        s.phone.includes(q) ||
        (s.subCategory && s.subCategory.toLowerCase().includes(q)) ||
        (s.address && s.address.toLowerCase().includes(q))
      );
    });
  }, [stores, selectedApprovalStatus, storeCategoryFilter, searchQuery]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'linear-gradient(135deg, #0284c7, #0369a1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <ShoppingBag size={22} />
            </div>
            <span>إدارة المتاجر والتسوق (Stores & Retail Hub)</span>
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            قسم مستقل لإدارة السوبرماركت، الصيدليات، محلات الدروب شيبينغ، كتالوج المنتجات وعمولة 7%
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          {selectedStore ? (
            <button
              onClick={() => setSelectedStore(null)}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px' }}
            >
              <ArrowRight size={14} /> العودة لقائمة المتاجر
            </button>
          ) : (
            <button
              onClick={() => setShowAddModal(true)}
              className="btn btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '800', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8' }}
            >
              <Plus size={16} /> + إضافة متجر / صيدلية جديدة
            </button>
          )}
        </div>
      </div>

      {/* ─── 4 MAIN FINANCIAL SUMMARY CARDS ─── */}
      {!selectedStore && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
          
          <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(2, 132, 199, 0.12) 0%, rgba(15, 23, 42, 0.6) 100%)', border: '1px solid rgba(56, 189, 248, 0.3)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>المتاجر المسجلة المعتمدة</span>
              <ShoppingBag size={18} color="#38bdf8" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#38bdf8', marginTop: '6px' }}>
              {stats.verifiedCount} متجر
            </div>
            <div style={{ fontSize: '11px', color: '#bae6fd', marginTop: '3px' }}>
               {stats.supermarketCount} سوبرماركت | {stats.pharmacyCount} صيدلية
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي مبيعات التسوق (Retail GMV)</span>
              <Coins size={18} color="#34d399" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
              {formatIqd(stats.gmv)}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              عبر {stats.ordersCount} طلب تسوق منفذ
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>عمولة مدار من المتاجر (7%)</span>
              <TrendingUp size={18} color="#fbbf24" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#fbbf24', marginTop: '6px' }}>
              {formatIqd(Math.round(stats.gmv * 0.07))}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              صافي أرباح المتاجر: {formatIqd(stats.net)}
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>قائمة الانتظار والمراجعة</span>
              <Clock size={18} color="#f59e0b" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: stats.pendingCount > 0 ? '#fbbf24' : '#94a3b8', marginTop: '6px' }}>
              {stats.pendingCount} متجر 
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              بانتظار تدقيق الإدارة والموافقة
            </div>
          </div>

        </div>
      )}

      {/* ─── VIEW 1: STORE PRODUCTS / INVENTORY MANAGEMENT ─── */}
      {selectedStore ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'linear-gradient(135deg, rgba(2, 132, 199, 0.1) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>
                  كتالوج منتجات وأصناف: {selectedStore.name}
                </h3>
                <span className={`badge ${selectedStore.isOpen ? 'badge-success' : 'badge-danger'}`}>
                  {selectedStore.isOpen ? 'مفتوح للطلبات ' : 'مغلق مؤقتاً '}
                </span>
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                المالك: {selectedStore.ownerName} • الهاتف: <span dir="ltr">{selectedStore.phone}</span> • العمولة: {selectedStore.commissionRate}%
              </div>
            </div>

            <button
              onClick={() => setShowAddProductModal(true)}
              className="btn btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', fontWeight: '800', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8' }}
            >
              <Plus size={15} /> + إضافة صنف / منتج جديد
            </button>
          </div>

          <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
            {isProductsLoading ? (
              <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={24} color="#0284c7" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                <div>جاري جلب أصناف المتجر...</div>
              </div>
            ) : products.length === 0 ? (
              <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Package size={36} color="#64748b" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>ماكو منتجات حالياً مضافة في كتالوج هذا المتجر</div>
                <button onClick={() => setShowAddProductModal(true)} className="btn btn-primary" style={{ marginTop: '12px', fontSize: '12px' }}>
                  + إضافة أول منتج
                </button>
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>اسم المنتج / الصنف</th>
                      <th>القسم / التصنيف</th>
                      <th>السعر</th>
                      <th>المبيعات</th>
                      <th>حالة التوفر</th>
                      <th>الإجراءات</th>
                    </tr>
                  </thead>
                  <tbody>
                    {products.map((prod) => (
                      <tr key={prod.id}>
                        <td>
                          <div style={{ fontWeight: '800', color: '#fff' }}>{prod.name}</div>
                          {prod.description && <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{prod.description}</div>}
                        </td>
                        <td><span className="badge badge-info">{prod.category}</span></td>
                        <td style={{ fontWeight: '800', color: '#34d399' }}>{formatIqd(prod.price)}</td>
                        <td>{prod.salesCount} طلب</td>
                        <td>
                          <button
                            onClick={() => handleToggleProductAvailability(prod)}
                            className={`badge ${prod.isAvailable ? 'badge-success' : 'badge-danger'}`}
                            style={{ cursor: 'pointer', border: 'none' }}
                          >
                            {prod.isAvailable ? 'متوفر ' : 'غير متوفر '}
                          </button>
                        </td>
                        <td>
                          <button
                            onClick={() => handleDeleteProduct(prod.id, prod.name)}
                            className="btn btn-secondary"
                            style={{ fontSize: '11px', padding: '4px 8px', color: '#ef4444' }}
                          >
                            <Trash2 size={13} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

        </div>
      ) : (
        /* ─── VIEW 2: STORES TABLE WITH SEPARATE TABS ─── */
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          {/* Filters */}
          <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
            
            {/* Row 1: Subcategories */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
              <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
                <button
                  onClick={() => setStoreCategoryFilter('all')}
                  className={`btn ${storeCategoryFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px' }}
                >
                   جميع المتاجر ({stores.length})
                </button>
                <button
                  onClick={() => setStoreCategoryFilter('supermarket')}
                  className={`btn ${storeCategoryFilter === 'supermarket' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', color: '#38bdf8' }}
                >
                   السوبرماركت والبقالة ({stats.supermarketCount})
                </button>
                <button
                  onClick={() => setStoreCategoryFilter('pharmacy')}
                  className={`btn ${storeCategoryFilter === 'pharmacy' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', color: '#a78bfa' }}
                >
                   الصيدليات والمستلزمات ({stats.pharmacyCount})
                </button>
              </div>

              {/* Search */}
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '280px' }}>
                <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
                <input
                  type="text"
                  placeholder="ابحث باسم المتجر، المالك، أو الهاتف..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  style={{ width: '100%', padding: '8px 36px 8px 12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                />
              </div>
            </div>

            {/* Row 2: Status Filter Tabs */}
            <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', borderTop: '1px solid var(--border-color)', paddingTop: '10px' }}>
              <button
                onClick={() => setSelectedApprovalStatus('verified')}
                className={`btn ${selectedApprovalStatus === 'verified' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '800' }}
              >
                <ShieldCheck size={14} color="#34d399" />
                <span> المتاجر الموثوقة والمعتمدة ({stats.verifiedCount})</span>
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
                  borderColor: stats.pendingCount > 0 ? '#f59e0b' : undefined,
                  color: selectedApprovalStatus === 'pending' ? '#fff' : (stats.pendingCount > 0 ? '#fbbf24' : undefined)
                }}
              >
                <AlertCircle size={14} color="#f59e0b" />
                <span> قائمة الانتظار وقيد المراجعة ({stats.pendingCount})</span>
              </button>

              <button
                onClick={() => setSelectedApprovalStatus('suspended')}
                className={`btn ${selectedApprovalStatus === 'suspended' ? 'btn-danger' : 'btn-secondary'}`}
                style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
              >
                <Ban size={14} />
                <span> المتاجر الموقوفة والمحظورة ({stats.suspendedCount})</span>
              </button>

              <button
                onClick={() => setSelectedApprovalStatus('all')}
                className={`btn ${selectedApprovalStatus === 'all' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '12px', padding: '6px 14px' }}
              >
                <span> عرض الكل ({stores.length})</span>
              </button>
            </div>

          </div>

          {/* Stores Main Table */}
          <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
            {isLoading ? (
              <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={26} color="#0284c7" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                <div>جاري جلب بيانات المتاجر من Firestore...</div>
              </div>
            ) : filtered.length === 0 ? (
              <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <ShoppingBag size={36} color="#64748b" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>ماكو متاجر حالياً مطابقة للشروط</div>
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>اسم المتجر والنشاط</th>
                      <th>المالك ورقم الهاتف</th>
                      <th>العنوان</th>
                      <th>نسبة العمولة %</th>
                      <th>حالة العمل</th>
                      <th>إجمالي المبيعات (GMV) </th>
                      <th>سجل الطلبات</th>
                      <th>كتالوج الأصناف</th>
                      <th>الإجراءات الإدارية</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map(s => {
                      const sales = getStoreSalesStats(s);
                      return (
                        <tr key={s.merchantId}>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                              {s.logoUrl ? (
                                <img src={s.logoUrl} alt={s.name} style={{ width: '38px', height: '38px', borderRadius: '10px', objectFit: 'cover' }} />
                              ) : (
                                <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: 'rgba(2, 132, 199, 0.15)', color: '#38bdf8', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '900' }}>
                                  
                                </div>
                              )}
                              <div>
                                <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{s.name}</div>
                                <div style={{ fontSize: '11px', color: '#38bdf8' }}>{s.subCategory || 'متاجر وتسوق'}</div>
                              </div>
                            </div>
                          </td>
                          <td>
                            <div style={{ fontSize: '12.5px', color: '#fff' }}>{s.ownerName}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{s.phone}</div>
                          </td>
                          <td>
                            <div style={{ fontSize: '12px', color: '#cbd5e1' }}> {s.address || 'القائم'}</div>
                          </td>
                          <td>
                            <span style={{ fontWeight: '900', color: '#38bdf8', fontSize: '13px' }}>{s.commissionRate}%</span>
                          </td>
                          <td>
                            <button
                              onClick={() => handleToggleStatus(s)}
                              className={`badge ${s.isOpen ? 'badge-success' : 'badge-danger'}`}
                              style={{ cursor: 'pointer', border: 'none', fontSize: '10.5px' }}
                            >
                              {s.isOpen ? 'مفتوح ' : 'مغلق مؤقتاً '}
                            </button>
                          </td>
                          <td>
                            <div style={{ fontWeight: '900', color: sales.totalSalesIqd > 0 ? '#34d399' : '#cbd5e1', fontSize: '13.5px' }}>
                              {formatIqd(sales.totalSalesIqd)}
                            </div>
                            <div style={{ fontSize: '10.5px', color: '#38bdf8' }}>
                              صافي: {formatIqd(sales.totalNetProfitIqd)}
                            </div>
                          </td>
                          <td>
                            <button
                              onClick={() => setOrdersStore(s)}
                              className="btn btn-primary"
                              style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
                            >
                              <Receipt size={12} /> الطلبات
                            </button>
                          </td>
                          <td>
                            <button
                              onClick={() => setSelectedStore(s)}
                              className="btn btn-secondary"
                              style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px', color: '#38bdf8' }}
                            >
                              <Package size={12} /> الأصناف
                            </button>
                          </td>
                          <td>
                            <div style={{ display: 'flex', gap: '4px' }}>
                              {s.status === 'pending' && (
                                <button
                                  onClick={() => handleApprove(s)}
                                  className="btn btn-primary"
                                  style={{ fontSize: '11px', padding: '4px 8px', background: '#059669', borderColor: '#34d399' }}
                                  title="اعتماد وتوثيق المتجر"
                                >
                                  <Check size={12} /> اعتماد
                                </button>
                              )}
                              <button
                                onClick={() => handleOpenEdit(s)}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '3px', color: '#38bdf8', borderColor: '#38bdf8' }}
                                title="تعديل بيانات المتجر والبريد والباسورد"
                              >
                                <Edit3 size={13} />
                                <span>تعديل</span>
                              </button>
                              <button
                                onClick={() => setDetailsStore(s)}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 7px' }}
                                title="عرض الملف"
                              >
                                <Eye size={13} color="#06b6d4" />
                              </button>
                              <button
                                onClick={() => { setPasswordStore(s); setNewPasswordInput(''); }}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 7px', color: '#fbbf24' }}
                                title="تغيير كلمة المرور"
                              >
                                <Key size={13} />
                              </button>
                              <button
                                onClick={() => handleDeleteStore(s)}
                                style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '4px' }}
                                title="حذف المتجر"
                              >
                                <Trash2 size={14} />
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

        </div>
      )}

      {/* ─── ADD STORE MODAL ─── */}
      {showAddModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '520px', width: '100%', borderRadius: '22px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0 }}>إضافة متجر / سوبرماركت شريك </h3>
              <button onClick={() => setShowAddModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleAddStore} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المتجر:</label>
                <input type="text" required value={storeName} onChange={e => setStoreName(e.target.value)} placeholder="مثال: هايبرماركت القائم الدولي" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>نوع النشاط والتصنيف:</label>
                  <select value={storeSubCategory} onChange={e => setStoreSubCategory(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }}>
                    <option value="سوبرماركت ومواد غذائية">سوبرماركت وبقالة</option>
                    <option value="صيدليات ومستلزمات طبية">صيدلية ومستلزمات</option>
                    <option value="دروب شيبينغ وتسوق إلكتروني">دروب شيبينغ وتسوق</option>
                    <option value="مكتبات وقرطاسية">مكتبات وقرطاسية</option>
                    <option value="ملابس ومستلزمات">ملابس ومستلزمات</option>
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>نسبة العمولة (%):</label>
                  <input type="number" min="0" max="25" value={storeCommission} onChange={e => setStoreCommission(Number(e.target.value))} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#38bdf8', fontSize: '13px', fontWeight: '800' }} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المالك:</label>
                  <input type="text" required value={storeOwner} onChange={e => setStoreOwner(e.target.value)} placeholder="اسم صاحب المتجر" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>رقم الهاتف:</label>
                  <input type="tel" required dir="ltr" value={storePhone} onChange={e => setStorePhone(e.target.value)} placeholder="077XXXXXXXX" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>العنوان في القائم:</label>
                <input type="text" value={storeAddress} onChange={e => setStoreAddress(e.target.value)} placeholder="سوق القائم / حي الجماهير" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #0284c7, #0369a1)' }}>
                  حفظ وإضافة المتجر
                </button>
                <button type="button" onClick={() => setShowAddModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── ADD PRODUCT MODAL ─── */}
      {showAddProductModal && selectedStore && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '480px', width: '100%', borderRadius: '22px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>إضافة منتج جديد لـ ({selectedStore.name})</h3>
              <button onClick={() => setShowAddProductModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleAddProduct} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المنتج / الصنف:</label>
                <input type="text" required value={newProdName} onChange={e => setNewProdName(e.target.value)} placeholder="مثال: حليب المراعي 1 لتر" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>القسم والتصنيف:</label>
                  <input type="text" value={newProdCategory} onChange={e => setNewProdCategory(e.target.value)} placeholder="ألبان / معلبات / منظفات" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>السعر بالدينار العراقي:</label>
                  <input type="number" step="250" value={newProdPrice} onChange={e => setNewProdPrice(Number(e.target.value))} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#34d399', fontSize: '13px', fontWeight: '800' }} />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>الوصف وتفاصيل العبوة:</label>
                <textarea rows={2} value={newProdDesc} onChange={e => setNewProdDesc(e.target.value)} placeholder="وصف الحجم أو الوزن أو المواصفات..." style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #0284c7, #0369a1)' }}>
                  حفظ وإضافة المنتج
                </button>
                <button type="button" onClick={() => setShowAddProductModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── STORE DETAILS MODAL ─── */}
      {detailsStore && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '560px', width: '100%', borderRadius: '22px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>ملف متجر: {detailsStore.name}</h3>
              <button onClick={() => setDetailsStore(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '13px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>اسم المالك:</span>
                <span style={{ color: '#fff', fontWeight: '700' }}>{detailsStore.ownerName}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>رقم الهاتف:</span>
                <span style={{ color: '#fff', fontWeight: '700' }} dir="ltr">{detailsStore.phone}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>العنوان في القائم:</span>
                <span style={{ color: '#cbd5e1' }}>{detailsStore.address}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>نسبة العمولة:</span>
                <span style={{ color: '#38bdf8', fontWeight: '800' }}>{detailsStore.commissionRate}%</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>تاريخ التسجيل:</span>
                <span style={{ color: '#cbd5e1' }}>{detailsStore.createdAt}</span>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '16px' }}>
              <button onClick={() => setDetailsStore(null)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إغلاق</button>
            </div>
          </div>
        </div>
      )}

      {/* ─── EDIT STORE PROFILE MODAL (Non-destructive: Preserves FCM tokens & products) ─── */}
      {editingStore && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '540px', width: '100%', borderRadius: '22px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '14px' }}>
              <div>
                <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0 }}>تعديل بيانات المتجر </h3>
                <div style={{ fontSize: '11.5px', color: '#38bdf8', marginTop: '2px' }}>{editingStore.name} (معرف: {editingStore.merchantId.slice(0, 8)})</div>
              </div>
              <button onClick={() => setEditingStore(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            {/* Safety Guarantee Ribbon */}
            <div style={{ padding: '8px 12px', background: 'rgba(16, 185, 129, 0.12)', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '10px', display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '14px' }}>
              <ShieldCheck size={16} color="#34d399" />
              <span style={{ fontSize: '11px', color: '#34d399', fontWeight: '700' }}>
                 حفظ آمن: يتم تحديث البيانات والبريد والباسورد بدون فقدان كتالوج المنتجات أو توكنات الإشعارات (FCM).
              </span>
            </div>

            <form onSubmit={handleUpdateStoreSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المتجر:</label>
                <input type="text" required value={editName} onChange={e => setEditName(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>نوع النشاط / التصنيف:</label>
                  <input type="text" value={editSubCategory} onChange={e => setEditSubCategory(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>نسبة العمولة (%):</label>
                  <input type="number" min="0" max="30" value={editCommission} onChange={e => setEditCommission(Number(e.target.value))} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#38bdf8', fontSize: '13px', fontWeight: '800' }} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم صاحب المتجر:</label>
                  <input type="text" required value={editOwner} onChange={e => setEditOwner(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>رقم الهاتف:</label>
                  <input type="tel" required dir="ltr" value={editPhone} onChange={e => setEditPhone(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
              </div>

              {/* Email & Password Credentials */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', background: 'rgba(255,255,255,0.02)', padding: '10px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: '#38bdf8', marginBottom: '4px', fontWeight: '700' }}>البريد الإلكتروني للـ Login:</label>
                  <input type="email" dir="ltr" value={editEmail} onChange={e => setEditEmail(e.target.value)} placeholder="store@madar.iq" style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: '#fbbf24', marginBottom: '4px', fontWeight: '700' }}>كلمة المرور الجديدة (اختياري):</label>
                  <input type="text" dir="ltr" value={editPassword} onChange={e => setEditPassword(e.target.value)} placeholder="اتركه فارغاً لعدم التغيير" style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fbbf24', fontSize: '12.5px', fontWeight: '700' }} />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>العنوان في القائم:</label>
                <input type="text" value={editAddress} onChange={e => setEditAddress(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 22px', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8', fontWeight: '800' }}>
                  حفظ التعديلات بأمان 
                </button>
                <button type="button" onClick={() => setEditingStore(null)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
