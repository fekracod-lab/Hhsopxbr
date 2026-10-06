import React, { useState } from 'react';
import { 
  Bell, 
  Send, 
  Users, 
  Car, 
  Store, 
  CheckCircle, 
  AlertCircle, 
  Loader2, 
  Smartphone, 
  Radio 
} from 'lucide-react';
import { NotificationRepository, BroadcastNotificationPayload } from '../../infrastructure/repositories/NotificationRepository';

export const BroadcastNotificationsModule: React.FC = () => {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [target, setTarget] = useState<'all' | 'drivers' | 'merchants' | 'customers'>('all');
  const [isSending, setIsSending] = useState(false);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 5000);
  };

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !body.trim()) {
      showToast('يرجى كتابة عنوان ونص الإشعار', 'error');
      return;
    }

    if (!window.confirm(`هل أنت متأكد من رغبتك في إرسال هذا الإشعار للجهة المستهدفة (${target})؟`)) return;

    setIsSending(true);
    try {
      await NotificationRepository.sendBroadcastNotification({
        title,
        body,
        target
      });
      showToast('تم إرسال ونشر الإشعار السحابي بنجاح ');
      setTitle('');
      setBody('');
    } catch (err: any) {
      showToast('فشل إرسال الإشعار: ' + (err.message || ''), 'error');
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '800', color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Bell size={22} color="#06b6d4" /> مركز التعاميم والإشعارات الجماعية (Broadcast Notification Center)
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            إرسال إشعارات وتنبيهات فورية لكافة مستخدمي التطبيق، الكباتن، أو الشركاء في مدينة القائم
          </p>
        </div>
      </div>

      {/* Main Grid: Composer & Mobile Live Preview */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: '24px' }}>
        
        {/* Composer Form */}
        <div className="glass-panel" style={{ padding: '28px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', marginBottom: '18px' }}>
            إنشاء تعميم جديد (Compose Broadcast)
          </h3>

          <form onSubmit={handleSend} style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
            {/* Target Selector */}
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '8px' }}>
                الجهة المستهدفة بالإشعار:
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <button
                  type="button"
                  onClick={() => setTarget('all')}
                  className={`btn ${target === 'all' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                >
                  <Users size={14} /> الجميع (كافة المستخدمين)
                </button>
                <button
                  type="button"
                  onClick={() => setTarget('drivers')}
                  className={`btn ${target === 'drivers' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                >
                  <Car size={14} /> الكباتن والسائقين فقط
                </button>
                <button
                  type="button"
                  onClick={() => setTarget('merchants')}
                  className={`btn ${target === 'merchants' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                >
                  <Store size={14} /> أصحاب المطاعم والمتاجر
                </button>
                <button
                  type="button"
                  onClick={() => setTarget('customers')}
                  className={`btn ${target === 'customers' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
                >
                  <Users size={14} /> الزبائن والركاب فقط
                </button>
              </div>
            </div>

            {/* Notification Title */}
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                عنوان الإشعار (Title):
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="مثال: خصم خاص 20% على كافة طلبات المطاعم اليوم! "
                style={{ width: '100%', padding: '12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '10px', color: '#fff', fontSize: '14px', outline: 'none' }}
              />
            </div>

            {/* Notification Body */}
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '700', color: 'var(--text-muted)', marginBottom: '6px' }}>
                نص الإشعار والتفاصيل (Body):
              </label>
              <textarea
                rows={4}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="اكتب الرسالة الترويجية أو التنبيه الإداري هنا..."
                style={{ width: '100%', padding: '12px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '10px', color: '#fff', fontSize: '13px', outline: 'none', resize: 'vertical' }}
              />
            </div>

            {/* Send Button */}
            <button
              type="submit"
              disabled={isSending}
              className="btn btn-primary"
              style={{ width: '100%', padding: '14px', fontSize: '14px', fontWeight: '800', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', marginTop: '6px' }}
            >
              {isSending ? (
                <>
                  <Loader2 size={18} style={{ animation: 'spin 1s linear infinite' }} />
                  <span>جاري إرسال التعميم السحابي...</span>
                </>
              ) : (
                <>
                  <Send size={16} />
                  <span>إرسال التعميم فوراً </span>
                </>
              )}
            </button>
          </form>
        </div>

        {/* Live Mobile Notification Preview */}
        <div className="glass-panel" style={{ padding: '28px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '16px', color: '#fff', fontSize: '14px', fontWeight: '700' }}>
            <Smartphone size={18} color="#06b6d4" />
            <span>معاينة الإشعار على الموبايل</span>
          </div>

          <div style={{ width: '100%', maxWidth: '300px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '16px', padding: '16px', boxShadow: '0 10px 30px rgba(0,0,0,0.5)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
              <div style={{ width: '22px', height: '22px', borderRadius: '6px', background: '#06b6d4', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: '11px', fontWeight: '900' }}>
                م
              </div>
              <span style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-muted)' }}>منظومة مدار • الآن</span>
            </div>

            <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px', marginBottom: '4px' }}>
              {title || 'عنوان الإشعار يظهر هنا...'}
            </div>
            <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', lineHeight: 1.4 }}>
              {body || 'نص وتفاصيل الإشعار تظهر هنا على شاشة القفل أو مركز التنبيهات للزبون.'}
            </div>
          </div>

          <div style={{ marginTop: '24px', fontSize: '11px', color: 'var(--text-dim)', textAlign: 'center', lineHeight: 1.5 }}>
            يتم تسليم الإشعارات عبر قنوات Firebase Cloud Messaging (FCM) المعتمدة في تطبيق أندرويد وiOS.
          </div>
        </div>

      </div>
    </div>
  );
};
