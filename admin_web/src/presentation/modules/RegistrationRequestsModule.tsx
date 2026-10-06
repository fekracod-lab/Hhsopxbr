import React, { useState, useEffect, useMemo } from 'react';
import {
  UserCheck,
  Search,
  CheckCircle,
  XCircle,
  Clock,
  Phone,
  MessageCircle,
  Utensils,
  Store,
  Car,
  FileText,
  Eye,
  Trash2,
  Download,
  AlertTriangle,
  Loader2,
  Compass,
  Check,
  X,
  ExternalLink,
  ShieldCheck,
  Sparkles,
  ChevronDown,
  Info,
  Calendar,
  Layers,
  MapPin,
  Image as ImageIcon
} from 'lucide-react';
import { 
  RegistrationRequestsRepository, 
  RegistrationRequestEntity, 
  RegistrationDomain 
} from '../../infrastructure/repositories/RegistrationRequestsRepository';

export const RegistrationRequestsModule: React.FC = () => {
  const [requests, setRequests] = useState<RegistrationRequestEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Active Main Tab Domain
  const [activeDomain, setActiveDomain] = useState<RegistrationDomain | 'all'>('restaurant');
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'approved' | 'rejected'>('pending');
  const [searchQuery, setSearchQuery] = useState('');

  // Selected Request Modal (Dossier & Inspection)
  const [selectedRequest, setSelectedRequest] = useState<RegistrationRequestEntity | null>(null);

  // Rejection Modal
  const [rejectingRequest, setRejectingRequest] = useState<RegistrationRequestEntity | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');

  // Action Loading & Toast
  const [actionLoading, setActionLoading] = useState(false);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  useEffect(() => {
    setIsLoading(true);
    const unsubscribe = RegistrationRequestsRepository.subscribeToAllRequests((data) => {
      setRequests(data);
      setIsLoading(false);

      if (selectedRequest) {
        const updated = data.find(r => r.id === selectedRequest.id && r.domain === selectedRequest.domain);
        if (updated) setSelectedRequest(updated);
      }
    });

    return () => unsubscribe();
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 4000);
  };

  // Filtered requests based on domain, status, and search query
  const filteredRequests = useMemo(() => {
    return requests.filter(r => {
      // 1. Domain
      if (activeDomain !== 'all' && r.domain !== activeDomain) return false;

      // 2. Status
      if (statusFilter !== 'all' && r.status !== statusFilter) return false;

      // 3. Search
      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;

      return (
        r.applicantName.toLowerCase().includes(q) ||
        r.businessOrVehicleTitle.toLowerCase().includes(q) ||
        r.phoneNumber.includes(q) ||
        (r.categoryOrType && r.categoryOrType.toLowerCase().includes(q)) ||
        (r.vehiclePlate && r.vehiclePlate.includes(q)) ||
        (r.address && r.address.toLowerCase().includes(q))
      );
    });
  }, [requests, activeDomain, statusFilter, searchQuery]);

  // Statistics
  const stats = useMemo(() => {
    const restReqs = requests.filter(r => r.domain === 'restaurant');
    const taxiReqs = requests.filter(r => r.domain === 'taxi_captain');
    const mersalReqs = requests.filter(r => r.domain === 'mersal_courier');
    const storeReqs = requests.filter(r => r.domain === 'store');

    const pendingCount = requests.filter(r => r.status === 'pending').length;
    const approvedCount = requests.filter(r => r.status === 'approved').length;
    const rejectedCount = requests.filter(r => r.status === 'rejected').length;

    return {
      restaurantPending: restReqs.filter(r => r.status === 'pending').length,
      restaurantTotal: restReqs.length,
      taxiPending: taxiReqs.filter(r => r.status === 'pending').length,
      taxiTotal: taxiReqs.length,
      mersalPending: mersalReqs.filter(r => r.status === 'pending').length,
      mersalTotal: mersalReqs.length,
      storePending: storeReqs.filter(r => r.status === 'pending').length,
      storeTotal: storeReqs.length,
      pendingCount,
      approvedCount,
      rejectedCount
    };
  }, [requests]);

  // Handle Approve
  const handleApprove = async (req: RegistrationRequestEntity) => {
    if (!window.confirm(`هل أنت متأكد من قبول وتفعيل طلب (${req.businessOrVehicleTitle || req.applicantName}) رسمياً في المنظومة؟`)) return;

    setActionLoading(true);
    try {
      await RegistrationRequestsRepository.approveRequest(req);
      showToast(`تم قبول وتفعيل طلب (${req.applicantName}) بنجاح `);
      if (selectedRequest?.id === req.id) setSelectedRequest(null);
    } catch (err: any) {
      showToast(`فشل قبول الطلب: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // Handle Reject
  const handleConfirmReject = async () => {
    if (!rejectingRequest) return;
    if (!rejectionReason.trim()) {
      showToast('يرجى إدخال سبب الرفض لتوضيحه لمقدم الطلب', 'error');
      return;
    }

    setActionLoading(true);
    try {
      await RegistrationRequestsRepository.rejectRequest(rejectingRequest, rejectionReason.trim());
      showToast(`تم رفض الطلب وتوثيق السبب بنجاح `);
      setRejectingRequest(null);
      setRejectionReason('');
      if (selectedRequest?.id === rejectingRequest.id) setSelectedRequest(null);
    } catch (err: any) {
      showToast(`فشل رفض الطلب: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // Handle Delete
  const handleDelete = async (req: RegistrationRequestEntity) => {
    if (!window.confirm(` تحذير: متأكد تريد تحذف هذا الطلب نهائياً من قاعدة البيانات؟`)) return;

    setActionLoading(true);
    try {
      await RegistrationRequestsRepository.deleteRequest(req);
      showToast(`تم حذف الطلب نهائياً `);
      if (selectedRequest?.id === req.id) setSelectedRequest(null);
    } catch (err: any) {
      showToast(`فشل حذف الطلب: ${err.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // Export CSV
  const handleExportCSV = () => {
    if (filteredRequests.length === 0) {
      showToast('ماكو بيانات حالياً لتصديرها', 'error');
      return;
    }

    const headers = ['المعرف', 'القسم', 'مقدم الطلب', 'اسم النشاط / المركبة', 'رقم الهاتف', 'الواتساب', 'المدينة', 'العنوان', 'الحالة', 'تاريخ التقديم'];
    const rows = filteredRequests.map(r => [
      `"${r.id}"`,
      `"${r.domain === 'restaurant' ? 'مطعم' : (r.domain === 'store' ? 'متجر' : 'كابتن/مندوب')}"`,
      `"${r.applicantName.replace(/"/g, '""')}"`,
      `"${(r.businessOrVehicleTitle || '').replace(/"/g, '""')}"`,
      `"${r.phoneNumber}"`,
      `"${r.whatsappNumber || ''}"`,
      `"${r.city || 'القائم'}"`,
      `"${(r.address || '').replace(/"/g, '""')}"`,
      `"${r.status === 'approved' ? 'مقبول' : (r.status === 'rejected' ? 'مرفوض' : 'قيد المراجعة')}"`,
      `"${r.createdAt}"`
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `madar_registration_requests_${activeDomain}_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير ملف الطلبات بنجاح ');
  };

  const renderStatusBadge = (status: RegistrationRequestEntity['status']) => {
    if (status === 'approved') {
      return <span className="badge badge-success" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><CheckCircle size={12} /> معتمد ومفعّل </span>;
    }
    if (status === 'rejected') {
      return <span className="badge badge-danger" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><XCircle size={12} /> مرفوض </span>;
    }
    return <span className="badge badge-warning" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><Clock size={12} /> قيد المراجعة والتدقيق </span>;
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

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ padding: '8px', borderRadius: '10px', background: 'linear-gradient(135deg, #06b6d4, #3b82f6)' }}>
              <UserCheck size={22} color="#fff" />
            </div>
            مركز إدارة طلبات التسجيل والانضمام (المطاعم، الكباتن، والمتاجر)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            مراجعة وفحص طلبات الانضمام الواردة من التطبيق، فحص المستمسكات والوثائق، والقبول أو الرفض الفوري
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
            {stats.pendingCount} طلب بانتظار قرارك
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* PRIMARY 4 DOMAIN SEGMENTATION TABS */}
      {/* ========================================================================= */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '14px',
        background: 'rgba(15, 23, 42, 0.6)',
        padding: '8px',
        borderRadius: '14px',
        border: '1px solid rgba(255, 255, 255, 0.08)'
      }}>
        
        {/* Tab 1: Restaurant Requests */}
        <button
          onClick={() => setActiveDomain('restaurant')}
          style={{
            background: activeDomain === 'restaurant'
              ? 'linear-gradient(135deg, rgba(239, 68, 68, 0.25), rgba(249, 115, 22, 0.25))'
              : 'rgba(255, 255, 255, 0.03)',
            border: activeDomain === 'restaurant' ? '1px solid #f87171' : '1px solid transparent',
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
              <div style={{ fontWeight: '800', fontSize: '13.5px' }}> طلبات المطاعم</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.restaurantTotal} طلب مسجل</div>
            </div>
          </div>
          {stats.restaurantPending > 0 ? (
            <span className="badge badge-warning" style={{ fontSize: '11px' }}>
              {stats.restaurantPending} جديد 
            </span>
          ) : (
            <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لا توجد معلقة</span>
          )}
        </button>

        {/* Tab 2: Store Requests */}
        <button
          onClick={() => setActiveDomain('store')}
          style={{
            background: activeDomain === 'store'
              ? 'linear-gradient(135deg, rgba(16, 185, 129, 0.25), rgba(5, 150, 105, 0.25))'
              : 'rgba(255, 255, 255, 0.03)',
            border: activeDomain === 'store' ? '1px solid #34d399' : '1px solid transparent',
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
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(16, 185, 129, 0.2)', color: '#34d399' }}>
              <Store size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '13.5px' }}> طلبات المتاجر</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.storeTotal} طلب مسجل</div>
            </div>
          </div>
          {stats.storePending > 0 ? (
            <span className="badge badge-warning" style={{ fontSize: '11px' }}>
              {stats.storePending} جديد 
            </span>
          ) : (
            <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لا توجد معلقة</span>
          )}
        </button>

        {/* Tab 3: Taxi Captain Requests */}
        <button
          onClick={() => setActiveDomain('taxi_captain')}
          style={{
            background: activeDomain === 'taxi_captain'
              ? 'linear-gradient(135deg, rgba(234, 179, 8, 0.25), rgba(245, 158, 11, 0.25))'
              : 'rgba(255, 255, 255, 0.03)',
            border: activeDomain === 'taxi_captain' ? '1px solid #facc15' : '1px solid transparent',
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
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(234, 179, 8, 0.2)', color: '#facc15' }}>
              <Car size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '13.5px' }}> كباتن التكسي</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.taxiTotal} طلب مسجل</div>
            </div>
          </div>
          {stats.taxiPending > 0 ? (
            <span className="badge badge-warning" style={{ fontSize: '11px' }}>
              {stats.taxiPending} جديد 
            </span>
          ) : (
            <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لا توجد معلقة</span>
          )}
        </button>

        {/* Tab 4: Mersal Courier Requests */}
        <button
          onClick={() => setActiveDomain('mersal_courier')}
          style={{
            background: activeDomain === 'mersal_courier'
              ? 'linear-gradient(135deg, rgba(6, 182, 212, 0.25), rgba(59, 130, 246, 0.25))'
              : 'rgba(255, 255, 255, 0.03)',
            border: activeDomain === 'mersal_courier' ? '1px solid #06b6d4' : '1px solid transparent',
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
            <div style={{ padding: '8px', borderRadius: '8px', background: 'rgba(6, 182, 212, 0.2)', color: '#06b6d4' }}>
              <Compass size={20} />
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: '800', fontSize: '13.5px' }}> مناديب الدليفري ومرسال</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.mersalTotal} طلب مسجل</div>
            </div>
          </div>
          {stats.mersalPending > 0 ? (
            <span className="badge badge-warning" style={{ fontSize: '11px' }}>
              {stats.mersalPending} جديد 
            </span>
          ) : (
            <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>لا توجد معلقة</span>
          )}
        </button>

      </div>

      {/* Filter Tabs & Search Bar */}
      <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '14px' }}>
        
        {/* Status Tabs */}
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
          {[
            { key: 'pending', label: ` قيد التدقيق (${requests.filter(r => (activeDomain === 'all' || r.domain === activeDomain) && r.status === 'pending').length})` },
            { key: 'approved', label: ` المقبولة والمفعلة (${requests.filter(r => (activeDomain === 'all' || r.domain === activeDomain) && r.status === 'approved').length})` },
            { key: 'rejected', label: ` المرفوضة (${requests.filter(r => (activeDomain === 'all' || r.domain === activeDomain) && r.status === 'rejected').length})` },
            { key: 'all', label: ` جميع الحالات (${requests.filter(r => (activeDomain === 'all' || r.domain === activeDomain)).length})` },
          ].map(tab => (
            <button
              key={tab.key}
              onClick={() => setStatusFilter(tab.key as any)}
              className={`btn ${statusFilter === tab.key ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', padding: '6px 14px', borderRadius: '8px' }}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Search */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          background: 'rgba(255, 255, 255, 0.05)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          borderRadius: '8px',
          padding: '8px 14px',
          minWidth: '280px',
          flex: 1,
          maxWidth: '380px'
        }}>
          <Search size={16} color="#94a3b8" />
          <input
            type="text"
            placeholder="ابحث باسم المتقدم، المتجر، الهاتف، أو اللوحة..."
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

      </div>

      {/* Main Table */}
      <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={32} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 12px' }} />
            <div>جاري جلب ومزامنة طلبات التسجيل من Firestore...</div>
          </div>
        ) : filteredRequests.length === 0 ? (
          <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <UserCheck size={38} color="#64748b" style={{ margin: '0 auto 12px' }} />
            <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff' }}>ماكو طلبات حالياً تسجيل مطابقة في هذا القسم</div>
            <div style={{ fontSize: '12px', marginTop: '4px' }}>يتم استلام الطلبات تلقائياً فور تقديمها من تطبيق المستخدمين</div>
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>مقدم الطلب</th>
                  <th>اسم النشاط / المركبة</th>
                  <th>رقم الهاتف والتواصل</th>
                  <th>العنوان / المدينة</th>
                  <th>التصنيف / النوع</th>
                  <th>الحالة</th>
                  <th>تاريخ التقديم</th>
                  <th style={{ textAlign: 'center' }}>الإجراءات والقرار</th>
                </tr>
              </thead>
              <tbody>
                {filteredRequests.map((req) => (
                  <tr key={req.id}>
                    
                    {/* Applicant */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        {req.profilePhotoUrl || req.storefrontPhotoUrl ? (
                          <img
                            src={req.profilePhotoUrl || req.storefrontPhotoUrl}
                            alt={req.applicantName}
                            style={{ width: '36px', height: '36px', borderRadius: '8px', objectFit: 'cover', border: '1px solid rgba(255, 255, 255, 0.1)' }}
                            onError={(e) => { (e.target as any).style.display = 'none'; }}
                          />
                        ) : (
                          <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#38bdf8', fontWeight: '800', fontSize: '13px' }}>
                            {req.domain === 'restaurant' ? '' : (req.domain === 'store' ? '' : '')}
                          </div>
                        )}
                        <div>
                          <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{req.applicantName}</div>
                          <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>
                            {req.domain === 'restaurant' ? 'مالك مطعم' : (req.domain === 'store' ? 'مالك متجر' : (req.domain === 'taxi_captain' ? 'كابتن تكسي' : 'مندوب توصيل'))}
                          </div>
                        </div>
                      </div>
                    </td>

                    {/* Business or Vehicle */}
                    <td>
                      <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px' }}>
                        {req.businessOrVehicleTitle}
                      </div>
                      {req.vehiclePlate && req.vehiclePlate !== 'غير مسجلة' && (
                        <div style={{ fontSize: '11px', color: '#fbbf24', marginTop: '2px' }}>
                          لوحة: <strong>{req.vehiclePlate}</strong>
                        </div>
                      )}
                    </td>

                    {/* Phone & WhatsApp */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <a
                          href={`tel:${req.phoneNumber}`}
                          style={{ color: '#38bdf8', textDecoration: 'none', fontWeight: '700', fontSize: '12.5px', direction: 'ltr' }}
                        >
                          {req.phoneNumber} 
                        </a>
                        {req.whatsappNumber && (
                          <a
                            href={`https://wa.me/${req.whatsappNumber.replace(/[^0-9]/g, '')}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            style={{ color: '#22c55e', textDecoration: 'none' }}
                            title="مراسلة عبر واتساب"
                          >
                            <MessageCircle size={15} />
                          </a>
                        )}
                      </div>
                    </td>

                    {/* Address */}
                    <td>
                      <div style={{ fontSize: '12px', color: '#e2e8f0' }}> {req.address || req.city || 'القائم'}</div>
                    </td>

                    {/* Category / Vehicle Badge */}
                    <td>
                      <span className="badge badge-info" style={{ fontSize: '11px' }}>
                        {req.categoryOrType || (req.domain === 'restaurant' ? 'مطعم' : 'متجر')}
                      </span>
                    </td>

                    {/* Status */}
                    <td>
                      {renderStatusBadge(req.status)}
                    </td>

                    {/* Date */}
                    <td style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                      {req.createdAt}
                    </td>

                    {/* Actions */}
                    <td style={{ textAlign: 'center' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
                        
                        {/* Inspect Dossier Button */}
                        <button
                          onClick={() => setSelectedRequest(req)}
                          className="btn btn-secondary"
                          style={{ fontSize: '11.5px', padding: '5px 10px', display: 'flex', alignItems: 'center', gap: '4px' }}
                          title="عرض المستمسكات والتفاصيل"
                        >
                          <Eye size={13} color="#06b6d4" /> فحص الملف
                        </button>

                        {/* Quick Approve Button (if not approved) */}
                        {req.status !== 'approved' && (
                          <button
                            onClick={() => handleApprove(req)}
                            className="btn btn-primary"
                            style={{ fontSize: '11.5px', padding: '5px 10px', background: '#059669', borderColor: '#10b981' }}
                            disabled={actionLoading}
                            title="قبول وتفعيل فوري"
                          >
                            <Check size={13} /> قبول
                          </button>
                        )}

                        {/* Quick Reject Button (if pending) */}
                        {req.status === 'pending' && (
                          <button
                            onClick={() => setRejectingRequest(req)}
                            className="btn btn-secondary"
                            style={{ fontSize: '11.5px', padding: '5px 8px', color: '#f87171', borderColor: '#ef4444' }}
                            disabled={actionLoading}
                            title="رفض مع سبب"
                          >
                            <X size={13} /> رفض
                          </button>
                        )}

                        {/* Delete Button */}
                        <button
                          onClick={() => handleDelete(req)}
                          style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '4px' }}
                          title="حذف الطلب نهائياً"
                        >
                          <Trash2 size={15} />
                        </button>

                      </div>
                    </td>

                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ========================================================================= */}
      {/* MODAL: FULL APPLICATION DOSSIER & DOCUMENT INSPECTOR */}
      {/* ========================================================================= */}
      {selectedRequest && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.85)',
          backdropFilter: 'blur(8px)',
          zIndex: 1000,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          padding: '16px'
        }}>
          <div className="glass-panel" style={{
            width: '100%',
            maxWidth: '850px',
            maxHeight: '92vh',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            padding: 0,
            animation: 'fadeIn 0.2s ease-out'
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
                <h3 style={{ margin: 0, color: '#fff', fontSize: '18px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span>ملف فحص وتوثيق طلب الانضمام:</span>
                  <span style={{ color: '#38bdf8' }}>{selectedRequest.businessOrVehicleTitle || selectedRequest.applicantName}</span>
                </h3>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                  تاريخ التقديم: <strong>{selectedRequest.createdAt}</strong> • المعرف: <code>#{selectedRequest.id.substring(0, 8)}</code>
                </div>
              </div>

              <button
                onClick={() => setSelectedRequest(null)}
                style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', padding: '6px' }}
              >
                <X size={22} />
              </button>
            </div>

            {/* Modal Body */}
            <div style={{ padding: '24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* Top Summary Bar */}
              <div style={{
                background: 'rgba(255, 255, 255, 0.03)',
                border: '1px solid rgba(255, 255, 255, 0.08)',
                borderRadius: '12px',
                padding: '16px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: '12px'
              }}>
                <div>
                  <div style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>حالة الطلب الحالية:</div>
                  <div style={{ marginTop: '4px' }}>{renderStatusBadge(selectedRequest.status)}</div>
                </div>

                {selectedRequest.status === 'rejected' && selectedRequest.rejectionReason && (
                  <div style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)', padding: '6px 12px', borderRadius: '8px', color: '#f87171', fontSize: '12px' }}>
                    <strong>سبب الرفض:</strong> {selectedRequest.rejectionReason}
                  </div>
                )}

                <div style={{ display: 'flex', gap: '10px' }}>
                  <a
                    href={`tel:${selectedRequest.phoneNumber}`}
                    className="btn btn-secondary"
                    style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                  >
                    <Phone size={14} color="#38bdf8" /> اتصال هاتفياً
                  </a>
                  {selectedRequest.whatsappNumber && (
                    <a
                      href={`https://wa.me/${selectedRequest.whatsappNumber.replace(/[^0-9]/g, '')}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px', color: '#22c55e', borderColor: '#22c55e' }}
                    >
                      <MessageCircle size={14} /> محادثة واتساب
                    </a>
                  )}
                </div>
              </div>

              {/* Information Grid */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '14px' }}>
                
                <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                  <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>اسم مقدم الطلب / المالك</div>
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginTop: '2px' }}>{selectedRequest.applicantName}</div>
                </div>

                <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                  <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>النشاط / المركبة</div>
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#38bdf8', marginTop: '2px' }}>{selectedRequest.businessOrVehicleTitle}</div>
                </div>

                <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                  <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>رقم الهاتف الأساسي</div>
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginTop: '2px', direction: 'ltr', textAlign: 'right' }}>{selectedRequest.phoneNumber}</div>
                </div>

                <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                  <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>العنوان والمدينة</div>
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginTop: '2px' }}>{selectedRequest.address || selectedRequest.city || 'القائم'}</div>
                </div>

                {selectedRequest.vehiclePlate && (
                  <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                    <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>رقم اللوحة والموديل</div>
                    <div style={{ fontSize: '14px', fontWeight: '800', color: '#fbbf24', marginTop: '2px' }}>
                      {selectedRequest.vehicleModel} ({selectedRequest.vehiclePlate})
                    </div>
                  </div>
                )}

                {selectedRequest.notes && (
                  <div style={{ gridColumn: '1 / -1', background: 'rgba(255, 255, 255, 0.02)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                    <div style={{ color: 'var(--text-muted)', fontSize: '11.5px' }}>ملاحظات وتفاصيل إضافية من مقدم الطلب:</div>
                    <div style={{ fontSize: '13px', color: '#e2e8f0', marginTop: '4px' }}>{selectedRequest.notes}</div>
                  </div>
                )}

              </div>

              {/* Uploaded Documents & Photos Section */}
              <div>
                <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <FileText size={16} color="#06b6d4" />
                  المستمسكات والوثائق والصور المرفقة:
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '14px' }}>
                  
                  {/* Document 1: Profile / Storefront */}
                  {(selectedRequest.profilePhotoUrl || selectedRequest.storefrontPhotoUrl) && (
                    <div style={{ background: 'rgba(255, 255, 255, 0.02)', border: '1px solid rgba(255, 255, 255, 0.08)', borderRadius: '10px', padding: '10px', textAlign: 'center' }}>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginBottom: '8px' }}>
                        {selectedRequest.domain === 'taxi_captain' || selectedRequest.domain === 'mersal_courier' ? 'الصورة الشخصية' : 'صورة الواجهة / الشعار'}
                      </div>
                      <a href={selectedRequest.profilePhotoUrl || selectedRequest.storefrontPhotoUrl} target="_blank" rel="noopener noreferrer">
                        <img
                          src={selectedRequest.profilePhotoUrl || selectedRequest.storefrontPhotoUrl}
                          alt="Store/Profile"
                          style={{ width: '100%', height: '140px', objectFit: 'cover', borderRadius: '6px' }}
                        />
                      </a>
                    </div>
                  )}

                  {/* Document 2: National ID */}
                  {selectedRequest.nationalIdUrl && (
                    <div style={{ background: 'rgba(255, 255, 255, 0.02)', border: '1px solid rgba(255, 255, 255, 0.08)', borderRadius: '10px', padding: '10px', textAlign: 'center' }}>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginBottom: '8px' }}>البطاقة الوطنية / هوية الأحوال</div>
                      <a href={selectedRequest.nationalIdUrl} target="_blank" rel="noopener noreferrer">
                        <img
                          src={selectedRequest.nationalIdUrl}
                          alt="National ID"
                          style={{ width: '100%', height: '140px', objectFit: 'cover', borderRadius: '6px' }}
                        />
                      </a>
                    </div>
                  )}

                  {/* Document 3: Driving License */}
                  {selectedRequest.licenseUrl && (
                    <div style={{ background: 'rgba(255, 255, 255, 0.02)', border: '1px solid rgba(255, 255, 255, 0.08)', borderRadius: '10px', padding: '10px', textAlign: 'center' }}>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginBottom: '8px' }}>إجازة السوق (الرخصة)</div>
                      <a href={selectedRequest.licenseUrl} target="_blank" rel="noopener noreferrer">
                        <img
                          src={selectedRequest.licenseUrl}
                          alt="License"
                          style={{ width: '100%', height: '140px', objectFit: 'cover', borderRadius: '6px' }}
                        />
                      </a>
                    </div>
                  )}

                  {/* Document 4: Vehicle Registration / Commercial Record */}
                  {(selectedRequest.vehicleDocUrl || selectedRequest.commercialRecordUrl) && (
                    <div style={{ background: 'rgba(255, 255, 255, 0.02)', border: '1px solid rgba(255, 255, 255, 0.08)', borderRadius: '10px', padding: '10px', textAlign: 'center' }}>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginBottom: '8px' }}>
                        {selectedRequest.domain === 'taxi_captain' || selectedRequest.domain === 'mersal_courier' ? 'سنوية المركبة' : 'الإجازة الصحية / السجل التجاري'}
                      </div>
                      <a href={selectedRequest.vehicleDocUrl || selectedRequest.commercialRecordUrl} target="_blank" rel="noopener noreferrer">
                        <img
                          src={selectedRequest.vehicleDocUrl || selectedRequest.commercialRecordUrl}
                          alt="Document"
                          style={{ width: '100%', height: '140px', objectFit: 'cover', borderRadius: '6px' }}
                        />
                      </a>
                    </div>
                  )}

                </div>
              </div>

            </div>

            {/* Modal Footer (Action Buttons) */}
            <div style={{
              padding: '16px 24px',
              borderTop: '1px solid rgba(255, 255, 255, 0.1)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              background: 'rgba(15, 23, 42, 0.8)'
            }}>
              <button
                onClick={() => handleDelete(selectedRequest)}
                className="btn btn-danger"
                style={{ fontSize: '12px', padding: '7px 12px' }}
                disabled={actionLoading}
              >
                <Trash2 size={14} /> حذف الطلب نهائياً
              </button>

              <div style={{ display: 'flex', gap: '8px' }}>
                {selectedRequest.status !== 'approved' && (
                  <button
                    onClick={() => handleApprove(selectedRequest)}
                    className="btn btn-primary"
                    style={{ fontSize: '12.5px', padding: '8px 18px', background: '#059669', borderColor: '#10b981', fontWeight: '800' }}
                    disabled={actionLoading}
                  >
                    <Check size={16} /> قبول وتفعيل الطلب رسمياً 
                  </button>
                )}

                {selectedRequest.status === 'pending' && (
                  <button
                    onClick={() => setRejectingRequest(selectedRequest)}
                    className="btn btn-secondary"
                    style={{ fontSize: '12.5px', padding: '8px 16px', color: '#f87171', borderColor: '#ef4444' }}
                    disabled={actionLoading}
                  >
                    <X size={16} /> رفض الطلب 
                  </button>
                )}

                <button
                  onClick={() => setSelectedRequest(null)}
                  className="btn btn-secondary"
                  style={{ fontSize: '12.5px', padding: '8px 16px' }}
                >
                  إغلاق
                </button>
              </div>
            </div>

          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* REJECT REQUEST MODAL */}
      {/* ========================================================================= */}
      {rejectingRequest && (
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
              <h3 style={{ margin: 0, fontSize: '17px', fontWeight: '800' }}>رفض طلب الانضمام وتوثيق السبب</h3>
            </div>

            <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>
              يرجى كتابة سبب رفض طلب ({rejectingRequest.businessOrVehicleTitle || rejectingRequest.applicantName}) ليتم إبلاغ المتقدم وتوثيقه في السجل:
            </p>

            <div>
              <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>
                سبب الرفض:
              </label>
              <textarea
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                placeholder="مثال: المستمسكات المرفقة غير واضحة / عدم توفر إجازة سوق سارية / رقم الهاتف غير متاح..."
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
                  setRejectingRequest(null);
                  setRejectionReason('');
                }}
                className="btn btn-secondary"
                style={{ fontSize: '12px' }}
                disabled={actionLoading}
              >
                تراجع
              </button>
              <button
                onClick={handleConfirmReject}
                className="btn btn-danger"
                style={{ fontSize: '12px', padding: '8px 16px' }}
                disabled={actionLoading}
              >
                تأكيد الرفض 
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
