import { collection, addDoc, serverTimestamp, query, orderBy, limit, onSnapshot } from 'firebase/firestore';
import { db, auth } from '../firebase';
import { AuditLogEntity } from '../../domain/types';

export class AuditRepository {
  /**
   * Log a critical administrative action to Firestore `admin_audit_logs`
   */
  static async logAction(
    actionOrParams: string | { action: string; targetResource: string; targetId?: string; payload?: Record<string, any> },
    targetResource?: string,
    targetId?: string,
    payload?: Record<string, any>
  ): Promise<void> {
    try {
      const currentUser = auth.currentUser;
      const traceId = 'trc_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 7);

      let action: string;
      let resource: string;
      let id: string;
      let extraPayload: Record<string, any> | undefined;

      if (typeof actionOrParams === 'object') {
        action = actionOrParams.action;
        resource = actionOrParams.targetResource;
        id = actionOrParams.targetId || actionOrParams.targetResource;
        extraPayload = actionOrParams.payload;
      } else {
        action = actionOrParams;
        resource = targetResource || '';
        id = targetId || resource;
        extraPayload = payload;
      }

      const logData = {
        action,
        targetResource: resource,
        targetId: id,
        adminUid: currentUser?.uid || 'anonymous_admin',
        adminEmail: currentUser?.email || '',
        timestamp: serverTimestamp(),
        createdAtClient: new Date().toISOString(),
        platform: 'admin_web_react',
        traceId,
        payload: extraPayload || {}
      };

      await addDoc(collection(db, 'admin_audit_logs'), logData);
    } catch (err) {
      console.warn(' [AuditRepository] Failed to write audit log:', err);
    }
  }

  /**
   * Stream realtime audit logs for the AuditModule
   */
  static subscribeToAuditLogs(
    callback: (logs: AuditLogEntity[]) => void,
    maxLimit = 50
  ): () => void {
    const q = query(
      collection(db, 'admin_audit_logs'),
      orderBy('timestamp', 'desc'),
      limit(maxLimit)
    );

    return onSnapshot(
      q,
      (snapshot) => {
        const logs: AuditLogEntity[] = snapshot.docs.map((doc) => {
          const data = doc.data();
          return {
            auditId: doc.id,
            adminUid: data.adminUid || 'unknown',
            adminName: data.adminEmail || data.adminName || 'مشرف النظام',
            adminRole: data.adminRole || 'admin',
            action: data.action || 'Unknown Action',
            targetResource: data.targetResource ? `${data.targetResource} (${data.targetId || ''})` : (data.targetId || ''),
            timestamp: data.timestamp?.toDate ? data.timestamp.toDate().toLocaleString('ar-IQ') : (data.createdAtClient || 'الآن'),
            payload: data.payload,
            integrityHash: data.traceId
          };
        });
        callback(logs);
      },
      (err) => {
        console.warn('Audit logs listener error:', err.message);
        callback([]);
      }
    );
  }
}
