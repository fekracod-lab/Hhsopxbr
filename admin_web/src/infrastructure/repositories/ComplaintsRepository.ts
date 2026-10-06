import { 
  collection, 
  query, 
  orderBy, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc,
  addDoc,
  serverTimestamp,
  deleteDoc,
  getDocs
} from 'firebase/firestore';
import { db } from '../firebase';
import { AuditRepository } from './AuditRepository';

export interface SupportTicketEntity {
  id: string;
  sourceCollection: string;
  ticketNumber: string;
  title: string;
  description: string;
  type: 'complaint' | 'technical' | 'financial' | 'suggestion' | 'emergency';
  typeArabic: string;
  category: 'driver' | 'customer' | 'merchant' | 'system';
  categoryArabic: string;
  priority: 'urgent' | 'high' | 'medium' | 'low';
  priorityArabic: string;
  status: 'pending' | 'in_progress' | 'resolved' | 'rejected';
  statusArabic: string;
  
  // User info
  userId?: string;
  userName: string;
  userPhone: string;
  userAvatar?: string;
  userRole?: string;
  
  // Related entity (e.g. specific order or trip)
  relatedOrderId?: string;
  relatedRideId?: string;
  
  // Resolution & admin notes
  adminResponse?: string;
  assignedAdmin?: string;
  resolvedAt?: string;
  resolutionNotes?: string;
  compensationAmountIqd?: number;
  
  // Timestamps
  createdAt: string;
  createdTimestamp: number;
}

