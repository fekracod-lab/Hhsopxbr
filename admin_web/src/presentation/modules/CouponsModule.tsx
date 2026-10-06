import React, { useState, useEffect, useMemo } from 'react';
import {
  Tag,
  Plus,
  Search,
  CheckCircle,
  XCircle,
  Clock,
  Percent,
  Coins,
  Calendar,
  Layers,
  Trash2,
  Download,
  AlertTriangle,
  Loader2,
  Copy,
  Sparkles,
  ToggleLeft,
  ToggleRight,
  Info,
  X
} from 'lucide-react';
import { CouponsRepository, CouponEntity } from '../../infrastructure/repositories/CouponsRepository';

export const CouponsModule: React.FC = () => {
  const [coupons, setCoupons] = useState<CouponEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all');
  const [scopeFilter, setScopeFilter] = useState<'all' | 'food' | 'taxi' | 'stores' | 'parcels'>('all');

  // Add Coupon Modal State
  const [showAddModal, setShowAddModal] = useState(false);
  const [code, setCode] = useState('');
  const [discountType, setDiscountType] = useState<'percentage' | 'fixed_amount'>('percentage');
  const [discountValue, setDiscountValue] = useState<number>(15);
  const [minOrderAmount, setMinOrderAmount] = useState<number>(5000);
  const [maxDiscountCap, setMaxDiscountCap] = useState<number>(3000);
  const [serviceScope, setServiceScope] = useState<'all' | 'food' | 'taxi' | 'stores' | 'parcels'>('all');
  const [usageLimitTotal, setUsageLimitTotal] = useState<number>(100);
  const [usageLimitPerUser, setUsageLimitPerUser] = useState<number>(1);
  const [expiryDate, setExpiryDate] = useState('2026-12-31');
  const [notes, setNotes] = useState('');

  // Action Loading & Toast
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  useEffect(() => {
    setIsLoading(true);
    const unsub = CouponsRepository.subscribeToCoupons((data) => {
      setCoupons(data);
      setIsLoading(false);
    });

    return () => unsub();
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 4000);
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Stats
  const stats = useMemo(() => {
    const activeCount = coupons.filter(c => c.isActive).length;
    const totalUses = coupons.reduce((sum, c) => sum + (c.timesUsed || 0), 0);
    const totalDiscountsGiven = coupons.reduce((sum, c) => sum + (c.totalDiscountGivenIqd || 0), 0);

    return {
      totalCount: coupons.length,
      activeCount,
      totalUses,
      totalDiscountsGiven
    };
  }, [coupons]);

  // Filtered Coupons
  const filteredCoupons = useMemo(() => {
    return coupons.filter(c => {
      if (statusFilter === 'active' && !c.isActive) return false;
      if (statusFilter === 'inactive' && c.isActive) return false;
      if (scopeFilter !== 'all' && c.serviceScope !== scopeFilter) return false;

      if (!searchQuery.trim()) return true;
      const q = searchQuery.toLowerCase().trim();
      return (
        c.code.toLowerCase().includes(q) ||
        (c.notes && c.notes.toLowerCase().includes(q))
      );
    });
  }, [coupons, statusFilter, scopeFilter, searchQuery]);

  // Handle Add
  const handleCreateCoupon = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!code.trim()) {
      showToast('يرجى إدخال كود الخصم', 'error');
      return;
    }

    try {
      await CouponsRepository.addCoupon({
        code: code.trim().toUpperCase(),
        discountType,
        discountValue: Number(discountValue),
        minOrderAmountIqd: Number(minOrderAmount) || 0,
        maxDiscountCapIqd: discountType === 'percentage' ? Number(maxDiscountCap) : undefined,
        serviceScope,
        usageLimitTotal: Number(usageLimitTotal) || 100,
        usageLimitPerUser: Number(usageLimitPerUser) || 1,
        startDate: new Date().toISOString().slice(0, 10),
        expiryDate: expiryDate || '2026-12-31',
        isActive: true,
        notes: notes.trim()
      });

      showToast(`تم إنشاء وتفعيل كوبون (${code.toUpperCase()}) بنجاح `);
      setShowAddModal(false);
      setCode('');
      setNotes('');
    } catch (err: any) {
      showToast('فشل إنشاء الكوبون: ' + (err.message || ''), 'error');
    }
  };

  // Toggle Status
  const handleToggleStatus = async (coupon: CouponEntity) => {
    setActionLoadingId(coupon.id);
    try {
      await CouponsRepository.toggleCouponStatus(coupon.id, !coupon.isActive);
      showToast(!coupon.isActive ? `تم تفعيل كوبون ${coupon.code} ` : `تم إيقاف كوبون ${coupon.code} `);
    } catch (err: any) {
      showToast('تعذر تغيير حالة الكوبون: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Delete Coupon
  const handleDeleteCoupon = async (coupon: CouponEntity) => {
    if (!window.confirm(`متأكد تريد تحذف كود الخصم (${coupon.code}) نهائياً من النظام؟`)) return;

    setActionLoadingId(coupon.id);
    try {
      await CouponsRepository.deleteCoupon(coupon.id);
      showToast(`تم حذف كوبون ${coupon.code} بنجاح `);
    } catch (err: any) {
      showToast('فشل حذف الكوبون: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Export CSV
  const handleExportCSV = () => {
    if (filteredCoupons.length === 0) {
      showToast('لا توجد كوبونات لتصديرها', 'error');
      return;
    }
    const headers = ['كود الخصم', 'نوع الخصم', 'قيمة الخصم', 'الحد الأدنى للطلب', 'الخدمة المشمولة', 'مرات الاستخدام', 'تاريخ الانتهاء', 'الحالة'];
    const rows = filteredCoupons.map(c => [
      `"${c.code}"`,
      `"${c.discountType === 'percentage' ? 'نسبة مئوية' : 'مبلغ ثابت'}"`,
      c.discountType === 'percentage' ? `${c.discountValue}%` : `${c.discountValue} د.ع`,
      c.minOrderAmountIqd,
      `"${c.serviceScope}"`,
      `${c.timesUsed} / ${c.usageLimitTotal}`,
      `"${c.expiryDate}"`,
      `"${c.isActive ? 'مفعل' : 'معطل'}"`
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `madar_coupons_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير كشف الكوبونات بنجاح ');
  };

  const renderScopeBadge = (scope: CouponEntity['serviceScope']) => {
    switch (scope) {
      case 'food':
        return <span className="badge badge-warning" style={{ fontSize: '11px' }}> مطاعم فقط</span>;
      case 'taxi':
        return <span className="badge badge-info" style={{ fontSize: '11px' }}> تكسي فقط</span>;
      case 'stores':
        return <span className="badge badge-success" style={{ fontSize: '11px' }}> متاجر فقط</span>;
      case 'parcels':
        return <span className="badge badge-secondary" style={{ fontSize: '11px' }}> طرود فقط</span>;
      default:
        return <span className="badge badge-primary" style={{ fontSize: '11px' }}> كافة الخدمات</span>;
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast */}
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
          fontSize: '13.5px'
        }}>
          {toast.type === 'success' ? <CheckCircle size={18} /> : <AlertTriangle size={18} />}
          <span>{toast.msg}</span>
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '14px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ padding: '8px', borderRadius: '10px', background: 'linear-gradient(135deg, #f59e0b, #d97706)' }}>
              <Tag size={22} color="#fff" />
            </div>
            مركز إدارة كوبونات وقسائم الخصم (Promo Codes & Coupons)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            إنشاء أكواد الخصم، تحديد قيم الخصم ونسبته، تقييد الخدمات المشمولة، ومراقبة استخدامات العملاء
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button
            onClick={handleExportCSV}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px' }}
          >
            <Download size={15} /> تصدير CSV
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24', fontWeight: '800' }}
          >
            <Plus size={16} /> إنشاء كود خصم جديد
          </button>
        </div>
      </div>

      {/* 4 Financial & Usage Stat Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
        
        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي الكوبونات النشطة</span>
            <Tag size={16} color="#fbbf24" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#fbbf24', marginTop: '6px' }}>
            {stats.activeCount} كود مفعّل
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>من أصل {stats.totalCount} كود مسجل</div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>مرات استخدام الكوبونات</span>
            <Sparkles size={16} color="#38bdf8" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#38bdf8', marginTop: '6px' }}>
            {stats.totalUses} عملية
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>استخدمها العملاء في الطلبات</div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي مبالغ الخصومات الممنوحة</span>
            <Coins size={16} color="#34d399" />
          </div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#34d399', marginTop: '6px' }}>
            {formatIqd(stats.totalDiscountsGiven)}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>وفرها العملاء عبر العروض</div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>حالة المنظومة</span>
            <CheckCircle size={16} color="#34d399" />
          </div>
          <div style={{ fontSize: '18px', fontWeight: '900', color: '#fff', marginTop: '8px' }}>
            Promo Engine Live 
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '2px' }}>تطبيق فوري عند إتمام الطلب</div>
        </div>

      </div>

      {/* Search & Filter Bar */}
      <div className="glass-panel" style={{ padding: '14px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
          {[
            { id: 'all', label: ` الكل (${coupons.length})` },
            { id: 'active', label: ` المفعّلة (${coupons.filter(c => c.isActive).length})` },
            { id: 'inactive', label: ` المعطلة (${coupons.filter(c => !c.isActive).length})` }
          ].map(f => (
            <button
              key={f.id}
              onClick={() => setStatusFilter(f.id as any)}
              className={`btn ${statusFilter === f.id ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12px', padding: '6px 14px' }}
            >
              {f.label}
            </button>
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'rgba(255, 255, 255, 0.05)', padding: '8px 14px', borderRadius: '8px', border: '1px solid rgba(255, 255, 255, 0.1)', minWidth: '260px' }}>
          <Search size={15} color="#94a3b8" />
          <input
            type="text"
            placeholder="ابحث بكود الخصم أو الوصف..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{ background: 'transparent', border: 'none', color: '#fff', fontSize: '13px', width: '100%', outline: 'none' }}
          />
          {searchQuery && <X size={13} color="#94a3b8" style={{ cursor: 'pointer' }} onClick={() => setSearchQuery('')} />}
        </div>

      </div>

      {/* Coupons Table */}
      <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={30} color="#fbbf24" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 10px' }} />
            <div>جاري جلب كوبونات الخصم من Firestore...</div>
          </div>
        ) : filteredCoupons.length === 0 ? (
          <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Tag size={36} color="#64748b" style={{ margin: '0 auto 10px' }} />
            <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>لا توجد كوبونات مسجلة حالياً</div>
            <div style={{ fontSize: '12px', marginTop: '4px' }}>اضغط على "إنشاء كود خصم جديد" لإطلاق أول حملة ترويجية</div>
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>كود الخصم</th>
                  <th>قيمة ونوع الخصم</th>
                  <th>الخدمة المشمولة</th>
                  <th>الحد الأدنى للطلب</th>
                  <th>مرات الاستخدام والحد</th>
                  <th>تاريخ الانتهاء</th>
                  <th>الحالة</th>
                  <th style={{ textAlign: 'center' }}>الإجراءات</th>
                </tr>
              </thead>
              <tbody>
                {filteredCoupons.map(c => (
                  <tr key={c.id}>
                    
                    {/* Code */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{
                          background: 'rgba(251, 191, 36, 0.15)',
                          border: '1px dashed #fbbf24',
                          padding: '4px 10px',
                          borderRadius: '6px',
                          fontFamily: 'monospace',
                          fontWeight: '900',
                          fontSize: '14px',
                          color: '#fbbf24',
                          letterSpacing: '1px'
                        }}>
                          {c.code}
                        </div>
                        <button
                          onClick={() => {
                            navigator.clipboard.writeText(c.code);
                            showToast(`تم نسخ الكود ${c.code} `);
                          }}
                          style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
                          title="نسخ الكود"
                        >
                          <Copy size={13} />
                        </button>
                      </div>
                      {c.notes && <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>{c.notes}</div>}
                    </td>

                    {/* Discount Value */}
                    <td>
                      <div style={{ fontWeight: '800', color: '#34d399', fontSize: '14px' }}>
                        {c.discountType === 'percentage' ? `${c.discountValue}% خصم` : `${formatIqd(c.discountValue)}`}
                      </div>
                      {c.discountType === 'percentage' && c.maxDiscountCapIqd && (
                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>
                          بحد أقصى: {formatIqd(c.maxDiscountCapIqd)}
                        </div>
                      )}
                    </td>

                    {/* Scope */}
                    <td>
                      {renderScopeBadge(c.serviceScope)}
                    </td>

                    {/* Min Order */}
                    <td>
                      <div style={{ fontSize: '12.5px', color: '#e2e8f0' }}>
                        {c.minOrderAmountIqd > 0 ? formatIqd(c.minOrderAmountIqd) : 'بدون حد أدنى'}
                      </div>
                    </td>

                    {/* Usage Limits */}
                    <td>
                      <div style={{ fontSize: '12.5px', fontWeight: '700', color: '#38bdf8' }}>
                        {c.timesUsed} / {c.usageLimitTotal}
                      </div>
                      <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>
                        {c.usageLimitPerUser} استخدام لكل زبون
                      </div>
                    </td>

                    {/* Expiry */}
                    <td>
                      <div style={{ fontSize: '12px', color: '#cbd5e1', display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <Clock size={12} color="#94a3b8" />
                        {c.expiryDate}
                      </div>
                    </td>

                    {/* Status */}
                    <td>
                      <button
                        onClick={() => handleToggleStatus(c)}
                        disabled={actionLoadingId === c.id}
                        style={{
                          padding: '4px 10px',
                          borderRadius: '6px',
                          fontSize: '11px',
                          fontWeight: '700',
                          cursor: 'pointer',
                          background: c.isActive ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                          color: c.isActive ? '#34d399' : '#f87171',
                          border: `1px solid ${c.isActive ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`
                        }}
                      >
                        {c.isActive ? 'مفعّل وشغّال ' : 'معطل مؤقتاً '}
                      </button>
                    </td>

                    {/* Actions */}
                    <td style={{ textAlign: 'center' }}>
                      <button
                        onClick={() => handleDeleteCoupon(c)}
                        disabled={actionLoadingId === c.id}
                        style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '6px' }}
                        title="حذف الكوبون نهائياً"
                      >
                        <Trash2 size={15} />
                      </button>
                    </td>

                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ========================================================================= */}
      {/* MODAL: CREATE NEW PROMO CODE */}
      {/* ========================================================================= */}
      {showAddModal && (
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
            maxWidth: '560px',
            borderRadius: '20px',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '16px',
            border: '1px solid rgba(251, 191, 36, 0.4)',
            boxShadow: '0 25px 70px rgba(0,0,0,0.8)'
          }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255, 255, 255, 0.1)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Tag size={20} color="#fbbf24" />
                <h3 style={{ margin: 0, color: '#fff', fontSize: '17px', fontWeight: '800' }}>
                  إنشاء كود خصم جديد (Promo Code)
                </h3>
              </div>
              <button
                onClick={() => setShowAddModal(false)}
                style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleCreateCoupon} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              {/* Code */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#fbbf24', marginBottom: '6px' }}>
                  كود الخصم (Promo Code):
                </label>
                <input
                  type="text"
                  required
                  value={code}
                  onChange={e => setCode(e.target.value.toUpperCase())}
                  placeholder="مثال: QAIM15 أو MADAR2026"
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    background: '#0f172a',
                    border: '1px solid #fbbf24',
                    borderRadius: '8px',
                    color: '#fbbf24',
                    fontSize: '14px',
                    fontWeight: '900',
                    letterSpacing: '1px',
                    outline: 'none'
                  }}
                />
              </div>

              {/* Discount Type & Value */}
              <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    نوع الخصم:
                  </label>
                  <select
                    value={discountType}
                    onChange={e => setDiscountType(e.target.value as any)}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  >
                    <option value="percentage">نسبة مئوية (%)</option>
                    <option value="fixed_amount">مبلغ ثابت بالدينار (د.ع)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    {discountType === 'percentage' ? 'نسبة الخصم (%):' : 'المبلغ (د.ع):'}
                  </label>
                  <input
                    type="number"
                    required
                    min="1"
                    value={discountValue}
                    onChange={e => setDiscountValue(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#34d399', fontSize: '13px', fontWeight: '800', outline: 'none' }}
                  />
                </div>
              </div>

              {/* Scope & Min Order */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    الخدمات المشمولة بالخصم:
                  </label>
                  <select
                    value={serviceScope}
                    onChange={e => setServiceScope(e.target.value as any)}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  >
                    <option value="all"> كافة الخدمات (مطاعم، تكسي، متاجر)</option>
                    <option value="food"> طلبات المطاعم فقط</option>
                    <option value="taxi"> مشاوير وتوصيل تكسي مدار</option>
                    <option value="stores"> المتاجر والسوبرماركت</option>
                    <option value="parcels"> طرود وتوصيل مرسال</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    الحد الأدنى للطلب (د.ع):
                  </label>
                  <input
                    type="number"
                    step="500"
                    value={minOrderAmount}
                    onChange={e => setMinOrderAmount(Number(e.target.value))}
                    placeholder="0 = بدون حد أدنى"
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  />
                </div>
              </div>

              {/* Usage Limits & Expiry */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--text-muted)', marginBottom: '4px' }}>
                    إجمالي عدد الاستخدامات:
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={usageLimitTotal}
                    onChange={e => setUsageLimitTotal(Number(e.target.value))}
                    style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '12px', outline: 'none' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--text-muted)', marginBottom: '4px' }}>
                    لكل زبون:
                  </label>
                  <input
                    type="number"
                    min="1"
                    value={usageLimitPerUser}
                    onChange={e => setUsageLimitPerUser(Number(e.target.value))}
                    style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '12px', outline: 'none' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--text-muted)', marginBottom: '4px' }}>
                    تاريخ الانتهاء:
                  </label>
                  <input
                    type="date"
                    value={expiryDate}
                    onChange={e => setExpiryDate(e.target.value)}
                    style={{ width: '100%', padding: '8px 10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '12px', outline: 'none' }}
                  />
                </div>
              </div>

              {/* Notes */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)', marginBottom: '4px' }}>
                  وصف الكوبون أو ملاحظات الحملة:
                </label>
                <input
                  type="text"
                  value={notes}
                  onChange={e => setNotes(e.target.value)}
                  placeholder="مثال: خصم خاص بافتتاح فرع شارع الأطباء"
                  style={{ width: '100%', padding: '8px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '6px', color: '#fff', fontSize: '12px', outline: 'none' }}
                />
              </div>

              {/* Submit */}
              <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                <button
                  type="submit"
                  className="btn btn-primary"
                  style={{ flex: 1, padding: '12px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24', fontWeight: '800', fontSize: '13px' }}
                >
                  تأكيد وتفعيل كود الخصم في Firestore 
                </button>
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
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
