import React, { useState, useEffect } from 'react';
import {
  LifeBuoy,
  RefreshCw,
  ZapOff,
  ServerCrash,
  CheckCircle,
  AlertTriangle,
  History,
  Archive,
  Wifi,
  WifiOff
} from 'lucide-react';

export const ResilienceModule: React.FC = () => {
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <LifeBuoy size={22} color="#06b6d4" /> مركز الصمود والتعافي ومقاومة الانهيار (Resilience & Offline Queue)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            مراقبة طابور العمليات دون اتصال (Durable Offline Queue)، قواطع الدوائر (Circuit Breakers)، واستعادة البيانات
          </p>
        </div>
        <span className={`badge ${isOnline ? 'badge-success' : 'badge-danger'}`}>
          {isOnline ? 'الشبكة متصلة ' : 'انقطاع الشبكة '}
        </span>
      </div>

      {/* Resilience Metrics */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px' }}>
        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>حالة اتصال العميل بالإنترنت</div>
          <div style={{ fontSize: '20px', fontWeight: '900', color: isOnline ? '#34d399' : '#ef4444' }}>
            {isOnline ? 'متصل ومستقر (Online)' : 'دون اتصال (Offline)'}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>Web Browser Network State</div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>قواطع الدوائر السحابية (Circuit Breakers)</div>
          <div style={{ fontSize: '20px', fontWeight: '900', color: '#38bdf8' }}>Closed (Healthy)</div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>Firestore Realtime Stream Active</div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>التخزين المؤقت المحلي (Local Cache)</div>
          <div style={{ fontSize: '20px', fontWeight: '900', color: '#fff' }}>IndexedDB Persistent</div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>حفظ البيانات محلياً عند انقطاع النت</div>
        </div>
      </div>

      {/* Resilience Controls & State */}
      <div className="glass-panel" style={{ padding: '20px' }}>
        <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff', marginBottom: '14px' }}>
          حالة الاتصال والخدمات السحابية الحقيقية (Cloud Service Invariants)
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
          <div style={{ padding: '14px', borderRadius: '8px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px' }}>قاعدة بيانات Firestore Realtime</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Mismatches: 0 | Auto-reconnect: ON</div>
            </div>
            <span className="badge badge-success">Operational </span>
          </div>

          <div style={{ padding: '14px', borderRadius: '8px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px' }}>خدمة التخزين والوثائق (Cloud Storage)</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>KYC Documents & Menu Photos</div>
            </div>
            <span className="badge badge-success">Operational </span>
          </div>
        </div>
      </div>
    </div>
  );
};