export class ComplaintsRepository {
  /**
   * Subscribe to all support tickets & complaints across collections
   */
  static subscribeToComplaints(callback: (tickets: SupportTicketEntity[]) => void): () => void {
    let complaintsList: SupportTicketEntity[] = [];
    let supportTicketsList: SupportTicketEntity[] = [];
    let contactList: SupportTicketEntity[] = [];

    const notify = () => {
      const combined = [...complaintsList, ...supportTicketsList, ...contactList];
      combined.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(combined);
    };

    const parseDate = (val: any) => {
      if (!val) return { str: 'الآن', ts: Date.now() };
      if (val.toDate) {
        const d = val.toDate();
        return { str: d.toLocaleString('ar-IQ'), ts: d.getTime() };
      }
      if (typeof val === 'string') {
        const d = new Date(val);
        if (!isNaN(d.getTime())) return { str: d.toLocaleString('ar-IQ'), ts: d.getTime() };
      }
      return { str: 'الآن', ts: Date.now() };
    };

    const mapPriority = (p?: string, desc?: string): { val: SupportTicketEntity['priority']; arabic: string } => {
      const lower = (p || '').toLowerCase();
      const text = (desc || '').toLowerCase();
      if (lower.includes('urgent') || text.includes('طوارئ') || text.includes('حادث') || text.includes('سرقة') || text.includes('احتيال')) {
        return { val: 'urgent', arabic: ' عاجلة جداً' };
      }
      if (lower.includes('high') || text.includes('مشكلة في الحساب') || text.includes('رصيد') || text.includes('فلوس')) {
        return { val: 'high', arabic: ' مرتفعة' };
      }
      if (lower.includes('low')) {
        return { val: 'low', arabic: ' منخفضة' };
      }
      return { val: 'medium', arabic: ' متوسطة' };
    };

    const mapCategory = (cat?: string, role?: string, userRole?: string): { val: SupportTicketEntity['category']; arabic: string } => {
      const c = (cat || '').toLowerCase();
      const r = (role || userRole || '').toLowerCase();
      if (c.includes('driver') || c.includes('captain') || r.includes('driver') || r.includes('كابتن') || r.includes('سائق')) {
        return { val: 'driver', arabic: ' كابتن / سائق' };
      }
      if (c.includes('merchant') || c.includes('restaurant') || c.includes('store') || r.includes('merchant') || r.includes('مطعم')) {
        return { val: 'merchant', arabic: ' متجر / مطعم' };
      }
      return { val: 'customer', arabic: ' زبون / راكب' };
    };

    const mapType = (t?: string): { val: SupportTicketEntity['type']; arabic: string } => {
      const typeLower = (t || '').toLowerCase();
      if (typeLower.includes('tech') || typeLower.includes('app') || typeLower.includes('تطبيق') || typeLower.includes('برمج')) {
        return { val: 'technical', arabic: ' خلل فني بالتطبيق' };
      }
      if (typeLower.includes('finan') || typeLower.includes('money') || typeLower.includes('wallet') || typeLower.includes('محفظ') || typeLower.includes('رصيد')) {
        return { val: 'financial', arabic: ' مشكلة مالية أو محفظة' };
      }
      if (typeLower.includes('sugg') || typeLower.includes('مقترح')) {
        return { val: 'suggestion', arabic: ' اقتراح تطوير' };
      }
      if (typeLower.includes('emerg') || typeLower.includes('طوارئ')) {
        return { val: 'emergency', arabic: ' بلاغ طارئ' };
      }
      return { val: 'complaint', arabic: ' شكوى على خدمة' };
    };

    const mapStatus = (s?: string): { val: SupportTicketEntity['status']; arabic: string } => {
      const statusLower = (s || '').toLowerCase();
      if (statusLower === 'resolved' || statusLower.includes('حل') || statusLower.includes('مكتمل')) {
        return { val: 'resolved', arabic: 'تم الحل بنجاح ' };
      }
      if (statusLower === 'in_progress' || statusLower.includes('معالج') || statusLower.includes('قيد')) {
        return { val: 'in_progress', arabic: 'جاري المعالجة ' };
      }
      if (statusLower === 'rejected' || statusLower.includes('مرفوض') || statusLower.includes('مغلق')) {
        return { val: 'rejected', arabic: 'مرفوضة / مغلقة ' };
      }
      return { val: 'pending', arabic: 'بانتظار المراجعة ' };
    };

    // 1. Listen to `complaints`
    const unsubComplaints = onSnapshot(
      collection(db, 'complaints'),
      (snapshot) => {
        complaintsList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { str, ts } = parseDate(data.createdAt || data.timestamp);
          const priorityObj = mapPriority(data.priority, data.description || data.message);
          const categoryObj = mapCategory(data.category, data.role, data.userRole);
          const typeObj = mapType(data.type);
          const statusObj = mapStatus(data.status);

          return {
            id: docSnap.id,
            sourceCollection: 'complaints',
            ticketNumber: data.ticketNumber || `TK-${docSnap.id.slice(0, 6).toUpperCase()}`,
            title: data.title || data.subject || 'بلاغ شكوى ودعم',
            description: data.description || data.message || data.body || '',
            type: typeObj.val,
            typeArabic: typeObj.arabic,
            category: categoryObj.val,
            categoryArabic: categoryObj.arabic,
            priority: priorityObj.val,
            priorityArabic: priorityObj.arabic,
            status: statusObj.val,
            statusArabic: statusObj.arabic,
            userId: data.userId || data.uid,
            userName: data.userName || data.name || data.customerName || 'مستخدم مدار',
            userPhone: data.userPhone || data.phone || data.customerPhone || 'غير مسجل',
            relatedOrderId: data.orderId || data.relatedOrderId,
            relatedRideId: data.rideId || data.relatedRideId,
            adminResponse: data.adminResponse || data.response,
            assignedAdmin: data.assignedAdmin,
            resolvedAt: data.resolvedAt,
            compensationAmountIqd: Number(data.compensationAmountIqd || 0),
            createdAt: str,
            createdTimestamp: ts
          };
        });
        notify();
      },
      (err) => console.warn('Complaints listener note:', err.message)
    );

    // 2. Listen to `support_tickets`
    const unsubSupport = onSnapshot(
      collection(db, 'support_tickets'),
      (snapshot) => {
        supportTicketsList = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          const { str, ts } = parseDate(data.createdAt || data.timestamp);
          const priorityObj = mapPriority(data.priority, data.description || data.message);
          const categoryObj = mapCategory(data.category, data.role, data.userRole);
          const typeObj = mapType(data.type);
          const statusObj = mapStatus(data.status);

          return {
            id: docSnap.id,
            sourceCollection: 'support_tickets',
            ticketNumber: data.ticketNumber || `ST-${docSnap.id.slice(0, 6).toUpperCase()}`,
            title: data.title || data.subject || 'تذكرة دعم فني',
            description: data.description || data.message || data.body || '',
            type: typeObj.val,
            typeArabic: typeObj.arabic,
            category: categoryObj.val,
            categoryArabic: categoryObj.arabic,
            priority: priorityObj.val,
            priorityArabic: priorityObj.arabic,
            status: statusObj.val,
            statusArabic: statusObj.arabic,
            userId: data.userId || data.uid,
            userName: data.userName || data.name || 'مستخدم',
            userPhone: data.userPhone || data.phone || 'غير مسجل',
            relatedOrderId: data.orderId,
            relatedRideId: data.rideId,
            adminResponse: data.adminResponse,
            assignedAdmin: data.assignedAdmin,
            resolvedAt: data.resolvedAt,
            compensationAmountIqd: Number(data.compensationAmountIqd || 0),
            createdAt: str,
            createdTimestamp: ts
          };
        });
        notify();
      },
      () => {}
    );

    return () => {
      unsubComplaints();
      unsubSupport();
    };
  }

  /**
   * Open a new support ticket manually
   */
  static async createTicket(ticket: {
    title: string;
    description: string;
    type: SupportTicketEntity['type'];
    category: SupportTicketEntity['category'];
    priority: SupportTicketEntity['priority'];
    userName: string;
    userPhone: string;
    userId?: string;
    relatedOrderId?: string;
    relatedRideId?: string;
  }): Promise<string> {
    const ticketNumber = `MD-${Math.floor(100000 + Math.random() * 900000)}`;
    const docRef = await addDoc(collection(db, 'support_tickets'), {
      ...ticket,
      ticketNumber,
      status: 'pending',
      createdAt: serverTimestamp(),
      createdTimestamp: Date.now()
    });

    try {
      await AuditRepository.logAction('CREATE_SUPPORT_TICKET', 'support_tickets', docRef.id, { ticketNumber, title: ticket.title });
    } catch (_) {}

    return docRef.id;
  }

  /**
   * Resolve or update ticket status with admin response
   */
  static async resolveComplaint(
    ticketId: string,
    sourceCollection: string,
    status: SupportTicketEntity['status'],
    adminResponse?: string,
    compensationAmountIqd?: number
  ): Promise<void> {
    const colName = sourceCollection || 'complaints';
    const ticketRef = doc(db, colName, ticketId);

    const updateData: any = {
      status,
      adminResponse: adminResponse || null,
      resolvedAt: new Date().toISOString(),
      updatedAt: serverTimestamp()
    };

    if (compensationAmountIqd && compensationAmountIqd > 0) {
      updateData.compensationAmountIqd = compensationAmountIqd;
    }

    await updateDoc(ticketRef, updateData);

    try {
      await AuditRepository.logAction(
        'RESOLVE_SUPPORT_TICKET',
        colName,
        ticketId,
        { status, adminResponse, compensationAmountIqd }
      );
    } catch (_) {}
  }

  /**
   * Delete ticket
   */
  static async deleteTicket(ticketId: string, sourceCollection: string): Promise<void> {
    const colName = sourceCollection || 'complaints';
    await deleteDoc(doc(db, colName, ticketId));
  }
}
