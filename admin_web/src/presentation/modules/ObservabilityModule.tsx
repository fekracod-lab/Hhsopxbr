import React, { useState, useEffect } from 'react';
import {
  Activity,
  Layers,
  Clock,
  CheckCircle2,
  AlertCircle,
  Search,
  Database,
  Loader2
} from 'lucide-react';
import { AuditRepository } from '../../infrastructure/repositories/AuditRepository';
import { AuditLogEntity } from '../../domain/types';

export const ObservabilityModule: React.FC = () => {
  const [searchTrace, setSearchTrace] = useState('');
  const [logs, setLogs] = useState<AuditLogEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const unsub = AuditRepository.subscribeToAuditLogs((data) => {
      setLogs(data);
      setIsLoading(false);
    });

    return () => unsub();
  }, []);

  const filteredLogs = logs.filter(l => 
    l.action.toLowerCase().includes(searchTrace.toLowerCase()) ||
    (l.integrityHash && l.integrityHash.toLowerCase().includes(searchTrace.toLowerCase())) ||
    l.targetResource.toLowerCase().includes(searchTrace.toLowerCase())
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Activity size={22} color="#06b6d4" /> مركز المراقبة والرصد والتتبع الموزع (Observability & APM)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            تتبع سلاسل العمليات من أول طلب وحتى إتمام الرحلة والتسوية (TraceId / SpanId / CorrelationId)
          </p>
        </div>
        <span className="badge badge-success">APM Telemetry: Active</span>
      </div>

      {/* Trace Search Filter */}
      <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <Search size={16} color="#94a3b8" />
        <input
          type="text"
          placeholder="ابحث بواسطة Trace ID، اسم الإجراء، أو المعرف المستهدف..."
          value={searchTrace}
          onChange={e => setSearchTrace(e.target.value)}
          style={{
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: '#fff',
            fontSize: '13px',
            width: '100%'
          }}
        />
      </div>

      {/* Distributed Traces List */}
      <div className="glass-panel" style={{ padding: '20px' }}>
        <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff', marginBottom: '14px' }}>
          سجل التتبع الموزع للعمليات الحية (Live Distributed Traces)
        </div>

        {isLoading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
            <div>جاري جلب إشارات التتبع...</div>
          </div>
        ) : filteredLogs.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Activity size={32} color="#64748b" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: '14px', fontWeight: '700', color: '#fff' }}>ماكو سلاسل تتبع مسجلة حالياً</div>
            <div style={{ fontSize: '11px', marginTop: '2px' }}>يتم تسجيل كل عملية تلقائياً بمعرف TraceId موثق</div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {filteredLogs.map(trace => (
              <div
                key={trace.auditId}
                style={{
                  padding: '14px 18px',
                  borderRadius: '8px',
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border-color)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between'
                }}
              >
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}>{trace.action}</span>
                    <code style={{ fontSize: '11px', color: '#38bdf8' }}>{trace.integrityHash || trace.auditId}</code>
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                    المستهدف: {trace.targetResource} | المنفذ: {trace.adminName}
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span className="badge badge-success">COMPLETED</span>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-dim)' }}>{trace.timestamp}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
