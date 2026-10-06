import React, { useState, useEffect, useMemo } from 'react';
import { 
  MessageSquare, 
  Search, 
  CheckCircle2, 
  Clock, 
  XCircle, 
  Send, 
  Loader2, 
  AlertCircle, 
  User, 
  Phone,
  Headphones,
  LifeBuoy,
  Plus,
  Filter,
  Trash2,
  ExternalLink,
  MessageCircle,
  Car,
  Store,
  Wallet,
  Gift,
  Tag,
  Sparkles,
  AlertTriangle,
  Flame,
  Check,
  RefreshCw,
  Copy,
  ChevronLeft,
  X
} from 'lucide-react';
import { ComplaintsRepository, SupportTicketEntity } from '../../infrastructure/repositories/ComplaintsRepository';
import { FinanceRepository } from '../../infrastructure/repositories/FinanceRepository';

export const ComplaintsSupportModule: React.FC = () => {
  const [tickets, setTickets] = useState<SupportTicketEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  // Filters
  const [activeTab, setActiveTab] = useState<'all' | 'urgent' | 'driver' | 'customer' | 'merchant'>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'in_progress' | 'resolved' | 'rejected'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  
  // Selected Ticket for Details & Resolution
  const [selectedTicket, setSelectedTicket] = useState<SupportTicketEntity | null>(null);
  const [adminResponseText, setAdminResponseText] = useState('');
  const [compensationAmount, setCompensationAmount] = useState<number>(0);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  // New Ticket Creation Modal
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newCategory, setNewCategory] = useState<SupportTicketEntity['category']>('customer');
  const [newType, setNewType] = useState<SupportTicketEntity['type']>('complaint');
  const [newPriority, setNewPriority] = useState<SupportTicketEntity['priority']>('medium');
  const [newUserName, setNewUserName] = useState('');
  const [newUserPhone, setNewUserPhone] = useState('');

  // Quick Reply Templates
  const quickTemplates = [
    'تم حل المشكلة وتحديث حسابك، نعتذر عن أي إزعاج.',
    'تم التواصل مع الكابتن المعني وتنبيهه لضمان جودة الخدمة.',
    'تمت إضافة تعويض مالي إلى محفظتك بنجاح، يمكنك استخدامه فوراً.',
    'نعتذر عن التأخير، تم اتخاذ الإجراء اللازم وتحديث مسار الطلب.',
    'تم رفع الخلل الفني إلى الفريق البرمجي وجاري العمل على إصلاحه.'
  ];

  useEffect(() => {
    setIsLoading(true);
    const unsub = ComplaintsRepository.subscribeToComplaints((data) => {
      setTickets(data);
      setIsLoading(false);

      if (selectedTicket) {
        const updated = data.find(t => t.id === selectedTicket.id);
        if (updated) setSelectedTicket(updated);
      }
    });

    return () => unsub();
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Resolve Ticket
  const handleResolveTicket = async (status: 'resolved' | 'in_progress' | 'rejected') => {
    if (!selectedTicket) return;
    setIsSubmitting(true);
    try {
      // If compensation entered and user has an ID/phone, record topup in finance
      if (compensationAmount > 0 && selectedTicket.userPhone) {
        await FinanceRepository.adjustWalletBalance({
          targetRole: selectedTicket.category === 'driver' ? 'driver' : 'customer',
          targetId: selectedTicket.userId || selectedTicket.userPhone,
          targetName: selectedTicket.userName,
          targetPhone: selectedTicket.userPhone,
          amountIqd: compensationAmount,
          operationType: 'bonus',
          reason: `تعويض دعم فني - تذكرة #${selectedTicket.ticketNumber}`
        });
      }

      await ComplaintsRepository.resolveComplaint(
        selectedTicket.id,
        selectedTicket.sourceCollection,
        status,
        adminResponseText,
        compensationAmount > 0 ? compensationAmount : undefined
      );

      showToast(status === 'resolved' ? 'تم حل التذكرة بنجاح وإرسال الرد للمستخدم ' : 'تم تحديث حالة التذكرة بنجاح');
      setAdminResponseText('');
      setCompensationAmount(0);
    } catch (err: any) {
      showToast('ما قدرنا نحدث التذكرة: ' + (err.message || ''), 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Delete Ticket
  const handleDeleteTicket = async (ticket: SupportTicketEntity) => {
    if (!window.confirm(`متأكد تريد تحذف التذكرة #${ticket.ticketNumber}؟`)) return;
    try {
      await ComplaintsRepository.deleteTicket(ticket.id, ticket.sourceCollection);
      showToast(`تم حذف التذكرة #${ticket.ticketNumber}`);
      if (selectedTicket?.id === ticket.id) setSelectedTicket(null);
    } catch (err: any) {
      showToast('فشل حذف التذكرة', 'error');
    }
  };

  // Create Manual Ticket Submit
  const handleCreateTicketSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim() || !newDesc.trim() || !newUserName.trim() || !newUserPhone.trim()) {
      showToast('يرجى ملء جميع الحقول المطلوبة', 'error');
      return;
    }

    try {
      await ComplaintsRepository.createTicket({
        title: newTitle.trim(),
        description: newDesc.trim(),
        category: newCategory,
        type: newType,
        priority: newPriority,
        userName: newUserName.trim(),
        userPhone: newUserPhone.trim()
      });

      showToast('تم فتح تذكرة الدعم الفني بنجاح ');
      setShowCreateModal(false);
      setNewTitle('');
      setNewDesc('');
      setNewUserName('');
      setNewUserPhone('');
    } catch (err: any) {
      showToast('فشل إنشاء التذكرة: ' + (err.message || ''), 'error');
    }
  };

  // Statistics
  const stats = useMemo(() => {
    const total = tickets.length;
    const pending = tickets.filter(t => t.status === 'pending').length;
    const inProgress = tickets.filter(t => t.status === 'in_progress').length;
    const resolved = tickets.filter(t => t.status === 'resolved').length;
    const urgent = tickets.filter(t => t.priority === 'urgent' && t.status !== 'resolved').length;
    const driverTickets = tickets.filter(t => t.category === 'driver').length;
    const customerTickets = tickets.filter(t => t.category === 'customer').length;
    const merchantTickets = tickets.filter(t => t.category === 'merchant').length;

    return {
      total,
      pending,
      inProgress,
      resolved,
      urgent,
      driverTickets,
      customerTickets,
      merchantTickets
    };
  }, [tickets]);

  // Filtered Tickets List
  const filteredTickets = useMemo(() => {
    return tickets.filter(t => {
      // 1. Tab / Category Filter
      if (activeTab === 'urgent' && (t.priority !== 'urgent' || t.status === 'resolved')) return false;
      if (activeTab === 'driver' && t.category !== 'driver') return false;
      if (activeTab === 'customer' && t.category !== 'customer') return false;
      if (activeTab === 'merchant' && t.category !== 'merchant') return false;

      // 2. Status Filter
      if (statusFilter !== 'all' && t.status !== statusFilter) return false;

      // 3. Search Query
      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;

      return (
        t.ticketNumber.toLowerCase().includes(q) ||
        t.title.toLowerCase().includes(q) ||
        t.description.toLowerCase().includes(q) ||
        t.userName.toLowerCase().includes(q) ||
        t.userPhone.includes(q) ||
        (t.adminResponse && t.adminResponse.toLowerCase().includes(q))
      );
    });
  }, [tickets, activeTab, statusFilter, searchQuery]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'linear-gradient(135deg, #06b6d4, #0284c7)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <Headphones size={22} />
            </div>
            <span>مركز الدعم الفني وتذاكر المساعدة (Support & Helpdesk Hub)</span>
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            نظام استقبال ومتابعة بلاغات الزبائن والكباتن والمتاجر، حل الشكاوى، والتعويض المالي الفوري
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            onClick={() => setShowCreateModal(true)}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '800', background: 'linear-gradient(135deg, #06b6d4, #0284c7)', borderColor: '#38bdf8' }}
          >
            <Plus size={16} /> + فتح تذكرة دعم جديدة
          </button>
        </div>
      </div>

      {/* ─── 4 MAIN KPI SUMMARY CARDS ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '14px' }}>
        
        <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(6, 182, 212, 0.12) 0%, rgba(15, 23, 42, 0.6) 100%)', border: '1px solid rgba(6, 182, 212, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي التذاكر والبلاغات</span>
            <LifeBuoy size={18} color="#06b6d4" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#fff', marginTop: '6px' }}>
            {stats.total} تذكرة
          </div>
          <div style={{ fontSize: '11px', color: '#38bdf8', marginTop: '3px' }}>
             {stats.customerTickets} زبائن | {stats.driverTickets} كباتن | {stats.merchantTickets} شركاء
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '16px', background: stats.pending > 0 ? 'linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(15, 23, 42, 0.6) 100%)' : undefined, border: stats.pending > 0 ? '1px solid rgba(245, 158, 11, 0.4)' : undefined }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>بانتظار الرد والمعالجة</span>
            <Clock size={18} color="#f59e0b" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: stats.pending > 0 ? '#fbbf24' : '#fff', marginTop: '6px' }}>
            {stats.pending} تذكرة 
          </div>
          <div style={{ fontSize: '11px', color: stats.urgent > 0 ? '#f87171' : 'var(--text-dim)', marginTop: '3px' }}>
            {stats.urgent > 0 ? ` منها ${stats.urgent} تذكرة عاجلة جداً` : 'لا توجد بلاغات طارئة'}
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>جاري المتابعة والتدقيق</span>
            <RefreshCw size={18} color="#38bdf8" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#38bdf8', marginTop: '6px' }}>
            {stats.inProgress} قيد المتابعة 
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            تذاكر مفتوحة مع الكباتن أو المطاعم
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>تم الحل بنجاح</span>
            <CheckCircle2 size={18} color="#34d399" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
            {stats.resolved} تذكرة محلولة 
          </div>
          <div style={{ fontSize: '11px', color: '#6ee7b7', marginTop: '3px' }}>
            معدل الرضا والإنجاز: {stats.total > 0 ? Math.round((stats.resolved / stats.total) * 100) : 100}%
          </div>
        </div>

      </div>

      {/* ─── ACTOR TABS & SEARCH BAR ─── */}
      <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
        
        {/* Row 1: Actor Domain Tabs */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
          <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
            <button
              onClick={() => setActiveTab('all')}
              className={`btn ${activeTab === 'all' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12.5px', fontWeight: '800' }}
            >
               جميع التذاكر ({tickets.length})
            </button>
            <button
              onClick={() => setActiveTab('urgent')}
              className={`btn ${activeTab === 'urgent' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12.5px', fontWeight: '800', color: activeTab === 'urgent' ? '#fff' : '#f87171', borderColor: stats.urgent > 0 ? '#ef4444' : undefined }}
            >
               البلاغات العاجلة ({stats.urgent})
            </button>
            <button
              onClick={() => setActiveTab('driver')}
              className={`btn ${activeTab === 'driver' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12.5px', fontWeight: '800', color: activeTab === 'driver' ? '#fff' : '#fbbf24' }}
            >
               دعم الكباتن ({stats.driverTickets})
            </button>
            <button
              onClick={() => setActiveTab('customer')}
              className={`btn ${activeTab === 'customer' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12.5px', fontWeight: '800', color: activeTab === 'customer' ? '#fff' : '#38bdf8' }}
            >
               دعم الزبائن والركاب ({stats.customerTickets})
            </button>
            <button
              onClick={() => setActiveTab('merchant')}
              className={`btn ${activeTab === 'merchant' ? 'btn-primary' : 'btn-secondary'}`}
              style={{ fontSize: '12.5px', fontWeight: '800', color: activeTab === 'merchant' ? '#fff' : '#a78bfa' }}
            >
               دعم المتاجر والمطاعم ({stats.merchantTickets})
            </button>
          </div>

          {/* Search */}
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '280px' }}>
            <Search size={16} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
            <input
              type="text"
              placeholder="ابحث برقم التذكرة، الاسم، الهاتف، أو المشكلة..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              style={{ width: '100%', padding: '8px 36px 8px 12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
            />
          </div>
        </div>

        {/* Row 2: Status Filters */}
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', borderTop: '1px solid var(--border-color)', paddingTop: '10px' }}>
          <button onClick={() => setStatusFilter('all')} className={`btn ${statusFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11.5px', padding: '5px 12px' }}>
            عرض كل الحالات
          </button>
          <button onClick={() => setStatusFilter('pending')} className={`btn ${statusFilter === 'pending' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11.5px', padding: '5px 12px', color: '#fbbf24' }}>
             بانتظار الرد ({stats.pending})
          </button>
          <button onClick={() => setStatusFilter('in_progress')} className={`btn ${statusFilter === 'in_progress' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11.5px', padding: '5px 12px', color: '#38bdf8' }}>
             قيد المعالجة ({stats.inProgress})
          </button>
          <button onClick={() => setStatusFilter('resolved')} className={`btn ${statusFilter === 'resolved' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11.5px', padding: '5px 12px', color: '#34d399' }}>
             تم الحل ({stats.resolved})
          </button>
        </div>

      </div>

      {/* ─── MAIN DUAL CONSOLE: TICKETS LIST (LEFT) & DETAILS / RESOLUTION PANEL (RIGHT) ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: selectedTicket ? '1.1fr 1fr' : '1fr', gap: '16px' }}>
        
        {/* LEFT: Tickets List */}
        <div className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
          {isLoading ? (
            <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Loader2 size={26} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
              <div>جاري جلب تذاكر الدعم الفني من Firestore...</div>
            </div>
          ) : filteredTickets.length === 0 ? (
            <div style={{ padding: '50px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <LifeBuoy size={36} color="#64748b" style={{ margin: '0 auto 8px' }} />
              <div style={{ fontSize: '15px', fontWeight: '800', color: '#fff' }}>لا توجد تذاكر دعم فني مطابقة</div>
              <div style={{ fontSize: '12px', marginTop: '4px' }}>جميع بلاغات الدعم والشكاوى تمت معالجتها بنجاح</div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', maxHeight: '680px', overflowY: 'auto' }}>
              {filteredTickets.map((t) => {
                const isSelected = selectedTicket?.id === t.id;
                return (
                  <div
                    key={t.id}
                    onClick={() => setSelectedTicket(t)}
                    style={{
                      padding: '14px 18px',
                      borderBottom: '1px solid rgba(255,255,255,0.06)',
                      background: isSelected ? 'rgba(6, 182, 212, 0.12)' : 'transparent',
                      borderRight: isSelected ? '4px solid #06b6d4' : '4px solid transparent',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'flex-start',
                      gap: '12px'
                    }}
                  >
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: 1 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: '900', color: '#fff', fontSize: '13.5px' }}>#{t.ticketNumber}</span>
                        <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '6px', background: 'rgba(255,255,255,0.06)', color: 'var(--text-muted)' }}>{t.categoryArabic}</span>
                        <span style={{ fontSize: '11px', color: t.priority === 'urgent' ? '#f87171' : (t.priority === 'high' ? '#fbbf24' : '#94a3b8') }}>
                          {t.priorityArabic}
                        </span>
                      </div>

                      <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px', marginTop: '2px' }}>
                        {t.title}
                      </div>

                      <div style={{ fontSize: '12px', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                        {t.description}
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
                        <span> {t.userName}</span>
                        <span>•</span>
                        <span dir="ltr"> {t.userPhone}</span>
                        <span>•</span>
                        <span> {t.createdAt}</span>
                      </div>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '6px' }}>
                      <span className={`badge ${t.status === 'resolved' ? 'badge-success' : (t.status === 'in_progress' ? 'badge-info' : (t.status === 'rejected' ? 'badge-danger' : 'badge-warning'))}`} style={{ fontSize: '10.5px' }}>
                        {t.statusArabic}
                      </span>
                      {t.compensationAmountIqd && t.compensationAmountIqd > 0 ? (
                        <span style={{ fontSize: '11px', color: '#34d399', fontWeight: '800' }}>
                          تعويض: {formatIqd(t.compensationAmountIqd)}
                        </span>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* RIGHT: Selected Ticket Resolution Console */}
        {selectedTicket ? (
          <div className="glass-panel" style={{ padding: '22px', display: 'flex', flexDirection: 'column', gap: '16px', border: '1px solid rgba(6, 182, 212, 0.4)' }}>
            
            {/* Ticket Header & Actions */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ fontSize: '16px', fontWeight: '900', color: '#fff' }}>تذكرة #{selectedTicket.ticketNumber}</span>
                  <span className={`badge ${selectedTicket.status === 'resolved' ? 'badge-success' : (selectedTicket.status === 'in_progress' ? 'badge-info' : 'badge-warning')}`}>
                    {selectedTicket.statusArabic}
                  </span>
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  تاريخ الإنشاء: {selectedTicket.createdAt} • المصدر: {selectedTicket.sourceCollection}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '6px' }}>
                <button
                  onClick={() => handleDeleteTicket(selectedTicket)}
                  style={{ background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '4px' }}
                  title="حذف التذكرة"
                >
                  <Trash2 size={16} />
                </button>
                <button
                  onClick={() => setSelectedTicket(null)}
                  style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: '4px' }}
                >
                  <X size={18} />
                </button>
              </div>
            </div>

            {/* User Profile Card & Direct Call / WhatsApp */}
            <div style={{ padding: '12px 16px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px', border: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{selectedTicket.userName}</div>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  الفئة: <strong style={{ color: '#38bdf8' }}>{selectedTicket.categoryArabic}</strong> • الهاتف: <span dir="ltr">{selectedTicket.userPhone}</span>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '8px' }}>
                {selectedTicket.userPhone && (
                  <>
                    <a
                      href={`https://wa.me/${selectedTicket.userPhone.replace(/[^0-9]/g, '')}`}
                      target="_blank"
                      rel="noreferrer"
                      className="btn btn-secondary"
                      style={{ fontSize: '11px', padding: '5px 10px', display: 'flex', alignItems: 'center', gap: '4px', color: '#34d399' }}
                    >
                      <MessageCircle size={13} /> واتساب
                    </a>
                    <a
                      href={`tel:${selectedTicket.userPhone}`}
                      className="btn btn-secondary"
                      style={{ fontSize: '11px', padding: '5px 10px', display: 'flex', alignItems: 'center', gap: '4px', color: '#38bdf8' }}
                    >
                      <Phone size={13} /> اتصال
                    </a>
                  </>
                )}
              </div>
            </div>

            {/* Ticket Subject & Description */}
            <div style={{ padding: '14px', background: 'rgba(15, 23, 42, 0.6)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '4px' }}>عنوان المشكلة:</div>
              <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff', marginBottom: '8px' }}>{selectedTicket.title}</div>
              
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '4px' }}>تفاصيل البلاغ:</div>
              <div style={{ fontSize: '13px', color: '#cbd5e1', lineHeight: '1.6', whiteSpace: 'pre-wrap' }}>
                {selectedTicket.description}
              </div>

              {selectedTicket.relatedOrderId && (
                <div style={{ marginTop: '10px', fontSize: '12px', color: '#38bdf8' }}>
                   مرتبطة بالطلب رقم: <strong>#{selectedTicket.relatedOrderId}</strong>
                </div>
              )}
              {selectedTicket.relatedRideId && (
                <div style={{ marginTop: '10px', fontSize: '12px', color: '#fbbf24' }}>
                   مرتبطة برحلة التكسي رقم: <strong>#{selectedTicket.relatedRideId}</strong>
                </div>
              )}
            </div>

            {/* Previous Admin Response if exists */}
            {selectedTicket.adminResponse && (
              <div style={{ padding: '12px 14px', background: 'rgba(16, 185, 129, 0.08)', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '12px' }}>
                <div style={{ fontSize: '11px', color: '#34d399', fontWeight: '800', marginBottom: '4px' }}>
                  رد الإدارة السابق ({selectedTicket.resolvedAt ? new Date(selectedTicket.resolvedAt).toLocaleString('ar-IQ') : 'مسجل'}):
                </div>
                <div style={{ fontSize: '12.5px', color: '#fff' }}>{selectedTicket.adminResponse}</div>
              </div>
            )}

            {/* Quick Reply Template Chips */}
            <div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>قوالب ردود جاهزة وسريعة:</div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {quickTemplates.map((tmpl, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => setAdminResponseText(tmpl)}
                    className="btn btn-secondary"
                    style={{ fontSize: '11px', padding: '4px 8px', borderRadius: '6px', textAlign: 'right' }}
                  >
                    {tmpl.slice(0, 32)}...
                  </button>
                ))}
              </div>
            </div>

            {/* Admin Response Input */}
            <div>
              <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>
                نص رد الدعم الفني / رسالة الحل:
              </label>
              <textarea
                rows={3}
                value={adminResponseText}
                onChange={e => setAdminResponseText(e.target.value)}
                placeholder="اكتب رد الدعم الفني أو التوجيهات للمستخدم..."
                style={{ width: '100%', padding: '10px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px', outline: 'none' }}
              />
            </div>

            {/* Optional Wallet Compensation */}
            <div style={{ padding: '10px 14px', background: 'rgba(255,255,255,0.02)', borderRadius: '10px', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Wallet size={16} color="#34d399" />
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>شحن محفظة كتعويض مالي (اختياري):</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <input
                  type="number"
                  step="500"
                  min="0"
                  value={compensationAmount}
                  onChange={e => setCompensationAmount(Number(e.target.value))}
                  style={{ width: '100px', padding: '5px 8px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '6px', color: '#34d399', fontSize: '12.5px', fontWeight: '800', textAlign: 'center' }}
                />
                <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>د.ع</span>
              </div>
            </div>

            {/* Action Buttons */}
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '6px' }}>
              <button
                type="button"
                onClick={() => handleResolveTicket('resolved')}
                disabled={isSubmitting}
                className="btn btn-primary"
                style={{ fontSize: '12.5px', padding: '8px 16px', background: 'linear-gradient(135deg, #10b981, #059669)', borderColor: '#34d399', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '800' }}
              >
                <Check size={14} /> تم الحل بنجاح 
              </button>

              <button
                type="button"
                onClick={() => handleResolveTicket('in_progress')}
                disabled={isSubmitting}
                className="btn btn-secondary"
                style={{ fontSize: '12.5px', padding: '8px 14px', color: '#38bdf8', display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <RefreshCw size={14} /> جاري المعالجة 
              </button>

              <button
                type="button"
                onClick={() => handleResolveTicket('rejected')}
                disabled={isSubmitting}
                className="btn btn-secondary"
                style={{ fontSize: '12.5px', padding: '8px 14px', color: '#f87171' }}
              >
                إغلاق / رفض
              </button>
            </div>

          </div>
        ) : null}

      </div>

      {/* ─── CREATE SUPPORT TICKET MODAL ─── */}
      {showCreateModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '520px', width: '100%', borderRadius: '22px', border: '1px solid rgba(6, 182, 212, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0 }}>فتح تذكرة دعم فني جديدة </h3>
              <button onClick={() => setShowCreateModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleCreateTicketSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>عنوان التذكرة / البلاغ:</label>
                <input type="text" required value={newTitle} onChange={e => setNewTitle(e.target.value)} placeholder="مثال: مشكلة في حساب الكابتن أو خصم رصيد" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>فئة المستخدم:</label>
                  <select value={newCategory} onChange={e => setNewCategory(e.target.value as any)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }}>
                    <option value="customer"> زبون / راكب</option>
                    <option value="driver"> كابتن / سائق</option>
                    <option value="merchant"> متجر / مطعم</option>
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>الأولوية:</label>
                  <select value={newPriority} onChange={e => setNewPriority(e.target.value as any)} style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }}>
                    <option value="medium"> متوسطة</option>
                    <option value="high"> مرتفعة</option>
                    <option value="urgent"> عاجلة جداً</option>
                    <option value="low"> منخفضة</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>اسم مقدم البلاغ:</label>
                  <input type="text" required value={newUserName} onChange={e => setNewUserName(e.target.value)} placeholder="اسم المتصل أو صاحب البلاغ" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>رقم الهاتف:</label>
                  <input type="tel" required dir="ltr" value={newUserPhone} onChange={e => setNewUserPhone(e.target.value)} placeholder="077XXXXXXXX" style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>تفاصيل المشكلة والوصف الكامل:</label>
                <textarea rows={3} required value={newDesc} onChange={e => setNewDesc(e.target.value)} placeholder="اكتب تفاصيل ما حدث..." style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }} />
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button type="submit" className="btn btn-primary" style={{ fontSize: '13px', padding: '9px 20px', background: 'linear-gradient(135deg, #06b6d4, #0284c7)' }}>
                  فتح التذكرة
                </button>
                <button type="button" onClick={() => setShowCreateModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
