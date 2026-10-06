import React, { useState, useEffect } from 'react';
import { 
  Users, 
  Search, 
  Phone, 
  Mail, 
  Calendar, 
  Ban, 
  CheckCircle2, 
  Copy, 
  Loader2,
  Trash2,
  Edit3,
  Eye,
  Wallet,
  ShoppingBag,
  TrendingUp,
  MapPin,
  X,
  Plus,
  DollarSign
} from 'lucide-react';
import { CustomersRepository, CustomerEntity } from '../../infrastructure/repositories/CustomersRepository';

export const CustomersModule: React.FC = () => {
  const [customers, setCustomers] = useState<CustomerEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTab, setSelectedTab] = useState<'active' | 'blocked' | 'wallet'>('active');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Bulk Selection State
  const [selectedCustomerIds, setSelectedCustomerIds] = useState<string[]>([]);
  const [isBulkDeleting, setIsBulkDeleting] = useState(false);

  // Details Modal
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerEntity | null>(null);

  // Edit Customer Modal State
  const [editingCustomer, setEditingCustomer] = useState<CustomerEntity | null>(null);
  const [editName, setEditName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editCity, setEditCity] = useState('القائم');
  const [editWalletBalance, setEditWalletBalance] = useState<number>(0);

  useEffect(() => {
    setIsLoading(true);
    const unsub = CustomersRepository.subscribeToCustomers((data) => {
      setCustomers(data);
      setIsLoading(false);

      if (selectedCustomer) {
        const updated = data.find(c => c.uid === selectedCustomer.uid);
        if (updated) setSelectedCustomer(updated);
      }
    });

    return () => unsub();
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const handleOpenEdit = (cust: CustomerEntity) => {
    setEditingCustomer(cust);
    setEditName(cust.name);
    setEditPhone(cust.phone);
    setEditEmail(cust.email || '');
    setEditCity(cust.city || 'القائم');
    setEditWalletBalance(cust.walletBalance || 0);
  };

  const handleSaveCustomer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCustomer) return;

    setActionLoadingId(editingCustomer.uid);
    try {
      await CustomersRepository.updateCustomerDetails(editingCustomer.uid, {
        name: editName.trim(),
        phone: editPhone.trim(),
        email: editEmail.trim(),
        city: editCity.trim(),
        walletBalance: Number(editWalletBalance) || 0
      });

      showToast(`تم تحديث بيانات ومحفظة العميل (${editName}) بنجاح `);
      setEditingCustomer(null);
    } catch (err: any) {
      showToast('فشل تحديث بيانات العميل: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleToggleBlock = async (cust: CustomerEntity) => {
    const nextBlocked = !cust.isBlocked;
    const confirmMsg = nextBlocked 
      ? `هل أنت متأكد من حظر حساب العميل (${cust.name})؟ سيتم إخفاؤه من قائمة النشطين.` 
      : `هل تريد فك الحظر عن العميل (${cust.name})؟`;

    if (!window.confirm(confirmMsg)) return;

    setActionLoadingId(cust.uid);
    try {
      await CustomersRepository.toggleBlockCustomer(cust.uid, nextBlocked);
      showToast(nextBlocked ? 'تم حظر حساب العميل ونقله للمحظورين ' : 'تم فك الحظر عن العميل بنجاح ');
    } catch (err: any) {
      showToast('تعذر تغيير حالة الحساب: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDeleteSingle = async (cust: CustomerEntity) => {
    if (!window.confirm(` تحذير: متأكد تريد تحذف حساب العميل (${cust.name}) نهائياً من قاعدة البيانات؟`)) return;

    setActionLoadingId(cust.uid);
    try {
      await CustomersRepository.deleteCustomer(cust.uid);
      showToast(`تم حذف العميل (${cust.name}) بنجاح `);
      if (selectedCustomer?.uid === cust.uid) setSelectedCustomer(null);
    } catch (err: any) {
      showToast('تعذر حذف الحساب: ' + (err.message || ''), 'error');
    } finally {
      setActionLoadingId(null);
    }
  };

  // Bulk Selection Handlers
  const handleToggleSelectAll = (filteredList: CustomerEntity[]) => {
    if (selectedCustomerIds.length === filteredList.length) {
      setSelectedCustomerIds([]);
    } else {
      setSelectedCustomerIds(filteredList.map(c => c.uid));
    }
  };

  const handleToggleSelectOne = (uid: string) => {
    if (selectedCustomerIds.includes(uid)) {
      setSelectedCustomerIds(prev => prev.filter(id => id !== uid));
    } else {
      setSelectedCustomerIds(prev => [...prev, uid]);
    }
  };

  const handleBulkDelete = async () => {
    if (selectedCustomerIds.length === 0) return;
    const count = selectedCustomerIds.length;

    if (!window.confirm(` تحذير: متأكد تريد تحذف (${count}) عميل دفعة واحدة نهائياً من قاعدة البيانات؟`)) return;

    setIsBulkDeleting(true);
    try {
      setCustomers(prev => prev.filter(c => !selectedCustomerIds.includes(c.uid)));
      await CustomersRepository.deleteMultipleCustomers(selectedCustomerIds);
      showToast(`تم حذف (${count}) عميل بنجاح `);
      setSelectedCustomerIds([]);
    } catch (err: any) {
      showToast('فشل الحذف الجماعي: ' + (err.message || ''), 'error');
    } finally {
      setIsBulkDeleting(false);
    }
  };

  const handleExportPhones = () => {
    const phones = customers.filter(c => !c.isBlocked).map(c => c.phone).filter(p => p && p !== 'غير متوفر').join('\n');
    navigator.clipboard.writeText(phones);
    showToast('تم نسخ أرقام هواتف العملاء النشطين إلى الحافظة ');
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Tab Counts
  const activeUnblockedCount = customers.filter(c => !c.isBlocked).length;
  const blockedCount = customers.filter(c => c.isBlocked).length;
  const walletCount = customers.filter(c => c.walletBalance > 0 && !c.isBlocked).length;

  // Filtered List
  const filtered = customers.filter(c => {
    const matchesSearch = 
      c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.phone.includes(searchQuery) ||
      (c.email && c.email.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (c.city && c.city.toLowerCase().includes(searchQuery.toLowerCase()));

    if (selectedTab === 'blocked') return matchesSearch && c.isBlocked;
    if (selectedTab === 'wallet') return matchesSearch && c.walletBalance > 0 && !c.isBlocked;
    // Default 'active': Blocked users disappear completely!
    return matchesSearch && !c.isBlocked;
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
            <Users size={22} color="#06b6d4" /> إدارة العملاء والركاب (مرتبة حسب الأحدث)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            تتبع حسابات المستخدمين والركاب، إدارة الأرصدة والمحافظ، الحذف المتعدد، والحظر الإداري
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button 
            onClick={handleExportPhones}
            className="btn btn-secondary" 
            style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <Copy size={14} /> نسخ هواتف العملاء للرسائل
          </button>
        </div>
      </div>

      {/* Floating Bulk Action Bar (When 1+ customers are checked) */}
      {selectedCustomerIds.length > 0 && (
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
              تم تحديد ({selectedCustomerIds.length}) عميل
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
              <span>{isBulkDeleting ? 'جاري الحذف...' : `حذف العملاء المحددين نهائياً (${selectedCustomerIds.length})`}</span>
            </button>
            <button
              onClick={() => setSelectedCustomerIds([])}
              className="btn btn-secondary"
              style={{ fontSize: '12px' }}
            >
              إلغاء التحديد
            </button>
          </div>
        </div>
      )}

      {/* Filter Tabs & Search */}
      <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '14px' }}>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button 
            onClick={() => setSelectedTab('active')}
            className={`btn ${selectedTab === 'active' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12px' }}
          >
            النشطين ({activeUnblockedCount})
          </button>
          <button 
            onClick={() => setSelectedTab('wallet')}
            className={`btn ${selectedTab === 'wallet' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Wallet size={13} /> أصحاب الأرصدة ({walletCount})
          </button>
          <button 
            onClick={() => setSelectedTab('blocked')}
            className={`btn ${selectedTab === 'blocked' ? 'btn-danger' : 'btn-secondary'}`}
            style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Ban size={13} /> المحظورين ({blockedCount})
          </button>
        </div>

        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '280px' }}>
          <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
          <input
            type="text"
            placeholder="ابحث بالاسم، رقم الهاتف، أو البريد..."
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

      {/* Customers Table */}
      <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
            <div>جاري جلب حسابات العملاء والركاب من Firestore...</div>
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Users size={32} color="#64748b" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>
              {selectedTab === 'blocked' ? 'لا يوجد أي عملاء محظورين حالياً' : 'ماكو عملاء مسجلين مطابقين للبحث'}
            </div>
            <div style={{ fontSize: '11px', marginTop: '2px' }}>يتم ترتيب العملاء تلقائياً من الأحدث تسجيلاً إلى الأقدم</div>
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th style={{ width: '40px', textAlign: 'center' }}>
                    <input
                      type="checkbox"
                      checked={selectedCustomerIds.length === filtered.length && filtered.length > 0}
                      onChange={() => handleToggleSelectAll(filtered)}
                      style={{ cursor: 'pointer', width: '16px', height: '16px', accentColor: '#06b6d4' }}
                    />
                  </th>
                  <th>اسم العميل</th>
                  <th>رقم الهاتف</th>
                  <th>المدينة</th>
                  <th>تاريخ التسجيل</th>
                  <th>رصيد المحفظة</th>
                  <th>الحالة</th>
                  <th>الإجراءات</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(cust => {
                  const isChecked = selectedCustomerIds.includes(cust.uid);

                  return (
                    <tr key={cust.uid} style={{ background: isChecked ? 'rgba(6, 182, 212, 0.08)' : undefined }}>
                      <td style={{ textAlign: 'center' }}>
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => handleToggleSelectOne(cust.uid)}
                          style={{ cursor: 'pointer', width: '16px', height: '16px', accentColor: '#06b6d4' }}
                        />
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '32px', height: '32px', borderRadius: '50%', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#38bdf8', fontWeight: '800', fontSize: '12px' }}>
                            {cust.name.substring(0, 1)}
                          </div>
                          <div>
                            <div style={{ fontWeight: '800', color: '#fff' }}>{cust.name}</div>
                            {cust.email && <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>{cust.email}</div>}
                          </div>
                        </div>
                      </td>
                      <td>
                        <span style={{ fontSize: '12px', color: '#cbd5e1' }} dir="ltr">{cust.phone}</span>
                      </td>
                      <td>
                        <span style={{ fontSize: '12px', color: '#94a3b8' }}> {cust.city || 'القائم'}</span>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#cbd5e1' }}>{cust.createdAt}</div>
                      </td>
                      <td>
                        <span style={{ fontWeight: '800', color: cust.walletBalance > 0 ? '#34d399' : '#94a3b8', fontSize: '12.5px' }}>
                          {formatIqd(cust.walletBalance)}
                        </span>
                      </td>
                      <td>
                        <button
                          onClick={() => handleToggleBlock(cust)}
                          disabled={actionLoadingId === cust.uid}
                          style={{
                            padding: '4px 10px',
                            borderRadius: '6px',
                            fontSize: '11px',
                            fontWeight: '700',
                            cursor: 'pointer',
                            background: cust.isBlocked ? 'rgba(239, 68, 68, 0.15)' : 'rgba(16, 185, 129, 0.15)',
                            color: cust.isBlocked ? '#f87171' : '#34d399',
                            border: `1px solid ${cust.isBlocked ? 'rgba(239, 68, 68, 0.3)' : 'rgba(16, 185, 129, 0.3)'}`
                          }}
                        >
                          {cust.isBlocked ? 'محظور ' : 'نشط '}
                        </button>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button
                            onClick={() => setSelectedCustomer(cust)}
                            className="btn btn-secondary"
                            style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
                            title="عرض الملف الكامل"
                          >
                            <Eye size={13} color="#06b6d4" />
                            <span>الملف</span>
                          </button>
                          <button
                            onClick={() => handleOpenEdit(cust)}
                            className="btn btn-secondary"
                            style={{ fontSize: '11px', padding: '5px 8px', display: 'flex', alignItems: 'center', gap: '4px', color: '#fbbf24' }}
                            title="تعديل البيانات والرصيد"
                          >
                            <Edit3 size={13} />
                            <span>تعديل</span>
                          </button>
                          <button
                            onClick={() => handleDeleteSingle(cust)}
                            disabled={actionLoadingId === cust.uid}
                            style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '5px' }}
                            title="حذف الحساب نهائياً"
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

      {/* ─── FULL CUSTOMER PROFILE MODAL ─── */}
      {selectedCustomer && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '580px', width: '100%', borderRadius: '24px', border: '1px solid rgba(6, 182, 212, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '14px', marginBottom: '18px' }}>
              <div>
                <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>ملف العميل: {selectedCustomer.name}</h3>
                <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginTop: '3px' }}>معرف الحساب: <code>{selectedCustomer.uid}</code></div>
              </div>
              <button onClick={() => setSelectedCustomer(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '20px' }}>
              <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>رقم الهاتف المسجل</div>
                <div style={{ fontSize: '13px', fontWeight: '800', color: '#fff', marginTop: '4px' }} dir="ltr">{selectedCustomer.phone}</div>
              </div>

              <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>رصيد المحفظة</div>
                <div style={{ fontSize: '14px', fontWeight: '800', color: '#34d399', marginTop: '4px' }}>{formatIqd(selectedCustomer.walletBalance)}</div>
              </div>

              <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>المدينة والموقع</div>
                <div style={{ fontSize: '13px', fontWeight: '700', color: '#fff', marginTop: '4px' }}> {selectedCustomer.city || 'القائم'}</div>
              </div>

              <div style={{ background: 'var(--bg-surface)', padding: '14px', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>تاريخ التسجيل</div>
                <div style={{ fontSize: '13px', fontWeight: '700', color: '#fff', marginTop: '4px' }}>{selectedCustomer.createdAt}</div>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '16px' }}>
              <div style={{ display: 'flex', gap: '10px' }}>
                <button
                  onClick={() => {
                    const c = selectedCustomer;
                    setSelectedCustomer(null);
                    handleOpenEdit(c);
                  }}
                  className="btn btn-primary"
                  style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  <Edit3 size={13} />
                  <span>تعديل البيانات والرصيد</span>
                </button>
                <button
                  onClick={() => handleToggleBlock(selectedCustomer)}
                  className={`btn ${selectedCustomer.isBlocked ? 'btn-secondary' : 'btn-danger'}`}
                  style={{ fontSize: '12px' }}
                >
                  {selectedCustomer.isBlocked ? 'فك الحظر' : 'حظر العميل'}
                </button>
              </div>

              <button
                onClick={() => handleDeleteSingle(selectedCustomer)}
                style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
              >
                <Trash2 size={14} /> حذف الحساب
              </button>
            </div>

          </div>
        </div>
      )}

      {/* ─── EDIT CUSTOMER & WALLET MODAL ─── */}
      {editingCustomer && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '520px', width: '100%', borderRadius: '24px', border: '1px solid rgba(251, 191, 36, 0.4)', boxShadow: '0 20px 60px rgba(0,0,0,0.7)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Edit3 size={18} color="#fbbf24" />
                <h3 style={{ fontSize: '17px', fontWeight: '800', color: '#fff', margin: 0 }}>
                  تعديل بيانات ورصيد العميل: {editingCustomer.name}
                </h3>
              </div>
              <button onClick={() => setEditingCustomer(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}>
                
              </button>
            </div>

            <form onSubmit={handleSaveCustomer} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                  اسم العميل:
                </label>
                <input
                  type="text"
                  required
                  value={editName}
                  onChange={e => setEditName(e.target.value)}
                  style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
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
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    المدينة / المنطقة:
                  </label>
                  <input
                    type="text"
                    value={editCity}
                    onChange={e => setEditCity(e.target.value)}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                  البريد الإلكتروني (اختياري):
                </label>
                <input
                  type="email"
                  value={editEmail}
                  onChange={e => setEditEmail(e.target.value)}
                  style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                />
              </div>

              {/* Wallet Balance Adjuster */}
              <div style={{ background: '#0f172a', padding: '14px', borderRadius: '12px', border: '1px solid rgba(52, 211, 153, 0.3)' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '800', color: '#34d399', marginBottom: '6px' }}>
                  رصيد المحفظة المالي (د.ع):
                </label>
                <input
                  type="number"
                  step="500"
                  value={editWalletBalance}
                  onChange={e => setEditWalletBalance(Number(e.target.value))}
                  style={{ width: '100%', padding: '10px 12px', background: '#070d18', border: '1px solid #34d399', borderRadius: '8px', color: '#34d399', fontSize: '14px', fontWeight: '800', outline: 'none' }}
                />
                <div style={{ fontSize: '10.5px', color: 'var(--text-dim)', marginTop: '4px' }}>
                  يمكنك شحن رصيد إضافي للعميل كتعويض أو رصيد ترويجي مباشرة من هنا.
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', marginTop: '12px' }}>
                <button
                  type="submit"
                  disabled={actionLoadingId === editingCustomer.uid}
                  className="btn btn-primary"
                  style={{ flex: 1, padding: '12px', fontSize: '13px', fontWeight: '800' }}
                >
                  {actionLoadingId === editingCustomer.uid ? 'جاري الحفظ...' : 'حفظ وتحديث بيانات العميل'}
                </button>
                <button
                  type="button"
                  onClick={() => setEditingCustomer(null)}
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
