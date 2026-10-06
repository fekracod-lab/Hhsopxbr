import { 
  collection, 
  query, 
  orderBy, 
  limit, 
  onSnapshot, 
  doc, 
  setDoc,
  updateDoc,
  addDoc,
  serverTimestamp,
  getDoc
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface SupportChatMessage {
  id: string;
  text: string;
  senderId: string;
  senderName?: string;
  isAdmin: boolean;
  timestamp: string;
  createdTimestamp: number;
}

export interface SupportChatSession {
  id: string; // usually userId
  userId: string;
  userName: string;
  userPhone: string;
  userRole: 'user' | 'driver' | 'merchant' | 'captain' | 'customer';
  roleArabic: string;
  lastMessage: string;
  lastMessageTime: string;
  lastMessageTimestamp: number;
  unreadByAdminCount: number;
  unreadByUserCount: number;
  isOnline?: boolean;
}

export class SupportChatRepository {
  /**
   * Subscribe to all active support chat sessions
   */
  static subscribeToChatSessions(callback: (sessions: SupportChatSession[]) => void): () => void {
    const q = query(
      collection(db, 'support_chats'),
      limit(100)
    );

    return onSnapshot(
      q,
      (snapshot) => {
        const list: SupportChatSession[] = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          
          let lastTimeStr = 'الآن';
          let lastTs = Date.now();
          if (data.lastMessageTime) {
            if (data.lastMessageTime.toDate) {
              const d = data.lastMessageTime.toDate();
              lastTimeStr = d.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
              lastTs = d.getTime();
            } else if (typeof data.lastMessageTime === 'string') {
              const d = new Date(data.lastMessageTime);
              if (!isNaN(d.getTime())) {
                lastTimeStr = d.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
                lastTs = d.getTime();
              }
            }
          }

          const rawRole = (data.userRole || data.role || 'user').toLowerCase();
          let roleArabic = ' زبون / مستخدم';
          if (rawRole.includes('driver') || rawRole.includes('captain') || rawRole.includes('كابتن')) {
            roleArabic = ' كابتن تكسي / مندوب';
          } else if (rawRole.includes('merchant') || rawRole.includes('store') || rawRole.includes('restaurant') || rawRole.includes('متجر') || rawRole.includes('مطعم')) {
            roleArabic = ' صاحب متجر / مطعم';
          }

          return {
            id: docSnap.id,
            userId: data.userId || docSnap.id,
            userName: data.userName || data.name || 'مستخدم مدار',
            userPhone: data.userPhone || data.phone || '-',
            userRole: rawRole as any,
            roleArabic,
            lastMessage: data.lastMessage || 'بدأ المحادثة مع الدعم الفني',
            lastMessageTime: lastTimeStr,
            lastMessageTimestamp: lastTs,
            unreadByAdminCount: Number(data.unreadByAdminCount || 0),
            unreadByUserCount: Number(data.unreadByUserCount || 0),
            isOnline: data.isOnline === true
          };
        });

        // Sort latest messages first
        list.sort((a, b) => b.lastMessageTimestamp - a.lastMessageTimestamp);
        callback(list);
      },
      (err) => {
        console.warn('Support chats stream note:', err.message);
        callback([]);
      }
    );
  }

  /**
   * Subscribe to messages of a specific support chat room
   */
  static subscribeToMessages(chatId: string, callback: (messages: SupportChatMessage[]) => void): () => void {
    const messagesCol = collection(db, 'support_chats', chatId, 'messages');
    const q = query(messagesCol, limit(200));

    return onSnapshot(
      q,
      (snapshot) => {
        const list: SupportChatMessage[] = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          let timeStr = 'الآن';
          let ts = Date.now();

          if (data.timestamp) {
            if (data.timestamp.toDate) {
              const d = data.timestamp.toDate();
              timeStr = d.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
              ts = d.getTime();
            } else if (typeof data.timestamp === 'string') {
              const d = new Date(data.timestamp);
              if (!isNaN(d.getTime())) {
                timeStr = d.toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' });
                ts = d.getTime();
              }
            }
          }

          const sId = (data.senderId || '').toLowerCase();
          const isAdmin = sId.includes('admin') || sId === 'support' || sId === 'madar_support' || data.isAdmin === true;

          return {
            id: docSnap.id,
            text: data.text || data.message || '',
            senderId: data.senderId || 'user',
            senderName: data.senderName,
            isAdmin,
            timestamp: timeStr,
            createdTimestamp: ts
          };
        });

        // Sort chronologically (oldest first for chat flow)
        list.sort((a, b) => a.createdTimestamp - b.createdTimestamp);
        callback(list);
      },
      (err) => {
        console.warn(`Chat messages stream error for ${chatId}:`, err.message);
        callback([]);
      }
    );
  }

  /**
   * Send message from Admin Support to user
   */
  static async sendAdminMessage(
    chatId: string, 
    text: string, 
    adminId = 'admin_support', 
    adminName = 'فريق الدعم الفني'
  ): Promise<void> {
    const chatDocRef = doc(db, 'support_chats', chatId);
    const messagesCol = collection(db, 'support_chats', chatId, 'messages');

    // 1. Add message to subcollection
    await addDoc(messagesCol, {
      text: text.trim(),
      senderId: adminId,
      senderName: adminName,
      isAdmin: true,
      timestamp: serverTimestamp()
    });

    // 2. Update parent chat room
    const snap = await getDoc(chatDocRef);
    let unreadUser = 0;
    if (snap.exists()) {
      unreadUser = Number(snap.data()?.unreadByUserCount || 0);
    }

    await setDoc(chatDocRef, {
      lastMessage: text.trim(),
      lastMessageTime: serverTimestamp(),
      unreadByAdminCount: 0,
      unreadByUserCount: unreadUser + 1
    }, { merge: true });

    try {
      await AuditRepository.logAction('SUPPORT_CHAT_REPLY', 'support_chats', chatId, { text });
    } catch (_) {}
  }

  /**
   * Mark chat room as read by admin
   */
  static async markChatAsRead(chatId: string): Promise<void> {
    const chatDocRef = doc(db, 'support_chats', chatId);
    await updateDoc(chatDocRef, {
      unreadByAdminCount: 0
    }).catch(() => {});
  }
}
