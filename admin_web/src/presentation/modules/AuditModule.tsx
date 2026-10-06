import React, { useState, useEffect } from 'react';
import { Shield, Search, Terminal, CheckCircle2, AlertTriangle, FileText, Loader2 } from 'lucide-react';
import { AuditLogEntity } from '../../domain/types';
import { AuditRepository } from '../../infrastructure/repositories/AuditRepository';

export const AuditModule: React.FC = () => {
  const [logs, setLogs] = useState<AuditLogEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    setIsLoading(true);
    const unsubscribe = AuditRepository.subscribeToAuditLogs((data) => {
      setLogs(data);
      setIsLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const filteredLogs = logs.filter(log => 
    log.action.toLowerCase().includes(searchQuery.toLowerCase()) ||
    log.adminName.toLowerCase().includes(searchQuery.toLowerCase()) ||
    log.targetResource.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (log.integrityHash && log.integrityHash.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Shield size={22} color="#06b6d4" /> سجل التدقيق الإداري وسلسلة النزاهة (Audit Trail & Ledger)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            سجل غير قابل للتعديل لكافة العمليات الإدارية الحساسة، التوثيق، الحظر، وتغييرات التسعير
          </p>
        </div>
      </div>

      {/* Search Filter */}
      <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '10px' }}>
        <Search size={18} color="#94a3b8" />
        <input
          type="text"
          placeholder="ابحث بالإجراء، البريد، المورد، أو معرف Trace ID..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          style={{ background: 'transparent', border: 'none', color: '#fff', fontSize: '13px', width: '100%', outline: 'none' }}
        />
      </div>

      {/* Logs Table */}
      <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Loader2 size={32} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 12px' }} />
            <div>جاري جلب سجل التدقيق من Firestore...</div>
          </div>
        ) : filteredLogs.length === 0 ? (
          <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <FileText size={36} color="#64748b" style={{ margin: '0 auto 12px' }} />
            <div style={{ fontSize: '15px', fontWeight: '700', color: '#fff' }}>ماكو حركات إدارية مسجلة حالياً</div>
            <div style={{ fontSize: '12px', marginTop: '4px' }}>يتم تسجيل أي إجراء حظر أو توثيق أو تعديل فورياً هنا</div>
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>معرف التدقيق (Audit ID)</th>
                  <th>المشرف المنفذ</th>
                  <th>نوع الإجراء (Action)</th>
                  <th>المورد المستهدف</th>
                  <th>معرف التتبع (TraceId)</th>
                  <th>التوقيت</th>
                </tr>
              </thead>
              <tbody>
                {filteredLogs.map((log) => (
                  <tr key={log.auditId}>
                    <td>
                      <code style={{ color: '#38bdf8' }}>#{log.auditId.substring(0, 8)}</code>
                    </td>
                    <td>
                      <div style={{ fontWeight: '700', color: '#fff' }}>{log.adminName}</div>
                      <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>UID: {log.adminUid.substring(0, 8)}</div>
                    </td>
                    <td>
                      <span className="badge badge-info" style={{ fontFamily: 'monospace', fontSize: '11px' }}>
                        {log.action}
                      </span>
                    </td>
                    <td>
                      <div style={{ color: '#fff', fontSize: '12.5px' }}>{log.targetResource}</div>
                    </td>
                    <td>
                      <code style={{ color: '#34d399', fontSize: '11px' }}>{log.integrityHash || 'trc_verified'}</code>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{log.timestamp}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
