import React, { useState, useEffect } from 'react';
import { 
  Search, 
  ShieldCheck, 
  Bell, 
  Volume2, 
  VolumeX, 
  User, 
  LogOut, 
  Activity, 
  Key, 
  Sparkles,
  Command
} from 'lucide-react';
import { useAuth } from '../../application/AuthContext';
import { AudioAlertService } from '../../infrastructure/services/AudioAlertService';

export const Topbar: React.FC<{ 
  onOpenCommandPalette: () => void;
  onOpenCredentialsModal?: () => void;
}> = ({ onOpenCommandPalette, onOpenCredentialsModal }) => {
  const { user, logout } = useAuth();
  const [isHealthy, setIsHealthy] = useState(true);
  const [isMuted, setIsMuted] = useState(AudioAlertService.getMuteState());

  useEffect(() => {
    const handleOnline = () => setIsHealthy(true);
    const handleOffline = () => setIsHealthy(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const handleToggleAudio = () => {
    const nextState = AudioAlertService.toggleMute();
    setIsMuted(nextState);
    if (!nextState) {
      AudioAlertService.playNewOrderChime();
    }
  };

  return (
    <header className="no-print" style={{ height: '70px', background: 'var(--bg-secondary)', borderBottom: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 28px', gap: '20px' }}>
      {/* Global Command & Search */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, maxWidth: '480px' }}>
        <div
          onClick={onOpenCommandPalette}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border-color)',
            borderRadius: '12px',
            padding: '8px 16px',
            width: '100%',
            cursor: 'pointer',
            color: 'var(--text-muted)',
            fontSize: '13px',
            transition: 'all 0.2s ease'
          }}
          onMouseEnter={(e) => (e.currentTarget.style.borderColor = 'var(--border-highlight)')}
          onMouseLeave={(e) => (e.currentTarget.style.borderColor = 'var(--border-color)')}
        >
          <Search size={16} color="#00BFA5" />
          <span>بحث سريع، أمر إداري، سائق، رحلة، أو معرف Trace...</span>
          <span style={{ marginRight: 'auto', fontSize: '11px', background: 'rgba(0, 191, 165, 0.1)', color: '#00BFA5', padding: '2px 8px', borderRadius: '6px', fontFamily: 'monospace', fontWeight: '700' }}>
            Ctrl + K
          </span>
        </div>
      </div>

      {/* System Indicators, Audio, & Profile */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
        
        {/* Audio Alerts Toggle */}
        <button
          onClick={handleToggleAudio}
          className="btn btn-secondary"
          style={{
            padding: '7px 12px',
            fontSize: '12px',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            color: isMuted ? 'var(--text-dim)' : '#00BFA5',
            borderColor: isMuted ? 'var(--border-color)' : 'rgba(0, 191, 165, 0.4)',
            background: isMuted ? 'transparent' : 'rgba(0, 191, 165, 0.08)'
          }}
          title={isMuted ? 'الصوت مكتوم - اضغط للتفعيل' : 'تنبيهات الصوت مفعلة للطلبات الجديدة'}
        >
          {isMuted ? <VolumeX size={15} color="#64748B" /> : <Volume2 size={15} color="#00BFA5" />}
          <span style={{ fontSize: '11.5px', fontWeight: '700' }}>
            {isMuted ? 'تنبيهات مكتومة' : 'رنين مباشر'}
          </span>
        </button>

        {/* Realtime Engine Status */}
        <div 
          style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '8px', 
            padding: '6px 12px', 
            borderRadius: '10px', 
            background: isHealthy ? 'rgba(16, 185, 129, 0.08)' : 'rgba(239, 68, 68, 0.08)', 
            border: `1px solid ${isHealthy ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}` 
          }}
        >
          <span 
            style={{ 
              width: '8px', 
              height: '8px', 
              borderRadius: '50%', 
              background: isHealthy ? '#10B981' : '#EF4444', 
              boxShadow: `0 0 10px ${isHealthy ? '#10B981' : '#EF4444'}` 
            }} 
          />
          <span style={{ fontSize: '12px', fontWeight: '700', color: isHealthy ? '#34D399' : '#F87171' }}>
            {isHealthy ? 'النواة متصلة ' : 'انقطاع الشبكة'}
          </span>
        </div>

        {/* Quick Credentials & Password Reset Tool */}
        {onOpenCredentialsModal && (
          <button
            onClick={onOpenCredentialsModal}
            className="btn btn-secondary"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '6px 12px',
              fontSize: '12px',
              fontWeight: '800',
              color: '#FBBF24',
              borderColor: 'rgba(245, 158, 11, 0.35)',
              background: 'rgba(245, 158, 11, 0.08)'
            }}
            title="تغيير رمز أو كلمة مرور أي حساب أو بريد إلكتروني في قاعدة البيانات"
          >
            <Key size={14} color="#FBBF24" />
            <span>تغيير الرموز</span>
          </button>
        )}

        {/* Profile Card & Logout */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', paddingRight: '12px', borderRight: '1px solid var(--border-color)' }}>
          <div style={{ textAlign: 'left' }}>
            <div style={{ fontSize: '12.5px', fontWeight: '800', color: '#fff' }}>
              {user?.name || 'المشرف العام'}
            </div>
            <div style={{ fontSize: '10.5px', color: '#00BFA5', fontWeight: '700' }}>
              {user?.role === 'super_admin' ? 'SuperAdmin ' : (user?.email || user?.role || '')}
            </div>
          </div>

          <button
            onClick={logout}
            className="btn btn-secondary"
            style={{ padding: '6px 10px', color: '#F87171', border: '1px solid rgba(239, 68, 68, 0.25)' }}
            title="تسجيل الخروج"
          >
            <LogOut size={15} />
          </button>
        </div>

      </div>
    </header>
  );
};
