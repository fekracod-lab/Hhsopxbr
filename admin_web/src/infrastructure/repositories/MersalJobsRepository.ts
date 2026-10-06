import { 
  collection, 
  query, 
  limit, 
  onSnapshot, 
  doc, 
  updateDoc
} from 'firebase/firestore';
import { db } from '../firebase';
import { MersalJobEntity } from '../../domain/types';
import { AuditRepository } from './AuditRepository';

export class MersalJobsRepository {
  /**
   * Stream Mersal Delivery Jobs strictly from `mersal_requests` collection
   */
  static subscribeToMersalJobs(callback: (jobs: MersalJobEntity[]) => void, maxLimit = 300): () => void {
    return onSnapshot(query(collection(db, 'mersal_requests'), limit(maxLimit)), (snapshot) => {
      const list: MersalJobEntity[] = snapshot.docs.map((d) => {
        const data = d.data();

        let createdStr = 'الآن';
        let createdTs = 0;
        if (data.createdAt?.toDate) {
          const dt = data.createdAt.toDate();
          createdStr = dt.toLocaleDateString('ar-IQ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
          createdTs = dt.getTime();
        } else if (data.createdAt) {
          const dt = new Date(data.createdAt);
          createdStr = !isNaN(dt.getTime()) ? dt.toLocaleDateString('ar-IQ') : 'مسجل';
          createdTs = !isNaN(dt.getTime()) ? dt.getTime() : 0;
        }

        const rawStatus = (data.status || 'pending').toString().toLowerCase();
        let status: MersalJobEntity['status'] = 'pending';
        let statusArabic = 'قيد الانتظار';

        if (rawStatus === 'accepted' || rawStatus === 'assigned') {
          status = 'accepted';
          statusArabic = 'تم قبول الطلب من المندوب ';
        } else if (rawStatus === 'picked_up' || rawStatus === 'in_transit' || rawStatus === 'on_the_way') {
          status = 'picked_up';
          statusArabic = 'المندوب استلم الشحنة وجاري التوصيل ';
        } else if (rawStatus === 'delivered' || rawStatus === 'completed') {
          status = 'delivered';
          statusArabic = 'تم تسليم الشحنة بنجاح ';
        } else if (rawStatus === 'cancelled' || rawStatus === 'rejected') {
          status = 'cancelled';
          statusArabic = 'ملغية ';
        }

        const fee = Number(data.deliveryFee || data.price || data.totalPrice || data.fee || 3000);
        const commission = Number(data.commission || data.platformCommission || (fee * 0.10));
        const courierNet = Number(data.courierNet || (fee - commission));

        return {
          jobId: d.id,
          senderId: data.senderId || data.userId || data.customerId,
          senderName: data.senderName || data.userName || data.customerName || 'مرسل الشحنة',
          senderPhone: data.senderPhone || data.userPhone || data.customerPhone || 'غير مسجل',
          recipientName: data.recipientName || data.receiverName || 'المستلم',
          recipientPhone: data.recipientPhone || data.receiverPhone || '—',
          courierId: data.courierId || data.driverId,
          courierName: data.courierName || data.driverName,
          courierPhone: data.courierPhone || data.driverPhone,
          packageDescription: data.packageDescription || data.description || data.itemDescription || 'طرد توصيل شخصي',
          packageValueIqd: data.packageValue ? Number(data.packageValue) : undefined,
          deliveryFeeIqd: fee,
          commissionIqd: commission,
          courierNetIqd: courierNet,
          pickupAddress: data.pickupAddress || data.pickupLocationName || 'نقطة الاستلام (القائم)',
          pickupLat: Number(data.pickupLat || (data.pickupLocation && data.pickupLocation.latitude)),
          pickupLng: Number(data.pickupLng || (data.pickupLocation && data.pickupLocation.longitude)),
          dropoffAddress: data.dropoffAddress || data.destinationAddress || 'نقطة التسليم (القائم)',
          dropoffLat: Number(data.dropoffLat || (data.dropoffLocation && data.dropoffLocation.latitude)),
          dropoffLng: Number(data.dropoffLng || (data.dropoffLocation && data.dropoffLocation.longitude)),
          status,
          rawStatus,
          statusArabic,
          createdAt: createdStr,
          createdTimestamp: createdTs,
          paymentMethod: data.paymentMethod || 'cash_on_delivery',
          notes: data.notes || data.specialInstructions
        };
      });

      list.sort((a, b) => b.createdTimestamp - a.createdTimestamp);
      callback(list);
    }, (err) => console.warn('mersal_requests stream:', err.message));
  }

  /**
   * Cancel Mersal Job
   */
  static async cancelMersalJob(jobId: string, reason = 'إلغاء إداري'): Promise<void> {
    await updateDoc(doc(db, 'mersal_requests', jobId), {
      status: 'cancelled',
      cancellationReason: reason,
      updatedAt: new Date().toISOString()
    });

    AuditRepository.logAction({
      action: 'CANCEL_MERSAL_JOB',
      targetResource: `mersal_requests/${jobId}`,
      payload: { reason }
    });
  }
}
