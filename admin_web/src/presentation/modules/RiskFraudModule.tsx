import React, { useState, useEffect } from 'react';
import {
  ShieldAlert,
  AlertTriangle,
  MapPin,
  Zap,
  Gauge,
  UserX,
  CheckCircle,
  Eye,
  Loader2,
  ShieldCheck
} from 'lucide-react';
import { DriversRepository } from '../../infrastructure/repositories/DriversRepository';
import { DriverEntity } from '../../domain/types';

export const RiskFraudModule: React.FC = () => {
  const [highRiskDrivers, setHighRiskDrivers] = useState<DriverEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const unsub = DriversRepository.subscribeToDrivers((allDrivers) => {
      // Find drivers with riskScore > 50 or isBlocked
      const risky = allDrivers.filter(d => d.riskScore > 50 || d.isBlocked);
      setHighRiskDrivers(risky);
      setIsLoading(false);
    });

    return () => unsub();
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <ShieldAlert size={22} color="#f59e0b" /> مركز الاستخبارات ومكافحة الاحتيال والمخاطر (Risk & Fraud Intelligence)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            تحليل أنماط السلوك المشبوه، تزييف الموقع الجغرافي (GPS Spoofing)، وقفل الحسابات العالية المخاطر
          </p>
        </div>
        <span className="badge badge-warning">المحرك يعمل في وضع الإنتاج التلقائي</span>
      </div>

      {/* Risk Metrics */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px' }}>
        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>حسابات محظورة أو عالية المخاطر</div>
          <div style={{ fontSize: '24px', fontWeight: '900', color: highRiskDrivers.length > 0 ? '#ef4444' : '#34d399' }}>
            {highRiskDrivers.length} حساب
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
            {highRiskDrivers.length > 0 ? 'تخضع للتقييد الإداري' : 'لا توجد حسابات مشبوهة'}
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>حماية انتقال الموقع الجغرافي</div>
          <div style={{ fontSize: '24px', fontWeight: '900', color: '#34d399' }}>Active </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>فحص سرعة التنقل ومنع القفز الوهمي</div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>حماية العمليات المكررة (Atomic Locks)</div>
          <div style={{ fontSize: '24px', fontWeight: '900', color: '#34d399' }}>Enforced </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>منع الخصم المزدوج أو التلاعب بالأرصدة</div>
        </div>
      </div>

      {/* Active Alerts List */}
      <div className="glass-panel" style={{ padding: '20px' }}>
        <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff', marginBottom: '14px' }}>
          قائمة الحسابات والمخاطر الميدانية المسجلة في Firestore (Active Risk Accounts)
        </div>

        {isLoading ? (
          <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
            <div>جاري فحص مؤشرات المخاطر...</div>
          </div>
        ) : highRiskDrivers.length === 0 ? (
          <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <ShieldCheck size={36} color="#34d399" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>ENGINE ACTIVE — NO RECORDED SIGNALS</div>
            <div style={{ fontSize: '11px', marginTop: '2px' }}>كافة الحسابات والكباتن ضمن المستويات الطبيعية للسلامة</div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {highRiskDrivers.map((d) => (
              <div key={d.driverId} style={{ padding: '14px 18px', borderRadius: '10px', background: 'rgba(239, 68, 68, 0.08)', border: '1px solid rgba(239, 68, 68, 0.25)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontWeight: '800', color: '#f87171', fontSize: '14px' }}>{d.name} ({d.vehicleModel})</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                    رقم الهاتف: {d.phoneNumber} | لوحة: {d.plateNumber} | مؤشر الخطر: {d.riskScore}
                  </div>
                </div>
                <span className="badge badge-danger">
                  {d.isBlocked ? 'محظور إدارياً' : 'مخاطر مرتفعة'}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
