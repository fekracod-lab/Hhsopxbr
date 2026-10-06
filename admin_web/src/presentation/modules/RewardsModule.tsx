import React, { useState, useEffect, useMemo } from 'react';
import {
  Gift,
  Award,
  Star,
  Plus,
  Coins,
  Sparkles,
  TrendingUp,
  Search,
  CheckCircle2,
  XCircle,
  Clock,
  Car,
  User,
  Phone,
  ShieldCheck,
  AlertTriangle,
  RotateCcw,
  Edit3,
  Trash2,
  Download,
  Filter,
  Flame,
  Zap,
  Sliders,
  ChevronDown,
  Percent,
  DollarSign,
  Layers,
  ArrowRightLeft,
  Loader2,
  X
} from 'lucide-react';
import { 
  RewardsRepository, 
  AdminRewardItem, 
  RewardTransactionRecord,
  CaptainPointsRank,
  AutoPointsRule
} from '../../infrastructure/repositories/RewardsRepository';
import { DriversRepository } from '../../infrastructure/repositories/DriversRepository';
import { DriverEntity } from '../../domain/types';

export const RewardsModule: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'catalog' | 'leaderboard' | 'ledger' | 'rules'>('catalog');
  
  // Data State
  const [rewards, setRewards] = useState<AdminRewardItem[]>([]);
  const [transactions, setTransactions] = useState<RewardTransactionRecord[]>([]);
  const [drivers, setDrivers] = useState<DriverEntity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [ledgerTypeFilter, setLedgerTypeFilter] = useState<'all' | 'earned' | 'redeemed' | 'bonus_admin'>('all');
  const [tierFilter, setTierFilter] = useState<'all' | 'diamond' | 'gold' | 'silver' | 'bronze'>('all');

  // Add / Edit Reward Modal
  const [showRewardModal, setShowRewardModal] = useState(false);
  const [editingReward, setEditingReward] = useState<AdminRewardItem | null>(null);
  const [rewardTitle, setRewardTitle] = useState('');
  const [rewardDesc, setRewardDesc] = useState('');
  const [rewardCost, setRewardCost] = useState<number>(100);
  const [rewardType, setRewardType] = useState<AdminRewardItem['rewardType']>('commission_free_trips');
  const [discountPercent, setDiscountPercent] = useState<number>(100);
  const [tripsCount, setTripsCount] = useState<number>(3);
  const [cashValueIqd, setCashValueIqd] = useState<number>(10000);
  const [targetAudience, setTargetAudience] = useState<'drivers' | 'customers' | 'all'>('drivers');
  const [isSubmittingReward, setIsSubmittingReward] = useState(false);

  // Manual Grant Modal
  const [showGrantModal, setShowGrantModal] = useState(false);
  const [grantTargetDriver, setGrantTargetDriver] = useState<DriverEntity | null>(null);
  const [grantPointsAmount, setGrantPointsAmount] = useState<number>(50);
  const [grantType, setGrantType] = useState<'bonus_admin' | 'penalty'>('bonus_admin');
  const [grantReason, setGrantReason] = useState('');
  const [isSubmittingGrant, setIsSubmittingGrant] = useState(false);

  // Auto Points Rules State
  const [pointsPerRide, setPointsPerRide] = useState<number>(10);
  const [pointsPerOrder, setPointsPerOrder] = useState<number>(10);
  const [fiveStarBonus, setFiveStarBonus] = useState<number>(5);
  const [peakBonus, setPeakBonus] = useState<number>(5);
  const [isSavingRules, setIsSavingRules] = useState(false);

  // Toast
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  useEffect(() => {
    setIsLoading(true);

    const unsubRewards = RewardsRepository.subscribeToRewardsCatalog((data) => {
      setRewards(data);
    });

    const unsubTxs = RewardsRepository.subscribeToRewardTransactions((data) => {
      setTransactions(data);
    });

    const unsubDrivers = DriversRepository.subscribeToDrivers((data) => {
      setDrivers(data);
      setIsLoading(false);
    });

    return () => {
      unsubRewards();
      unsubTxs();
      unsubDrivers();
    };
  }, []);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 4000);
  };

  const formatIqd = (val: number) => {
    return new Intl.NumberFormat('ar-IQ').format(val) + ' د.ع';
  };

  // ─── LEADERBOARD COMPUTATION ───
  const captainRanks = useMemo<CaptainPointsRank[]>(() => {
    return drivers.map(d => {
      // Calculate points (either static rewardsPoints or computed)
      const points = Number((d as any).rewardsPoints || (d.totalTrips ? d.totalTrips * 10 : 0));
      
      let tier: CaptainPointsRank['tier'] = 'bronze';
      let tierAr = 'البرونزي ';
      let tierCol = '#cd7f32';

      if (points >= 500) {
        tier = 'diamond';
        tierAr = 'الماسي ';
        tierCol = '#38bdf8';
      } else if (points >= 250) {
        tier = 'gold';
        tierAr = 'الذهبي ';
        tierCol = '#facc15';
      } else if (points >= 100) {
        tier = 'silver';
        tierAr = 'الفضي ';
        tierCol = '#94a3b8';
      }

      return {
        driverId: d.driverId,
        name: d.name,
        phone: d.phoneNumber,
        vehicleModel: d.vehicleModel,
        plateNumber: d.plateNumber,
        rewardsPoints: points,
        tier,
        tierArabic: tierAr,
        tierColor: tierCol,
        totalTrips: d.totalTrips || 0,
        rating: d.rating || 5.0
      };
    }).sort((a, b) => b.rewardsPoints - a.rewardsPoints);
  }, [drivers]);

  // Filtered Leaderboard
  const filteredRanks = useMemo(() => {
    return captainRanks.filter(c => {
      if (tierFilter !== 'all' && c.tier !== tierFilter) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const match = c.name.toLowerCase().includes(q) || c.phone.includes(q) || (c.vehicleModel && c.vehicleModel.toLowerCase().includes(q));
        if (!match) return false;
      }
      return true;
    });
  }, [captainRanks, tierFilter, searchQuery]);

  // Filtered Transactions
  const filteredTransactions = useMemo(() => {
    return transactions.filter(t => {
      if (ledgerTypeFilter !== 'all' && t.type !== ledgerTypeFilter) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const match = (t.driverName && t.driverName.toLowerCase().includes(q)) || t.reason.toLowerCase().includes(q);
        if (!match) return false;
      }
      return true;
    });
  }, [transactions, ledgerTypeFilter, searchQuery]);

  // Overall KPIs
  const stats = useMemo(() => {
    const totalPointsInSystem = captainRanks.reduce((sum, c) => sum + c.rewardsPoints, 0);
    const diamondCount = captainRanks.filter(c => c.tier === 'diamond').length;
    const goldCount = captainRanks.filter(c => c.tier === 'gold').length;
    const totalRedeemedCount = transactions.filter(t => t.type === 'redeemed').length;

    return {
      totalRewards: rewards.length,
      activeRewards: rewards.filter(r => r.isActive).length,
      totalPointsInSystem,
      eliteCaptainsCount: diamondCount + goldCount,
      totalRedeemedCount
    };
  }, [rewards, captainRanks, transactions]);

  // Handle Open Create Reward
  const handleOpenCreateReward = () => {
    setEditingReward(null);
    setRewardTitle('');
    setRewardDesc('');
    setRewardCost(100);
    setRewardType('commission_free_trips');
    setDiscountPercent(100);
    setTripsCount(3);
    setCashValueIqd(10000);
    setTargetAudience('drivers');
    setShowRewardModal(true);
  };

  // Handle Open Edit Reward
  const handleOpenEditReward = (reward: AdminRewardItem) => {
    setEditingReward(reward);
    setRewardTitle(reward.title);
    setRewardDesc(reward.description);
    setRewardCost(reward.cost);
    setRewardType(reward.rewardType);
    setDiscountPercent(reward.discountPercent || 100);
    setTripsCount(reward.tripsCount || 3);
    setCashValueIqd(reward.cashValueIqd || 10000);
    setTargetAudience(reward.targetAudience);
    setShowRewardModal(true);
  };

  // Save / Update Reward Submit
  const handleSaveReward = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!rewardTitle.trim()) {
      showToast('يرجى إدخال عنوان المكافأة', 'error');
      return;
    }

    setIsSubmittingReward(true);
    try {
      if (editingReward) {
        await RewardsRepository.updateReward(editingReward.id, {
          title: rewardTitle.trim(),
          description: rewardDesc.trim(),
          cost: Number(rewardCost),
          rewardType,
          discountPercent: Number(discountPercent),
          tripsCount: Number(tripsCount),
          cashValueIqd: Number(cashValueIqd),
          targetAudience
        });
        showToast('تم تحديث بيانات المكافأة بنجاح');
      } else {
        await RewardsRepository.addReward({
          title: rewardTitle.trim(),
          description: rewardDesc.trim(),
          cost: Number(rewardCost),
          rewardType,
          discountPercent: Number(discountPercent),
          tripsCount: Number(tripsCount),
          cashValueIqd: Number(cashValueIqd),
          targetAudience,
          isActive: true
        });
        showToast('تمت إضافة المكافأة الجديدة إلى الكتالوج بنجاح ');
      }
      setShowRewardModal(false);
    } catch (err: any) {
      showToast('فشل حفظ المكافأة: ' + (err.message || ''), 'error');
    } finally {
      setIsSubmittingReward(false);
    }
  };

  // Toggle Reward Status
  const handleToggleReward = async (reward: AdminRewardItem) => {
    try {
      await RewardsRepository.toggleRewardStatus(reward.id, reward.isActive);
      showToast(`تم ${reward.isActive ? 'تعطيل' : 'تفعيل'} المكافأة (${reward.title})`);
    } catch (err: any) {
      showToast('فشل تغيير الحالة: ' + (err.message || ''), 'error');
    }
  };

  // Delete Reward
  const handleDeleteReward = async (reward: AdminRewardItem) => {
    if (!window.confirm(`متأكد تريد تحذف المكافأة (${reward.title}) نهائياً؟`)) return;
    try {
      await RewardsRepository.deleteReward(reward.id);
      showToast('تم حذف المكافأة بنجاح');
    } catch (err: any) {
      showToast('فشل الحذف: ' + (err.message || ''), 'error');
    }
  };

  // Handle Submit Manual Grant / Deduction
  const handleSaveGrant = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!grantTargetDriver) {
      showToast('يرجى اختيار الكابتن المستهدف', 'error');
      return;
    }
    if (grantPointsAmount <= 0) {
      showToast('يرجى إدخال عدد نقاط صحيح', 'error');
      return;
    }

    setIsSubmittingGrant(true);
    try {
      const finalAmount = grantType === 'penalty' ? -Math.abs(grantPointsAmount) : Math.abs(grantPointsAmount);
      await RewardsRepository.grantOrDeductPoints(
        grantTargetDriver.driverId,
        grantTargetDriver.name,
        grantTargetDriver.phoneNumber,
        finalAmount,
        grantType,
        grantReason.trim()
      );
      showToast(`تم ${grantType === 'bonus_admin' ? 'إهداء' : 'خصم'} ${grantPointsAmount} نقطة للكابتن (${grantTargetDriver.name}) بنجاح `);
      setShowGrantModal(false);
      setGrantTargetDriver(null);
      setGrantReason('');
    } catch (err: any) {
      showToast('فشل تعديل النقاط: ' + (err.message || ''), 'error');
    } finally {
      setIsSubmittingGrant(false);
    }
  };

  // Save Auto Points Rules
  const handleSaveRules = async () => {
    setIsSavingRules(true);
    try {
      await RewardsRepository.saveAutoPointsRules({
        pointsPerCompletedRide: Number(pointsPerRide),
        pointsPerCompletedOrder: Number(pointsPerOrder),
        pointsForFiveStarRating: Number(fiveStarBonus),
        peakHourBonusPoints: Number(peakBonus)
      });
      showToast('تم حفظ قواعد احتساب النقاط التلقائية بنجاح ');
    } catch (err: any) {
      showToast('فشل حفظ القواعد: ' + (err.message || ''), 'error');
    } finally {
      setIsSavingRules(false);
    }
  };

  // Export CSV
  const handleExportLedger = () => {
    if (filteredTransactions.length === 0) {
      showToast('ماكو عمليات حالياً لتصديرها', 'error');
      return;
    }
    const headers = ['معرف العملية', 'تاريخ العملية', 'المستفيد', 'نوع العملية', 'عدد النقاط', 'السبب والبيان'];
    const rows = filteredTransactions.map(t => [
      t.id,
      t.createdAt,
      `"${t.driverName || ''}"`,
      t.type === 'earned' ? 'اكتساب' : t.type === 'redeemed' ? 'استبدال' : 'منحة إدارية',
      t.amount,
      `"${t.reason}"`
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,\uFEFF' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `madar_rewards_ledger_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast('تم تصدير سجل المكافآت CSV بنجاح ');
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Toast Notification */}
      {toast && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: toast.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {toast.msg}
        </div>
      )}

      {/* Top Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '12px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <Gift size={22} />
            </div>
            <span>نظام المكافئات ونقاط الولاء (Rewards & Gamification Engine)</span>
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            كتالوج المكافآت، تصنيف ومستويات الكباتن، سجل العمليات، وقواعد احتساب النقاط التلقائية
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            onClick={() => { setShowGrantModal(true); setGrantTargetDriver(null); }}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '700', color: '#fbbf24' }}
          >
            <Sparkles size={15} /> إهداء / شحن نقاط يدوياً
          </button>
          <button
            onClick={handleOpenCreateReward}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '800', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24' }}
          >
            <Plus size={16} /> إضافة باقة مكافأة جديدة
          </button>
        </div>
      </div>

      {/* ─── 4 MAIN STATS CARDS ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: '14px' }}>
        
        <div className="glass-panel" style={{ padding: '16px', background: 'linear-gradient(135deg, rgba(245, 158, 11, 0.12) 0%, rgba(15, 23, 42, 0.6) 100%)', border: '1px solid rgba(245, 158, 11, 0.3)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>المكافآت المتاحة في الكتالوج</span>
            <Gift size={18} color="#f59e0b" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#fbbf24', marginTop: '6px' }}>
            {stats.activeRewards} باقة نشطة
          </div>
          <div style={{ fontSize: '11px', color: '#fef08a', marginTop: '3px' }}>
            من أصل {stats.totalRewards} باقة مكافآت معتمدة
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي رصيد النقاط في المنظومة</span>
            <Coins size={18} color="#34d399" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#34d399', marginTop: '6px' }}>
            {stats.totalPointsInSystem.toLocaleString('ar-IQ')} 
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            موزعة على {captainRanks.length} كابتن وعضو
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>كباتن النخبة (الذهبي والماسي)</span>
            <Award size={18} color="#38bdf8" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#38bdf8', marginTop: '6px' }}>
            {stats.eliteCaptainsCount} كابتن 
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            مؤهلون للترقيات وتخفيضات العمولات
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>إجمالي عمليات الاستبدال</span>
            <RotateCcw size={18} color="#a78bfa" />
          </div>
          <div style={{ fontSize: '24px', fontWeight: '950', color: '#a78bfa', marginTop: '6px' }}>
            {stats.totalRedeemedCount} عملية
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '3px' }}>
            تصفير عمولات ومكافآت مستلمة
          </div>
        </div>

      </div>

      {/* ─── NAVIGATION TABS ─── */}
      <div className="glass-panel" style={{ padding: '12px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
          <button
            onClick={() => setActiveTab('catalog')}
            className={`btn ${activeTab === 'catalog' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Gift size={14} /> باقات الكتالوج ({rewards.length})
          </button>
          <button
            onClick={() => setActiveTab('leaderboard')}
            className={`btn ${activeTab === 'leaderboard' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Award size={14} /> مستويات وتصنيف الكباتن ({captainRanks.length})
          </button>
          <button
            onClick={() => setActiveTab('ledger')}
            className={`btn ${activeTab === 'ledger' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Coins size={14} /> سجل حركة النقاط ({transactions.length})
          </button>
          <button
            onClick={() => setActiveTab('rules')}
            className={`btn ${activeTab === 'rules' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700' }}
          >
            <Sliders size={14} /> محرك احتساب النقاط
          </button>
        </div>

        {activeTab === 'ledger' && (
          <button
            onClick={handleExportLedger}
            className="btn btn-secondary"
            style={{ fontSize: '11.5px', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Download size={13} /> تصدير السجل CSV
          </button>
        )}
      </div>

      {/* ─── TAB 1: REWARDS CATALOG (باقات الكتالوج) ─── */}
      {activeTab === 'catalog' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          {isLoading ? (
            <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Loader2 size={28} color="#f59e0b" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 10px' }} />
              <div>جاري تحميل باقات المكافآت من Firebase...</div>
            </div>
          ) : rewards.length === 0 ? (
            <div className="glass-panel" style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Gift size={40} color="#64748b" style={{ margin: '0 auto 12px' }} />
              <div style={{ fontSize: '16px', fontWeight: '800', color: '#fff' }}>لا توجد باقات مكافآت معرّفة حالياً</div>
              <div style={{ fontSize: '12px', marginTop: '6px', marginBottom: '18px' }}>
                قم بإضافة أول باقة لتشجيع الكباتن على إنجاز المزيد من الرحلات
              </div>
              <button onClick={handleOpenCreateReward} className="btn btn-primary" style={{ fontSize: '13px' }}>
                + إضافة باقة مكافأة
              </button>
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
              {rewards.map(r => (
                <div
                  key={r.id}
                  className="glass-panel"
                  style={{
                    padding: '20px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    gap: '14px',
                    border: `1px solid ${r.isActive ? 'rgba(245, 158, 11, 0.3)' : 'rgba(239, 68, 68, 0.2)'}`,
                    background: r.isActive ? 'linear-gradient(135deg, rgba(245, 158, 11, 0.06) 0%, rgba(15, 23, 42, 0.8) 100%)' : 'rgba(15, 23, 42, 0.5)'
                  }}
                >
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'rgba(245, 158, 11, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#f59e0b' }}>
                          <Gift size={20} />
                        </div>
                        <div>
                          <h4 style={{ fontSize: '15px', fontWeight: '900', color: '#fff', margin: 0 }}>{r.title}</h4>
                          <span className={`badge ${r.isActive ? 'badge-success' : 'badge-danger'}`} style={{ fontSize: '9.5px', marginTop: '3px' }}>
                            {r.isActive ? 'متاحة للاستبدال ' : 'معطلة مؤقتاً '}
                          </span>
                        </div>
                      </div>

                      <div style={{ textAlign: 'left' }}>
                        <div style={{ fontSize: '18px', fontWeight: '950', color: '#facc15' }}>
                          {r.cost} 
                        </div>
                        <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>نقطة مطلوبة</div>
                      </div>
                    </div>

                    {r.description && (
                      <p style={{ fontSize: '12px', color: '#cbd5e1', marginTop: '12px', lineHeight: '1.5' }}>
                        {r.description}
                      </p>
                    )}

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '14px', padding: '10px', background: 'rgba(0,0,0,0.25)', borderRadius: '8px', fontSize: '11.5px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: 'var(--text-dim)' }}>نوع المكافأة:</span>
                        <span style={{ color: '#38bdf8', fontWeight: '700' }}>
                          {r.rewardType === 'commission_free_trips' ? `تصفير عمولة (${r.tripsCount || 3} رحلات)` : r.rewardType === 'commission_discount' ? `خصم عمولة ${r.discountPercent}%` : r.rewardType === 'fuel_voucher' ? 'كوبون وقود' : r.rewardType === 'cash_bonus' ? `رصيد محفظة (${formatIqd(r.cashValueIqd || 0)})` : 'مكافأة خاصة'}
                        </span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <span style={{ color: 'var(--text-dim)' }}>الفئة المستهدفة:</span>
                        <span style={{ color: '#fff' }}>{r.targetAudience === 'drivers' ? 'كباتن مدار ' : r.targetAudience === 'customers' ? 'الركاب والعملاء ' : 'الجميع '}</span>
                      </div>
                    </div>
                  </div>

                  {/* Card Actions */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '12px' }}>
                    <button
                      onClick={() => handleToggleReward(r)}
                      className="btn btn-secondary"
                      style={{ fontSize: '11px', padding: '4px 10px', color: r.isActive ? '#f87171' : '#34d399' }}
                    >
                      {r.isActive ? 'تعطيل' : 'تفعيل'}
                    </button>

                    <div style={{ display: 'flex', gap: '6px' }}>
                      <button
                        onClick={() => handleOpenEditReward(r)}
                        className="btn btn-secondary"
                        style={{ fontSize: '11px', padding: '4px 8px' }}
                        title="تعديل المكافأة"
                      >
                        <Edit3 size={13} color="#06b6d4" />
                      </button>
                      <button
                        onClick={() => handleDeleteReward(r)}
                        className="btn btn-secondary"
                        style={{ fontSize: '11px', padding: '4px 8px', color: '#ef4444' }}
                        title="حذف المكافأة"
                      >
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </div>

                </div>
              ))}
            </div>
          )}

        </div>
      )}

      {/* ─── TAB 2: CAPTAINS LEADERBOARD (تصنيف ومستويات الكباتن) ─── */}
      {activeTab === 'leaderboard' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          {/* Filters Bar */}
          <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
            <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
              <button onClick={() => setTierFilter('all')} className={`btn ${tierFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px' }}>
                 جميع المستويات ({captainRanks.length})
              </button>
              <button onClick={() => setTierFilter('diamond')} className={`btn ${tierFilter === 'diamond' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#38bdf8' }}>
                 الماسي ({captainRanks.filter(c => c.tier === 'diamond').length})
              </button>
              <button onClick={() => setTierFilter('gold')} className={`btn ${tierFilter === 'gold' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#facc15' }}>
                 الذهبي ({captainRanks.filter(c => c.tier === 'gold').length})
              </button>
              <button onClick={() => setTierFilter('silver')} className={`btn ${tierFilter === 'silver' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#94a3b8' }}>
                 الفضي ({captainRanks.filter(c => c.tier === 'silver').length})
              </button>
              <button onClick={() => setTierFilter('bronze')} className={`btn ${tierFilter === 'bronze' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#cd7f32' }}>
                 البرونزي ({captainRanks.filter(c => c.tier === 'bronze').length})
              </button>
            </div>

            <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '260px' }}>
              <Search size={15} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
              <input
                type="text"
                placeholder="ابحث باسم الكابتن أو الهاتف..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{ width: '100%', padding: '8px 34px 8px 10px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px' }}
              />
            </div>
          </div>

          {/* Leaderboard Table */}
          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>الترتيب</th>
                    <th>اسم الكابتن</th>
                    <th>رقم الهاتف</th>
                    <th>المركبة واللوحة</th>
                    <th>المستوى الفخري</th>
                    <th>رصيد النقاط </th>
                    <th>الرحلات المنفذة</th>
                    <th>التقييم</th>
                    <th>الإجراءات الإدارية</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRanks.map((c, idx) => (
                    <tr key={c.driverId}>
                      <td>
                        <span style={{
                          width: '26px',
                          height: '26px',
                          borderRadius: '50%',
                          display: 'inline-flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontWeight: '900',
                          fontSize: '12px',
                          background: idx === 0 ? '#f59e0b' : idx === 1 ? '#94a3b8' : idx === 2 ? '#cd7f32' : 'rgba(255,255,255,0.05)',
                          color: idx < 3 ? '#000' : '#fff'
                        }}>
                          {idx + 1}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{c.name}</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>#{c.driverId.slice(0, 6)}</div>
                      </td>
                      <td dir="ltr" style={{ fontSize: '12px' }}>{c.phone}</td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#cbd5e1' }}>{c.vehicleModel || 'سيارة أجرة'}</div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>{c.plateNumber || 'بدون لوحة'}</div>
                      </td>
                      <td>
                        <span style={{ padding: '3px 8px', borderRadius: '6px', fontSize: '11px', fontWeight: '800', background: `${c.tierColor}20`, color: c.tierColor, border: `1px solid ${c.tierColor}40` }}>
                          {c.tierArabic}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '950', color: '#facc15', fontSize: '14px' }}>
                          {c.rewardsPoints} 
                        </div>
                      </td>
                      <td>{c.totalTrips} رحلة</td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                          <Star size={13} color="#facc15" fill="#facc15" />
                          <span style={{ fontWeight: '800', color: '#facc15', fontSize: '12px' }}>{c.rating}</span>
                        </div>
                      </td>
                      <td>
                        <button
                          onClick={() => {
                            const found = drivers.find(d => d.driverId === c.driverId);
                            if (found) {
                              setGrantTargetDriver(found);
                              setShowGrantModal(true);
                            }
                          }}
                          className="btn btn-primary"
                          style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24' }}
                        >
                          <Gift size={12} /> إهداء نقاط
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

        </div>
      )}

      {/* ─── TAB 3: POINTS TRANSACTIONS LEDGER (سجل العمليات) ─── */}
      {activeTab === 'ledger' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          <div className="glass-panel" style={{ padding: '14px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
            <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
              <button onClick={() => setLedgerTypeFilter('all')} className={`btn ${ledgerTypeFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px' }}>
                 جميع الحركات ({transactions.length})
              </button>
              <button onClick={() => setLedgerTypeFilter('earned')} className={`btn ${ledgerTypeFilter === 'earned' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#34d399' }}>
                 نقاط مكتسبة من رحلات ({transactions.filter(t => t.type === 'earned').length})
              </button>
              <button onClick={() => setLedgerTypeFilter('redeemed')} className={`btn ${ledgerTypeFilter === 'redeemed' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#f87171' }}>
                 استبدال مكافآت ({transactions.filter(t => t.type === 'redeemed').length})
              </button>
              <button onClick={() => setLedgerTypeFilter('bonus_admin')} className={`btn ${ledgerTypeFilter === 'bonus_admin' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '12px', color: '#fbbf24' }}>
                 منح إدارية تشجيعية ({transactions.filter(t => t.type === 'bonus_admin').length})
              </button>
            </div>

            <div style={{ position: 'relative', display: 'flex', alignItems: 'center', minWidth: '260px' }}>
              <Search size={15} color="#94a3b8" style={{ position: 'absolute', right: '12px' }} />
              <input
                type="text"
                placeholder="ابحث باسم الكابتن أو البيان..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{ width: '100%', padding: '8px 34px 8px 10px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px' }}
              />
            </div>
          </div>

          <div className="glass-panel" style={{ padding: '0px', overflow: 'hidden' }}>
            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>تاريخ العملية</th>
                    <th>الكابتن / المستفيد</th>
                    <th>نوع الحركة</th>
                    <th>عدد النقاط</th>
                    <th>البيان والسبب</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTransactions.map(t => (
                    <tr key={t.id}>
                      <td style={{ fontSize: '12px', color: '#cbd5e1' }}>{t.createdAt}</td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff' }}>{t.driverName}</div>
                        {t.driverPhone && (
                          <div style={{ fontSize: '11px', color: 'var(--text-dim)' }} dir="ltr">{t.driverPhone}</div>
                        )}
                      </td>
                      <td>
                        <span className={`badge ${t.amount > 0 ? 'badge-success' : 'badge-danger'}`} style={{ fontSize: '11px' }}>
                          {t.type === 'earned' ? 'اكتساب رحلة ' : t.type === 'redeemed' ? 'استبدال مكافأة ' : t.type === 'bonus_admin' ? 'منحة إدارية ' : 'خصم إداري '}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: '950', color: t.amount > 0 ? '#34d399' : '#f87171', fontSize: '14px' }}>
                          {t.amount > 0 ? `+${t.amount}` : t.amount} 
                        </div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12.5px', color: '#fff' }}>{t.reason}</div>
                        {t.referenceId && (
                          <div style={{ fontSize: '10px', color: '#38bdf8', marginTop: '2px' }}>مرجع: #{t.referenceId.slice(0, 8)}</div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

        </div>
      )}

      {/* ─── TAB 4: AUTO POINTS RULES ENGINE (محرك احتساب النقاط) ─── */}
      {activeTab === 'rules' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          <div className="glass-panel" style={{ padding: '24px', maxWidth: '700px' }}>
            <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Zap size={18} color="#f59e0b" />
              <span>قواعد منح النقاط التلقائية للكباتن والركاب</span>
            </h3>
            <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', marginBottom: '20px' }}>
              يتم تطبيق هذه القواعد آلياً في الخلفية فور اكتمال أي رحلة أو طلب في تطبيق مدار
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: 'rgba(255,255,255,0.02)', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div>
                  <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> نقاط إكمال مشوار التكسي:</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>تمنح للكابتن فور ضغط زر "إتمام الرحلة"</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <input
                    type="number"
                    min="1"
                    max="100"
                    value={pointsPerRide}
                    onChange={e => setPointsPerRide(Number(e.target.value))}
                    style={{ width: '70px', padding: '6px', background: '#0f172a', border: '1px solid #06b6d4', borderRadius: '6px', color: '#fff', fontSize: '13px', textAlign: 'center', fontWeight: '800' }}
                  />
                  <span style={{ fontSize: '12px', color: '#facc15' }}>نقطة </span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: 'rgba(255,255,255,0.02)', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div>
                  <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> نقاط إكمال توصيل طلب مطعم / متجر:</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>تمنح لكابتن التوصيل عند تسليم الطلب للزبون</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <input
                    type="number"
                    min="1"
                    max="100"
                    value={pointsPerOrder}
                    onChange={e => setPointsPerOrder(Number(e.target.value))}
                    style={{ width: '70px', padding: '6px', background: '#0f172a', border: '1px solid #06b6d4', borderRadius: '6px', color: '#fff', fontSize: '13px', textAlign: 'center', fontWeight: '800' }}
                  />
                  <span style={{ fontSize: '12px', color: '#facc15' }}>نقطة </span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: 'rgba(255,255,255,0.02)', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div>
                  <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> بونص التقييم الممتاز (5 نجوم):</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>نقاط إضافية تمنح للكابتن عند حصوله على تقييم 5 نجوم</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <input
                    type="number"
                    min="0"
                    max="50"
                    value={fiveStarBonus}
                    onChange={e => setFiveStarBonus(Number(e.target.value))}
                    style={{ width: '70px', padding: '6px', background: '#0f172a', border: '1px solid #06b6d4', borderRadius: '6px', color: '#fff', fontSize: '13px', textAlign: 'center', fontWeight: '800' }}
                  />
                  <span style={{ fontSize: '12px', color: '#facc15' }}>نقطة </span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: 'rgba(255,255,255,0.02)', borderRadius: '10px', border: '1px solid var(--border-color)' }}>
                <div>
                  <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px' }}> بونص أوقات الذروة والمطر:</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>حوافز إضافية لتحفيز الكباتن على فتح التطبيق</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <input
                    type="number"
                    min="0"
                    max="50"
                    value={peakBonus}
                    onChange={e => setPeakBonus(Number(e.target.value))}
                    style={{ width: '70px', padding: '6px', background: '#0f172a', border: '1px solid #06b6d4', borderRadius: '6px', color: '#fff', fontSize: '13px', textAlign: 'center', fontWeight: '800' }}
                  />
                  <span style={{ fontSize: '12px', color: '#facc15' }}>نقطة </span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button
                  onClick={handleSaveRules}
                  disabled={isSavingRules}
                  className="btn btn-primary"
                  style={{ fontSize: '13px', fontWeight: '800', padding: '10px 24px', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8' }}
                >
                  {isSavingRules ? 'جاري الحفظ...' : 'حفظ وتحديث القواعد في المنظومة'}
                </button>
              </div>

            </div>
          </div>

        </div>
      )}

      {/* ─── MODAL 1: ADD / EDIT REWARD MODAL ─── */}
      {showRewardModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '540px', width: '100%', borderRadius: '24px', border: '1px solid rgba(245, 158, 11, 0.4)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0 }}>
                {editingReward ? 'تعديل بيانات باقة المكافأة' : 'إضافة باقة مكافأة جديدة إلى الكتالوج '}
              </h3>
              <button onClick={() => setShowRewardModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveReward} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>عنوان المكافأة:</label>
                <input
                  type="text"
                  placeholder="مثال: تصفير عمولة 3 رحلات تكسي"
                  value={rewardTitle}
                  onChange={e => setRewardTitle(e.target.value)}
                  required
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>الوصف والشروط:</label>
                <textarea
                  rows={2}
                  placeholder="وصف تفصيلي يظهر للكابتن داخل التطبيق..."
                  value={rewardDesc}
                  onChange={e => setRewardDesc(e.target.value)}
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>التكلفة بالنقاط :</label>
                  <input
                    type="number"
                    min="10"
                    step="10"
                    value={rewardCost}
                    onChange={e => setRewardCost(Number(e.target.value))}
                    required
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#facc15', fontSize: '13px', fontWeight: '800' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>نوع المكافأة:</label>
                  <select
                    value={rewardType}
                    onChange={e => setRewardType(e.target.value as any)}
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px' }}
                  >
                    <option value="commission_free_trips">تصفير عمولة لعدد من الرحلات</option>
                    <option value="commission_discount">خصم نسبة مئوية من العمولة (%)</option>
                    <option value="fuel_voucher">كوبون وقود ومحروقات</option>
                    <option value="cash_bonus">شحن رصيد مالي في المحفظة</option>
                    <option value="custom">مكافأة خاصة / عينية</option>
                  </select>
                </div>
              </div>

              {rewardType === 'commission_free_trips' && (
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>عدد الرحلات المعفاة من العمولة:</label>
                  <input
                    type="number"
                    min="1"
                    max="20"
                    value={tripsCount}
                    onChange={e => setTripsCount(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                  />
                </div>
              )}

              {rewardType === 'commission_discount' && (
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>نسبة الخصم من العمولة (%):</label>
                  <input
                    type="number"
                    min="10"
                    max="100"
                    value={discountPercent}
                    onChange={e => setDiscountPercent(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '13px' }}
                  />
                </div>
              )}

              {rewardType === 'cash_bonus' && (
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>المبلغ المالي المضاف للمحفظة (د.ع):</label>
                  <input
                    type="number"
                    min="1000"
                    step="1000"
                    value={cashValueIqd}
                    onChange={e => setCashValueIqd(Number(e.target.value))}
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#34d399', fontSize: '13px', fontWeight: '800' }}
                  />
                </div>
              )}

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>الفئة المستهدفة:</label>
                <select
                  value={targetAudience}
                  onChange={e => setTargetAudience(e.target.value as any)}
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px' }}
                >
                  <option value="drivers">كباتن التوصيل والتكسي فقط </option>
                  <option value="customers">الزبائن والركاب فقط </option>
                  <option value="all">الجميع </option>
                </select>
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button
                  type="submit"
                  disabled={isSubmittingReward}
                  className="btn btn-primary"
                  style={{ fontSize: '13px', fontWeight: '800', padding: '10px 24px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24' }}
                >
                  {isSubmittingReward ? 'جاري الحفظ...' : editingReward ? 'تحديث المكافأة' : 'إضافة المكافأة للكتالوج'}
                </button>
                <button
                  type="button"
                  onClick={() => setShowRewardModal(false)}
                  className="btn btn-secondary"
                  style={{ fontSize: '13px' }}
                >
                  إلغاء
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

      {/* ─── MODAL 2: MANUAL GRANT / DEDUCTION MODAL ─── */}
      {showGrantModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '20px' }}>
          <div className="glass-panel" style={{ padding: '28px', maxWidth: '500px', width: '100%', borderRadius: '24px', border: '1px solid rgba(251, 191, 36, 0.4)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '17px', fontWeight: '900', color: '#fff', margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Sparkles size={18} color="#fbbf24" />
                <span>إهداء أو تعديل نقاط المكافآت يدوياً</span>
              </h3>
              <button onClick={() => setShowGrantModal(false)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveGrant} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>اختر الكابتن المستهدف:</label>
                <select
                  value={grantTargetDriver ? grantTargetDriver.driverId : ''}
                  onChange={e => {
                    const d = drivers.find(drv => drv.driverId === e.target.value);
                    setGrantTargetDriver(d || null);
                  }}
                  required
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }}
                >
                  <option value="">-- اختر الكابتن --</option>
                  {drivers.map(d => (
                    <option key={d.driverId} value={d.driverId}>
                      {d.name} ({d.phoneNumber}) • {d.vehicleModel || 'سيارة'}
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>نوع العملية:</label>
                  <select
                    value={grantType}
                    onChange={e => setGrantType(e.target.value as any)}
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: grantType === 'bonus_admin' ? '#34d399' : '#f87171', fontSize: '12.5px', fontWeight: '800' }}
                  >
                    <option value="bonus_admin">منحة إدارية تشجيعية (+)</option>
                    <option value="penalty">خصم نقاط لمخالفة (-)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>عدد النقاط :</label>
                  <input
                    type="number"
                    min="5"
                    step="5"
                    value={grantPointsAmount}
                    onChange={e => setGrantPointsAmount(Number(e.target.value))}
                    required
                    style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#facc15', fontSize: '13px', fontWeight: '800' }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: 'var(--text-dim)', marginBottom: '5px' }}>سبب المنح / البيان:</label>
                <input
                  type="text"
                  placeholder="مثال: مكافأة تميز في ساعات الذروة، إنجاز 100 رحلة، إلخ..."
                  value={grantReason}
                  onChange={e => setGrantReason(e.target.value)}
                  style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12.5px' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '10px' }}>
                <button
                  type="submit"
                  disabled={isSubmittingGrant}
                  className="btn btn-primary"
                  style={{ fontSize: '13px', fontWeight: '800', padding: '10px 24px', background: 'linear-gradient(135deg, #f59e0b, #d97706)', borderColor: '#fbbf24' }}
                >
                  {isSubmittingGrant ? 'جاري التنفيذ...' : 'تأكيد العملية'}
                </button>
                <button
                  type="button"
                  onClick={() => setShowGrantModal(false)}
                  className="btn btn-secondary"
                  style={{ fontSize: '13px' }}
                >
                  إلغاء
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

    </div>
  );
};
