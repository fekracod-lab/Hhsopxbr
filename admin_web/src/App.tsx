import React, { useState } from 'react';
import { Sidebar } from './presentation/components/Sidebar';
import { Topbar } from './presentation/components/Topbar';
import { CommandPaletteModal } from './presentation/components/CommandPaletteModal';
import { DashboardModule } from './presentation/modules/DashboardModule';
import { OperationsModule } from './presentation/modules/OperationsModule';
import { DriversModule } from './presentation/modules/DriversModule';
import { MerchantsModule } from './presentation/modules/MerchantsModule';
import { RestaurantsModule } from './presentation/modules/RestaurantsModule';
import { StoresModule } from './presentation/modules/StoresModule';
import { OrdersModule } from './presentation/modules/OrdersModule';
import { FinanceModule } from './presentation/modules/FinanceModule';
import { RiskFraudModule } from './presentation/modules/RiskFraudModule';
import { ObservabilityModule } from './presentation/modules/ObservabilityModule';
import { ResilienceModule } from './presentation/modules/ResilienceModule';
import { SecurityModule } from './presentation/modules/SecurityModule';
import { AuditModule } from './presentation/modules/AuditModule';
import { GovernanceModule } from './presentation/modules/GovernanceModule';
import { CustomersModule } from './presentation/modules/CustomersModule';
import { BroadcastNotificationsModule } from './presentation/modules/BroadcastNotificationsModule';
import { ComplaintsSupportModule } from './presentation/modules/ComplaintsSupportModule';
import { LiveSupportChatModule } from './presentation/modules/LiveSupportChatModule';
import { RegistrationRequestsModule } from './presentation/modules/RegistrationRequestsModule';
import { CouponsModule } from './presentation/modules/CouponsModule';
import { TaxiRidesModule } from './presentation/modules/TaxiRidesModule';
import { ReportsModule } from './presentation/modules/ReportsModule';
import { RewardsModule } from './presentation/modules/RewardsModule';
import { UserCredentialsModal } from './presentation/components/UserCredentialsModal';
import { AuthProvider, useAuth } from './application/AuthContext';
import { Lock, Mail, AlertCircle, Eye, EyeOff, ShieldCheck, Loader2 } from 'lucide-react';

