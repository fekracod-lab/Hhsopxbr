import React from 'react';
import {
  LayoutDashboard,
  Navigation,
  Car,
  Users,
  Store,
  ShoppingBag,
  HeartPulse,
  Wallet,
  ShieldAlert,
  Activity,
  LifeBuoy,
  Lock,
  FileText,
  Bell,
  MessageSquare,
  MapPin,
  Tag,
  ToggleLeft,
  Settings,
  UserCheck,
  BarChart3,
  Gift,
  Headphones,
  Sparkles
} from 'lucide-react';
import { useAuth } from '../../application/AuthContext';

export interface NavItem {
  id: string;
  label: string;
  icon: React.ElementType;
  section: string;
  permission?: string;
  badge?: number | string;
  badgeColor?: string;
}

export const navItems: NavItem[] = [
  // 1. Core
  { id: 'dashboard', label: 'لوحة المؤشرات العامة', icon: LayoutDashboard, section: 'الرئيسية' },
  { id: 'operations', label: 'مركز العمليات والرادار المباشر', icon: Navigation, section: 'الرئيسية', badge: 'Live', badgeColor: '#10B981' },
  
  // 2. Actors & Fleet
  { id: 'registration_requests', label: 'طلبات الانضمام والتوثيق (KYC)', icon: UserCheck, section: 'الأسطول والشركاء', badge: 'جديد', badgeColor: '#F59E0B' },
  { id: 'taxi_captains', label: 'كباتن التكسي (سيارات الركاب )', icon: Car, section: 'الأسطول والشركاء' },
  { id: 'delivery_couriers', label: 'مندوبي ودراجات التوصيل (مرسال )', icon: Navigation, section: 'الأسطول والشركاء' },
  { id: 'restaurants', label: 'المطاعم والكافيهات', icon: Store, section: 'الأسطول والشركاء' },
  { id: 'stores', label: 'المتاجر والهايبرماركت', icon: ShoppingBag, section: 'الأسطول والشركاء' },
  { id: 'customers', label: 'إدارة العملاء والركاب', icon: Users, section: 'الأسطول والشركاء' },
  { id: 'rewards', label: 'نظام المكافئات ونقاط الولاء', icon: Gift, section: 'الأسطول والشركاء', badge: 'نقاط', badgeColor: '#EC407A' },
  
  // 3. Commerce & Services
  { id: 'rides', label: 'مشاوير ورحلات التكسي (Taxi)', icon: Car, section: 'الخدمات اللوجستية' },
  { id: 'orders', label: 'طلبات التوصيل والمسواك', icon: Navigation, section: 'الخدمات اللوجستية' },
  { id: 'coupons', label: 'كوبونات وقسائم الخصم', icon: Tag, section: 'الخدمات اللوجستية', badge: 'خصومات', badgeColor: '#8B5CF6' },
  { id: 'health', label: 'الخدمات الطبية والإسعاف', icon: HeartPulse, section: 'الخدمات اللوجستية' },

  // 4. Financial & Integrity
  { id: 'reports', label: 'التقارير والمحاسبة الرسمية', icon: BarChart3, section: 'الإدارة والرقابة', badge: 'PDF', badgeColor: '#00BFA5' },
  { id: 'finance', label: 'المالية والمحافظ والتسويات', icon: Wallet, section: 'الإدارة والرقابة', permission: 'finance.manage' },
  { id: 'risk', label: 'المخاطر ومكافحة الاحتيال', icon: ShieldAlert, section: 'الإدارة والرقابة' },
  
  // 5. Communications & Support
  { id: 'live_support', label: 'محادثات الدعم الفني المباشرة', icon: Headphones, section: 'التواصل والدعم', badge: 'شات ', badgeColor: '#0284C7' },
  { id: 'complaints', label: 'بلاغات الشكاوى والمقترحات', icon: MessageSquare, section: 'التواصل والدعم' },
  { id: 'notifications', label: 'مركز الإشعارات والتعاميم', icon: Bell, section: 'التواصل والدعم' },

  // 6. Engineering Kernel & Security
  { id: 'security', label: 'الأمان وانعدام الثقة (Zero-Trust)', icon: Lock, section: 'الأنظمة والنواة', badge: 'Enforced', badgeColor: '#10B981' },
  { id: 'observability', label: 'المراقبة والتتبع الموزع', icon: Activity, section: 'الأنظمة والنواة' },
  { id: 'resilience', label: 'الصمود ومقاومة الانهيار', icon: LifeBuoy, section: 'الأنظمة والنواة' },
  { id: 'audit', label: 'سجل التدقيق وسلسلة النزاهة', icon: FileText, section: 'الأنظمة والنواة' },

  // 7. System Governance
  { id: 'pricing', label: 'التسعير والعمولات والمناطق', icon: Tag, section: 'الإعدادات والسياسات' },
  { id: 'settings', label: 'إعدادات النظام العامة', icon: Settings, section: 'الإعدادات والسياسات' },
  { id: 'admin_users', label: 'المشرفين والصلاحيات (RBAC)', icon: UserCheck, section: 'الإعدادات والسياسات', permission: 'admin.manage' },
];

