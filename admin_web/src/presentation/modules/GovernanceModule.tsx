import React, { useState, useEffect } from 'react';
import {
  Settings,
  MapPin,
  Tag,
  ToggleLeft,
  UserCheck,
  Plus,
  Check,
  AlertCircle,
  Loader2,
  Save,
  Shield,
  Layers
} from 'lucide-react';
import { 
  GovernanceRepository, 
  PricingConfig, 
  RegionRecord 
} from '../../infrastructure/repositories/GovernanceRepository';
import { AdminUser, MadarRole } from '../../domain/types';

export const GovernanceModule: React.FC<{ initialSection?: 'regions' | 'pricing' | 'feature_flags' | 'settings' | 'admin_users' }> = ({ initialSection = 'regions' }) => {
  const [activeSection, setActiveSection] = useState(initialSection);

  // Pricing State
  const [pricing, setPricing] = useState<PricingConfig>({
    baseFareIqd: 3000,
    baseDistanceKm: 2.0,
    perKmPriceIqd: 650,
    taxiCommissionPercent: 10,
    restaurantCommissionPercent: 10,
    storeCommissionPercent: 7,
    parcelCommissionPercent: 10,
    fixedDeliveryFeeIqd: 2000
  });
  const [isSavingPricing, setIsSavingPricing] = useState(false);

  // Regions State
  const [regions, setRegions] = useState<RegionRecord[]>([]);
  const [isLoadingRegions, setIsLoadingRegions] = useState(true);

  // Admins State
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [isLoadingAdmins, setIsLoadingAdmins] = useState(true);

  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  useEffect(() => {
    const unsubPricing = GovernanceRepository.subscribeToPricing((data) => {
      setPricing(data);
    });

    const unsubRegions = GovernanceRepository.subscribeToRegions((data) => {
      setRegions(data);
      setIsLoadingRegions(false);
    });

    const unsubAdmins = GovernanceRepository.subscribeToAdmins((data) => {
      setAdmins(data);
      setIsLoadingAdmins(false);
    });

    return () => {
      unsubPricing();
      unsubRegions();
      unsubAdmins();
    };
  }, []);

  const handleSavePricing = async () => {
    setIsSavingPricing(true);
    try {
      await GovernanceRepository.savePricing(pricing);
      showToast('تم حفظ قواعد التسعير والعمولات الجديدة في Firestore بنجاح ');
    } catch (err: any) {
      showToast('فشل حفظ التسعير: ' + (err.message || ''), 'error');
    } finally {
      setIsSavingPricing(false);
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
            <Settings size={22} color="#06b6d4" /> الحوكمة، السياسات، التسعير والمناطق
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            إدارة النطاقات الجغرافية لقضاء القائم والأنبار، تعرفة الكيلومتر والحد الأدنى، مفاتيح الميزات، وصلاحيات المشرفين
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div className="glass-panel" style={{ padding: '12px 20px', display: 'flex', gap: '10px' }}>
        <button
          onClick={() => setActiveSection('pricing')}
          className={`btn ${activeSection === 'pricing' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px' }}
        >
          التسعير والعمولات 
        </button>
        <button
          onClick={() => setActiveSection('regions')}
          className={`btn ${activeSection === 'regions' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px' }}
        >
          المحافظات والمناطق ({regions.length})
        </button>
        <button
          onClick={() => setActiveSection('admin_users')}
          className={`btn ${activeSection === 'admin_users' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px' }}
        >
          المشرفين والصلاحيات ({admins.length})
        </button>
        <button
          onClick={() => setActiveSection('feature_flags')}
          className={`btn ${activeSection === 'feature_flags' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px' }}
        >
          مفاتيح الميزات (Feature Flags) 
        </button>
      </div>

      {/* ─── 1. Pricing & Commission Matrix ─── */}
      {activeSection === 'pricing' && (
        <div className="glass-panel" style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', margin: 0 }}>
                قواعد التسعير والعمولات المعتمدة (Firestore Live Pricing Engine)
              </h3>
              <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '4px 0 0' }}>
                القيم المطبقة حالياً في التطبيق السحابي مع إمكانية التعديل والحفظ المباشر
              </p>
            </div>
            <button
              onClick={handleSavePricing}
              disabled={isSavingPricing}
              className="btn btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              {isSavingPricing ? <Loader2 size={16} style={{ animation: 'spin 1s linear infinite' }} /> : <Save size={16} />}
              <span>حفظ التعديلات في Firestore</span>
            </button>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
            {/* Base Fare */}
            <div style={{ padding: '16px', borderRadius: '12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                الحد الأدنى لفتح العداد الأساسي (د.ع)
              </label>
              <input
                type="number"
                value={pricing.baseFareIqd}
                onChange={(e) => setPricing({ ...pricing, baseFareIqd: Number(e.target.value) })}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '16px', fontWeight: '800' }}
              />
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>يشمل مسافة أول 2.0 كم</div>
            </div>

            {/* Per KM Price */}
            <div style={{ padding: '16px', borderRadius: '12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                سعر الكيلومتر الإضافي (د.ع / كم)
              </label>
              <input
                type="number"
                value={pricing.perKmPriceIqd}
                onChange={(e) => setPricing({ ...pricing, perKmPriceIqd: Number(e.target.value) })}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#38bdf8', fontSize: '16px', fontWeight: '800' }}
              />
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>يحسب تلقائياً من خريطة المسار</div>
            </div>

            {/* Taxi Commission */}
            <div style={{ padding: '16px', borderRadius: '12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                عمولة التطبيق على التكسي (%)
              </label>
              <input
                type="number"
                value={pricing.taxiCommissionPercent}
                onChange={(e) => setPricing({ ...pricing, taxiCommissionPercent: Number(e.target.value) })}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#34d399', fontSize: '16px', fontWeight: '800' }}
              />
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>تخصم تلقائياً من محفظة الكابتن</div>
            </div>

            {/* Restaurant Commission */}
            <div style={{ padding: '16px', borderRadius: '12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                عمولة التطبيق على المطاعم (%)
              </label>
              <input
                type="number"
                value={pricing.restaurantCommissionPercent}
                onChange={(e) => setPricing({ ...pricing, restaurantCommissionPercent: Number(e.target.value) })}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#34d399', fontSize: '16px', fontWeight: '800' }}
              />
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>تخصم من قيمة فواتير الطعام</div>
            </div>

            {/* Store Commission */}
            <div style={{ padding: '16px', borderRadius: '12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                عمولة التطبيق على المتاجر والسوبرماركت (%)
              </label>
              <input
                type="number"
                value={pricing.storeCommissionPercent}
                onChange={(e) => setPricing({ ...pricing, storeCommissionPercent: Number(e.target.value) })}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fbbf24', fontSize: '16px', fontWeight: '800' }}
              />
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>نسبة مبيعات المتاجر والمحلات</div>
            </div>

            {/* Fixed Delivery Fee */}
            <div style={{ padding: '16px', borderRadius: '12px', background: 'var(--bg-surface)', border: '1px solid var(--border-color)' }}>
              <label style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'block', marginBottom: '6px' }}>
                رسوم التوصيل الثابت للمطاعم (د.ع)
              </label>
              <input
                type="number"
                value={pricing.fixedDeliveryFeeIqd}
                onChange={(e) => setPricing({ ...pricing, fixedDeliveryFeeIqd: Number(e.target.value) })}
                style={{ width: '100%', padding: '10px', background: '#0f172a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: '#fff', fontSize: '16px', fontWeight: '800' }}
              />
              <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>أجرة دليفري الكابتن الأساسية</div>
            </div>
          </div>
        </div>
      )}

      {/* ─── 2. Regions & Governorates ─── */}
      {activeSection === 'regions' && (
        <div className="glass-panel" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '10px' }}>
            <div>
              <h3 style={{ fontSize: '16px', fontWeight: '800', color: '#fff', margin: 0 }}>
                المحافظات والمناطق المسجلة في المنظومة ({regions.length} محافظة ومنطقة)
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', margin: '3px 0 0' }}>
                رصد أعداد المستخدمين والكباتن والمتاجر والطلبات النشطة في كل محافظة، وإدارة تفعيل التغطية ورسوم التوصيل
              </p>
            </div>
          </div>

          {isLoadingRegions ? (
            <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
              <div>جاري جلب إحصائيات المحافظات...</div>
            </div>
          ) : (
            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>المحافظة والمنطقة</th>
                    <th>المستخدمين والزبائن </th>
                    <th>الكباتن والأسطول </th>
                    <th>المتاجر والمطاعم </th>
                    <th>الطلبات النشطة </th>
                    <th>رسوم التوصيل الأساسية</th>
                    <th>حالة التغطية والخدمة</th>
                  </tr>
                </thead>
                <tbody>
                  {regions.map(r => (
                    <tr key={r.id}>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fff', fontSize: '13.5px' }}>{r.name}</div>
                        <div style={{ fontSize: '11px', color: '#38bdf8' }}>محافظة {r.governorateName}</div>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#38bdf8', fontSize: '13px' }}>
                          {r.usersCount || 0} مستخدم
                        </div>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#fbbf24', fontSize: '13px' }}>
                          {r.driversCount || 0} كابتن
                        </div>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: '#34d399', fontSize: '13px' }}>
                          {r.merchantsCount || 0} شريك
                        </div>
                      </td>
                      <td>
                        <div style={{ fontWeight: '800', color: (r.activeOrdersCount || 0) > 0 ? '#34d399' : 'var(--text-dim)', fontSize: '13px' }}>
                          {r.activeOrdersCount || 0} طلب نشط
                        </div>
                      </td>
                      <td>
                        <span style={{ fontWeight: '800', color: '#fff', fontSize: '12.5px' }}>
                          {r.fixedDeliveryFeeIqd ? `${new Intl.NumberFormat('ar-IQ').format(r.fixedDeliveryFeeIqd)} د.ع` : '2,500 د.ع'}
                        </span>
                      </td>
                      <td>
                        <button
                          onClick={async () => {
                            const next = r.status === 'active' ? 'inactive' : 'active';
                            await GovernanceRepository.toggleRegionStatus(r.id, next);
                            showToast(`تم ${next === 'active' ? 'تفعيل' : 'تعطيل'} التغطية في منطقة (${r.name})`);
                          }}
                          style={{
                            padding: '5px 12px',
                            borderRadius: '8px',
                            fontSize: '11.5px',
                            fontWeight: '800',
                            cursor: 'pointer',
                            background: r.status === 'active' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                            color: r.status === 'active' ? '#34d399' : '#f87171',
                            border: `1px solid ${r.status === 'active' ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`
                          }}
                        >
                          {r.status === 'active' ? 'التغطية مفعّلة ' : 'التغطية متوقفة '}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ─── 3. Admin Users (RBAC) ─── */}
      {activeSection === 'admin_users' && (
        <div className="glass-panel" style={{ padding: '20px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '700', color: '#fff', marginBottom: '16px' }}>
            قائمة المشرفين المعتمدين وصلاحيات الـ RBAC من Firestore
          </h3>
          
          {isLoadingAdmins ? (
            <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
              <Loader2 size={24} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px' }} />
              <div>جاري جلب حسابات الأدمن...</div>
            </div>
          ) : (
            <div className="data-table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>المشرف</th>
                    <th>البريد الإلكتروني</th>
                    <th>الدور الإداري (Role)</th>
                    <th>حالة التوثيق</th>
                  </tr>
                </thead>
                <tbody>
                  {admins.map(adm => (
                    <tr key={adm.uid}>
                      <td>
                        <div style={{ fontWeight: '700', color: '#fff' }}>{adm.name}</div>
                        <code style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>UID: {adm.uid.substring(0, 10)}</code>
                      </td>
                      <td>{adm.email}</td>
                      <td>
                        <span className={`badge ${adm.role === 'super_admin' ? 'badge-info' : 'badge-neutral'}`}>
                          {adm.role}
                        </span>
                      </td>
                      <td>
                        <span className="badge badge-success">معتمد وموثق </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ─── 4. Feature Flags ─── */}
      {activeSection === 'feature_flags' && (
        <div className="glass-panel" style={{ padding: '20px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '700', color: '#fff', marginBottom: '16px' }}>
            مفاتيح الميزات الفورية (Dynamic Feature Toggles)
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {[
              { key: 'enable_taxi_captain_live_tracking', label: 'تتبع كابتن التكسي الحي على الخريطة للعميل', enabled: true },
              { key: 'enable_store_order_inventory_lock', label: 'قفل المخزون الذري لطلبات المتاجر لمنع البيع المزدوج', enabled: true },
              { key: 'enable_zero_trust_wallet_shield', label: 'حظر التعديل المالي المباشر وتفعيل درع Zero-Trust', enabled: true },
              { key: 'enable_health_ambulance_service', label: 'تفعيل خدمة طلب سيارات الإسعاف والخدمات الطبية', enabled: true },
            ].map(f => (
              <div key={f.key} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: 'var(--bg-surface)', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
                <div>
                  <div style={{ fontWeight: '700', color: '#fff', fontSize: '13px' }}>{f.label}</div>
                  <code style={{ fontSize: '11px', color: 'var(--text-dim)' }}>{f.key}</code>
                </div>
                <span className="badge badge-success">مفعل في الإنتاج </span>
              </div>
            ))}
          </div>
        </div>
      )}

    </div>
  );
};