const AdminLoginForm: React.FC = () => {
  const [isRegisterMode, setIsRegisterMode] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const { loginWithEmail, registerAdminAccount, isLoading, error, clearError } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    clearError();

    if (isRegisterMode && !name.trim()) {
      setFormError('يرجى إدخال اسم المسؤول الكامل');
      return;
    }
    if (!email.trim()) {
      setFormError('يرجى إدخال البريد الإلكتروني للمسؤول');
      return;
    }
    if (!password) {
      setFormError('يرجى إدخال كلمة المرور');
      return;
    }

    try {
      if (isRegisterMode) {
        await registerAdminAccount(email, password, name);
      } else {
        await loginWithEmail(email, password);
      }
    } catch (err: any) {
      // Error is handled in AuthContext
    }
  };

  return (
    <div style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'radial-gradient(circle at 50% 40%, #0d1e22 0%, #070B12 100%)', padding: '20px' }}>
      <div className="glass-panel" style={{ padding: '40px', maxWidth: '440px', width: '100%', borderRadius: '24px', border: '1px solid rgba(0, 191, 165, 0.3)', boxShadow: '0 25px 60px rgba(0, 0, 0, 0.6)' }}>
        
        {/* Brand Icon */}
        <div style={{ width: '72px', height: '72px', borderRadius: '20px', background: 'linear-gradient(135deg, #00BFA5 0%, #00897B 100%)', padding: '3px', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', boxShadow: '0 8px 28px rgba(0, 191, 165, 0.4)' }}>
          <img 
            src="/imges/app_icon.png" 
            alt="Madar Logo" 
            style={{ width: '100%', height: '100%', borderRadius: '17px', objectFit: 'cover' }}
            onError={(e) => {
              (e.target as HTMLElement).style.display = 'none';
            }}
          />
        </div>

        <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', textAlign: 'center', marginBottom: '6px' }}>
          {isRegisterMode ? 'تهيئة حساب المشرف الرئيسي (SuperAdmin)' : 'بوابة تحكم المشرفين — مـدار'}
        </h2>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', textAlign: 'center', marginBottom: '28px' }}>
          MADAR Enterprise Control Plane • Firebase Production
        </p>

        {/* Error Alert */}
        {(error || formError) && (
          <div style={{ background: 'rgba(239, 68, 68, 0.12)', border: '1px solid rgba(239, 68, 68, 0.3)', padding: '12px 14px', borderRadius: '12px', color: '#f87171', fontSize: '12.5px', display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <AlertCircle size={18} style={{ flexShrink: 0 }} />
              <span>{error || formError}</span>
            </div>
            {error === 'هذا الحساب ليس لديه صلاحيات وصول للوحة الإدارة.' && !isRegisterMode && (
              <button
                type="button"
                onClick={() => {
                  setIsRegisterMode(true);
                  clearError();
                }}
                style={{
                  background: 'rgba(0, 191, 165, 0.2)',
                  border: '1px solid #00BFA5',
                  color: '#00BFA5',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  fontSize: '12px',
                  fontWeight: '700',
                  cursor: 'pointer',
                  marginTop: '4px',
                  textAlign: 'center'
                }}
              >
                هل أنت صاحب هذا الحساب وتريد إدارته؟ اضغط هنا لترقيته إلى مشرف رئيسي (SuperAdmin)
              </button>
            )}
          </div>
        )}

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
          
          {/* Name Field (for register mode) */}
          {isRegisterMode && (
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '8px' }}>
                اسم المسؤول الكامل
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="المهندس عمر (SuperAdmin)"
                disabled={isLoading}
                style={{ width: '100%', padding: '12px 14px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '12px', color: '#fff', fontSize: '14px', outline: 'none' }}
              />
            </div>
          )}

          {/* Email Field */}
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '8px' }}>
              البريد الإلكتروني للإدارة
            </label>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <Mail size={18} color="#94a3b8" style={{ position: 'absolute', right: '14px' }} />
              <input
                type="email"
                dir="ltr"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@example.com"
                disabled={isLoading}
                style={{ width: '100%', padding: '12px 42px 12px 14px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '12px', color: '#fff', fontSize: '14px', outline: 'none' }}
              />
            </div>
          </div>

          {/* Password Field */}
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '8px' }}>
              كلمة المرور
            </label>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <Lock size={18} color="#94a3b8" style={{ position: 'absolute', right: '14px' }} />
              <input
                type={showPassword ? 'text' : 'password'}
                dir="ltr"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••••"
                disabled={isLoading}
                style={{ width: '100%', padding: '12px 42px 12px 42px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '12px', color: '#fff', fontSize: '14px', outline: 'none' }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{ position: 'absolute', left: '14px', background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: 0 }}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={isLoading}
            className="btn btn-primary"
            style={{ width: '100%', padding: '14px', fontSize: '15px', fontWeight: '800', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', marginTop: '10px' }}
          >
            {isLoading ? (
              <>
                <Loader2 size={18} style={{ animation: 'spin 1s linear infinite' }} />
                <span>{isRegisterMode ? 'جاري إنشاء الحساب...' : 'جاري التحقق من الصلاحيات...'}</span>
              </>
            ) : (
              <>
                <ShieldCheck size={18} />
                <span>{isRegisterMode ? 'إنشاء حساب المشرف وتفعيل الصلاحيات' : 'تسجيل الدخول الآمن'}</span>
              </>
            )}
          </button>
        </form>

        {/* Toggle Mode Button */}
        <div style={{ textAlign: 'center', marginTop: '20px' }}>
          <button
            type="button"
            onClick={() => {
              setIsRegisterMode(!isRegisterMode);
              setFormError(null);
              clearError();
            }}
            style={{ background: 'transparent', border: 'none', color: '#06b6d4', fontSize: '12.5px', cursor: 'pointer', textDecoration: 'underline' }}
          >
            {isRegisterMode 
              ? 'لديك حساب بالفعل؟ العودة لتسجيل الدخول' 
              : 'أول مرة تسجل؟ اضغط هنا لتهيئة حساب المشرف الرئيسي (SuperAdmin)'}
          </button>
        </div>

        <div style={{ textAlign: 'center', marginTop: '18px', fontSize: '11px', color: 'var(--text-dim)' }}>
           محمي بتشفير TLS ومصادقة Firebase Authoritative Guard
        </div>
      </div>
    </div>
  );
};

const AdminContent: React.FC = () => {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false);
  const [isCredentialsModalOpen, setIsCredentialsModalOpen] = useState(false);
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-primary)', flexDirection: 'column', gap: '16px' }}>
        <Loader2 size={36} color="#06b6d4" style={{ animation: 'spin 1s linear infinite' }} />
        <div style={{ color: 'var(--text-muted)', fontSize: '14px', fontWeight: '600' }}>
          جاري فحص جلسة المشرف وقاعدة البيانات...
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <AdminLoginForm />;
  }

  const renderModule = () => {
    switch (activeTab) {
      case 'dashboard':
        return <DashboardModule onNavigate={(mod) => setActiveTab(mod)} />;
      case 'operations':
        return <OperationsModule />;
      case 'registration_requests':
        return <RegistrationRequestsModule />;
      case 'taxi_captains':
        return <DriversModule initialVehicleCategory="taxi" pageTitle="إدارة كباتن التكسي (سيارات نقل الركاب )" />;
      case 'delivery_couriers':
        return <DriversModule initialVehicleCategory="motorcycle" pageTitle="إدارة مندوبي ودراجات التوصيل (المطاعم والمتاجر ومرسال )" />;
      case 'drivers':
        return <DriversModule initialVehicleCategory="all" />;
      case 'customers':
        return <CustomersModule />;
      case 'restaurants':
        return <RestaurantsModule />;
      case 'stores':
        return <StoresModule />;
      case 'merchants':
        return <MerchantsModule />;
      case 'rewards':
        return <RewardsModule />;
      case 'orders':
      case 'delivery':
      case 'health':
        return <OrdersModule />;
      case 'rides':
      case 'taxi':
        return <TaxiRidesModule />;
      case 'coupons':
        return <CouponsModule />;
      case 'reports':
        return <ReportsModule />;
      case 'finance':
        return <FinanceModule />;
      case 'risk':
        return <RiskFraudModule />;
      case 'observability':
        return <ObservabilityModule />;
      case 'resilience':
        return <ResilienceModule />;
      case 'security':
        return <SecurityModule />;
      case 'audit':
        return <AuditModule />;
      case 'notifications':
      case 'broadcast':
        return <BroadcastNotificationsModule />;
      case 'live_support':
      case 'support':
      case 'chat':
        return <LiveSupportChatModule />;
      case 'complaints':
        return <ComplaintsSupportModule />;
      case 'regions':
      case 'pricing':
      case 'feature_flags':
      case 'settings':
      case 'admin_users':
        return <GovernanceModule initialSection={activeTab as any} />;
      default:
        return <DashboardModule onNavigate={(mod) => setActiveTab(mod)} />;
    }
  };

  return (
    <div style={{ display: 'flex', width: '100vw', height: '100vh', overflow: 'hidden', background: 'var(--bg-primary)' }}>
      {/* Central Sidebar */}
      <Sidebar activeTab={activeTab} onSelectTab={setActiveTab} />

      {/* Main App Layout */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
        <Topbar 
          onOpenCommandPalette={() => setIsCommandPaletteOpen(true)} 
          onOpenCredentialsModal={() => setIsCredentialsModalOpen(true)}
        />
        
        {/* Dynamic Module Content Viewport */}
        <main style={{ flex: 1, overflowY: 'auto', padding: '28px', position: 'relative' }}>
          {renderModule()}
        </main>
      </div>

      {/* Quick Jump Command Palette */}
      <CommandPaletteModal
        isOpen={isCommandPaletteOpen}
        onClose={() => setIsCommandPaletteOpen(false)}
        onSelect={setActiveTab}
      />

      {/* Universal Account Password & Credentials Manager */}
      <UserCredentialsModal
        isOpen={isCredentialsModalOpen}
        onClose={() => setIsCredentialsModalOpen(false)}
      />
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <AdminContent />
    </AuthProvider>
  );
};

export default App;
