import React, { useState, useEffect, useMemo } from 'react';
import {
  UtensilsCrossed,
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
import { RestaurantEntity } from '../../domain/types';
import { 
  RestaurantDomainRepository, 
  RestaurantMenuItemEntity as ProductItemEntity, 
  RestaurantMenuCategoryEntity as MenuCategoryEntity 
} from '../../infrastructure/repositories/RestaurantDomainRepository';
import { RestaurantOrdersRepository } from '../../infrastructure/repositories/RestaurantOrdersRepository';
import { RestaurantOrderEntity } from '../../domain/types';

export interface CuisineCategoryDef {
  id: string;
  label: string;
  icon: string;
  imageFileName: string;
  color: string;
}

export const CUISINE_CATEGORIES: CuisineCategoryDef[] = [
  { id: 'all', label: 'الكل', icon: '', imageFileName: 'all.png', color: '#00BFA5' },
  { id: 'برغر وسندويشات', label: 'برغر وسندويش', icon: '', imageFileName: 'burger.png', color: '#FF9800' },
  { id: 'مشويات وكباب', label: 'مشاوي وكباب', icon: '', imageFileName: 'kebab.png', color: '#E53935' },
  { id: 'بيتزا ومعجنات', label: 'بيتزا وفطائر', icon: '', imageFileName: 'pizza.png', color: '#FF7043' },
  { id: 'دجاج ومقرمشات', label: 'دجاج كرسبي', icon: '', imageFileName: 'chicken.png', color: '#F59E0B' },
  { id: 'عصائر ومشروبات', label: 'عصائر ومشروبات', icon: '', imageFileName: 'drinks.png', color: '#00ACC1' },
  { id: 'حلويات وكافيهات', label: 'حلويات وكافيه', icon: '', imageFileName: 'sweets.png', color: '#EC407A' },
  { id: 'مأكولات شرقية', label: 'مأكولات شرقية', icon: '', imageFileName: 'oriental.png', color: '#8D6E63' },
  { id: 'وجبات سريعة', label: 'وجبات سريعة', icon: '', imageFileName: 'burger.png', color: '#F59E0B' },
  { id: 'شاورما وسندويشات', label: 'شاورما وصاج', icon: '', imageFileName: 'burger.png', color: '#EA580C' },
  { id: 'أكلات شعبية وفلافل', label: 'أكلات شعبية وفلافل', icon: '', imageFileName: 'oriental.png', color: '#84CC16' },
  { id: 'أسماك ومأكولات بحرية', label: 'أسماك ومسكوف', icon: '', imageFileName: 'oriental.png', color: '#0284C7' },
  { id: 'فطور وصباحيات', label: 'فطور وصباحيات', icon: '', imageFileName: 'all.png', color: '#10B981' },
  { id: 'دايت وصحي', label: 'دايت وصحي', icon: '', imageFileName: 'all.png', color: '#14B8A6' },
];

export const RestaurantsModule: React.FC = () => {
  const [restaurants, setRestaurants] = useState<RestaurantEntity[]>([]);
  const [allOrders, setAllOrders] = useState<RestaurantOrderEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedApprovalStatus, setSelectedApprovalStatus] = useState<'verified' | 'pending' | 'suspended' | 'all'>('verified');
  const [selectedCuisineCategory, setSelectedCuisineCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [editingCommissionId, setEditingCommissionId] = useState<string | null>(null);
  const [newCommissionValue, setNewCommissionValue] = useState<number>(10);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Dedicated Orders & Sales State for a specific Restaurant
  const [ordersRestaurant, setOrdersRestaurant] = useState<RestaurantEntity | null>(null);
  const [storeOrders, setStoreOrders] = useState<RestaurantOrderEntity[]>([]);
  const [isStoreOrdersLoading, setIsStoreOrdersLoading] = useState(false);
  const [ordersStatusFilter, setOrdersStatusFilter] = useState<'all' | 'delivered' | 'active' | 'cancelled'>('all');
  const [ordersSearch, setOrdersSearch] = useState('');

  // Selected Restaurant for Menu & Categories Management
  const [selectedRestaurant, setSelectedRestaurant] = useState<RestaurantEntity | null>(null);
  const [products, setProducts] = useState<ProductItemEntity[]>([]);
  const [menuCategories, setMenuCategories] = useState<MenuCategoryEntity[]>([]);
  const [selectedMenuSection, setSelectedMenuSection] = useState<string>('all');
  const [menuSearchQuery, setMenuSearchQuery] = useState<string>('');
  const [isProductsLoading, setIsProductsLoading] = useState(false);
  const [showAddProductModal, setShowAddProductModal] = useState(false);
  const [showAddCategoryModal, setShowAddCategoryModal] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState('');

  // Details Modal State
  const [detailsRestaurant, setDetailsRestaurant] = useState<RestaurantEntity | null>(null);
  const [showPasswordInDetails, setShowPasswordInDetails] = useState(false);

  // Password Reset Modal State
  const [passwordRestaurant, setPasswordRestaurant] = useState<RestaurantEntity | null>(null);
  const [newPasswordInput, setNewPasswordInput] = useState('');

  // Add Restaurant Form State
  const [showAddModal, setShowAddModal] = useState(false);
  const [restName, setRestName] = useState('');
  const [restSubCategory, setRestSubCategory] = useState('مشاوي ومأكولات شرقية');
  const [restOwner, setRestOwner] = useState('');
  const [restPhone, setRestPhone] = useState('');
  const [restEmail, setRestEmail] = useState('');
  const [restPassword, setRestPassword] = useState('');
  const [restCommission, setRestCommission] = useState<number>(10);
  const [restAddress, setRestAddress] = useState('شارع الأطباء - القائم');

  // Edit Restaurant State
  const [editingRestaurant, setEditingRestaurant] = useState<RestaurantEntity | null>(null);
  const [editName, setEditName] = useState('');
  const [editSubCategory, setEditSubCategory] = useState('');
  const [editOwner, setEditOwner] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editPassword, setEditPassword] = useState('');
  const [editCommission, setEditCommission] = useState<number>(10);
  const [editAddress, setEditAddress] = useState('');

  // Add Product Form State
  const [newProdName, setNewProdName] = useState('');
  const [newProdCategory, setNewProdCategory] = useState('وجبات رئيسية');
  const [newProdPrice, setNewProdPrice] = useState<number>(6000);
  const [newProdDesc, setNewProdDesc] = useState('');

  useEffect(() => {
    setIsLoading(true);
    const unsubscribeRestaurants = RestaurantDomainRepository.subscribeToRestaurants((data) => {
      setRestaurants(data);
      setIsLoading(false);

      if (detailsRestaurant) {
        const updated = data.find(m => m.restaurantId === detailsRestaurant.restaurantId);
        if (updated) setDetailsRestaurant(updated);
      }
    });

    const unsubscribeOrders = RestaurantOrdersRepository.subscribeToRestaurantOrders((data) => {
      setAllOrders(data);
    });

    return () => {
      unsubscribeRestaurants();
      unsubscribeOrders();
    };
  }, []);

  // Fetch Menu and Categories when a Restaurant is selected
  useEffect(() => {
    if (!selectedRestaurant) {
      setProducts([]);
      setMenuCategories([]);
      setSelectedMenuSection('all');
      return;
    }
    setIsProductsLoading(true);
    const unsubscribe = RestaurantDomainRepository.subscribeToRestaurantMenuAndCategories(
      selectedRestaurant.restaurantId,
      selectedRestaurant.name,
      ({ products: items, categories: cats }) => {
        setProducts(items);
        setMenuCategories(cats);
        setIsProductsLoading(false);
      }
    );
    return () => unsubscribe();
  }, [selectedRestaurant]);

  // Fetch Orders when View Orders is opened
  useEffect(() => {
    if (!ordersRestaurant) {
      setStoreOrders([]);
      return;
    }
    setIsStoreOrdersLoading(true);
    const unsubscribe = RestaurantOrdersRepository.subscribeToRestaurantOrders(
      (ordersList) => {
        setStoreOrders(ordersList);
        setIsStoreOrdersLoading(false);
      },
      ordersRestaurant.restaurantId
    );
    return () => unsubscribe();
  }, [ordersRestaurant]);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Toggle Restaurant Open/Closed Status
  const handleToggleStatus = async (restaurant: RestaurantEntity) => {
    const nextState = !restaurant.isOpen;
    setActionLoadingId(restaurant.restaurantId);
    try {
      await RestaurantDomainRepository.toggleRestaurantOpenStatus(restaurant.restaurantId, nextState);
      showToast(nextState ? 'تم فتح المطعم لاستقبال الطلبات ' : 'تم إغلاق المطعم مؤقتاً ');
    } catch (err: any) {
      showToast('تعذر تغيير حالة المطعم: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Approve Restaurant
  const handleApprove = async (restaurant: RestaurantEntity) => {
    if (!window.confirm(`هل أنت متأكد من اعتماد وتوثيق مطعم (${restaurant.name}) رسمياً؟`)) return;
    setActionLoadingId(restaurant.restaurantId);
    try {
      await RestaurantDomainRepository.setRestaurantStatus(restaurant.restaurantId, 'active');
      showToast(`تم توثيق واعتماد مطعم ${restaurant.name} بنجاح `);
    } catch (err: any) {
      showToast('فشل اعتماد المطعم: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Suspend Restaurant
  const handleSuspend = async (restaurant: RestaurantEntity) => {
    const reason = window.prompt(`أدخل سبب إيقاف (${restaurant.name}):`, 'مخالفة معايير الجودة والتوصيل');
    if (reason === null) return;
    setActionLoadingId(restaurant.restaurantId);
    try {
      await RestaurantDomainRepository.setRestaurantStatus(restaurant.restaurantId, 'suspended');
      showToast(`تم إيقاف مطعم (${restaurant.name})`);
    } catch (err: any) {
      showToast('فشل إيقاف المطعم: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Save Commission Rate
  const handleSaveCommission = async (restaurant: RestaurantEntity) => {
    setActionLoadingId(restaurant.restaurantId);
    try {
      await RestaurantDomainRepository.updateRestaurantCommission(restaurant.restaurantId, newCommissionValue);
      showToast(`تم تحديث عمولة ${restaurant.name} إلى ${newCommissionValue}%`);
      setEditingCommissionId(null);
    } catch (err: any) {
      showToast('ما قدرنا نحدث العمولة: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Delete Restaurant
  const handleDeleteRestaurant = async (restaurant: RestaurantEntity) => {
    if (!window.confirm(` تحذير: متأكد تريد تحذف مطعم (${restaurant.name}) نهائياً؟`)) return;
    setActionLoadingId(restaurant.restaurantId);
    try {
      await RestaurantDomainRepository.deleteRestaurant(restaurant.restaurantId);
      showToast(`تم حذف ${restaurant.name} نهائياً`);
      setDetailsRestaurant(null);
    } catch (err: any) {
      showToast('تعذر حذف المطعم: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Add Restaurant Submit
  const handleAddRestaurant = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!restName.trim() || !restOwner.trim() || !restPhone.trim()) {
      showToast('يرجى ملء جميع الحقول المطلوبة', 'error');
      return;
    }

    try {
      await RestaurantDomainRepository.addRestaurant({
        name: restName.trim(),
        cuisineType: restSubCategory.trim(),
        ownerName: restOwner.trim(),
        phone: restPhone.trim(),
        email: restEmail.trim() || undefined,
        password: restPassword.trim() || undefined,
        commissionRate: restCommission,
        address: restAddress.trim()
      });

      showToast(`تمت إضافة مطعم ${restName} بنجاح إلى منظومة مدار `);
      setShowAddModal(false);
      setRestName('');
      setRestOwner('');
      setRestPhone('');
      setRestEmail('');
      setRestPassword('');
    } catch (err: any) {
      showToast('فشل إضافة المطعم: ' + (err.message || ''), 'error');
    }
  };

  // Open Edit Restaurant Modal
  const handleOpenEdit = (restaurant: RestaurantEntity) => {
    setEditingRestaurant(restaurant);
    setEditName(restaurant.name);
    setEditSubCategory(restaurant.cuisineType || restaurant.subCategory || 'مشاوي ومأكولات شرقية');
    setEditOwner(restaurant.ownerName);
    setEditPhone(restaurant.phone);
    setEditEmail(restaurant.email && restaurant.email !== 'لا يوجد بريد' ? restaurant.email : '');
    setEditPassword('');
    setEditCommission(restaurant.commissionRate || 10);
    setEditAddress(restaurant.address || 'القائم');
  };

  // Submit Edit Restaurant Profile
  const handleUpdateRestaurantSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingRestaurant || !editName.trim() || !editOwner.trim() || !editPhone.trim()) {
      showToast('يرجى ملء الحقول المطلوبة', 'error');
      return;
    }

    setActionLoadingId(editingRestaurant.restaurantId);
    try {
      await RestaurantDomainRepository.updateRestaurant(editingRestaurant.restaurantId, {
        name: editName.trim(),
        cuisineType: editSubCategory.trim(),
        ownerName: editOwner.trim(),
        phone: editPhone.trim(),
        email: editEmail.trim() || undefined,
        password: editPassword.trim() || undefined,
        commissionRate: editCommission,
        address: editAddress.trim()
      });

      showToast(`تم حفظ وتحديث بيانات مطعم (${editName}) بأمان تام `);
      setEditingRestaurant(null);
    } catch (err: any) {
      showToast('ما قدرنا نحدث بيانات المطعم: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Add Category / Section to Restaurant Menu
  const handleAddMenuCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedRestaurant || !newCategoryName.trim()) return;
    try {
      await RestaurantDomainRepository.addCategory(
        selectedRestaurant.restaurantId,
        newCategoryName.trim()
      );
      showToast(`تمت إضافة قسم (${newCategoryName.trim()}) لمنيو المطعم بنجاح `);
      setShowAddCategoryModal(false);
      setNewCategoryName('');
    } catch (err: any) {
      showToast(`فشل إضافة القسم: ${err.message}`, 'error');
    }
  };

  // Delete Category / Section from Restaurant Menu
  const handleDeleteMenuCategory = async (cat: MenuCategoryEntity) => {
    if (!selectedRestaurant) return;
    if (!window.confirm(`متأكد تريد تحذف قسم (${cat.name})؟`)) return;
    try {
      await RestaurantDomainRepository.deleteCategory(
        selectedRestaurant.restaurantId,
        cat.id
      );
      showToast(`تم حذف قسم (${cat.name}) بنجاح`);
      if (selectedMenuSection === cat.name) setSelectedMenuSection('all');
    } catch (err: any) {
      showToast(`فشل حذف القسم: ${err.message}`, 'error');
    }
  };

  // Add Meal/Dish to Menu
  const handleAddProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedRestaurant || !newProdName.trim()) return;

    try {
      await RestaurantDomainRepository.addMenuItem(
        selectedRestaurant.restaurantId,
        {
          name: newProdName.trim(),
          category: newProdCategory.trim() || 'وجبات رئيسية',
          price: Number(newProdPrice) || 0,
          description: newProdDesc.trim(),
          isAvailable: true
        }
      );
      showToast('تمت إضافة الوجبة بنجاح إلى منيو المطعم ');
      setShowAddProductModal(false);
      setNewProdName('');
      setNewProdDesc('');
      setNewProdPrice(6000);
    } catch (err: any) {
      showToast('فشل إضافة الصنف: ' + (err.message || ''), 'error');
    }
  };

  // Toggle Dish Availability
  const handleToggleProductAvailability = async (prod: ProductItemEntity) => {
    if (!selectedRestaurant) return;
    try {
      await RestaurantDomainRepository.updateMenuItem(
        selectedRestaurant.restaurantId,
        prod.id,
        { isAvailable: !prod.isAvailable }
      );
      showToast(prod.isAvailable ? 'تم إيقاف توفر الوجبة مؤقتاً' : 'تم تفعيل توفر الوجبة للزبائن');
    } catch (err: any) {
      showToast('فشل تغيير حالة الصنف', 'error');
    }
  };

  // Delete Dish
  const handleDeleteProduct = async (productId: string, productName: string) => {
    if (!selectedRestaurant) return;
    if (!window.confirm(`متأكد تريد تحذف (${productName}) من المنيو؟`)) return;

    setProducts(prev => prev.filter(p => p.id !== productId));
    try {
      await RestaurantDomainRepository.deleteMenuItem(
        selectedRestaurant.restaurantId,
        productId
      );
      showToast(`تم حذف ${productName} من القائمة بنجاح `);
    } catch (err: any) {
      showToast('فشل حذف الوجبة: ' + (err.message || ''), 'error');
    }
  };

  // Change Password
  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!passwordRestaurant || !newPasswordInput.trim()) return;

    setActionLoadingId(passwordRestaurant.restaurantId);
    try {
      await RestaurantDomainRepository.updateRestaurantPassword(
        passwordRestaurant.restaurantId,
        newPasswordInput.trim()
      );
      showToast(`تم تحديث كلمة مرور مطعم ${passwordRestaurant.name} بنجاح `);
      setPasswordRestaurant(null);
      setNewPasswordInput('');
    } catch (err: any) {
      showToast('ما قدرنا نحدث كلمة المرور: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Filtered Meals for Menu view
  const filteredProducts = useMemo(() => {
    return products.filter(p => {
      if (selectedMenuSection !== 'all') {
        const cat = (p.category || '').toLowerCase().trim();
        const sel = selectedMenuSection.toLowerCase().trim();
        if (cat !== sel && !cat.includes(sel) && !sel.includes(cat)) return false;
      }
      if (menuSearchQuery.trim()) {
        const q = menuSearchQuery.toLowerCase().trim();
        return (
          p.name.toLowerCase().includes(q) ||
          (p.description && p.description.toLowerCase().includes(q)) ||
          (p.category && p.category.toLowerCase().includes(q))
        );
      }
      return true;
    });
  }, [products, selectedMenuSection, menuSearchQuery]);

  // Calculate Sales & Profits for a Restaurant
  const getRestaurantSalesStats = (restaurant: RestaurantEntity) => {
    const mId = restaurant.restaurantId;
    const mName = restaurant.name.trim().toLowerCase();
    const mPhone = (restaurant.phone || '').trim();

    const matchedOrders = allOrders.filter(o => {
      const oId = o.restaurantId || o.merchantId;
      const oTitle = (o.restaurantName || o.merchantOrTitle || '').trim().toLowerCase();
      const oPhone = (o.restaurantPhone || o.merchantPhone || '').trim();
      return (
        (oId && oId === mId) ||
        (oTitle && (oTitle === mName || oTitle.includes(mName) || mName.includes(oTitle))) ||
        (mPhone && oPhone && oPhone.length > 5 && (oPhone === mPhone || mPhone.includes(oPhone)))
      );
    });

    const totalOrdersCount = Math.max(matchedOrders.length, restaurant.totalOrders || 0);
    const completedOrders = matchedOrders.filter(o => 
      o.rawStatus.includes('deliver') || o.rawStatus.includes('complet') || o.status.includes('تم') || o.status.includes('مكتمل')
    );
    const validOrders = matchedOrders.filter(o => !o.rawStatus.includes('cancel') && !o.rawStatus.includes('reject') && !o.status.includes('ملغي'));

    const dynamicSalesIqd = validOrders.reduce((sum, o) => sum + (o.totalPriceIqd || 0), 0);
    const totalSalesIqd = Math.max(dynamicSalesIqd, restaurant.totalRevenueIqd || 0);
    const commissionRate = restaurant.commissionRate || 10;
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

    restaurants.forEach(r => {
      const s = getRestaurantSalesStats(r);
      gmv += s.totalSalesIqd;
      net += s.totalNetProfitIqd;
      ordersCount += s.totalOrdersCount;
    });

    const openCount = restaurants.filter(r => r.isOpen && r.status === 'active').length;
    const closedCount = restaurants.filter(r => !r.isOpen && r.status === 'active').length;
    const pendingCount = restaurants.filter(r => r.status === 'pending').length;
    const suspendedCount = restaurants.filter(r => r.status === 'suspended').length;
    const verifiedCount = restaurants.filter(r => r.status === 'active' || (r.status !== 'pending' && r.status !== 'suspended')).length;

    return {
      total: restaurants.length,
      verifiedCount,
      openCount,
      closedCount,
      pendingCount,
      suspendedCount,
      gmv,
      net,
      ordersCount
    };
  }, [restaurants, allOrders]);

  // Dynamic category matching matching the Madar mobile app
  const matchesCategory = (restaurant: RestaurantEntity, catId: string): boolean => {
    if (catId === 'all') return true;
    const sub = (restaurant.subCategory || '').toLowerCase();
    const target = catId.toLowerCase();
    const cats = Array.isArray((restaurant as any).categories) ? (restaurant as any).categories.map((c: any) => String(c).toLowerCase()) : [];
    
    if (sub === target || cats.includes(target) || sub.includes(target) || target.includes(sub)) return true;

    if (target.includes('مشاو') || target.includes('كباب') || target.includes('مشويات')) {
      return sub.includes('مشاو') || sub.includes('كباب') || sub.includes('لحم') || sub.includes('تكة') || sub.includes('شواء') || cats.some((c: string) => c.includes('مشاو') || c.includes('كباب'));
    }
    if (target.includes('برغر') || target.includes('سندويش')) {
      return sub.includes('برغر') || sub.includes('سندويش') || sub.includes('همبرغر') || sub.includes('صاج') || cats.some((c: string) => c.includes('برغر') || c.includes('سندويش'));
    }
    if (target.includes('بيتزا') || target.includes('معجن') || target.includes('فطائر')) {
      return sub.includes('بيتزا') || sub.includes('معجن') || sub.includes('فطائر') || sub.includes('صمون') || sub.includes('لحم بعجين') || cats.some((c: string) => c.includes('بيتزا') || c.includes('معجن'));
    }
    if (target.includes('دجاج') || target.includes('كرسبي') || target.includes('مقرمش')) {
      return sub.includes('دجاج') || sub.includes('كرسبي') || sub.includes('بروستد') || sub.includes('كنتاكي') || sub.includes('زنجر') || cats.some((c: string) => c.includes('دجاج') || c.includes('كرسبي'));
    }
    if (target.includes('عصير') || target.includes('مشروب')) {
      return sub.includes('عصير') || sub.includes('عصائر') || sub.includes('مشروب') || sub.includes('كافيه') || sub.includes('كوكتيل') || cats.some((c: string) => c.includes('عصير') || c.includes('مشروب'));
    }
    if (target.includes('حلو') || target.includes('كافيه')) {
      return sub.includes('حلو') || sub.includes('كيك') || sub.includes('وافل') || sub.includes('كريب') || sub.includes('كنافة') || sub.includes('ايس') || cats.some((c: string) => c.includes('حلو') || c.includes('كافيه'));
    }
    if (target.includes('شرق') || target.includes('طبخ') || target.includes('قوزي')) {
      return sub.includes('شرق') || sub.includes('قوزي') || sub.includes('مندي') || sub.includes('برياني') || sub.includes('دولمة') || sub.includes('باجة') || cats.some((c: string) => c.includes('شرق') || c.includes('قوزي'));
    }
    if (target.includes('سريع') || target.includes('فاست')) {
      return sub.includes('سريع') || sub.includes('برغر') || sub.includes('صاج') || sub.includes('شاورما') || sub.includes('كرسبي') || sub.includes('فاست') || cats.some((c: string) => c.includes('سريع'));
    }
    if (target.includes('شاورما') || target.includes('صاج')) {
      return sub.includes('شاورما') || sub.includes('صاج') || sub.includes('سندويش') || sub.includes('قص') || cats.some((c: string) => c.includes('شاورما'));
    }
    if (target.includes('شعب') || target.includes('فلافل')) {
      return sub.includes('فلافل') || sub.includes('شعب') || sub.includes('حمص') || sub.includes('فول') || sub.includes('كبة') || cats.some((c: string) => c.includes('فلافل'));
    }
    if (target.includes('سمك') || target.includes('بحري')) {
      return sub.includes('سمك') || sub.includes('بحري') || sub.includes('روبيان') || sub.includes('مسكوف') || cats.some((c: string) => c.includes('سمك'));
    }
    if (target.includes('فطور') || target.includes('صباح')) {
      return sub.includes('فطور') || sub.includes('صباح') || sub.includes('أجبان') || sub.includes('بيض') || sub.includes('قيمر') || cats.some((c: string) => c.includes('فطور'));
    }
    if (target.includes('دايت') || target.includes('صحي')) {
      return sub.includes('دايت') || sub.includes('صحي') || sub.includes('سلط') || sub.includes('رجيم') || cats.some((c: string) => c.includes('دايت'));
    }

    return false;
  };

  const getCategoryRestaurantCount = (catId: string): number => {
    if (catId === 'all') return restaurants.length;
    return restaurants.filter(r => matchesCategory(r, catId)).length;
  };

  // Filtered list
  const filtered = useMemo(() => {
    return restaurants.filter(r => {
      if (selectedApprovalStatus === 'verified' && (r.status === 'pending' || r.status === 'suspended')) return false;
      if (selectedApprovalStatus === 'pending' && r.status !== 'pending') return false;
      if (selectedApprovalStatus === 'suspended' && r.status !== 'suspended') return false;

      // Cuisine Category Filter
      if (selectedCuisineCategory !== 'all' && !matchesCategory(r, selectedCuisineCategory)) {
        return false;
      }

      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;

      return (
        r.name.toLowerCase().includes(q) ||
        r.ownerName.toLowerCase().includes(q) ||
        r.phone.includes(q) ||
        (r.subCategory && r.subCategory.toLowerCase().includes(q)) ||
        (r.address && r.address.toLowerCase().includes(q))
      );
    });
  }, [restaurants, selectedApprovalStatus, selectedCuisineCategory, searchQuery]);

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
            <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'linear-gradient(135deg, #f97316, #ea580c)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <UtensilsCrossed size={22} />
            </div>
            <span>إدارة المطاعم والكافيهات وتصنيفات المأكولات (Restaurants Hub)</span>
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            تصنيف المطاعم (دجاج، كباب، مأكولات شرقية، برغر، بيتزا...)، إدارة المنيو، وتتبع مبيعات الطعام
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          {selectedRestaurant ? (
            <button
              onClick={() => setSelectedRestaurant(null)}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px' }}
            >
              <ArrowRight size={14} /> العودة لقائمة المطاعم
            </button>
          ) : (
            <button
              onClick={() => setShowAddModal(true)}
              className="btn btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '800', background: 'linear-gradient(135deg, #f97316, #ea580c)', borderColor: '#fbbf24' }}
            >
              <Plus size={16} /> + إضافة مطعم جديد
            </button>
          )}
        </div>
      </div>

      {/* ─── 4 MAIN FINANCIAL SUMMARY CARDS ─── */}
      {!selectedRestaurant && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
          
          <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(249, 115, 22, 0.12) 0%, rgba(15, 23, 42, 0.6) 100%)', border: '1px solid rgba(249, 115, 22, 0.3)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>المطاعم المسجلة المعتمدة</span>
              <UtensilsCrossed size={18} color="#fbbf24" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#fbbf24', marginTop: '6px' }}>
              {stats.verifiedCount} مطعم
            </div>
            <div style={{ fontSize: '11px', color: '#fde047', marginTop: '3px' }}>
               {stats.openCount} مفتوح الآن | {stats.closedCount} مغلق
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي مبيعات المأكولات (Food GMV)</span>
              <Coins size={18} color="#34d399" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
              {formatIqd(stats.gmv)}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              عبر {stats.ordersCount} طلب وجبة منفذ
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>عمولة مدار من المطاعم (10%)</span>
              <TrendingUp size={18} color="#38bdf8" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: '#38bdf8', marginTop: '6px' }}>
              {formatIqd(Math.round(stats.gmv * 0.1))}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              صافي أرباح المطاعم: {formatIqd(stats.net)}
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>قائمة الانتظار والمراجعة</span>
              <Clock size={18} color="#f59e0b" />
            </div>
            <div style={{ fontSize: '24px', fontWeight: '950', color: stats.pendingCount > 0 ? '#fbbf24' : '#94a3b8', marginTop: '6px' }}>
              {stats.pendingCount} مطعم 
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
              بانتظار تدقيق الإدارة وتفعيل الحساب
            </div>
          </div>

        </div>
      )}

      {/* ─── VIEW 1: RESTAURANT MENU / CATALOG & SECTIONS MANAGEMENT ─── */}
      {selectedRestaurant ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          <div className="glass-panel" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px', background: 'linear-gradient(135deg, rgba(249, 115, 22, 0.1) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>
                  منيو وأقسام وجبات: {selectedRestaurant.name}
                </h3>
                <span className={`badge ${selectedRestaurant.isOpen ? 'badge-success' : 'badge-danger'}`}>
                  {selectedRestaurant.isOpen ? 'مفتوح للطلبات ' : 'مغلق مؤقتاً '}
                </span>
                <span style={{ fontSize: '11.5px', color: '#fbbf24', background: 'rgba(251, 191, 36, 0.15)', padding: '2px 8px', borderRadius: '6px' }}>
                   {selectedRestaurant.subCategory || 'مطاعم'}
                </span>
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                المالك: {selectedRestaurant.ownerName} • الهاتف: <span dir="ltr">{selectedRestaurant.phone}</span> • إجمالي أصناف المنيو: {products.length} وجبة • الأقسام: {menuCategories.length} أقسام
              </div>
            </div>

            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                onClick={() => setShowAddCategoryModal(true)}
                className="btn btn-secondary"
                style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', fontWeight: '700', borderColor: '#38bdf8', color: '#38bdf8' }}
              >
                <Plus size={14} /> + إضافة قسم بالمنيو
              </button>
              <button
                onClick={() => setShowAddProductModal(true)}
                className="btn btn-primary"
                style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', fontWeight: '800', background: 'linear-gradient(135deg, #f97316, #ea580c)', borderColor: '#fbbf24' }}
              >
                <Plus size={15} /> + إضافة وجبة / طبق جديد
              </button>
            </div>
          </div>

          {/* RESTAURANT MENU SECTIONS / CATEGORIES BAR */}
          <div className="glass-panel" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '8px' }}>
              <div style={{ fontSize: '12.5px', fontWeight: '800', color: '#fbbf24', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span> أقسام قائمة الطعام المضافة ({menuCategories.length}):</span>
              </div>
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '220px' }}>
                <Search size={14} color="#94a3b8" style={{ position: 'absolute', right: '10px' }} />
                <input
                  type="text"
                  placeholder="ابحث في وجبات هذا المطعم..."
                  value={menuSearchQuery}
                  onChange={e => setMenuSearchQuery(e.target.value)}
                  style={{ width: '100%', padding: '6px 30px 6px 10px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px', outline: 'none' }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '4px' }}>
              <button
                onClick={() => setSelectedMenuSection('all')}
                style={{
                  background: selectedMenuSection === 'all' ? 'linear-gradient(135deg, rgba(249, 115, 22, 0.3), rgba(249, 115, 22, 0.1))' : 'rgba(255, 255, 255, 0.03)',
                  border: selectedMenuSection === 'all' ? '1px solid #f97316' : '1px solid rgba(255, 255, 255, 0.08)',
                  color: selectedMenuSection === 'all' ? '#fff' : 'var(--text-muted)',
                  padding: '6px 14px',
                  borderRadius: '10px',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  whiteSpace: 'nowrap',
                  fontSize: '12px',
                  fontWeight: selectedMenuSection === 'all' ? '800' : '600'
                }}
              >
                <span></span>
                <span>جميع الأقسام</span>
                <span style={{ background: 'rgba(255,255,255,0.1)', padding: '1px 6px', borderRadius: '10px', fontSize: '10px' }}>
                  {products.length}
                </span>
              </button>

              {menuCategories.map(cat => {
                const isSel = selectedMenuSection === cat.name;
                const count = cat.itemCount !== undefined ? cat.itemCount : products.filter(p => (p.category || '').toLowerCase() === cat.name.toLowerCase()).length;
                return (
                  <div
                    key={cat.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      background: isSel ? 'linear-gradient(135deg, rgba(56, 189, 248, 0.25), rgba(56, 189, 248, 0.08))' : 'rgba(255, 255, 255, 0.03)',
                      border: isSel ? '1px solid #38bdf8' : '1px solid rgba(255, 255, 255, 0.08)',
                      borderRadius: '10px',
                      overflow: 'hidden'
                    }}
                  >
                    <button
                      onClick={() => setSelectedMenuSection(cat.name)}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        color: isSel ? '#fff' : 'var(--text-muted)',
                        padding: '6px 10px 6px 12px',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        whiteSpace: 'nowrap',
                        fontSize: '12px',
                        fontWeight: isSel ? '800' : '600'
                      }}
                    >
                      <span></span>
                      <span>{cat.name}</span>
                      <span style={{ background: isSel ? '#38bdf8' : 'rgba(255,255,255,0.1)', color: isSel ? '#0f172a' : 'inherit', padding: '1px 6px', borderRadius: '10px', fontSize: '10px', fontWeight: '800' }}>
                        {count}
                      </span>
                    </button>
                    <button
                      onClick={(e) => { e.stopPropagation(); handleDeleteMenuCategory(cat); }}
                      style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: '6px 8px 6px 6px', fontSize: '12px' }}
                      title={`حذف قسم (${cat.name})`}
                    >
                      
                    </button>
                  </div>
                );
              })}

              <button
                onClick={() => setShowAddCategoryModal(true)}
                style={{
                  background: 'rgba(56, 189, 248, 0.08)',
                  border: '1px dashed #38bdf8',
                  color: '#38bdf8',
                  padding: '6px 12px',
                  borderRadius: '10px',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  whiteSpace: 'nowrap',
                  fontSize: '11.5px',
                  fontWeight: '700'
                }}
              >
                <Plus size={13} /> إضافة قسم جديد
              </button>
            </div>
          </div>

          {/* Products / Menu Table */}
          <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
            {isProductsLoading ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={24} color="#f97316" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                <div>جاري جلب قائمة الوجبات والأقسام من Firestore...</div>
              </div>
            ) : filteredProducts.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Package size={32} color="#64748b" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>
                  {products.length === 0 ? 'ماكو وجبات حالياً مضافة في قائمة هذا المطعم' : 'ماكو وجبات حالياً في هذا القسم المحدد'}
                </div>
                <div style={{ display: 'flex', gap: '8px', justifyContent: 'center', marginTop: '12px' }}>
                  <button onClick={() => setShowAddProductModal(true)} className="btn btn-primary" style={{ fontSize: '12px' }}>
                    + إضافة وجبة أولى
                  </button>
                  <button onClick={() => setShowAddCategoryModal(true)} className="btn btn-secondary" style={{ fontSize: '12px' }}>
                    + إضافة قسم جديد
                  </button>
                </div>
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>اسم الوجبة والطبق</th>
                      <th>القسم في المنيو</th>
                      <th>السعر</th>
                      <th>حالة التوفر للزبائن</th>
                      <th>الوصف والمكونات</th>
                      <th>الإجراءات</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredProducts.map(p => (
                      <tr key={p.id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            {p.imageUrl ? (
                              <img src={p.imageUrl} alt={p.name} style={{ width: '36px', height: '36px', borderRadius: '8px', objectFit: 'cover' }} />
                            ) : (
                              <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: 'rgba(255,255,255,0.05)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '16px' }}>
                                
                              </div>
                            )}
                            <div>
                              <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{p.name}</div>
                              {p.salesCount > 0 && (
                                <div style={{ fontSize: '10.5px', color: '#fbbf24' }}>طلب {p.salesCount} مرة</div>
                              )}
                            </div>
                          </div>
                        </td>
                        <td>
                          <span style={{ fontSize: '11px', color: '#38bdf8', background: 'rgba(56, 189, 248, 0.1)', padding: '2px 8px', borderRadius: '6px', border: '1px solid rgba(56, 189, 248, 0.2)' }}>
                             {p.category || 'رئيسي'}
                          </span>
                        </td>
                        <td>
                          <span style={{ fontWeight: '800', color: '#34d399', fontSize: '13px' }}>{formatIqd(p.price)}</span>
                        </td>
                        <td>
                          <button
                            onClick={() => handleToggleProductAvailability(p)}
                            className={`badge ${p.isAvailable ? 'badge-success' : 'badge-danger'}`}
                            style={{ cursor: 'pointer', border: 'none', fontSize: '10.5px' }}
                          >
                            {p.isAvailable ? 'متاح للطلب ' : 'غير متوفر '}
                          </button>
                        </td>
                        <td>
                          <div style={{ fontSize: '11px', color: 'var(--text-dim)', maxWidth: '250px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {p.description || 'ماكو وصف حالياً'}
                          </div>
                        </td>
                        <td>
                          <button
                            onClick={() => handleDeleteProduct(p.id, p.name)}
                            style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '4px' }}
                            title="حذف الوجبة"
                          >
                            <Trash2 size={14} />
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
        /* ─── VIEW 2: RESTAURANTS TABLE WITH SEPARATE TABS & CUISINE SELECTOR ─── */
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          {/* Status & Search Filters */}
          <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            
            {/* CUISINE CATEGORIES SELECTOR BAR */}
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                <span style={{ fontSize: '12px', fontWeight: '800', color: '#fbbf24', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <span> تصفية حسب تصنيف المطعم والمطبخ:</span>
                  <span style={{ color: 'var(--text-dim)', fontWeight: 'normal' }}>(مطابق لتطبيق الزبائن)</span>
                </span>
                {selectedCuisineCategory !== 'all' && (
                  <button
                    onClick={() => setSelectedCuisineCategory('all')}
                    style={{ background: 'transparent', border: 'none', color: '#38bdf8', fontSize: '11px', cursor: 'pointer', textDecoration: 'underline' }}
                  >
                    إلغاء الفلتر
                  </button>
                )}
              </div>

              <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '6px' }}>
                {CUISINE_CATEGORIES.map(cat => {
                  const isSel = selectedCuisineCategory === cat.id;
                  const count = getCategoryRestaurantCount(cat.id);

                  return (
                    <button
                      key={cat.id}
                      onClick={() => setSelectedCuisineCategory(cat.id)}
                      style={{
                        background: isSel ? `linear-gradient(135deg, ${cat.color}33, ${cat.color}11)` : 'rgba(255, 255, 255, 0.03)',
                        border: isSel ? `1.5px solid ${cat.color}` : '1px solid rgba(255, 255, 255, 0.06)',
                        color: isSel ? '#fff' : 'var(--text-muted)',
                        padding: '6px 12px',
                        borderRadius: '12px',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        whiteSpace: 'nowrap',
                        fontSize: '12px',
                        fontWeight: isSel ? '800' : '600',
                        transition: 'all 0.15s ease',
                        boxShadow: isSel ? `0 4px 14px ${cat.color}22` : 'none'
                      }}
                    >
                      {/* Food Graphic Image with Fallback to Emoji */}
                      <div style={{
                        width: '24px',
                        height: '24px',
                        borderRadius: '50%',
                        background: isSel ? `${cat.color}33` : 'rgba(255, 255, 255, 0.05)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        overflow: 'hidden'
                      }}>
                        <img
                          src={`/imges/restaurants/${cat.imageFileName}`}
                          alt={cat.label}
                          onError={(e) => {
                            (e.target as HTMLElement).style.display = 'none';
                          }}
                          style={{ width: '20px', height: '20px', objectFit: 'contain' }}
                        />
                        <span style={{ fontSize: '13px', display: 'none' }}>{cat.icon}</span>
                      </div>

                      <span>{cat.label}</span>
                      <span style={{
                        background: isSel ? cat.color : 'rgba(255, 255, 255, 0.08)',
                        color: isSel ? '#0f172a' : 'var(--text-dim)',
                        padding: '1px 7px',
                        borderRadius: '10px',
                        fontSize: '10px',
                        fontWeight: '800'
                      }}>
                        {count}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px', paddingTop: '8px', borderTop: '1px solid rgba(255, 255, 255, 0.06)' }}>
              {/* Approval Status Tabs */}
              <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
                <button
                  onClick={() => setSelectedApprovalStatus('verified')}
                  className={`btn ${selectedApprovalStatus === 'verified' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '800' }}
                >
                  <ShieldCheck size={14} color="#34d399" />
                  <span> المعتمدة ({stats.verifiedCount})</span>
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
                  <span> قيد المراجعة ({stats.pendingCount})</span>
                </button>

                <button
                  onClick={() => setSelectedApprovalStatus('suspended')}
                  className={`btn ${selectedApprovalStatus === 'suspended' ? 'btn-danger' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
                >
                  <Ban size={14} />
                  <span> الموقوفة ({stats.suspendedCount})</span>
                </button>

                <button
                  onClick={() => setSelectedApprovalStatus('all')}
                  className={`btn ${selectedApprovalStatus === 'all' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', padding: '6px 14px' }}
                >
                  <span> عرض الكل ({restaurants.length})</span>
                </button>
              </div>

              {/* Search */}
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '280px' }}>
                <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
                <input
                  type="text"
                  placeholder="ابحث باسم المطعم، المالك، أو الهاتف..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  style={{ width: '100%', padding: '8px 36px 8px 12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                />
              </div>
            </div>

          </div>

          {/* Restaurants Main Table */}
          <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
            {isLoading ? (
              <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={26} color="#f97316" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                <div>جاري جلب بيانات المطاعم من Firestore...</div>
              </div>
            ) : filtered.length === 0 ? (
              <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <UtensilsCrossed size={36} color="#64748b" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>ماكو مطاعم حالياً مطابقة للشروط المحددة</div>
                <div style={{ fontSize: '12px', marginTop: '4px' }}>جرب تغيير تصنيف المطبخ أو تصفير حقل البحث</div>
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>اسم المطعم والتصنيف</th>
                      <th>المالك ورقم الهاتف</th>
                      <th>العنوان</th>
                      <th>نسبة العمولة %</th>
                      <th>حالة العمل</th>
                      <th>إجمالي مبيعات المطعم (GMV) </th>
                      <th>سجل الطلبات</th>
                      <th>قائمة المنيو</th>
                      <th>الإجراءات الإدارية</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map(r => {
                      const sales = getRestaurantSalesStats(r);
                      return (
                        <tr key={r.merchantId}>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                              {r.logoUrl ? (
                                <img src={r.logoUrl} alt={r.name} style={{ width: '40px', height: '40px', borderRadius: '10px', objectFit: 'cover' }} />
                              ) : (
                                <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(249, 115, 22, 0.15)', color: '#fbbf24', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '900', fontSize: '18px' }}>
                                  
                                </div>
                              )}
                              <div>
                                <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{r.name}</div>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '4px' }}>
                                  <select
                                    value={CUISINE_CATEGORIES.some(c => c.id === r.subCategory) ? r.subCategory : 'custom'}
                                    onChange={async (e) => {
                                      const newCat = e.target.value;
                                      if (newCat === 'custom') {
                                        handleOpenEdit(r);
                                        return;
                                      }
                                      try {
                                        await RestaurantDomainRepository.updateRestaurant(r.restaurantId, { cuisineType: newCat, subCategory: newCat });
                                        showToast(`تم تصنيف (${r.name}) كـ (${newCat}) بنجاح `);
                                      } catch (err: any) {
                                        showToast(`فشل تحديث التصنيف: ${err.message}`, 'error');
                                      }
                                    }}
                                    style={{
                                      background: '#0f172a',
                                      color: '#fbbf24',
                                      border: '1px solid rgba(251, 191, 36, 0.4)',
                                      borderRadius: '6px',
                                      fontSize: '11px',
                                      fontWeight: '700',
                                      padding: '2px 6px',
                                      outline: 'none',
                                      cursor: 'pointer'
                                    }}
                                    title="تغيير تصنيف المطبخ مباشرة"
                                  >
                                    {CUISINE_CATEGORIES.filter(c => c.id !== 'all').map(c => (
                                      <option key={c.id} value={c.id}>{c.icon} {c.label}</option>
                                    ))}
                                    <option value="custom"> {r.subCategory || 'تعديل مخصص'}</option>
                                  </select>
                                </div>
                              </div>
                            </div>
                          </td>
                          <td>
                            <div style={{ fontSize: '12.5px', color: '#fff' }}>{r.ownerName}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{r.phone}</div>
                          </td>
                          <td>
                            <div style={{ fontSize: '12px', color: '#cbd5e1' }}> {r.address || 'القائم'}</div>
                          </td>
                          <td>
                            <span style={{ fontWeight: '900', color: '#38bdf8', fontSize: '13px' }}>{r.commissionRate}%</span>
                          </td>
                          <td>
                            <button
                              onClick={() => handleToggleStatus(r)}
                              className={`badge ${r.isOpen ? 'badge-success' : 'badge-danger'}`}
                              style={{ cursor: 'pointer', border: 'none', fontSize: '10.5px' }}
                            >
                              {r.isOpen ? 'مفتوح ' : 'مغلق مؤقتاً '}
                            </button>
                          </td>
                          <td>
                            <div style={{ fontWeight: '900', color: sales.totalSalesIqd > 0 ? '#34d399' : '#cbd5e1', fontSize: '13.5px' }}>
                              {formatIqd(sales.totalSalesIqd)}
                            </div>
                            <div style={{ fontSize: '10.5px', color: '#fbbf24' }}>
                              صافي: {formatIqd(sales.totalNetProfitIqd)}
                            </div>
                          </td>
                          <td>
                            <button
                              onClick={() => setOrdersRestaurant(r)}
                              className="btn btn-primary"
                              style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
                            >
                              <Receipt size={12} /> الطلبات
                            </button>
                          </td>
                          <td>
                            <button
                              onClick={() => setSelectedRestaurant(r)}
                              className="btn btn-secondary"
                              style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px', color: '#fbbf24' }}
                            >
                              <UtensilsCrossed size={12} /> المنيو
                            </button>
                          </td>
                          <td>
                            <div style={{ display: 'flex', gap: '4px' }}>
                              {r.status === 'pending' && (
                                <button
                                  onClick={() => handleApprove(r)}
                                  className="btn btn-primary"
                                  style={{ fontSize: '11px', padding: '4px 8px', background: '#059669', borderColor: '#34d399' }}
                                  title="اعتماد وتوثيق المطعم"
                                >
                                  <Check size={12} /> اعتماد
                                </button>
                              )}
                              <button
                                onClick={() => handleOpenEdit(r)}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '3px', color: '#38bdf8', borderColor: '#38bdf8' }}
                                title="تعديل بيانات المطعم والبريد والباسورد"
                              >
                                <Edit3 size={13} />
                                <span>تعديل</span>
                              </button>
                              <button
                                onClick={() => setDetailsRestaurant(r)}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 7px' }}
                                title="عرض الملف"
                              >
                                <Eye size={13} color="#06b6d4" />
                              </button>
                              <button
                                onClick={() => { setPasswordRestaurant(r); setNewPasswordInput(''); }}
                                className="btn btn-secondary"
                                style={{ fontSize: '11px', padding: '4px 7px', color: '#fbbf24' }}
                                title="تغيير كلمة المرور"
                              >
                                <Key size={13} />
                              </button>
                              <button
                                onClick={() => handleDeleteRestaurant(r)}
                                style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '4px' }}
                                title="حذف المطعم"
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

      {/* ─── ADD RESTAURANT MODAL ─── */}
      {showAddModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '520px', width: '100%', borderRadius: '22px', border: '1px solid rgba(249, 115, 22, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0 }}>إضافة مطعم جديد للمنظومة </h3>
              <button onClick={() => setShowAddModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleAddRestaurant} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المطعم:</label>
                <input type="text" required value={restName} onChange={e => setRestName(e.target.value)} placeholder="مثال: مطاعم ومشويات القائم الملكية" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>تصنيف ونوع المطبخ:</label>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <select
                    value={CUISINE_CATEGORIES.some(c => c.id === restSubCategory) ? restSubCategory : 'custom'}
                    onChange={e => {
                      if (e.target.value !== 'custom') setRestSubCategory(e.target.value);
                    }}
                    style={{ padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fbbf24', fontSize: '13px', fontWeight: '700', outline: 'none' }}
                  >
                    {CUISINE_CATEGORIES.filter(c => c.id !== 'all').map(c => (
                      <option key={c.id} value={c.id}>{c.icon} {c.label}</option>
                    ))}
                    <option value="custom"> تصنيف مخصص...</option>
                  </select>
                  <input
                    type="text"
                    value={restSubCategory}
                    onChange={e => setRestSubCategory(e.target.value)}
                    placeholder="مشاوي / دجاج / برغر..."
                    style={{ flex: 1, padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المالك:</label>
                  <input type="text" required value={restOwner} onChange={e => setRestOwner(e.target.value)} placeholder="اسم صاحب المطعم" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>نسبة العمولة (%):</label>
                  <input type="number" min="0" max="30" value={restCommission} onChange={e => setRestCommission(Number(e.target.value))} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#38bdf8', fontSize: '13px', fontWeight: '800' }} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>رقم الهاتف:</label>
                  <input type="tel" required dir="ltr" value={restPhone} onChange={e => setRestPhone(e.target.value)} placeholder="077XXXXXXXX" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>العنوان في القائم:</label>
                  <input type="text" value={restAddress} onChange={e => setRestAddress(e.target.value)} placeholder="شارع الأطباء / سوق القائم" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #f97316, #ea580c)' }}>
                  حفظ وإضافة المطعم
                </button>
                <button type="button" onClick={() => setShowAddModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── ADD MENU SECTION / CATEGORY MODAL ─── */}
      {showAddCategoryModal && selectedRestaurant && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '440px', width: '100%', borderRadius: '22px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>إضافة قسم جديد لمنيو ({selectedRestaurant.name}) </h3>
              <button onClick={() => setShowAddCategoryModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleAddMenuCategory} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '6px' }}>اسم القسم الجديد بالمنيو:</label>
                <input
                  type="text"
                  required
                  value={newCategoryName}
                  onChange={e => setNewCategoryName(e.target.value)}
                  placeholder="مثال: وجبات التوفير، المقبلات، الصاج، المشروبات..."
                  style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                />
              </div>

              {/* Suggestions Chips */}
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>أقسام مقترحة شائعة:</span>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                  {['وجبات رئيسية', 'مشاوي وكباب', 'برغر وسندويشات', 'دجاج كرسبي', 'بيتزا وفطائر', 'مقبلات وسلطات', 'مشروبات وعصائر', 'حلويات وكافيه', 'إضافات وصلصات'].map(sug => (
                    <button
                      type="button"
                      key={sug}
                      onClick={() => setNewCategoryName(sug)}
                      style={{
                        background: 'rgba(255,255,255,0.04)',
                        border: '1px solid rgba(255,255,255,0.1)',
                        color: '#cbd5e1',
                        padding: '4px 10px',
                        borderRadius: '12px',
                        fontSize: '11px',
                        cursor: 'pointer'
                      }}
                    >
                      + {sug}
                    </button>
                  ))}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '8px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #0284c7, #0369a1)' }}>
                  حفظ وإضافة القسم 
                </button>
                <button type="button" onClick={() => setShowAddCategoryModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── ADD DISH / MEAL MODAL ─── */}
      {showAddProductModal && selectedRestaurant && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '480px', width: '100%', borderRadius: '22px', border: '1px solid rgba(249, 115, 22, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0 }}>إضافة وجبة جديدة لـ ({selectedRestaurant.name})</h3>
              <button onClick={() => setShowAddProductModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleAddProduct} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم الوجبة / الطبق:</label>
                <input type="text" required value={newProdName} onChange={e => setNewProdName(e.target.value)} placeholder="مثال: نفر كباب عراقي مشوي" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>القسم في المنيو:</label>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {menuCategories.length > 0 && (
                      <select
                        value={menuCategories.some(c => c.name === newProdCategory) ? newProdCategory : 'custom'}
                        onChange={e => {
                          if (e.target.value !== 'custom') setNewProdCategory(e.target.value);
                        }}
                        style={{ padding: '8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fbbf24', fontSize: '12px', outline: 'none' }}
                      >
                        {menuCategories.map(c => (
                          <option key={c.id} value={c.name}> {c.name}</option>
                        ))}
                        <option value="custom"> قسم مخصص...</option>
                      </select>
                    )}
                    <input
                      type="text"
                      value={newProdCategory}
                      onChange={e => setNewProdCategory(e.target.value)}
                      placeholder="مشاوي / مقبلات / عصائر"
                      style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }}
                    />
                  </div>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>السعر بالدينار العراقي:</label>
                  <input type="number" step="250" value={newProdPrice} onChange={e => setNewProdPrice(Number(e.target.value))} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#34d399', fontSize: '13px', fontWeight: '800' }} />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>المكونات والوصف:</label>
                <textarea rows={2} value={newProdDesc} onChange={e => setNewProdDesc(e.target.value)} placeholder="مكونات الوجبة والخيارات الإضافية..." style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #f97316, #ea580c)' }}>
                  حفظ وإضافة الوجبة
                </button>
                <button type="button" onClick={() => setShowAddProductModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── RESTAURANT DETAILS MODAL ─── */}
      {detailsRestaurant && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '560px', width: '100%', borderRadius: '22px', border: '1px solid rgba(249, 115, 22, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>ملف مطعم: {detailsRestaurant.name}</h3>
              <button onClick={() => setDetailsRestaurant(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '13px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>اسم المالك:</span>
                <span style={{ color: '#fff', fontWeight: '700' }}>{detailsRestaurant.ownerName}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>التصنيف / المطبخ:</span>
                <span style={{ color: '#fbbf24', fontWeight: '800' }}>{detailsRestaurant.subCategory || 'مطاعم ومأكولات'}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>رقم الهاتف:</span>
                <span style={{ color: '#fff', fontWeight: '700' }} dir="ltr">{detailsRestaurant.phone}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>العنوان في القائم:</span>
                <span style={{ color: '#cbd5e1' }}>{detailsRestaurant.address}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>نسبة العمولة:</span>
                <span style={{ color: '#38bdf8', fontWeight: '800' }}>{detailsRestaurant.commissionRate}%</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'rgba(255,255,255,0.02)', borderRadius: '8px' }}>
                <span style={{ color: 'var(--text-muted)' }}>تاريخ التسجيل:</span>
                <span style={{ color: '#cbd5e1' }}>{detailsRestaurant.createdAt}</span>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '16px' }}>
              <button onClick={() => setDetailsRestaurant(null)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إغلاق</button>
            </div>
          </div>
        </div>
      )}

      {/* ─── EDIT RESTAURANT PROFILE MODAL ─── */}
      {editingRestaurant && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '540px', width: '100%', borderRadius: '22px', border: '1px solid rgba(56, 189, 248, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '14px' }}>
              <div>
                <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0 }}>تعديل وتصنيف بيانات المطعم </h3>
                <div style={{ fontSize: '11.5px', color: '#38bdf8', marginTop: '2px' }}>{editingRestaurant.name} (معرف: {editingRestaurant.merchantId.slice(0, 8)})</div>
              </div>
              <button onClick={() => setEditingRestaurant(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            {/* Safety Guarantee Ribbon */}
            <div style={{ padding: '8px 12px', background: 'rgba(16, 185, 129, 0.12)', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '10px', display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '14px' }}>
              <ShieldCheck size={16} color="#34d399" />
              <span style={{ fontSize: '11px', color: '#34d399', fontWeight: '700' }}>
                 حفظ آمن: يتم تحديث التصنيف والبيانات بدون فقدان المنيو أو توكنات الإشعارات (FCM).
              </span>
            </div>

            <form onSubmit={handleUpdateRestaurantSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم المطعم:</label>
                <input type="text" required value={editName} onChange={e => setEditName(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>تصنيف ونوع المطبخ (يظهر في تطبيق الزبائن):</label>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <select
                    value={CUISINE_CATEGORIES.some(c => c.id === editSubCategory) ? editSubCategory : 'custom'}
                    onChange={e => {
                      if (e.target.value !== 'custom') setEditSubCategory(e.target.value);
                    }}
                    style={{ padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fbbf24', fontSize: '13px', fontWeight: '700', outline: 'none' }}
                  >
                    {CUISINE_CATEGORIES.filter(c => c.id !== 'all').map(c => (
                      <option key={c.id} value={c.id}>{c.icon} {c.label}</option>
                    ))}
                    <option value="custom"> تصنيف مخصص...</option>
                  </select>
                  <input
                    type="text"
                    value={editSubCategory}
                    onChange={e => setEditSubCategory(e.target.value)}
                    placeholder="مشاوي / دجاج كرسبي / برغر..."
                    style={{ flex: 1, padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم صاحب المطعم:</label>
                  <input type="text" required value={editOwner} onChange={e => setEditOwner(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>نسبة العمولة (%):</label>
                  <input type="number" min="0" max="30" value={editCommission} onChange={e => setEditCommission(Number(e.target.value))} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#38bdf8', fontSize: '13px', fontWeight: '800' }} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>رقم الهاتف:</label>
                  <input type="tel" required dir="ltr" value={editPhone} onChange={e => setEditPhone(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>العنوان في القائم:</label>
                  <input type="text" value={editAddress} onChange={e => setEditAddress(e.target.value)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
              </div>

              {/* Email & Password Credentials */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', background: 'rgba(255,255,255,0.02)', padding: '10px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: '#38bdf8', marginBottom: '4px', fontWeight: '700' }}>البريد الإلكتروني للـ Login:</label>
                  <input type="email" dir="ltr" value={editEmail} onChange={e => setEditEmail(e.target.value)} placeholder="restaurant@madar.iq" style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }} />
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
                <button type="button" onClick={() => setEditingRestaurant(null)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
