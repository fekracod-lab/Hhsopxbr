import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db, auth } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface BroadcastNotificationPayload {
  title: string;
  body: string;
  target: 'all' | 'drivers' | 'merchants' | 'customers' | 'specific_user';
  targetUserId?: string;
  data?: Record<string, string>;
}

export class NotificationRepository {
  /**
   * Send a broadcast or direct notification via Firestore event pipeline
   */
  static async sendBroadcastNotification(payload: BroadcastNotificationPayload): Promise<void> {
    const currentUser = auth.currentUser;

    const notificationDoc = {
      title: payload.title.trim(),
      body: payload.body.trim(),
      target: payload.target,
      targetUserId: payload.targetUserId || null,
      senderAdminUid: currentUser?.uid || 'admin',
      senderAdminEmail: currentUser?.email || '',
      createdAt: serverTimestamp(),
      status: 'queued',
      platform: 'admin_web_react',
      data: payload.data || { type: 'admin_broadcast' }
    };

    // Add to notifications collection
    await addDoc(collection(db, 'admin_broadcasts'), notificationDoc);

    // Also emit event to `events` collection for Flutter app notification listeners
    await addDoc(collection(db, 'events'), {
      type: payload.target === 'specific_user' ? 'user_notification' : 'broadcast_notification',
      payload: {
        user_id: payload.targetUserId,
        target_role: payload.target,
        title: payload.title,
        body: payload.body,
        data: payload.data || { type: 'admin_broadcast' }
      },
      createdAt: serverTimestamp()
    });

    await AuditRepository.logAction(
      'SEND_BROADCAST_NOTIFICATION',
      'notifications',
      payload.target,
      { title: payload.title, body: payload.body, target: payload.target }
    );
  }
}
