import React, { useState, useEffect, useMemo } from 'react';
import {
  Wallet,
  TrendingUp,
  ArrowDownLeft,
  ArrowUpRight,
  ShieldCheck,
  AlertTriangle,
  RefreshCw,
  Lock,
  CheckCircle,
  FileSpreadsheet,
  Loader2,
  Plus,
  Search,
  Download,
  Coins,
  DollarSign,
  User,
  Car,
  Store,
  X
} from 'lucide-react';
import { useLiveDashboard } from '../../infrastructure/useLiveDashboard';
import { OrdersRepository, AdminOrderRecord } from '../../infrastructure/repositories/OrdersRepository';
import { FinanceRepository, WalletTransactionRecord } from '../../infrastructure/repositories/FinanceRepository';
import { DriversRepository } from '../../infrastructure/repositories/DriversRepository';
import { DriverEntity } from '../../domain/types';

export const FinanceModule: React.FC = () => {
  const { metrics } = useLiveDashboard();
  const [orders, setOrders] = useState<AdminOrderRecord[]>([]);
  const [transactions, setTransactions] = useState<WalletTransactionRecord[]>([]);
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'transactions' | 'orders_revenue' | 'drivers_settlement'>('transactions');
  const [searchQuery, setSearchQuery] = useState('');

  // Top-Up Modal State
  const [showTopUpModal, setShowTopUpModal] = useState(false);
  const [targetRole, setTargetRole] = useState<'driver' | 'customer' | 'merchant'>('driver');
  const [targetId, setTargetId] = useState('');
  const [targetName, setTargetName] = useState('');
  const [targetPhone, setTargetPhone] = useState('');
  const [amountIqd, setAmountIqd] = useState<number>(10000);
  const [operationType, setOperationType] = useState<'deposit' | 'bonus' | 'penalty'>('deposit');
  const [reason, setReason] = useState('شحن رصيد نقدي من الإدارة');

  // Clear Debt Modal State
  const [showClearDebtModal, setShowClearDebtModal] = useState(false);
  const [selectedDriverForDebt, setSelectedDriverForDebt] = useState<DriverEntity | null>(null);

  // Toast
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    setIsLoading(true);
    const unsubOrders = OrdersRepository.subscribeToAllOrders((data) => {
      setOrders(data);
    });

    const unsubTxs = FinanceRepository.subscribeToTransactions((data) => {
      setTransactions(data);
      setIsLoading(false);
    });

    const unsubDrivers = DriversRepository.subscribeToDrivers((data) => {
      setDrivers(data);
    });

    return () => {
      unsubOrders();
      unsubTxs();
      unsubDrivers();
    };
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
    const totalDriverDebt = drivers.reduce((sum, d) => sum + (d.appDebt || 0), 0);
    const totalDriverWallets = drivers.reduce((sum, d) => sum + (d.walletBalance || 0), 0);

    return {
      totalDriverDebt,
      totalDriverWallets
    };
  }, [drivers]);

  // Handle Submit Top Up
  const handleTopUpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!targetId.trim() || !targetName.trim() || amountIqd <= 0) {
      showToast('يرجى إكمال جميع الحقول المطلوبة', 'error');
      return;
    }

    setActionLoading(true);
    try {
      await FinanceRepository.adjustWalletBalance({
        targetId: targetId.trim(),
        targetName: targetName.trim(),
        targetPhone: targetPhone.trim(),
        targetRole,
        operationType,
        amountIqd: Number(amountIqd),
        reason: reason.trim()
      });

      showToast(`تم تنفيذ حركة المحفظة لـ (${targetName}) بمبلغ ${formatIqd(amountIqd)} بنجاح `);
      setShowTopUpModal(false);
      setTargetId('');
      setTargetName('');
      setTargetPhone('');
      setAmountIqd(10000);
    } catch (err: any) {
      showToast('فشل تعديل المحفظة: ' + (err.message || ''), 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // Handle Clear Debt
  const handleConfirmClearDebt = async () => {
    if (!selectedDriverForDebt) return;
    setActionLoading(true);
    try {
      await FinanceRepository.clearDriverDebt(
        selectedDriverForDebt.driverId,
        selectedDriverForDebt.name,
        'تصفير وتسوية يدوية مستلمة نقداً من الكابتن في المكتب'
      );
      showToast(`تم تصفير وتسوية ديون الكابتن (${selectedDriverForDebt.name}) بنجاح `);
      setSelectedDriverForDebt(null);
    } catch (err: any) {
      showToast('فشل تصفير الديون: ' + (err.message || ''), 'error');
    } finally {
      setActionLoading(false);
    }
  };

  // Export CSV
  const handleExportCSV = () => {
    if (transactions.length === 0) {
      showToast('لا توجد معاملات لتصديرها', 'error');
      return;
    }
    const headers = ['المعرف', 'المستفيد', 'الدور', 'نوع الحركة', 'المبلغ بالدينار', 'الرصيد السابق', 'الرصيد الجديد', 'السبب والملاحظات', 'التاريخ والوقت'];
    const rows = transactions.map(t => [
      `"${t.id}"`,
      `"${t.targetName.replace(/"/g, '""')}"`,
      `"${t.targetRole === 'driver' ? 'كابتن' : (t.targetRole === 'merchant' ? 'متجر' : 'عميل')}"`,
      `"${t.operationType}"`,
      t.amountIqd,
      t.previousBalanceIqd,
      t.newBalanceIqd,
      `"${t.reason.replace(/"/g, '""')}"`,
      `"${t.createdAt}"`
    ]);

    const csvContent = '\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `madar_finance_ledger_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير سجل الحركات المالية بنجاح ');
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
            <div style={{ padding: '8px', borderRadius: '10px', background: 'linear-gradient(135deg, #059669, #10b981)' }}>
              <Wallet size={22} color="#fff" />
            </div>
            مركز الرقابة المالية والمحافظ والتسويات (Financial Control Plane)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            مراقبة المحافظ، الشحن والتسوية اليدوية، تصفير ديون الكباتن، وتدقيق العمولات بالدينار العراقي
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button
            onClick={handleExportCSV}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px' }}
          >
            <Download size={15} /> تصدير السجل CSV
          </button>
          <button
            onClick={() => setShowTopUpModal(true)}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', background: 'linear-gradient(135deg, #059669, #10b981)', borderColor: '#34d399', fontWeight: '800' }}
          >
            <Plus size={16} /> شحن وتعديل محفظة 
          </button>
        </div>
      </div>

      {/* 4 Financial Health & Invariants Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>إجمالي حجم التداول المباشر (GMV)</div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#fff' }}>
            {formatIqd(metrics.totalVolumeIqd + metrics.totalRidesVolumeIqd)}
          </div>
          <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '4px' }}>
            عبر {metrics.totalOrders + metrics.totalRides} عملية موثقة في المنظومة
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>صافي عمولة مدار المحصلة</div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#34d399' }}>
            {formatIqd(metrics.platformCommissionIqd)}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
            اقتطاع فوري وآمن من العمليات
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>ديون الكباتن المستحقة للتطبيق</div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#f87171' }}>
            {formatIqd(stats.totalDriverDebt)}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
            عمولات كاش مستحقة القبض من الكباتن
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>أرصدة محافظ الكباتن</div>
          <div style={{ fontSize: '22px', fontWeight: '900', color: '#fbbf24' }}>
            {formatIqd(stats.totalDriverWallets)}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
            أرصدة إيجابية مسبقة الدفع
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="glass-panel" style={{ padding: '12px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            onClick={() => setActiveTab('transactions')}
            className={`btn ${activeTab === 'transactions' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', padding: '7px 16px' }}
          >
            سجل الحركات والشحن الإداري ({transactions.length})
          </button>
          <button
            onClick={() => setActiveTab('drivers_settlement')}
            className={`btn ${activeTab === 'drivers_settlement' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', padding: '7px 16px' }}
          >
            تسوية وتصفير ديون الكباتن ({drivers.filter(d => (d.appDebt || 0) > 0).length})
          </button>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'rgba(255, 255, 255, 0.05)', padding: '6px 12px', borderRadius: '8px', border: '1px solid rgba(255, 255, 255, 0.1)', minWidth: '260px' }}>
          <Search size={14} color="#94a3b8" />
          <input
            type="text"
            placeholder="ابحث بالاسم، المعرف، أو البيان..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{ background: 'transparent', border: 'none', color: '#fff', fontSize: '12.5px', width: '100%', outline: 'none' }}
          />
        </div>

      </div>

      {/* Tab 1: Transactions Table */}
      {activeTab === 'transactions' && (
        <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
          {isLoading ? (
            <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Loader2 size={30} color="#10b981" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 10px' }} />
              <div>جاري جلب سجل المعاملات المالية من Firestore...</div>
            </div>
          ) : transactions.length === 0 ? (
            <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Wallet size={36} color="#64748b" style={{ margin: '0 auto 10px' }} />
              <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>لا توجد حركات شحن وتعديل يدوي حتى الآن</div>
              <div style={{ fontSize: '12px', marginTop: '4px' }}>اضغط على "شحن وتعديل محفظة" لتنفيذ أول تسوية مالية</div>
            </div>
          ) : (
            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>المستفيد</th>
                    <th>الدور</th>
                    <th>نوع العملية</th>
                    <th>المبلغ بالدينار</th>
                    <th>الرصيد السابق</th>
                    <th>الرصيد الجديد</th>
                    <th>السبب والملاحظات</th>
                    <th>التاريخ والوقت</th>
                    <th>المسؤول</th>
                  </tr>
                </thead>
                <tbody>
                  {transactions
                    .filter(t => !searchQuery.trim() || t.targetName.toLowerCase().includes(searchQuery.toLowerCase()) || t.reason.toLowerCase().includes(searchQuery.toLowerCase()))
                    .map(t => (
                    <tr key={t.id}>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{t.targetName}</div>
                        {t.targetPhone && <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{t.targetPhone}</div>}
                      </td>
                      <td>
                        <span className={`badge ${t.targetRole === 'driver' ? 'badge-info' : (t.targetRole === 'merchant' ? 'badge-warning' : 'badge-primary')}`} style={{ fontSize: '11px' }}>
                          {t.targetRole === 'driver' ? 'كابتن ' : (t.targetRole === 'merchant' ? 'متجر ' : 'زبون ')}
                        </span>
                      </td>
                      <td>
                        <span className={`badge ${t.operationType === 'deposit' ? 'badge-success' : (t.operationType === 'bonus' ? 'badge-primary' : (t.operationType === 'debt_cleared' ? 'badge-info' : 'badge-danger'))}`} style={{ fontSize: '11px' }}>
                          {t.operationType === 'deposit' ? 'إيداع وشحن ' : (t.operationType === 'bonus' ? 'مكافأة ' : (t.operationType === 'debt_cleared' ? 'تصفير ديون ' : 'خصم/غرامة '))}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '900', color: t.operationType === 'penalty' ? '#f87171' : '#34d399', fontSize: '13px' }}>
                          {t.operationType === 'penalty' ? '-' : '+'}{formatIqd(t.amountIqd)}
                        </div>
                      </td>
                      <td style={{ fontSize: '12px', color: '#cbd5e1' }}>{formatIqd(t.previousBalanceIqd)}</td>
                      <td style={{ fontSize: '12.5px', fontWeight: '800', color: '#38bdf8' }}>{formatIqd(t.newBalanceIqd)}</td>
                      <td style={{ fontSize: '12px', color: '#e2e8f0' }}>{t.reason}</td>
                      <td style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>{t.createdAt}</td>
                      <td style={{ fontSize: '11.5px', color: '#94a3b8' }}>{t.adminEmail}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Tab 2: Drivers Debt Settlement */}
      {activeTab === 'drivers_settlement' && (
        <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>اسم الكابتن</th>
                  <th>رقم الهاتف</th>
                  <th>نوع المركبة</th>
                  <th>الديون المستحقة للتطبيق</th>
                  <th>رصيد المحفظة</th>
                  <th style={{ textAlign: 'center' }}>الإجراء المالي</th>
                </tr>
              </thead>
              <tbody>
                {drivers
                  .filter(d => (d.appDebt || 0) > 0)
                  .map(d => (
                    <tr key={d.driverId}>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{d.name}</div>
                        <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>ID: <code>{d.driverId.substring(0, 8)}</code></div>
                      </td>
                      <td>
                        <a href={`tel:${d.phoneNumber}`} style={{ color: '#38bdf8', textDecoration: 'none', fontSize: '12.5px', direction: 'ltr' }}>
                          {d.phoneNumber}
                        </a>
                      </td>
                      <td>
                        <span className={`badge ${d.vehicleCategory === 'motorcycle' ? 'badge-warning' : 'badge-info'}`} style={{ fontSize: '11px' }}>
                          {d.vehicleCategory === 'motorcycle' ? 'دراجة ' : 'سيارة '}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '900', color: '#f87171', fontSize: '14px' }}>
                          {formatIqd(d.appDebt || 0)}
                        </div>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: (d.walletBalance || 0) >= 0 ? '#34d399' : '#f87171', fontSize: '13px' }}>
                          {formatIqd(d.walletBalance || 0)}
                        </div>
                      </td>
                      <td style={{ textAlign: 'center' }}>
                        <button
                          onClick={() => setSelectedDriverForDebt(d)}
                          className="btn btn-primary"
                          style={{ fontSize: '11.5px', padding: '6px 12px', background: '#059669', borderColor: '#10b981', fontWeight: '800' }}
                        >
                          تصفير وتسوية الديون 
                        </button>
                      </td>
                    </tr>
                  ))}
                {drivers.filter(d => (d.appDebt || 0) > 0).length === 0 && (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '40px', color: '#34d399', fontWeight: '700' }}>
                       جميع حسابات الكباتن مسواة ولا توجد ديون معلقة حالياً!
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODAL: MANUAL WALLET TOP-UP */}
      {/* ========================================================================= */}
      {showTopUpModal && (
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
            maxWidth: '520px',
            borderRadius: '20px',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '16px',
            border: '1px solid rgba(16, 185, 129, 0.4)',
            boxShadow: '0 25px 70px rgba(0,0,0,0.8)'
          }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255, 255, 255, 0.1)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Wallet size={20} color="#34d399" />
                <h3 style={{ margin: 0, color: '#fff', fontSize: '17px', fontWeight: '800' }}>
                  شحن وتعديل محفظة يدوياً
                </h3>
              </div>
              <button
                onClick={() => setShowTopUpModal(false)}
                style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleTopUpSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              {/* Target Role */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                  الفئة المستفيدة:
                </label>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '8px' }}>
                  {[
                    { id: 'driver', label: 'كابتن / مندوب ' },
                    { id: 'customer', label: 'زبون / راكب ' },
                    { id: 'merchant', label: 'متجر / مطعم ' },
                  ].map(r => (
                    <button
                      key={r.id}
                      type="button"
                      onClick={() => setTargetRole(r.id as any)}
                      className={`btn ${targetRole === r.id ? 'btn-primary' : 'btn-secondary'}`}
                      style={{ fontSize: '11.5px', padding: '8px 4px', textAlign: 'center' }}
                    >
                      {r.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Target ID / Quick select from drivers if driver */}
              {targetRole === 'driver' && drivers.length > 0 ? (
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    اختر الكابتن:
                  </label>
                  <select
                    value={targetId}
                    onChange={e => {
                      const selected = drivers.find(d => d.driverId === e.target.value);
                      if (selected) {
                        setTargetId(selected.driverId);
                        setTargetName(selected.name);
                        setTargetPhone(selected.phoneNumber);
                      } else {
                        setTargetId(e.target.value);
                      }
                    }}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  >
                    <option value="">-- اختر الكابتن من الأسطول --</option>
                    {drivers.map(d => (
                      <option key={d.driverId} value={d.driverId}>
                        {d.name} ({d.phoneNumber}) - رصيد: {d.walletBalance || 0} د.ع
                      </option>
                    ))}
                  </select>
                </div>
              ) : (
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      معرف الحساب (User / Target ID):
                    </label>
                    <input
                      type="text"
                      required
                      value={targetId}
                      onChange={e => setTargetId(e.target.value)}
                      placeholder="معرف Firestore"
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                      اسم المستفيد:
                    </label>
                    <input
                      type="text"
                      required
                      value={targetName}
                      onChange={e => setTargetName(e.target.value)}
                      placeholder="الاسم الكامل"
                      style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                    />
                  </div>
                </div>
              )}

              {/* Amount & Operation Type */}
              <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: '#34d399', marginBottom: '6px' }}>
                    المبلغ بالدينار العراقي (IQD):
                  </label>
                  <input
                    type="number"
                    required
                    step="1000"
                    min="1000"
                    value={amountIqd}
                    onChange={e => setAmountIqd(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid #10b981', borderRadius: '8px', color: '#34d399', fontSize: '15px', fontWeight: '900', outline: 'none' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    نوع الحركة:
                  </label>
                  <select
                    value={operationType}
                    onChange={e => setOperationType(e.target.value as any)}
                    style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                  >
                    <option value="deposit">إيداع وشحن نقدي </option>
                    <option value="bonus">مكافأة / تعويض </option>
                    <option value="penalty">خصم / استقطاع </option>
                  </select>
                </div>
              </div>

              {/* Reason */}
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>
                  سبب الحركة وملاحظات التوثيق:
                </label>
                <input
                  type="text"
                  required
                  value={reason}
                  onChange={e => setReason(e.target.value)}
                  placeholder="مثال: استلام نقد باليد من الكابتن / شحن محفظة"
                  style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                <button
                  type="submit"
                  disabled={actionLoading}
                  className="btn btn-primary"
                  style={{ flex: 1, padding: '12px', background: 'linear-gradient(135deg, #059669, #10b981)', borderColor: '#34d399', fontWeight: '800', fontSize: '13px' }}
                >
                  {actionLoading ? 'جاري التنفيذ والتسجيل...' : 'تأكيد وحفظ الحركة المالية في Firestore '}
                </button>
                <button
                  type="button"
                  onClick={() => setShowTopUpModal(false)}
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

      {/* ========================================================================= */}
      {/* MODAL: CONFIRM CLEAR DRIVER DEBT */}
      {/* ========================================================================= */}
      {selectedDriverForDebt && (
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
          padding: '20px'
        }}>
          <div className="glass-panel" style={{
            width: '100%',
            maxWidth: '460px',
            borderRadius: '20px',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '16px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#34d399' }}>
              <CheckCircle size={24} />
              <h3 style={{ margin: 0, fontSize: '17px', fontWeight: '800', color: '#fff' }}>
                تأكيد استلام وتصفير ديون الكابتن
              </h3>
            </div>

            <p style={{ fontSize: '13.5px', color: '#cbd5e1', margin: 0, lineHeight: 1.6 }}>
              هل تم استلام مبلغ الديون النقدية البالغة{' '}
              <strong style={{ color: '#f87171', fontSize: '16px' }}>{formatIqd(selectedDriverForDebt.appDebt || 0)}</strong>{' '}
              من الكابتن (<strong style={{ color: '#fff' }}>{selectedDriverForDebt.name}</strong>) وترغب بتصفير ديونه في قاعدة البيانات؟
            </p>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '10px' }}>
              <button
                onClick={() => setSelectedDriverForDebt(null)}
                className="btn btn-secondary"
                style={{ fontSize: '12.5px' }}
                disabled={actionLoading}
              >
                تراجع
              </button>
              <button
                onClick={handleConfirmClearDebt}
                className="btn btn-primary"
                style={{ fontSize: '12.5px', padding: '10px 18px', background: '#059669', borderColor: '#10b981', fontWeight: '800' }}
                disabled={actionLoading}
              >
                تأكيد استلام النقد وتصفير الديون 
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
