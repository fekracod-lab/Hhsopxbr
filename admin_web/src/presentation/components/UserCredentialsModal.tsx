import React, { useState, useEffect, useMemo } from 'react';
import {
  Key,
  Search,
  Check,
  Copy,
  Eye,
  EyeOff,
  Sparkles,
  ShieldCheck,
  Loader2,
  Mail,
  Phone,
  User,
  X,
  RefreshCw,
  Sliders,
  CheckCircle2
} from 'lucide-react';
import { 
  UserCredentialsRepository, 
  DatabaseAccount 
} from '../../infrastructure/repositories/UserCredentialsRepository';
import { useAuth } from '../../application/AuthContext';

interface Props {
  isOpen: boolean;
  onClose: () => void;
  preselectedEmail?: string;
}

export const UserCredentialsModal: React.FC<Props> = ({ isOpen, onClose, preselectedEmail }) => {
  const { user: currentAdmin } = useAuth();
  const [accounts, setAccounts] = useState<DatabaseAccount[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Search & Selected Account
  const [searchQuery, setSearchQuery] = useState(preselectedEmail || '');
  const [selectedAccount, setSelectedAccount] = useState<DatabaseAccount | null>(null);
  const [filterRole, setFilterRole] = useState<'all' | 'admin' | 'restaurant' | 'store' | 'driver' | 'user'>('all');

  // Form Fields
  const [newEmail, setNewEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [showPassword, setShowPassword] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [copied, setCopied] = useState(false);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // Subscribe to all accounts in DB
  useEffect(() => {
    if (!isOpen) return;
    setIsLoading(true);
    const unsubscribe = UserCredentialsRepository.subscribeToAllAccounts((data) => {
      setAccounts(data);
      setIsLoading(false);

      if (preselectedEmail) {
        const found = data.find(a => a.email.toLowerCase() === preselectedEmail.toLowerCase());
        if (found) {
          handleSelectAccount(found);
        }
      }
    });

    return () => unsubscribe();
  }, [isOpen, preselectedEmail]);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const handleSelectAccount = (acc: DatabaseAccount) => {
    setSelectedAccount(acc);
    setNewEmail(acc.email);
    setNewPassword('');
  };

  // Generate strong random password
  const handleGeneratePassword = () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%';
    let pass = 'Madar@';
    for (let i = 0; i < 4; i++) {
      pass += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setNewPassword(pass);
  };

  // Copy credentials to clipboard
  const handleCopyCredentials = () => {
    if (!selectedAccount || !newPassword) return;
    const text = `بيانات تسجيل الدخول لتطبيق مدار:
البريد الإلكتروني: ${newEmail || selectedAccount.email}
كلمة المرور: ${newPassword}`;

    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
    showToast('تم نسخ بيانات الدخول إلى الحافظة بنجاح ');
  };

  // Submit Password Change
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedAccount || !newPassword.trim()) {
      showToast('يرجى اختيار حساب وإدخال كلمة المرور الجديدة', 'error');
      return;
    }

    if (newPassword.trim().length < 4) {
      showToast('كلمة المرور يجب أن تكون 4 أحرف أو أرقام على الأقل', 'error');
      return;
    }

    setIsSubmitting(true);
    try {
      await UserCredentialsRepository.updateAccountPassword({
        account: selectedAccount,
        newPassword: newPassword.trim(),
        newEmail: newEmail.trim() || undefined,
        adminEmail: currentAdmin?.email || 'SuperAdmin'
      });

      showToast(`تم تغيير رمز حساب (${selectedAccount.name}) بنجاح `);
      setTimeout(() => {
        onClose();
      }, 1200);
    } catch (err: any) {
      showToast('فشل تغيير كلمة المرور: ' + (err.message || ''), 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Filter accounts by search query & role
  const filteredAccounts = useMemo(() => {
    return accounts.filter((acc) => {
      if (filterRole !== 'all' && acc.role !== filterRole) return false;
      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;
      return (
        acc.name.toLowerCase().includes(q) ||
        acc.email.toLowerCase().includes(q) ||
        acc.phone.includes(q)
      );
    });
  }, [accounts, filterRole, searchQuery]);

  if (!isOpen) return null;

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(6px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
      
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 11000, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      <div className="glass-panel" style={{ padding: '26px', maxWidth: '780px', width: '100%', borderRadius: '24px', border: '1px solid rgba(245, 158, 11, 0.4)', display: 'flex', flexDirection: 'column', gap: '16px', maxHeight: '90vh', overflow: 'hidden' }}>
        
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '12px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <Key size={22} />
            </div>
            <div>
              <h3 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', margin: 0 }}>
                تغيير رمز وكلمة مرور أي حساب في قاعدة البيانات
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', margin: '2px 0 0' }}>
                ابحث عن أي بريد إلكتروني، مطعم، كابتن، أو مستخدم وقم بتعيين رمزه الجديد فوراً
              </p>
            </div>
          </div>
          <button onClick={onClose} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px', padding: '4px' }}></button>
        </div>

        {/* ─── DUAL COLUMN: ACCOUNT SEARCH & SELECTION (LEFT) & PASSWORD FORM (RIGHT) ─── */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', overflow: 'hidden', flex: 1, minHeight: 0 }}>
          
          {/* LEFT: Search & Pick Email / Account */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', overflow: 'hidden' }}>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <Search size={15} color="#94a3b8" style={{ position: 'absolute', right: '10px' }} />
              <input
                type="text"
                placeholder="ابحث بالبريد الإلكتروني أو الاسم أو الهاتف..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{ width: '100%', padding: '8px 32px 8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '10px', color: '#fff', fontSize: '12.5px', outline: 'none' }}
              />
            </div>

            {/* Role Filter Chips */}
            <div style={{ display: 'flex', gap: '4px', overflowX: 'auto', paddingBottom: '2px' }}>
              <button onClick={() => setFilterRole('all')} className={`btn ${filterRole === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '10.5px', padding: '3px 7px' }}>الكل ({accounts.length})</button>
              <button onClick={() => setFilterRole('restaurant')} className={`btn ${filterRole === 'restaurant' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '10.5px', padding: '3px 7px', color: '#fbbf24' }}>المطاعم</button>
              <button onClick={() => setFilterRole('store')} className={`btn ${filterRole === 'store' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '10.5px', padding: '3px 7px', color: '#38bdf8' }}>المتاجر</button>
              <button onClick={() => setFilterRole('driver')} className={`btn ${filterRole === 'driver' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '10.5px', padding: '3px 7px', color: '#34d399' }}>الكباتن</button>
              <button onClick={() => setFilterRole('admin')} className={`btn ${filterRole === 'admin' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '10.5px', padding: '3px 7px', color: '#c084fc' }}>المشرفين</button>
            </div>

            {/* Accounts List (Scrollable) */}
            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '6px', paddingRight: '2px' }}>
              {isLoading ? (
                <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <Loader2 size={20} color="#f59e0b" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 6px' }} />
                  <div style={{ fontSize: '12px' }}>جاري تحميل حسابات قاعدة البيانات...</div>
                </div>
              ) : filteredAccounts.length === 0 ? (
                <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <Mail size={24} color="#64748b" style={{ margin: '0 auto 6px' }} />
                  <div style={{ fontSize: '12.5px', color: '#fff', fontWeight: '700' }}>لا يوجد حساب مطابق</div>
                </div>
              ) : (
                filteredAccounts.map((acc) => {
                  const isSelected = selectedAccount?.id === acc.id && selectedAccount?.sourceCollection === acc.sourceCollection;
                  return (
                    <div
                      key={`${acc.sourceCollection}_${acc.id}`}
                      onClick={() => handleSelectAccount(acc)}
                      style={{
                        padding: '9px 12px',
                        borderRadius: '10px',
                        background: isSelected ? 'linear-gradient(135deg, rgba(245, 158, 11, 0.2), rgba(217, 119, 6, 0.2))' : 'rgba(255, 255, 255, 0.02)',
                        border: isSelected ? '1px solid #f59e0b' : '1px solid rgba(255, 255, 255, 0.05)',
                        cursor: 'pointer',
                        transition: 'all 0.15s ease',
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '2px'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{acc.name}</span>
                        <span style={{ fontSize: '10px', padding: '1px 6px', borderRadius: '6px', background: 'rgba(255,255,255,0.06)', color: '#fbbf24' }}>
                          {acc.roleArabic}
                        </span>
                      </div>
                      
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11.5px', color: '#38bdf8' }} dir="ltr">
                        <Mail size={11} />
                        <span>{acc.email || 'بدون بريد مسجل'}</span>
                      </div>

                      {acc.phone && acc.phone !== '-' && (
                        <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">
                           {acc.phone}
                        </div>
                      )}
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* RIGHT: Selected Account Password Change Form */}
          <div style={{ background: 'rgba(15, 23, 42, 0.7)', border: '1px solid var(--border-color)', borderRadius: '16px', padding: '18px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            
            {selectedAccount ? (
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                
                {/* Selected Account Summary Banner */}
                <div style={{ padding: '10px 14px', background: 'rgba(245, 158, 11, 0.1)', border: '1px solid rgba(245, 158, 11, 0.3)', borderRadius: '12px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontWeight: '900', color: '#fff', fontSize: '14px' }}>{selectedAccount.name}</div>
                    <span style={{ fontSize: '11px', color: '#fbbf24', fontWeight: '800' }}>{selectedAccount.roleArabic}</span>
                  </div>
                  <div style={{ fontSize: '11.5px', color: '#38bdf8', marginTop: '2px' }} dir="ltr">
                    {selectedAccount.email || 'لا يوجد بريد مسجل حالياً'}
                  </div>
                  {selectedAccount.currentPasswordHint && (
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>
                      الرمز الحالي المسجل: <span style={{ color: '#34d399', fontWeight: '700' }}>{selectedAccount.currentPasswordHint}</span>
                    </div>
                  )}
                </div>

                {/* Optional Email Edit */}
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>البريد الإلكتروني للـ Login:</label>
                  <input
                    type="email"
                    dir="ltr"
                    value={newEmail}
                    onChange={e => setNewEmail(e.target.value)}
                    placeholder="account@madar.iq"
                    style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                  />
                </div>

                {/* New Password Input */}
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                    <label style={{ fontSize: '12px', color: '#fbbf24', fontWeight: '800' }}>كلمة المرور / الرمز الجديد:</label>
                    <button
                      type="button"
                      onClick={handleGeneratePassword}
                      style={{ background: 'transparent', border: 'none', color: '#38bdf8', fontSize: '11px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '3px', fontWeight: '700' }}
                    >
                      <Sparkles size={12} /> توليد رمز قوي
                    </button>
                  </div>

                  <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      dir="ltr"
                      value={newPassword}
                      onChange={e => setNewPassword(e.target.value)}
                      placeholder="أدخل الرمز الجديد..."
                      style={{ width: '100%', padding: '10px 40px 10px 12px', background: '#0f172a', border: '1px solid #f59e0b', borderRadius: '8px', color: '#fbbf24', fontSize: '14px', fontWeight: '800' }}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      style={{ position: 'absolute', right: '10px', background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}
                    >
                      {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                {/* Quick Copy Credentials Button */}
                {newPassword && (
                  <button
                    type="button"
                    onClick={handleCopyCredentials}
                    className="btn btn-secondary"
                    style={{ fontSize: '11.5px', padding: '6px 12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', color: copied ? '#34d399' : '#38bdf8' }}
                  >
                    {copied ? <CheckCircle2 size={13} /> : <Copy size={13} />}
                    <span>{copied ? 'تم نسخ البيانات بنجاح!' : 'نسخ البريد والرمز للحافظة '}</span>
                  </button>
                )}

                {/* Submit Action */}
                <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '10px' }}>
                  <button
                    type="submit"
                    disabled={isSubmitting || !newPassword.trim()}
                    className="btn btn-primary"
                    style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '6px' }}
                  >
                    {isSubmitting ? <Loader2 size={15} style={{ animation: 'spin 1s linear infinite' }} /> : <Key size={15} />}
                    <span>حفظ وتعيين الرمز </span>
                  </button>
                </div>

              </form>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Key size={38} color="#64748b" style={{ marginBottom: '10px' }} />
                <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff' }}>اختر حساباً أو بريداً من القائمة</div>
                <div style={{ fontSize: '12px', marginTop: '4px' }}>لتعديل كلمة المرور أو تحديث البريد الإلكتروني</div>
              </div>
            )}

          </div>

        </div>

      </div>

    </div>
  );
};
