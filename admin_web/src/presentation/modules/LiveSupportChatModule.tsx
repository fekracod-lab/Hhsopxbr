import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  MessageSquare,
  Search,
  Send,
  Loader2,
  Phone,
  MessageCircle,
  User,
  Car,
  Store,
  Wallet,
  CheckCheck,
  Clock,
  Sparkles,
  ShieldCheck,
  RefreshCw,
  Plus,
  X,
  Radio,
  Bell,
  Sliders,
  ChevronLeft,
  Coins
} from 'lucide-react';
import { 
  SupportChatRepository, 
  SupportChatSession, 
  SupportChatMessage 
} from '../../infrastructure/repositories/SupportChatRepository';
import { FinanceRepository } from '../../infrastructure/repositories/FinanceRepository';
import { useAuth } from '../../application/AuthContext';

export const LiveSupportChatModule: React.FC = () => {
  const { user } = useAuth();
  const [sessions, setSessions] = useState<SupportChatSession[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeSession, setActiveSession] = useState<SupportChatSession | null>(null);
  
  // Messages for active session
  const [messages, setMessages] = useState<SupportChatMessage[]>([]);
  const [isMessagesLoading, setIsMessagesLoading] = useState(false);
  const [inputText, setInputText] = useState('');
  const [isSending, setIsSending] = useState(false);

  // Filters & Search
  const [roleFilter, setRoleFilter] = useState<'all' | 'unread' | 'driver' | 'customer' | 'merchant'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Quick Wallet Topup Modal In-Chat
  const [showTopupModal, setShowTopupModal] = useState(false);
  const [topupAmount, setTopupAmount] = useState<number>(3000);
  const [topupReason, setTopupReason] = useState('تعويض فني من الدعم المباشر');
  const [isTopupSubmitting, setIsTopupSubmitting] = useState(false);
  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const messagesEndRef = useRef<HTMLDivElement | null>(null);

  // Quick Support Pre-written Replies
  const quickReplies = [
    'أهلاً بك في الدعم الفني لمدار، كيف يمكنني مساعدتك اليوم؟',
    'تم التحقق من طلبك والمشكلة قيد المتابعة مع الفريق الميداني.',
    'تمت إضافة تعويض مالي إلى محفظتك بنجاح، يمكنك التحقق من الرصيد.',
    'تم تحديث مسار رحلتك والتواصل مع الكابتن مباشرة.',
    'يرجى تزويدنا برقم الطلب أو رقم الرحلة لمتابعتها فوراً.'
  ];

  // Subscribe to all chat sessions
  useEffect(() => {
    setIsLoading(true);
    const unsubscribe = SupportChatRepository.subscribeToChatSessions((data) => {
      setSessions(data);
      setIsLoading(false);

      // Keep active session in sync
      if (activeSession) {
        const updated = data.find(s => s.id === activeSession.id);
        if (updated) {
          setActiveSession(updated);
        }
      } else if (data.length > 0) {
        // Auto select first session
        setActiveSession(data[0]);
      }
    });

    return () => unsubscribe();
  }, []);

  // Subscribe to messages when active session changes
  useEffect(() => {
    if (!activeSession) {
      setMessages([]);
      return;
    }

    setIsMessagesLoading(true);
    // Mark as read
    SupportChatRepository.markChatAsRead(activeSession.id);

    const unsubscribe = SupportChatRepository.subscribeToMessages(activeSession.id, (msgs) => {
      setMessages(msgs);
      setIsMessagesLoading(false);
      // Auto-scroll
      setTimeout(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
      }, 100);
    });

    return () => unsubscribe();
  }, [activeSession?.id]);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(amount) + ' د.ع';
  };

  // Send Admin Message
  const handleSendMessage = async (customText?: string) => {
    const textToSend = (customText || inputText).trim();
    if (!textToSend || !activeSession || isSending) return;

    setIsSending(true);
    if (!customText) setInputText('');

    try {
      await SupportChatRepository.sendAdminMessage(
        activeSession.id,
        textToSend,
        user?.email || 'admin_support',
        user?.name || 'فريق الدعم الفني مدار'
      );
    } catch (err: any) {
      showToast('ما قدرنا نرسل الرسالة: ' + (err.message || ''), 'error');
    } finally {
      setIsSending(false);
    }
  };

  // Handle Enter Key
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  // In-Chat Wallet Topup
  const handleExecuteTopup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeSession || topupAmount <= 0) return;

    setIsTopupSubmitting(true);
    try {
      const targetRole = activeSession.userRole.includes('driver') ? 'driver' : 'customer';
      await FinanceRepository.adjustWalletBalance({
        targetId: activeSession.userId || activeSession.id,
        targetName: activeSession.userName,
        targetPhone: activeSession.userPhone,
        targetRole,
        operationType: 'bonus',
        amountIqd: topupAmount,
        reason: topupReason,
        adminEmail: user?.email || 'SupportAdmin'
      });

      // Send automated confirmation in chat
      await handleSendMessage(`تم شحن رصيد إضافي بقيمة (${formatIqd(topupAmount)}) في محفظتك بنجاح كتعويض فني من إدارة مدار.`);

      showToast(`تم شحن ${formatIqd(topupAmount)} للمستخدم بنجاح `);
      setShowTopupModal(false);
    } catch (err: any) {
      showToast('فشل شحن المحفظة: ' + (err.message || ''), 'error');
    } finally {
      setIsTopupSubmitting(false);
    }
  };

  // Filtered Sessions List
  const filteredSessions = useMemo(() => {
    return sessions.filter((s) => {
      // 1. Role / Status Filter
      if (roleFilter === 'unread' && s.unreadByAdminCount === 0) return false;
      if (roleFilter === 'driver' && !s.userRole.includes('driver') && !s.userRole.includes('captain')) return false;
      if (roleFilter === 'customer' && (s.userRole.includes('driver') || s.userRole.includes('merchant'))) return false;
      if (roleFilter === 'merchant' && !s.userRole.includes('merchant') && !s.userRole.includes('store') && !s.userRole.includes('restaurant')) return false;

      // 2. Search
      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;

      return (
        s.userName.toLowerCase().includes(q) ||
        s.userPhone.includes(q) ||
        s.lastMessage.toLowerCase().includes(q)
      );
    });
  }, [sessions, roleFilter, searchQuery]);

  const totalUnreadCount = useMemo(() => {
    return sessions.reduce((sum, s) => sum + (s.unreadByAdminCount || 0), 0);
  }, [sessions]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', height: 'calc(100vh - 120px)' }}>
      
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'linear-gradient(135deg, #06b6d4, #0284c7)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <Radio size={20} style={{ animation: 'pulse 1.5s infinite' }} />
            </div>
            <span>محادثات الدعم الفني والمراسلة المباشرة (Live Support Chat)</span>
          </h2>
          <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', marginTop: '2px' }}>
            شات مباشر لحظي للتواصل والرد على رسائل الزبائن والكباتن والمتاجر عبر تطبيق مدار
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '6px 14px', borderRadius: '20px', background: totalUnreadCount > 0 ? 'rgba(239, 68, 68, 0.15)' : 'rgba(16, 185, 129, 0.15)', border: totalUnreadCount > 0 ? '1px solid #f87171' : '1px solid rgba(16, 185, 129, 0.3)', color: totalUnreadCount > 0 ? '#f87171' : '#34d399', fontSize: '12px', fontWeight: '800' }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: totalUnreadCount > 0 ? '#f87171' : '#34d399', animation: 'pulse 1.5s infinite' }} />
            <span>{totalUnreadCount > 0 ? `${totalUnreadCount} رسائل غير مقروءة` : 'جميع المحادثات مجاب عليها '}</span>
          </div>
        </div>
      </div>

      {/* ─── DUAL CONSOLE: CHAT SESSIONS LIST (LEFT) & ACTIVE CHAT WINDOW (RIGHT) ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: '340px 1fr', gap: '16px', flex: 1, minHeight: 0 }}>
        
        {/* LEFT COLUMN: Sessions List */}
        <div className="glass-panel" style={{ padding: '14px', display: 'flex', flexDirection: 'column', gap: '10px', overflow: 'hidden' }}>
          
          {/* Search Box */}
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
            <Search size={15} color="#94a3b8" style={{ position: 'absolute', right: '10px' }} />
            <input
              type="text"
              placeholder="ابحث بالاسم أو الهاتف..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              style={{ width: '100%', padding: '7px 32px 7px 10px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px', outline: 'none' }}
            />
          </div>

          {/* Filter Tabs */}
          <div style={{ display: 'flex', gap: '4px', overflowX: 'auto', paddingBottom: '4px' }}>
            <button onClick={() => setRoleFilter('all')} className={`btn ${roleFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px' }}>الكل ({sessions.length})</button>
            <button onClick={() => setRoleFilter('unread')} className={`btn ${roleFilter === 'unread' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px', color: totalUnreadCount > 0 ? '#f87171' : undefined }}>غير مقروء ({totalUnreadCount})</button>
            <button onClick={() => setRoleFilter('driver')} className={`btn ${roleFilter === 'driver' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px', color: '#fbbf24' }}>الكباتن</button>
            <button onClick={() => setRoleFilter('customer')} className={`btn ${roleFilter === 'customer' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px', color: '#38bdf8' }}>الزبائن</button>
          </div>

          {/* Sessions List */}
          <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '4px' }}>
            {isLoading ? (
              <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={20} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 6px' }} />
                <div style={{ fontSize: '12px' }}>جاري جلب المحادثات...</div>
              </div>
            ) : filteredSessions.length === 0 ? (
              <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <MessageSquare size={28} color="#64748b" style={{ margin: '0 auto 6px' }} />
                <div style={{ fontSize: '13px', fontWeight: '700', color: '#fff' }}>لا توجد محادثات مطابقة</div>
              </div>
            ) : (
              filteredSessions.map((s) => {
                const isSelected = activeSession?.id === s.id;
                const hasUnread = s.unreadByAdminCount > 0;
                return (
                  <div
                    key={s.id}
                    onClick={() => setActiveSession(s)}
                    style={{
                      padding: '10px 12px',
                      borderRadius: '10px',
                      background: isSelected 
                        ? 'linear-gradient(135deg, rgba(6, 182, 212, 0.2), rgba(2, 132, 199, 0.2))' 
                        : (hasUnread ? 'rgba(239, 68, 68, 0.08)' : 'rgba(255, 255, 255, 0.02)'),
                      border: isSelected ? '1px solid #06b6d4' : (hasUnread ? '1px solid rgba(239, 68, 68, 0.3)' : '1px solid transparent'),
                      cursor: 'pointer',
                      transition: 'all 0.2s ease',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      gap: '10px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', overflow: 'hidden' }}>
                      <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: s.userRole.includes('driver') ? 'rgba(245, 158, 11, 0.2)' : 'rgba(6, 182, 212, 0.2)', color: s.userRole.includes('driver') ? '#fbbf24' : '#38bdf8', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '900', flexShrink: 0, fontSize: '14px' }}>
                        {s.userRole.includes('driver') ? '' : ''}
                      </div>
                      <div style={{ overflow: 'hidden' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontWeight: '800', color: '#fff', fontSize: '13px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.userName}</span>
                        </div>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginTop: '1px' }}>
                          {s.lastMessage}
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '4px', flexShrink: 0 }}>
                      <span style={{ fontSize: '10px', color: 'var(--text-dim)' }}>{s.lastMessageTime}</span>
                      {hasUnread && (
                        <span style={{ background: '#ef4444', color: '#fff', fontSize: '10px', fontWeight: '900', padding: '1px 6px', borderRadius: '10px', animation: 'pulse 1.5s infinite' }}>
                          {s.unreadByAdminCount}
                        </span>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>

        </div>

        {/* RIGHT COLUMN: Active Chat Conversation Thread */}
        {activeSession ? (
          <div className="glass-panel" style={{ padding: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden', border: '1px solid rgba(6, 182, 212, 0.3)' }}>
            
            {/* Chat Room Top Bar */}
            <div style={{ padding: '12px 18px', background: 'rgba(15, 23, 42, 0.9)', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: activeSession.userRole.includes('driver') ? 'rgba(245, 158, 11, 0.2)' : 'rgba(6, 182, 212, 0.2)', color: activeSession.userRole.includes('driver') ? '#fbbf24' : '#38bdf8', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '900', fontSize: '16px' }}>
                  {activeSession.userRole.includes('driver') ? '' : ''}
                </div>
                <div>
                  <div style={{ fontWeight: '900', color: '#fff', fontSize: '14.5px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span>{activeSession.userName}</span>
                    <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '10px', background: 'rgba(255,255,255,0.06)', color: '#38bdf8' }}>
                      {activeSession.roleArabic}
                    </span>
                  </div>
                  <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginTop: '2px' }} dir="ltr">
                     {activeSession.userPhone}
                  </div>
                </div>
              </div>

              {/* In-Chat Quick Action Buttons */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <button
                  onClick={() => setShowTopupModal(true)}
                  className="btn btn-primary"
                  style={{ fontSize: '11.5px', padding: '6px 12px', display: 'flex', alignItems: 'center', gap: '5px', background: 'linear-gradient(135deg, #10b981, #059669)', borderColor: '#34d399', fontWeight: '800' }}
                  title="شحن رصيد أو تعويض مالي مباشر للمستخدم"
                >
                  <Wallet size={13} />
                  <span>شحن تعويض </span>
                </button>

                {activeSession.userPhone && activeSession.userPhone.length > 5 && (
                  <>
                    <a
                      href={`https://wa.me/${activeSession.userPhone.replace(/[^0-9]/g, '')}`}
                      target="_blank"
                      rel="noreferrer"
                      className="btn btn-secondary"
                      style={{ fontSize: '11.5px', padding: '6px 10px', display: 'flex', alignItems: 'center', gap: '4px', color: '#34d399' }}
                    >
                      <MessageCircle size={13} /> واتساب
                    </a>
                    <a
                      href={`tel:${activeSession.userPhone}`}
                      className="btn btn-secondary"
                      style={{ fontSize: '11.5px', padding: '6px 10px', display: 'flex', alignItems: 'center', gap: '4px', color: '#38bdf8' }}
                    >
                      <Phone size={13} /> اتصال
                    </a>
                  </>
                )}
              </div>
            </div>

            {/* Messages Thread (Scrollable) */}
            <div style={{ flex: 1, padding: '18px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '12px', background: 'rgba(10, 15, 29, 0.5)' }}>
              {isMessagesLoading ? (
                <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
                  <div>جاري تحميل سجل المحادثة...</div>
                </div>
              ) : messages.length === 0 ? (
                <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <MessageSquare size={36} color="#64748b" style={{ margin: '0 auto 8px' }} />
                  <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff' }}>بدء محادثة جديدة مع {activeSession.userName}</div>
                  <div style={{ fontSize: '12px', marginTop: '4px' }}>اكتب رسالتك بالأسفل للرد الفوري على المستخدم</div>
                </div>
              ) : (
                messages.map((m) => {
                  const isAdmin = m.isAdmin;
                  return (
                    <div
                      key={m.id}
                      style={{
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: isAdmin ? 'flex-end' : 'flex-start',
                        maxWidth: '75%',
                        alignSelf: isAdmin ? 'flex-end' : 'flex-start'
                      }}
                    >
                      <div style={{ fontSize: '10.5px', color: 'var(--text-dim)', marginBottom: '3px', padding: '0 4px' }}>
                        {isAdmin ? 'الدعم الفني (أنت)' : activeSession.userName} • {m.timestamp}
                      </div>
                      <div
                        style={{
                          padding: '10px 16px',
                          borderRadius: isAdmin ? '16px 16px 2px 16px' : '16px 16px 16px 2px',
                          background: isAdmin 
                            ? 'linear-gradient(135deg, #0284c7, #0369a1)' 
                            : 'rgba(30, 41, 59, 0.9)',
                          color: '#fff',
                          fontSize: '13.5px',
                          lineHeight: '1.5',
                          border: isAdmin ? '1px solid rgba(56, 189, 248, 0.4)' : '1px solid rgba(255, 255, 255, 0.08)',
                          boxShadow: '0 4px 12px rgba(0,0,0,0.2)',
                          wordBreak: 'break-word'
                        }}
                      >
                        {m.text}
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Quick Reply Chips */}
            <div style={{ padding: '8px 14px', background: 'rgba(15, 23, 42, 0.8)', borderTop: '1px solid var(--border-color)', display: 'flex', gap: '6px', overflowX: 'auto' }}>
              {quickReplies.map((reply, idx) => (
                <button
                  key={idx}
                  type="button"
                  onClick={() => handleSendMessage(reply)}
                  className="btn btn-secondary"
                  style={{ fontSize: '11px', padding: '3px 10px', borderRadius: '12px', whiteSpace: 'nowrap', color: '#38bdf8' }}
                >
                   {reply.slice(0, 24)}...
                </button>
              ))}
            </div>

            {/* Message Input Form */}
            <div style={{ padding: '12px 16px', background: 'rgba(15, 23, 42, 0.95)', borderTop: '1px solid var(--border-color)', display: 'flex', gap: '10px', alignItems: 'center' }}>
              <input
                type="text"
                placeholder={`اكتب رسالتك لـ ${activeSession.userName}... (اضغط Enter للإرسال)`}
                value={inputText}
                onChange={e => setInputText(e.target.value)}
                onKeyDown={handleKeyDown}
                disabled={isSending}
                style={{
                  flex: 1,
                  padding: '10px 14px',
                  background: '#0f172a',
                  border: '1px solid var(--border-color)',
                  borderRadius: '10px',
                  color: '#fff',
                  fontSize: '13.5px',
                  outline: 'none'
                }}
              />

              <button
                type="button"
                onClick={() => handleSendMessage()}
                disabled={isSending || !inputText.trim()}
                className="btn btn-primary"
                style={{
                  padding: '10px 18px',
                  borderRadius: '10px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  fontWeight: '800',
                  fontSize: '13px',
                  background: 'linear-gradient(135deg, #06b6d4, #0284c7)',
                  borderColor: '#38bdf8'
                }}
              >
                {isSending ? <Loader2 size={16} style={{ animation: 'spin 1s linear infinite' }} /> : <Send size={16} />}
                <span>إرسال</span>
              </button>
            </div>

          </div>
        ) : (
          <div className="glass-panel" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>
            <div style={{ textAlign: 'center' }}>
              <MessageSquare size={48} color="#64748b" style={{ margin: '0 auto 12px' }} />
              <div style={{ fontSize: '16px', fontWeight: '800', color: '#fff' }}>اختر محادثة من القائمة لبدء الرد</div>
            </div>
          </div>
        )}

      </div>

      {/* ─── IN-CHAT WALLET TOP-UP / COMPENSATION MODAL ─── */}
      {showTopupModal && activeSession && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '26px', maxWidth: '460px', width: '100%', borderRadius: '20px', border: '1px solid rgba(16, 185, 129, 0.4)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '14px' }}>
              <h3 style={{ fontSize: '16px', fontWeight: '900', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Wallet size={18} color="#34d399" />
                <span>شحن رصيد تعويض فوري لـ ({activeSession.userName})</span>
              </h3>
              <button onClick={() => setShowTopupModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
            </div>

            <form onSubmit={handleExecuteTopup} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>المبلغ بالدينار العراقي:</label>
                <input
                  type="number"
                  step="500"
                  min="500"
                  required
                  value={topupAmount}
                  onChange={e => setTopupAmount(Number(e.target.value))}
                  style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#34d399', fontSize: '16px', fontWeight: '900' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '4px' }}>سبب التعويض / ملاحظات:</label>
                <input
                  type="text"
                  required
                  value={topupReason}
                  onChange={e => setTopupReason(e.target.value)}
                  placeholder="مثال: تعويض عن تأخر الطلب أو خلل فني"
                  style={{ width: '100%', padding: '9px 12px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button
                  type="submit"
                  disabled={isTopupSubmitting}
                  className="btn btn-primary"
                  style={{ fontSize: '13px', padding: '8px 18px', background: 'linear-gradient(135deg, #10b981, #059669)', borderColor: '#34d399', fontWeight: '800' }}
                >
                  {isTopupSubmitting ? 'جاري الشحن...' : 'تأكيد الشحن الفوري '}
                </button>
                <button type="button" onClick={() => setShowTopupModal(false)} className="btn btn-secondary" style={{ fontSize: '13px' }}>إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
