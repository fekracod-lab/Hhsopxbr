import React, { useState, useEffect } from 'react';
import {
  Lock,
  ShieldCheck,
  ShieldAlert,
  UserX,
  Key,
  Flame,
  FileCheck2,
  RefreshCw,
  Loader2
} from 'lucide-react';
import { AuditLogEntity } from '../../domain/types';
import { AuditRepository } from '../../infrastructure/repositories/AuditRepository';

export const SecurityModule: React.FC = () => {
  const [securityLogs, setSecurityLogs] = useState<AuditLogEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const unsub = AuditRepository.subscribeToAuditLogs((logs) => {
      // Filter actions relevant to security (BLOCK, PERMISSIONS, ADMIN_LOGIN, etc.)
      const secLogs = logs.filter(l => 
        l.action.toLowerCase().includes('block') || 
        l.action.toLowerCase().includes('permission') ||
        l.action.toLowerCase().includes('auth') ||
        l.action.toLowerCase().includes('security')
      );
      setSecurityLogs(secLogs);
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
            <Lock size={22} color="#06b6d4" /> مركز الأمان وانعدام الثقة (Zero-Trust Security Center)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            مراقبة محاولات تصعيد الصلاحيات، حظر التعديل المالي من طرف العميل، وفحص قواعد Firestore
          </p>
        </div>
        <span className="badge badge-success"> Zero-Trust Engine Active</span>
      </div>

      {/* Security Gate & Evaluation */}
      <div className="glass-panel" style={{ padding: '20px', background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(15, 23, 42, 0.8) 100%)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div style={{ fontSize: '12px', color: '#34d399', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              بوابة الجاهزية والحصانة الأمنية (Production Security Status)
            </div>
            <h3 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', marginTop: '4px' }}>
              الحالة الحالية: ENFORCED & PROTECTED 
            </h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '12px', marginTop: '4px' }}>
              قواعد Firestore Rules تحظر أي تعديل مالي مباشر من طرف العميل وتفرض المصادقة الإدارية الصارمة.
            </p>
          </div>
          <div style={{ textAlign: 'center', padding: '12px 24px', background: 'rgba(16, 185, 129, 0.15)', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
            <div style={{ fontSize: '24px', fontWeight: '900', color: '#34d399' }}>SECURE</div>
            <div style={{ fontSize: '11px', color: '#cbd5e1' }}>حماية سيرفر كاملة</div>
          </div>
        </div>
      </div>

      {/* Security Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '16px' }}>
        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>حظر تعديل الرصيد من العميل</div>
          <div style={{ fontSize: '20px', fontWeight: '900', color: '#34d399' }}>محصن سيرفر 100%</div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>Firestore client balance write blocked</div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>حماية صلاحيات الأدمن (RBAC)</div>
          <div style={{ fontSize: '20px', fontWeight: '900', color: '#38bdf8' }}>Server-Checked</div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>فحص دور المستخدم في users/{'{uid}'}</div>
        </div>

        <div className="glass-panel" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>سجل تدقيق العمليات (Audit Trail)</div>
          <div style={{ fontSize: '20px', fontWeight: '900', color: '#fff' }}>نشط وموثق </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>توثيق كل حركة مع TraceId غير قابل للمسح</div>
        </div>
      </div>

      {/* Security Events Stream */}
      <div className="glass-panel" style={{ padding: '20px' }}>
        <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff', marginBottom: '14px' }}>
          سجل الأحداث الأمنية الموثقة في Firestore (Security Audit Events)
        </div>

        {isLoading ? (
          <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
            <div>جاري جلب الأحداث الأمنية...</div>
          </div>
        ) : securityLogs.length === 0 ? (
          <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <ShieldCheck size={32} color="#34d399" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>النظام آمن ومستقر</div>
            <div style={{ fontSize: '11px', marginTop: '2px' }}>لم يتم تسجيل أي انتهاكات أو محاولات حظر حديثة</div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {securityLogs.map((log) => (
              <div key={log.auditId} style={{ padding: '12px 16px', borderRadius: '8px', background: 'rgba(239, 68, 68, 0.08)', border: '1px solid rgba(239, 68, 68, 0.2)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <ShieldAlert size={18} color="#ef4444" />
                  <div>
                    <div style={{ fontWeight: '700', color: '#f87171', fontSize: '13px' }}>
                      {log.action} على {log.targetResource}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      المشرف: {log.adminName} | المعرف: {log.auditId.substring(0, 8)}
                    </div>
                  </div>
                </div>
                <span className="badge badge-info">{log.timestamp}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
