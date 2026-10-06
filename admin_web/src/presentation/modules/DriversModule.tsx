import React, { useState, useEffect } from 'react';
import {
  Car,
  Search,
  Filter,
  ShieldCheck,
  ShieldAlert,
  CheckCircle,
  XCircle,
  Star,
  Wallet,
  Loader2,
  Ban,
  Check,
  AlertCircle,
  Eye,
  FileText,
  User,
  Phone,
  MapPin,
  Calendar,
  DollarSign,
  TrendingUp,
  Trash2,
  X,
  ExternalLink,
  Edit3,
  Image,
  CheckSquare,
  Square,
  Radio
} from 'lucide-react';
import { DriverEntity } from '../../domain/types';
import { TaxiCaptainRepository } from '../../infrastructure/repositories/TaxiCaptainRepository';
import { MersalCourierRepository } from '../../infrastructure/repositories/MersalCourierRepository';

interface DriversModuleProps {
  initialVehicleCategory?: 'all' | 'motorcycle' | 'taxi';
  pageTitle?: string;
}

export const DriversModule: React.FC<DriversModuleProps> = ({
  initialVehicleCategory = 'all',
  pageTitle
}) => {
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<'verified' | 'pending' | 'blocked' | 'all'>('verified');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Multi-Selection State for Bulk Delete
  const [selectedDriverIds, setSelectedDriverIds] = useState<string[]>([]);
  const [isBulkDeleting, setIsBulkDeleting] = useState(false);

  // Detailed Driver View Modal
  const [selectedDriver, setSelectedDriver] = useState<DriverEntity | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');
  const [showRejectInput, setShowRejectInput] = useState(false);
  const [blockReasonInput, setBlockReasonInput] = useState('');
  const [showBlockInput, setShowBlockInput] = useState(false);

  // Edit Driver State & Modal
  const [editingDriver, setEditingDriver] = useState<DriverEntity | null>(null);
  const [editName, setEditName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editVehicleModel, setEditVehicleModel] = useState('');
  const [editPlateNumber, setEditPlateNumber] = useState('');
  const [editVehicleColor, setEditVehicleColor] = useState('');
  const [editVehicleYear, setEditVehicleYear] = useState('');
  const [editCity, setEditCity] = useState('القائم');
  const [editWalletBalance, setEditWalletBalance] = useState<number>(0);
  const [editAppDebt, setEditAppDebt] = useState<number>(0);
  const [editPhotoUrl, setEditPhotoUrl] = useState('');
  const [editNationalIdUrl, setEditNationalIdUrl] = useState('');
  const [editLicenseUrl, setEditLicenseUrl] = useState('');
  const [editCarDocUrl, setEditCarDocUrl] = useState('');

  const [selectedVehicleType, setSelectedVehicleType] = useState<'all' | 'motorcycle' | 'taxi'>(initialVehicleCategory);

  useEffect(() => {
    if (initialVehicleCategory) {
      setSelectedVehicleType(initialVehicleCategory);
    }
  }, [initialVehicleCategory]);

  useEffect(() => {
    setIsLoading(true);

    if (selectedVehicleType === 'taxi') {
      const unsub = TaxiCaptainRepository.subscribeToCaptains((data) => {
        setDrivers(data);
        setIsLoading(false);
        if (selectedDriver) {
          const updated = data.find(d => d.driverId === selectedDriver.driverId);
          if (updated) setSelectedDriver(updated);
        }
      });
      return () => unsub();
    } else if (selectedVehicleType === 'motorcycle') {
      const unsub = MersalCourierRepository.subscribeToCouriers((data) => {
        setDrivers(data);
        setIsLoading(false);
        if (selectedDriver) {
          const updated = data.find(d => d.driverId === selectedDriver.driverId);
          if (updated) setSelectedDriver(updated);
        }
      });
      return () => unsub();
    } else {
      // Combined 'all'
      let captains: DriverEntity[] = [];
      let couriers: DriverEntity[] = [];
      const unsubCaptains = TaxiCaptainRepository.subscribeToCaptains((cData) => {
        captains = cData;
        setDrivers([...captains, ...couriers]);
        setIsLoading(false);
      });
      const unsubCouriers = MersalCourierRepository.subscribeToCouriers((mData) => {
        couriers = mData;
        setDrivers([...captains, ...couriers]);
        setIsLoading(false);
      });
      return () => {
        unsubCaptains();
        unsubCouriers();
      };
    }
  }, [selectedVehicleType]);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const handleOpenEditModal = (driver: DriverEntity) => {
    setEditingDriver(driver);
    setEditName(driver.name);
    setEditPhone(driver.phoneNumber);
    setEditVehicleModel(driver.vehicleModel);
    setEditPlateNumber(driver.plateNumber);
    setEditVehicleColor(driver.vehicleColor || 'أصفر / أبيض');
    setEditVehicleYear(driver.vehicleYear || '2020');
    setEditCity(driver.city || 'القائم');
    setEditWalletBalance(driver.walletBalance || 0);
    setEditAppDebt(driver.appDebt || 0);
    setEditPhotoUrl(driver.personalPhotoUrl || '');
    setEditNationalIdUrl(driver.nationalIdUrl || '');
    setEditLicenseUrl(driver.licenseUrl || '');
    setEditCarDocUrl(driver.carDocUrl || '');
  };

  const handleSaveDriverDetails = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingDriver) return;

    setActionLoadingId(editingDriver.driverId);
    try {
      const updates = {
        name: editName.trim(),
        phoneNumber: editPhone.trim(),
        vehicleModel: editVehicleModel.trim(),
        plateNumber: editPlateNumber.trim(),
        vehicleColor: editVehicleColor.trim(),
        vehicleYear: editVehicleYear.trim(),
        city: editCity.trim(),
        walletBalance: Number(editWalletBalance) || 0,
        appDebt: Number(editAppDebt) || 0,
        personalPhotoUrl: editPhotoUrl.trim(),
        nationalIdUrl: editNationalIdUrl.trim(),
        licenseUrl: editLicenseUrl.trim(),
        carDocUrl: editCarDocUrl.trim()
      };

      if (editingDriver.vehicleCategory === 'motorcycle') {
        await MersalCourierRepository.updateCourierDetails(editingDriver.driverId, updates);
      } else {
        await TaxiCaptainRepository.updateCaptainDetails(editingDriver.driverId, updates);
      }

      showToast(`تم تحديث بيانات وصور الكابتن (${editName}) بنجاح `);
      setEditingDriver(null);
    } catch (err: any) {
      showToast('فشل تحديث بيانات الكابتن: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Checkbox handlers
  const handleToggleSelectAll = (filteredList: DriverEntity[]) => {
    if (selectedDriverIds.length === filteredList.length) {
      setSelectedDriverIds([]);
    } else {
      setSelectedDriverIds(filteredList.map(d => d.driverId));
    }
  };

  const handleToggleSelectOne = (driverId: string) => {
    if (selectedDriverIds.includes(driverId)) {
      setSelectedDriverIds(prev => prev.filter(id => id !== driverId));
    } else {
      setSelectedDriverIds(prev => [...prev, driverId]);
    }
  };

  // Bulk Delete
  const handleBulkDelete = async () => {
    if (selectedDriverIds.length === 0) return;
    const count = selectedDriverIds.length;

    if (!window.confirm(` تحذير: متأكد تريد تحذف (${count}) كابتن دفعة واحدة نهائياً من قاعدة البيانات؟ لا يمكن التراجع عن هذا الإجراء.`)) {
      return;
    }

    setIsBulkDeleting(true);
    try {
      setDrivers(prev => prev.filter(d => !selectedDriverIds.includes(d.driverId)));
      if (selectedVehicleType === 'motorcycle') {
        await MersalCourierRepository.deleteMultipleCouriers(selectedDriverIds);
      } else {
        await TaxiCaptainRepository.deleteMultipleCaptains(selectedDriverIds);
      }
      showToast(`تم حذف (${count}) كابتن بنجاح من قاعدة البيانات `);
      setSelectedDriverIds([]);
      if (selectedDriver && selectedDriverIds.includes(selectedDriver.driverId)) {
        setSelectedDriver(null);
      }
    } catch (err: any) {
      showToast('فشل الحذف الجماعي: ' + (err.message || ''), 'error');
    } finally {
      setIsBulkDeleting(false);
    }
  };

  const handleToggleBlock = async (driver: DriverEntity, reason?: string) => {
    const nextState = !driver.isBlocked;
    const confirmMsg = nextState 
      ? `هل أنت متأكد من حظر الكابتن (${driver.name})؟ سيتم إخفاؤه من قائمة الكباتن النشطين.` 
      : `هل تريد فك الحظر عن الكابتن (${driver.name})؟`;
    
    if (!window.confirm(confirmMsg)) return;

    setActionLoadingId(driver.driverId);
    try {
      if (driver.vehicleCategory === 'motorcycle') {
        await MersalCourierRepository.toggleCourierBlock(driver.driverId, nextState, reason || blockReasonInput);
      } else {
        await TaxiCaptainRepository.toggleCaptainBlock(driver.driverId, nextState, reason || blockReasonInput);
      }
      showToast(nextState ? 'تم حظر الكابتن ونقله إلى تبويب المحظورين ' : 'تم فك الحظر عن الكابتن وإعادته للنشطين ');
      setShowBlockInput(false);
      setBlockReasonInput('');
    } catch (err: any) {
      showToast('ما قدرنا نحدث حالة الكابتن: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleApproveKyc = async (driverId: string) => {
    if (!window.confirm('هل تريد اعتماد وتوثيق وثائق هذا الكابتن رسمياً؟')) return;

    setActionLoadingId(driverId);
    try {
      if (selectedVehicleType === 'motorcycle') {
        await MersalCourierRepository.updateCourierKyc(driverId, 'verified');
      } else {
        await TaxiCaptainRepository.updateCaptainKyc(driverId, 'verified');
      }
      showToast('تم توثيق واعتماد الكابتن بنجاح ');
    } catch (err: any) {
      showToast('فشل توثيق الكابتن: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleRejectKyc = async (driverId: string) => {
    if (!rejectionReason.trim()) {
      showToast('يرجى كتابة سبب رفض الوثائق', 'error');
      return;
    }

    setActionLoadingId(driverId);
    try {
      if (selectedVehicleType === 'motorcycle') {
        await MersalCourierRepository.updateCourierKyc(driverId, 'rejected', rejectionReason);
      } else {
        await TaxiCaptainRepository.updateCaptainKyc(driverId, 'rejected', rejectionReason);
      }
      showToast('تم رفض وثائق الكابتن وإرسال الملاحظة له');
      setShowRejectInput(false);
      setRejectionReason('');
    } catch (err: any) {
      showToast('فشل رفض التوثيق: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDeleteDriver = async (driver: DriverEntity) => {
    if (!window.confirm(` تحذير نهائي: متأكد تريد تحذف حساب الكابتن (${driver.name}) نهائياً من قاعدة البيانات؟`)) return;

    setActionLoadingId(driver.driverId);
    try {
      if (driver.vehicleCategory === 'motorcycle') {
        await MersalCourierRepository.deleteCourier(driver.driverId);
      } else {
        await TaxiCaptainRepository.deleteCaptain(driver.driverId);
      }
      showToast('تم حذف الكابتن بنجاح من النظام');
      setSelectedDriver(null);
    } catch (err: any) {
      showToast('تعذر حذف الكابتن: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleToggleOnlineStatus = async (driver: DriverEntity) => {
    const newStatus = !driver.isOnline;
    setActionLoadingId(driver.driverId);
    try {
      if (driver.vehicleCategory === 'motorcycle') {
        await MersalCourierRepository.toggleCourierOnlineStatus(driver.driverId, newStatus);
      } else {
        await TaxiCaptainRepository.toggleCaptainOnlineStatus(driver.driverId, newStatus);
      }
      showToast(`تم تغيير حالة اتصال الكابتن (${driver.name}) إلى (${newStatus ? 'متصل ومتاح للطلبات ' : 'غير متصل '}) بنجاح.`);
    } catch (err: any) {
      showToast('فشل تغيير حالة الاتصال: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Counts for tabs & vehicles
  const activeUnblockedCount = drivers.filter(d => !d.isBlocked).length;
  const pendingKycCount = drivers.filter(d => d.kycStatus === 'pending' && !d.isBlocked).length;
  const verifiedCount = drivers.filter(d => d.kycStatus === 'verified' && !d.isBlocked).length;
  const blockedCount = drivers.filter(d => d.isBlocked).length;

  const motorcycleCount = drivers.filter(d => d.vehicleCategory === 'motorcycle' && !d.isBlocked).length;
  const taxiCarCount = drivers.filter(d => d.vehicleCategory !== 'motorcycle' && !d.isBlocked).length;

  // Filter logic: In "all", blocked drivers DISAPPEAR and only appear in "blocked" tab!
  const filteredDrivers = drivers.filter(d => {
    const matchesSearch = 
      d.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
      d.phoneNumber.includes(searchQuery) || 
      d.vehicleModel.toLowerCase().includes(searchQuery.toLowerCase()) ||
      d.plateNumber.includes(searchQuery) ||
      (d.city && d.city.toLowerCase().includes(searchQuery.toLowerCase()));

    if (!matchesSearch) return false;

    // Vehicle Type Filter (STRICT SEPARATION)
    if (selectedVehicleType === 'motorcycle' && d.vehicleCategory !== 'motorcycle') return false;
    if (selectedVehicleType === 'taxi' && d.vehicleCategory === 'motorcycle') return false;

    if (selectedStatus === 'verified') return d.kycStatus === 'verified' && !d.isBlocked;
    if (selectedStatus === 'pending') return d.kycStatus === 'pending' && !d.isBlocked;
    if (selectedStatus === 'blocked') return d.isBlocked;
    
    // Default 'all': Only show unblocked drivers!
    return !d.isBlocked;
  });

  const isTaxiView = selectedVehicleType === 'taxi';
  const isMotorcycleView = selectedVehicleType === 'motorcycle';

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
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Car size={22} color={isTaxiView ? '#F59E0B' : (isMotorcycleView ? '#00BFA5' : '#0284C7')} />
            {pageTitle || (
              isTaxiView 
                ? 'إدارة كباتن التكسي وسيارات نقل الركاب (تكسي مدار )' 
                : (isMotorcycleView 
                    ? 'إدارة مندوبي ودراجات التوصيل السريع (المطاعم والمتاجر ومرسال )' 
                    : 'إدارة الكباتن والأسطول الميداني')
            )}
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            {isTaxiView
              ? 'إدارة كباتن سيارات التكسي لنقل الركاب، المستمسكات، تسعيرة المشاوير، وتصفير الديون والعمولات'
              : (isMotorcycleView
                  ? 'إدارة دراجات وسيارات التوصيل السريع لتوصيل وجبات المطاعم، سلع المتاجر، وطرود مرسال'
                  : 'استعراض وتعديل ملفات وصور الكباتن، فحص المستمسكات (KYC)، وتصنيف الفئات')}
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {isTaxiView ? (
            <span className="badge badge-warning" style={{ fontSize: '12px' }}> {taxiCarCount} سيارة تكسي نشطة</span>
          ) : isMotorcycleView ? (
            <span className="badge badge-primary" style={{ fontSize: '12px' }}> {motorcycleCount} دراجة توصيل نشطة</span>
          ) : (
            <>
              <span className="badge badge-primary" style={{ fontSize: '12px' }}> {motorcycleCount} دراجة توصيل</span>
              <span className="badge badge-warning" style={{ fontSize: '12px' }}> {taxiCarCount} سيارة تكسي</span>
            </>
          )}
          {blockedCount > 0 && <span className="badge badge-danger" style={{ fontSize: '12px' }}>{blockedCount} محظور</span>}
        </div>
      </div>

      {/* Filter Tabs & Search Bar */}
      <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
        
        {/* Row 1: Vehicle Category Segmentation Switcher */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
          <div style={{ display: 'flex', gap: '8px', background: 'rgba(255, 255, 255, 0.04)', padding: '4px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
            <button 
              onClick={() => setSelectedVehicleType('taxi')}
              className={`btn ${selectedVehicleType === 'taxi' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', padding: '6px 14px', borderRadius: '8px', color: selectedVehicleType === 'taxi' ? '#070B12' : '#FBBF24' }}
            >
               كباتن التكسي ({taxiCarCount})
            </button>
            <button 
              onClick={() => setSelectedVehicleType('motorcycle')}
              className={`btn ${selectedVehicleType === 'motorcycle' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', padding: '6px 14px', borderRadius: '8px', color: selectedVehicleType === 'motorcycle' ? '#070B12' : '#00BFA5' }}
            >
               مندوبي ودراجات التوصيل ({motorcycleCount})
            </button>
            <button 
              onClick={() => setSelectedVehicleType('all')}
              className={`btn ${selectedVehicleType === 'all' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', padding: '6px 14px', borderRadius: '8px' }}
            >
               كامل الأسطول ({activeUnblockedCount})
            </button>
          </div>

          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '280px', flex: 1, maxWidth: '400px' }}>
            <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
            <input
              type="text"
              placeholder="ابحث بالاسم، رقم الهاتف، نوع السيارة/الدراجة، أو اللوحة..."
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
        </div>

        {/* Row 2: Status Filter Tabs (Separating Verified vs Waiting List vs Blocked) */}
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', borderTop: '1px solid var(--border-color)', paddingTop: '10px' }}>
          <button 
            onClick={() => setSelectedStatus('verified')}
            className={`btn ${selectedStatus === 'verified' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '800' }}
          >
            <ShieldCheck size={14} color="#34d399" />
            <span> الكباتن الموثوقين والمعتمدين ({verifiedCount})</span>
          </button>

          <button 
            onClick={() => setSelectedStatus('pending')}
            className={`btn ${selectedStatus === 'pending' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ 
              fontSize: '12px', 
              padding: '6px 14px', 
              display: 'flex', 
              alignItems: 'center', 
              gap: '6px', 
              fontWeight: '800',
              borderColor: pendingKycCount > 0 ? '#f59e0b' : undefined,
              color: selectedStatus === 'pending' ? '#fff' : (pendingKycCount > 0 ? '#fbbf24' : undefined)
            }}
          >
            <AlertCircle size={14} color="#f59e0b" />
            <span> قائمة الانتظار وقيد التدقيق ({pendingKycCount})</span>
          </button>

          <button 
            onClick={() => setSelectedStatus('blocked')}
            className={`btn ${selectedStatus === 'blocked' ? 'btn-danger' : 'btn-secondary'}`}
            style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Ban size={14} />
            <span> المحظورين والموقوفين ({blockedCount})</span>
          </button>

          <button 
            onClick={() => setSelectedStatus('all')}
            className={`btn ${selectedStatus === 'all' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12px', padding: '6px 14px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <span> عرض كامل الأسطول ({activeUnblockedCount})</span>
          </button>
        </div>
      </div>

      {/* Floating Bulk Action Bar (When 1+ drivers are checked) */}
      {selectedDriverIds.length > 0 && (
        <div style={{
          background: 'linear-gradient(135deg, rgba(239, 68, 68, 0.9) 0%, rgba(15, 23, 42, 0.95) 100%)',
          padding: '12px 20px',
          borderRadius: '12px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          border: '1px solid rgba(239, 68, 68, 0.5)',
          boxShadow: '0 8px 30px rgba(239, 68, 68, 0.3)',
          animation: 'slideDown 0.3s ease'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <span style={{ fontSize: '14px', fontWeight: '900', color: '#fff' }}>
              تم تحديد ({selectedDriverIds.length}) كابتن
            </span>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button
              onClick={handleBulkDelete}
              disabled={isBulkDeleting}
              className="btn btn-danger"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '800', padding: '8px 18px', background: '#dc2626' }}
            >
              <Trash2 size={15} />
              <span>{isBulkDeleting ? 'جاري الحذف...' : `حذف الكباتن المحددين نهائياً (${selectedDriverIds.length})`}</span>
            </button>
            <button
              onClick={() => setSelectedDriverIds([])}
              className="btn btn-secondary"
              style={{ fontSize: '12px' }}
            >
              إلغاء التحديد
            </button>
          </div>
        </div>
      )}

      {/* Drivers Data Table */}
      <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
            <div>جاري جلب أسطول الكباتن من Firestore...</div>
          </div>
        ) : filteredDrivers.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Car size={32} color="#64748b" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>
              {selectedStatus === 'blocked' ? 'لا يوجد أي كباتن محظورين حالياً' : 'ماكو كباتن مطابقين للبحث'}
            </div>
            <div style={{ fontSize: '11px', marginTop: '2px' }}>يتم ترتيب الكباتن تلقائياً من الأحدث تسجيلاً إلى الأقدم</div>
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th style={{ width: '40px', textAlign: 'center' }}>
                    <input
                      type="checkbox"
                      checked={selectedDriverIds.length === filteredDrivers.length && filteredDrivers.length > 0}
                      onChange={() => handleToggleSelectAll(filteredDrivers)}
                      style={{ cursor: 'pointer', width: '16px', height: '16px', accentColor: '#06b6d4' }}
                    />
                  </th>
                  <th>اسم وصورة الكابتن</th>
                  <th>بيانات المركبة واللوحة</th>
                  <th>تاريخ التسجيل</th>
                  <th>حالة التوثيق (KYC)</th>
                  <th>الرصيد والديون</th>
                  <th>التقييم والرحلات</th>
                  <th>الحالة</th>
                  <th>الإجراءات والملف</th>
                </tr>
              </thead>
              <tbody>
                {filteredDrivers.map((driver) => {
                  const isChecked = selectedDriverIds.includes(driver.driverId);

                  return (
                    <tr key={driver.driverId} style={{ background: isChecked ? 'rgba(6, 182, 212, 0.08)' : undefined }}>
                      <td style={{ textAlign: 'center' }}>
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => handleToggleSelectOne(driver.driverId)}
                          style={{ cursor: 'pointer', width: '16px', height: '16px', accentColor: '#06b6d4' }}
                        />
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          {driver.personalPhotoUrl ? (
                            <img
                              src={driver.personalPhotoUrl}
                              alt={driver.name}
                              style={{ width: '36px', height: '36px', borderRadius: '50%', objectFit: 'cover', border: '1px solid rgba(6, 182, 212, 0.5)' }}
                              onError={(e) => { (e.target as any).style.display = 'none'; }}
                            />
                          ) : (
                            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: '14px', fontWeight: '800' }}>
                              {driver.name.substring(0, 1)}
                            </div>
                          )}
                          <div>
                            <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{driver.name}</div>
                            <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{driver.phoneNumber}</div>
                            <div style={{ fontSize: '10px', color: '#06b6d4' }}> {driver.city || 'القائم'}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                          <span style={{ fontSize: '14px' }}>
                            {driver.vehicleCategory === 'motorcycle' ? '' : ''}
                          </span>
                          <span style={{ color: '#fff', fontSize: '13px', fontWeight: '800' }}>
                            {driver.vehicleModel} {driver.vehicleYear ? `(${driver.vehicleYear})` : ''}
                          </span>
                          <span style={{
                            fontSize: '10px',
                            padding: '2px 6px',
                            borderRadius: '4px',
                            background: driver.vehicleCategory === 'motorcycle' ? 'rgba(56, 189, 248, 0.15)' : 'rgba(251, 191, 36, 0.15)',
                            color: driver.vehicleCategory === 'motorcycle' ? '#38bdf8' : '#fbbf24',
                            fontWeight: '700'
                          }}>
                            {driver.vehicleCategory === 'motorcycle' ? 'دراجة توصيل' : 'سيارة تكسي'}
                          </span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '4px' }}>
                          <span style={{ 
                            background: 'rgba(245, 158, 11, 0.15)', 
                            color: '#fbbf24', 
                            border: '1px solid rgba(245, 158, 11, 0.4)', 
                            padding: '1px 6px', 
                            borderRadius: '4px', 
                            fontSize: '11px', 
                            fontWeight: '800',
                            letterSpacing: '0.5px'
                          }}>
                            لوحة: {driver.plateNumber}
                          </span>
                          <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                            اللون: {driver.vehicleColor}
                          </span>
                        </div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#cbd5e1' }}>{driver.createdAt}</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>تاريخ الانضمام</div>
                      </td>
                      <td>
                        <span className={`badge ${driver.kycStatus === 'verified' ? 'badge-success' : (driver.kycStatus === 'rejected' ? 'badge-danger' : 'badge-warning')}`}>
                          {driver.kycStatus === 'verified' ? 'موثق رسمياً ' : (driver.kycStatus === 'rejected' ? 'مرفوض ' : 'بانتظار التدقيق ')}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '700', color: '#34d399', fontSize: '12.5px' }}>
                          {formatIqd(driver.walletBalance)}
                        </div>
                        {driver.appDebt && driver.appDebt > 0 ? (
                          <div style={{ fontSize: '10.5px', color: '#f87171' }}>دين: {formatIqd(driver.appDebt)}</div>
                        ) : null}
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <Star size={13} color="#f59e0b" fill="#f59e0b" />
                          <span style={{ fontWeight: '700', color: '#fff', fontSize: '12px' }}>{driver.rating.toFixed(1)}</span>
                          <span style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>({driver.totalTrips} مشوار)</span>
                        </div>
                      </td>
                      <td>
                        <button
                          onClick={() => handleToggleOnlineStatus(driver)}
                          disabled={actionLoadingId === driver.driverId || driver.isBlocked}
                          className={`badge ${driver.isBlocked ? 'badge-danger' : (driver.isOnline ? 'badge-success' : 'badge-secondary')}`}
                          style={{
                            cursor: driver.isBlocked ? 'not-allowed' : 'pointer',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '6px',
                            padding: '4px 10px',
                            borderRadius: '20px',
                            border: driver.isOnline ? '1px solid rgba(16, 185, 129, 0.4)' : '1px solid rgba(255, 255, 255, 0.1)',
                            background: driver.isBlocked ? 'rgba(239, 68, 68, 0.15)' : (driver.isOnline ? 'rgba(16, 185, 129, 0.2)' : 'rgba(100, 116, 139, 0.2)'),
                            color: driver.isBlocked ? '#f87171' : (driver.isOnline ? '#34d399' : '#94a3b8'),
                            fontWeight: '800'
                          }}
                          title="انقر لتغيير حالة الاتصال (متصل / غير متصل)"
                        >
                          <span style={{
                            width: '8px',
                            height: '8px',
                            borderRadius: '50%',
                            background: driver.isBlocked ? '#ef4444' : (driver.isOnline ? '#10b981' : '#64748b'),
                            boxShadow: driver.isOnline ? '0 0 8px #10b981' : 'none'
                          }}></span>
                          <span>{driver.isBlocked ? 'محظور ' : (driver.isOnline ? 'متصل ' : 'غير متصل ')}</span>
                        </button>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button
                            onClick={() => handleToggleOnlineStatus(driver)}
                            disabled={actionLoadingId === driver.driverId || driver.isBlocked}
                            className="btn btn-secondary"
                            style={{
                              fontSize: '11px',
                              padding: '5px 8px',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                              color: driver.isOnline ? '#34d399' : '#94a3b8',
                              border: driver.isOnline ? '1px solid rgba(16, 185, 129, 0.3)' : undefined
                            }}
                            title={driver.isOnline ? 'فصل اتصال الكابتن (تحويل لغير متصل)' : 'جعل الكابتن متصلاً ومتاحاً للطلبات الآن'}
                          >
                            <Radio size={13} color={driver.isOnline ? '#34d399' : '#94a3b8'} />
                            <span>{driver.isOnline ? 'فصل' : 'توصيل'}</span>
                          </button>

                          {driver.kycStatus === 'pending' && (
                            <button
                              onClick={() => handleApproveKyc(driver.driverId)}
                              disabled={actionLoadingId === driver.driverId}
                              className="btn btn-primary"
                              style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '4px', background: 'linear-gradient(135deg, #10b981, #059669)', borderColor: '#34d399' }}
                              title="قبول وتوثيق الكابتن فوراً"
                            >
                              <Check size={13} />
                              <span>توثيق</span>
                            </button>
                          )}
                          <button
                            onClick={() => setSelectedDriver(driver)}
                            className="btn btn-secondary"
                            style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
                            title="عرض التفاصيل الكاملة"
                          >
                            <Eye size={13} color="#06b6d4" />
                            <span>التفاصيل</span>
                          </button>
                          <button
                            onClick={() => handleOpenEditModal(driver)}
                            className="btn btn-secondary"
                            style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '4px', color: '#fbbf24' }}
                            title="تعديل معلومات وصور الكابتن"
                          >
                            <Edit3 size={13} />
                            <span>تعديل</span>
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

      {/* ─── FULL DRIVER DETAILS MODAL ─── */}
      {selectedDriver && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '780px', width: '100%', maxHeight: '90vh', overflowY: 'auto', borderRadius: '24px', border: '1px solid rgba(6, 182, 212, 0.35)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
            
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-color)', paddingBottom: '16px', marginBottom: '20px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                {selectedDriver.personalPhotoUrl ? (
                  <img
                    src={selectedDriver.personalPhotoUrl}
                    alt={selectedDriver.name}
                    style={{ width: '56px', height: '56px', borderRadius: '50%', objectFit: 'cover', border: '2px solid #06b6d4' }}
                  />
                ) : (
                  <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: '20px', fontWeight: '800' }}>
                    {selectedDriver.name.substring(0, 1)}
                  </div>
                )}
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <h3 style={{ fontSize: '20px', fontWeight: '900', color: '#fff', margin: 0 }}>{selectedDriver.name}</h3>
                    <span className={`badge ${selectedDriver.isBlocked ? 'badge-danger' : (selectedDriver.isOnline ? 'badge-success' : 'badge-info')}`}>
                      {selectedDriver.isBlocked ? 'محظور إدارياً' : (selectedDriver.isOnline ? 'متصل الآن' : 'غير متصل')}
                    </span>
                    <span className={`badge ${selectedDriver.kycStatus === 'verified' ? 'badge-success' : 'badge-warning'}`}>
                      {selectedDriver.kycStatus === 'verified' ? 'موثق KYC' : 'غير موثق'}
                    </span>
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                    معرف الكابتن: <code>{selectedDriver.driverId}</code> | تاريخ الانضمام: {selectedDriver.createdAt}
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <button
                  onClick={() => handleToggleOnlineStatus(selectedDriver)}
                  disabled={actionLoadingId === selectedDriver.driverId || selectedDriver.isBlocked}
                  className="btn btn-secondary"
                  style={{
                    fontSize: '12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '6px 12px',
                    color: selectedDriver.isOnline ? '#34d399' : '#fbbf24',
                    border: selectedDriver.isOnline ? '1px solid rgba(16, 185, 129, 0.5)' : '1px solid rgba(245, 158, 11, 0.5)',
                    background: selectedDriver.isOnline ? 'rgba(16, 185, 129, 0.1)' : 'rgba(245, 158, 11, 0.1)',
                    fontWeight: '800'
                  }}
                  title="التحكم باتصال الكابتن في النظام"
                >
                  <Radio size={14} color={selectedDriver.isOnline ? '#34d399' : '#fbbf24'} />
                  <span>{selectedDriver.isOnline ? 'فصل الاتصال (تحويل لغير متصل)' : 'جعل الكابتن متصلاً الآن '}</span>
                </button>

                <button
                  onClick={() => {
                    const d = selectedDriver;
                    setSelectedDriver(null);
                    handleOpenEditModal(d);
                  }}
                  className="btn btn-secondary"
                  style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px', color: '#fbbf24', border: '1px solid #fbbf24' }}
                >
                  <Edit3 size={13} />
                  <span>تعديل</span>
                </button>
                <button 
                  onClick={() => { setSelectedDriver(null); setShowRejectInput(false); setShowBlockInput(false); }}
                  style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '20px' }}
                >
                  
                </button>
              </div>
            </div>

            {/* Grid: 3 Main Cards (Personal, Vehicle, Financial) */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '20px' }}>
              
              {/* Personal Info */}
              <div style={{ background: 'var(--bg-surface)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#38bdf8', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <User size={14} /> المعلومات الشخصية
                </div>
                <div style={{ fontSize: '12.5px', color: '#cbd5e1', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <div><strong>الهاتف:</strong> <span dir="ltr">{selectedDriver.phoneNumber}</span></div>
                  <div><strong>البريد:</strong> {selectedDriver.email || 'غير مسجل'}</div>
                  <div><strong>الموقع:</strong> {selectedDriver.city || 'القائم'} - {selectedDriver.governorate || 'الأنبار'}</div>
                  <div><strong>مؤشر الأمان:</strong> {selectedDriver.riskScore} / 100</div>
                </div>
              </div>

              {/* Vehicle Info */}
              <div style={{ background: 'var(--bg-surface)', padding: '16px', borderRadius: '12px', border: '1px solid rgba(251, 191, 36, 0.3)' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#fbbf24', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Car size={14} /> بيانات السيارة واللوحة والمركبة
                </div>
                <div style={{ fontSize: '12.5px', color: '#cbd5e1', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <div><strong>نوع وماركة المركبة:</strong> <span style={{ color: '#fff', fontWeight: '800' }}>{selectedDriver.vehicleModel}</span></div>
                  <div>
                    <strong>رقم اللوحة:</strong>{' '}
                    <span style={{ 
                      background: 'rgba(245, 158, 11, 0.2)', 
                      color: '#fbbf24', 
                      border: '1px solid rgba(245, 158, 11, 0.5)', 
                      padding: '2px 8px', 
                      borderRadius: '6px', 
                      fontWeight: '900',
                      fontSize: '12px'
                    }}>
                      {selectedDriver.plateNumber}
                    </span>
                  </div>
                  <div><strong>لون السيارة:</strong> {selectedDriver.vehicleColor || 'أصفر / أبيض'}</div>
                  <div><strong>سنة الصنع:</strong> {selectedDriver.vehicleYear || 'غير محدد'}</div>
                </div>
              </div>

              {/* Financial & Performance */}
              <div style={{ background: 'var(--bg-surface)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#34d399', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <DollarSign size={14} /> المالية والأداء الميداني
                </div>
                <div style={{ fontSize: '12.5px', color: '#cbd5e1', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <div><strong>رصيد المحفظة:</strong> <span style={{ color: '#34d399', fontWeight: '700' }}>{formatIqd(selectedDriver.walletBalance)}</span></div>
                  <div><strong>ديون التطبيق:</strong> <span style={{ color: '#f87171', fontWeight: '700' }}>{formatIqd(selectedDriver.appDebt || 0)}</span></div>
                  <div><strong>إجمالي الرحلات:</strong> {selectedDriver.totalTrips} رحلة</div>
                  <div><strong>التقييم العام:</strong> {selectedDriver.rating.toFixed(1)} / 5.0</div>
                </div>
              </div>

            </div>

            {/* Documents & KYC Section */}
            <div style={{ background: 'var(--bg-surface)', padding: '18px', borderRadius: '12px', border: '1px solid var(--border-color)', marginBottom: '20px' }}>
              <div style={{ fontSize: '13px', fontWeight: '800', color: '#fff', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <FileText size={15} color="#06b6d4" /> وثائق ومستمسكات الكابتن المرفوعة (KYC Documents)
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '14px' }}>
                
                {/* National ID */}
                <div style={{ background: '#0f172a', padding: '12px', borderRadius: '8px', textAlign: 'center', border: '1px solid rgba(255,255,255,0.08)' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>البطاقة الوطنية / الهوية</div>
                  {selectedDriver.nationalIdUrl ? (
                    <a href={selectedDriver.nationalIdUrl} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', color: '#38bdf8', fontSize: '11.5px', textDecoration: 'none', fontWeight: '700' }}>
                      <ExternalLink size={12} /> معاينة المستمسك
                    </a>
                  ) : (
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لم ترفع بعد</span>
                  )}
                </div>

                {/* Driving License */}
                <div style={{ background: '#0f172a', padding: '12px', borderRadius: '8px', textAlign: 'center', border: '1px solid rgba(255,255,255,0.08)' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>إجازة السوق (السياقة)</div>
                  {selectedDriver.licenseUrl ? (
                    <a href={selectedDriver.licenseUrl} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', color: '#38bdf8', fontSize: '11.5px', textDecoration: 'none', fontWeight: '700' }}>
                      <ExternalLink size={12} /> معاينة الإجازة
                    </a>
                  ) : (
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لم ترفع بعد</span>
                  )}
                </div>

                {/* Vehicle Registration */}
                <div style={{ background: '#0f172a', padding: '12px', borderRadius: '8px', textAlign: 'center', border: '1px solid rgba(255,255,255,0.08)' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>سنوية السيارة (الملكية)</div>
                  {selectedDriver.carDocUrl ? (
                    <a href={selectedDriver.carDocUrl} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', color: '#38bdf8', fontSize: '11.5px', textDecoration: 'none', fontWeight: '700' }}>
                      <ExternalLink size={12} /> معاينة السنوية
                    </a>
                  ) : (
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لم ترفع بعد</span>
                  )}
                </div>

                {/* Personal Photo */}
                <div style={{ background: '#0f172a', padding: '12px', borderRadius: '8px', textAlign: 'center', border: '1px solid rgba(255,255,255,0.08)' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>الصورة الشخصية</div>
                  {selectedDriver.personalPhotoUrl ? (
                    <a href={selectedDriver.personalPhotoUrl} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', color: '#38bdf8', fontSize: '11.5px', textDecoration: 'none', fontWeight: '700' }}>
                      <ExternalLink size={12} /> معاينة الصورة
                    </a>
                  ) : (
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لم ترفع بعد</span>
                  )}
                </div>

              </div>
            </div>

            {/* Block / Rejection Inputs if active */}
            {showRejectInput && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(239, 68, 68, 0.3)', marginBottom: '16px' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#f87171', marginBottom: '6px' }}>
                  سبب رفض التوثيق (يصل إشعار للكابتن):
                </label>
                <input
                  type="text"
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="مثال: صورة إجازة السوق غير واضحة، يرجى إعادة التصوير"
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none', marginBottom: '10px' }}
                />
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button onClick={() => handleRejectKyc(selectedDriver.driverId)} className="btn btn-danger" style={{ fontSize: '12px', padding: '6px 14px' }}>
                    تأكيد رفض التوثيق
                  </button>
                  <button onClick={() => setShowRejectInput(false)} className="btn btn-secondary" style={{ fontSize: '12px', padding: '6px 14px' }}>
                    إلغاء
                  </button>
                </div>
              </div>
            )}

            {showBlockInput && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(239, 68, 68, 0.3)', marginBottom: '16px' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#f87171', marginBottom: '6px' }}>
                  سبب الحظر الإداري:
                </label>
                <input
                  type="text"
                  value={blockReasonInput}
                  onChange={(e) => setBlockReasonInput(e.target.value)}
                  placeholder="مثال: شكاوى متكررة من الركاب بخصوص التأخير أو مخالفة التعليمات"
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none', marginBottom: '10px' }}
                />
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button onClick={() => handleToggleBlock(selectedDriver, blockReasonInput)} className="btn btn-danger" style={{ fontSize: '12px', padding: '6px 14px' }}>
                    تأكيد حظر الكابتن فوراً
                  </button>
                  <button onClick={() => setShowBlockInput(false)} className="btn btn-secondary" style={{ fontSize: '12px', padding: '6px 14px' }}>
                    إلغاء
                  </button>
                </div>
              </div>
            )}

            {/* Action Buttons Toolbar */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px', borderTop: '1px solid var(--border-color)', paddingTop: '18px' }}>
              <div style={{ display: 'flex', gap: '10px' }}>
                {selectedDriver.kycStatus !== 'verified' && (
                  <button
                    onClick={() => handleApproveKyc(selectedDriver.driverId)}
                    disabled={actionLoadingId === selectedDriver.driverId}
                    className="btn btn-primary"
                    style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px' }}
                  >
                    <CheckCircle size={15} />
                    <span>اعتماد وتوثيق الحساب (Approve KYC)</span>
                  </button>
                )}

                {selectedDriver.kycStatus !== 'rejected' && !showRejectInput && (
                  <button
                    onClick={() => setShowRejectInput(true)}
                    className="btn btn-secondary"
                    style={{ fontSize: '12.5px', color: '#f87171' }}
                  >
                    رفض التوثيق
                  </button>
                )}

                {!showBlockInput && (
                  <button
                    onClick={() => {
                      if (selectedDriver.isBlocked) {
                        handleToggleBlock(selectedDriver);
                      } else {
                        setShowBlockInput(true);
                      }
                    }}
                    disabled={actionLoadingId === selectedDriver.driverId}
                    style={{
                      padding: '8px 16px',
                      borderRadius: '8px',
                      fontSize: '12.5px',
                      fontWeight: '700',
                      cursor: 'pointer',
                      background: selectedDriver.isBlocked ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                      color: selectedDriver.isBlocked ? '#34d399' : '#f87171',
                      border: `1px solid ${selectedDriver.isBlocked ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`
                    }}
                  >
                    {selectedDriver.isBlocked ? 'فك الحظر عن الكابتن' : 'حظر الكابتن'}
                  </button>
                )}
              </div>

              <button
                onClick={() => handleDeleteDriver(selectedDriver)}
                disabled={actionLoadingId === selectedDriver.driverId}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: '#ef4444',
                  cursor: 'pointer',
                  fontSize: '12px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  padding: '6px 10px'
                }}
              >
                <Trash2 size={15} /> حذف الحساب نهائياً
              </button>
            </div>

          </div>
        </div>
      )}

      {/* ─── EDIT DRIVER & PHOTOS MODAL ─── */}
      {editingDriver && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '640px', width: '100%', maxHeight: '90vh', overflowY: 'auto', borderRadius: '24px', border: '1px solid rgba(251, 191, 36, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Edit3 size={18} color="#fbbf24" />
                <h3 style={{ fontSize: '17px', fontWeight: '800', color: '#fff', margin: 0 }}>
                  تعديل بيانات وصور الكابتن: {editingDriver.name}
                </h3>
              </div>
              <button onClick={() => setEditingDriver(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                
              </button>
            </div>

            <form onSubmit={handleSaveDriverDetails} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              {/* Photo Preview & URL */}
              <div style={{ background: '#0f172a', padding: '14px', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.08)', display: 'flex', gap: '14px', alignItems: 'center' }}>
                {editPhotoUrl ? (
                  <img
                    src={editPhotoUrl}
                    alt="معاينة الصورة"
                    style={{ width: '50px', height: '50px', borderRadius: '50%', objectFit: 'cover', border: '2px solid #06b6d4' }}
                    onError={(e) => { (e.target as any).style.display = 'none'; }}
                  />
                ) : (
                  <div style={{ width: '50px', height: '50px', borderRadius: '50%', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8' }}>
                    <Image size={22} />
                  </div>
                )}
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#38bdf8', marginBottom: '4px' }}>
                    رابط الصورة الشخصية (Photo URL):
                  </label>
                  <input
                    type="url"
                    value={editPhotoUrl}
                    onChange={e => setEditPhotoUrl(e.target.value)}
                    placeholder="https://firebasestorage.googleapis.com/.../photo.jpg"
                    style={{ width: '100%', padding: '8px 10px', background: '#070d18', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '12px', outline: 'none' }}
                  />
                </div>
              </div>

              {/* Name & Phone */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    اسم الكابتن الكامل:
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

              {/* Vehicle Model & Plate */}
              <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    ماركة وموديل السيارة:
                  </label>
                  <input
                    type="text"
                    required
                    value={editVehicleModel}
                    onChange={e => setEditVehicleModel(e.target.value)}
                    placeholder="مثال: كيا اوبتيما"
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#fbbf24', marginBottom: '6px' }}>
                    رقم اللوحة والمحافظة:
                  </label>
                  <input
                    type="text"
                    required
                    value={editPlateNumber}
                    onChange={e => setEditPlateNumber(e.target.value)}
                    placeholder="12345 بغداد"
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid #fbbf24', borderRadius: '8px', color: '#fbbf24', fontSize: '13px', fontWeight: '800', outline: 'none' }}
                  />
                </div>
              </div>

              {/* Color & Year & City */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    لون السيارة:
                  </label>
                  <input
                    type="text"
                    value={editVehicleColor}
                    onChange={e => setEditVehicleColor(e.target.value)}
                    placeholder="أصفر / أبيض"
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    سنة الصنع:
                  </label>
                  <input
                    type="text"
                    value={editVehicleYear}
                    onChange={e => setEditVehicleYear(e.target.value)}
                    placeholder="2022"
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    المدينة / القضاء:
                  </label>
                  <input
                    type="text"
                    value={editCity}
                    onChange={e => setEditCity(e.target.value)}
                    placeholder="القائم"
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  />
                </div>
              </div>

              {/* KYC Document URLs */}
              <div style={{ background: '#0f172a', padding: '12px', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.06)', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ fontSize: '11.5px', fontWeight: '800', color: '#cbd5e1' }}>روابط الوثائق والمستمسكات (KYC):</div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '8px' }}>
                  <div>
                    <span style={{ fontSize: '10.5px', color: 'var(--text-muted)' }}>البطاقة الوطنية:</span>
                    <input
                      type="url"
                      value={editNationalIdUrl}
                      onChange={e => setEditNationalIdUrl(e.target.value)}
                      placeholder="رابط الهوية..."
                      style={{ width: '100%', padding: '6px 8px', background: '#070d18', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '11px', outline: 'none' }}
                    />
                  </div>
                  <div>
                    <span style={{ fontSize: '10.5px', color: 'var(--text-muted)' }}>إجازة السوق:</span>
                    <input
                      type="url"
                      value={editLicenseUrl}
                      onChange={e => setEditLicenseUrl(e.target.value)}
                      placeholder="رابط الإجازة..."
                      style={{ width: '100%', padding: '6px 8px', background: '#070d18', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '11px', outline: 'none' }}
                    />
                  </div>
                  <div>
                    <span style={{ fontSize: '10.5px', color: 'var(--text-muted)' }}>سنوية السيارة:</span>
                    <input
                      type="url"
                      value={editCarDocUrl}
                      onChange={e => setEditCarDocUrl(e.target.value)}
                      placeholder="رابط السنوية..."
                      style={{ width: '100%', padding: '6px 8px', background: '#070d18', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '11px', outline: 'none' }}
                    />
                  </div>
                </div>
              </div>

              {/* Wallet Balance & Debt */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#34d399', marginBottom: '6px' }}>
                    رصيد المحفظة (د.ع):
                  </label>
                  <input
                    type="number"
                    step="500"
                    value={editWalletBalance}
                    onChange={e => setEditWalletBalance(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(52, 211, 153, 0.4)', borderRadius: '8px', color: '#34d399', fontSize: '13px', fontWeight: '700', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#f87171', marginBottom: '6px' }}>
                    ديون التطبيق المستحقة (د.ع):
                  </label>
                  <input
                    type="number"
                    step="500"
                    value={editAppDebt}
                    onChange={e => setEditAppDebt(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(248, 113, 113, 0.4)', borderRadius: '8px', color: '#f87171', fontSize: '13px', fontWeight: '700', outline: 'none' }}
                  />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', marginTop: '12px' }}>
                <button
                  type="submit"
                  disabled={actionLoadingId === editingDriver.driverId}
                  className="btn btn-primary"
                  style={{ flex: 1, padding: '12px', fontSize: '13px', fontWeight: '800' }}
                >
                  {actionLoadingId === editingDriver.driverId ? 'جاري الحفظ...' : 'حفظ وتحديث بيانات وصور الكابتن في Firestore'}
                </button>
                <button
                  type="button"
                  onClick={() => setEditingDriver(null)}
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

    </div>
  );
};