export const Sidebar: React.FC<{ activeTab: string; onSelectTab: (id: string) => void }> = ({ activeTab, onSelectTab }) => {
  const { hasPermission } = useAuth();

  const sections = Array.from(new Set(navItems.map(item => item.section)));

  return (
    <aside style={{ width: '280px', height: '100vh', background: 'var(--bg-secondary)', borderLeft: '1px solid var(--border-color)', display: 'flex', flexDirection: 'column' }}>
      {/* Brand Header */}
      <div style={{ padding: '18px 20px', borderBottom: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div style={{ width: '42px', height: '42px', borderRadius: '12px', background: 'linear-gradient(135deg, #00BFA5 0%, #00897B 100%)', padding: '2px', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 18px var(--primary-glow)' }}>
          <img 
            src="/imges/app_icon.png" 
            alt="Madar Logo" 
            style={{ width: '100%', height: '100%', borderRadius: '10px', objectFit: 'cover' }}
            onError={(e) => {
              (e.target as HTMLElement).style.display = 'none';
            }}
          />
        </div>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <h1 style={{ fontSize: '18px', fontWeight: '900', color: '#fff', letterSpacing: '-0.02em' }}>منظومة مـدار</h1>
            <span style={{ fontSize: '9px', fontWeight: '800', background: 'var(--primary-soft)', color: '#00BFA5', padding: '1px 6px', borderRadius: '4px', border: '1px solid var(--border-highlight)' }}>v8.15</span>
          </div>
          <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Enterprise Control Plane</p>
        </div>
      </div>

      {/* Nav List */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 12px' }}>
        {sections.map(section => {
          const itemsInSection = navItems.filter(item => item.section === section && (!item.permission || hasPermission(item.permission)));
          if (itemsInSection.length === 0) return null;

          return (
            <div key={section} style={{ marginBottom: '18px' }}>
              <div style={{ padding: '4px 12px', fontSize: '10.5px', fontWeight: '800', color: 'var(--text-dim)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                {section}
              </div>
              <div style={{ marginTop: '6px', display: 'flex', flexDirection: 'column', gap: '2px' }}>
                {itemsInSection.map(item => {
                  const Icon = item.icon;
                  const isActive = activeTab === item.id;

                  return (
                    <button
                      key={item.id}
                      onClick={() => onSelectTab(item.id)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        width: '100%',
                        padding: '9px 12px',
                        borderRadius: '10px',
                        border: isActive ? '1px solid var(--border-highlight)' : '1px solid transparent',
                        background: isActive ? 'linear-gradient(90deg, rgba(0, 191, 165, 0.16) 0%, rgba(0, 191, 165, 0.04) 100%)' : 'transparent',
                        color: isActive ? '#00BFA5' : 'var(--text-sub)',
                        fontWeight: isActive ? '800' : '500',
                        fontSize: '12.5px',
                        cursor: 'pointer',
                        textAlign: 'right',
                        transition: 'all 0.15s ease',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <Icon size={17} color={isActive ? '#00BFA5' : '#64748B'} />
                        <span>{item.label}</span>
                      </div>
                      {item.badge && (
                        <span style={{ fontSize: '10px', fontWeight: '700', padding: '2px 6px', borderRadius: '6px', background: item.badgeColor ? `${item.badgeColor}22` : 'rgba(255, 255, 255, 0.08)', color: item.badgeColor || 'var(--text-muted)', border: item.badgeColor ? `1px solid ${item.badgeColor}44` : 'none' }}>
                          {item.badge}
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </aside>
  );
};
