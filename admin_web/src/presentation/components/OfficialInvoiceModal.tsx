import React, { useRef } from 'react';
import { 
  Printer, 
  X, 
  Download, 
  CheckCircle2, 
  ShieldCheck, 
  QrCode, 
  MapPin, 
  Phone, 
  Calendar, 
  Receipt,
  FileText,
  Clock,
  Car,
  UtensilsCrossed,
  Store
} from 'lucide-react';

export interface InvoiceItem {
  name: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  notes?: string;
}

export interface OfficialInvoiceData {
  documentNumber: string; // e.g. "INV-2026-0892"
  documentType: 'order' | 'taxi_ride' | 'payout' | 'general';
  documentTitle: string; // e.g. "فاتورة طلب وجبة طعام رسمية"
  date: string;
  time: string;
  
  // Parties
  customerName: string;
  customerPhone?: string;
  customerAddress?: string;

  providerName: string; // Merchant or Captain
  providerPhone?: string;
  providerRole?: string; // "مطعم", "متجر", "كابتن تكسي"
  
  // Financial Details
  items: InvoiceItem[];
  subtotalIqd: number;
  deliveryFeeIqd: number;
  discountIqd: number;
  totalIqd: number;
  paymentMethod: string; // "كاش عند الاستلام" / "رصيد محفظة مدار"
  paymentStatus: 'paid' | 'pending' | 'settled';

  // Notes
  notes?: string;
}

interface OfficialInvoiceModalProps {
  data: OfficialInvoiceData | null;
  onClose: () => void;
}

export const OfficialInvoiceModal: React.FC<OfficialInvoiceModalProps> = ({ data, onClose }) => {
  if (!data) return null;

  const handlePrint = () => {
    window.print();
  };

  const formatIqd = (amount: number) => {
    return new Intl.NumberFormat('ar-IQ').format(Math.round(amount)) + ' د.ع';
  };

  return (
    <div 
      className="no-print-overlay"
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.85)',
        backdropFilter: 'blur(10px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 99999,
        padding: '20px',
        overflowY: 'auto'
      }}
    >
      <div 
        style={{
          width: '100%',
          maxWidth: '820px',
          maxHeight: '92vh',
          display: 'flex',
          flexDirection: 'column',
          borderRadius: '20px',
          background: 'var(--bg-surface)',
          border: '1px solid var(--border-color)',
          boxShadow: '0 25px 60px rgba(0, 0, 0, 0.6)',
          overflow: 'hidden'
        }}
      >
        {/* Modal Action Bar (Hidden on print) */}
        <div 
          className="no-print"
          style={{
            padding: '16px 24px',
            borderBottom: '1px solid var(--border-color)',
            background: 'var(--bg-secondary)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '32px', height: '32px', borderRadius: '8px', background: 'var(--primary-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#00BFA5' }}>
              <Receipt size={18} />
            </div>
            <div>
              <div style={{ fontSize: '14px', fontWeight: '800', color: '#fff' }}>معاينة المستند والفاتورة الرسمية</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>رقم المرجع: {data.documentNumber}</div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <button 
              onClick={handlePrint}
              className="btn btn-primary"
              style={{ padding: '8px 18px', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px' }}
            >
              <Printer size={16} /> طباعة / تصدير PDF
            </button>
            <button 
              onClick={onClose}
              style={{
                background: 'rgba(255, 255, 255, 0.05)',
                border: 'none',
                color: '#94A3B8',
                borderRadius: '8px',
                padding: '8px',
                cursor: 'pointer'
              }}
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Printable Formal Document Content */}
        <div 
          style={{
            flex: 1,
            overflowY: 'auto',
            padding: '30px',
            background: '#ffffff',
            color: '#0f172a'
          }}
        >
          <div 
            className="printable-document"
            style={{
              fontFamily: "'IBM Plex Sans Arabic', sans-serif",
              direction: 'rtl',
              color: '#0f172a'
            }}
          >
            {/* ─── 1. OFFICIAL HEADER ─── */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2.5px solid #00BFA5', paddingBottom: '20px', marginBottom: '20px' }}>
              
              {/* Logo & Company Title */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <img 
                  src="/imges/app_icon.png" 
                  alt="Madar Logo" 
                  style={{ width: '64px', height: '64px', borderRadius: '12px', objectFit: 'cover' }}
                  onError={(e) => {
                    (e.target as HTMLElement).style.display = 'none';
                  }}
                />
                <div>
                  <h1 style={{ fontSize: '22px', fontWeight: '900', color: '#00897B', margin: 0, letterSpacing: '-0.02em' }}>
                    منظومة مـدار (MADAR)
                  </h1>
                  <div style={{ fontSize: '12px', fontWeight: '700', color: '#475569', marginTop: '2px' }}>
                    للخدمات اللوجستية والتجارة الإلكترونية ونقل الركاب
                  </div>
                  <div style={{ fontSize: '11px', color: '#64748B' }}>
                    الفرع الرئيسي: محافظة الأنبار — قضاء القائم
                  </div>
                </div>
              </div>

              {/* Invoice Meta Box */}
              <div style={{ textAlign: 'left', minWidth: '220px' }}>
                <div style={{ display: 'inline-block', background: '#E6F8F5', border: '1px solid #00BFA5', padding: '4px 12px', borderRadius: '6px', fontSize: '12px', fontWeight: '800', color: '#00897B', marginBottom: '6px' }}>
                  {data.documentTitle}
                </div>
                <div style={{ fontSize: '12px', fontWeight: '800', color: '#0f172a' }}>
                  الرقم المرجعي: <span style={{ fontFamily: 'monospace', color: '#0284C7' }}>{data.documentNumber}</span>
                </div>
                <div style={{ fontSize: '11px', color: '#64748B', marginTop: '2px' }}>
                  تاريخ الإصدار: {data.date} • {data.time}
                </div>
              </div>
            </div>

            {/* ─── 2. PARTIES DETAILS ─── */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '22px', background: '#F8FAFC', padding: '16px', borderRadius: '12px', border: '1px solid #E2E8F0' }}>
              <div>
                <div style={{ fontSize: '11px', fontWeight: '800', color: '#00897B', textTransform: 'uppercase', marginBottom: '4px' }}>
                   بيانات العميل / المستلم:
                </div>
                <div style={{ fontSize: '14px', fontWeight: '800', color: '#0f172a' }}>{data.customerName}</div>
                {data.customerPhone && (
                  <div style={{ fontSize: '12px', color: '#475569', marginTop: '2px' }} dir="ltr">
                     {data.customerPhone}
                  </div>
                )}
                {data.customerAddress && (
                  <div style={{ fontSize: '11.5px', color: '#64748B', marginTop: '2px' }}>
                     {data.customerAddress}
                  </div>
                )}
              </div>

              <div>
                <div style={{ fontSize: '11px', fontWeight: '800', color: '#00897B', textTransform: 'uppercase', marginBottom: '4px' }}>
                   مقدم الخدمة / الشريك ({data.providerRole || 'الشريك'}):
                </div>
                <div style={{ fontSize: '14px', fontWeight: '800', color: '#0f172a' }}>{data.providerName}</div>
                {data.providerPhone && (
                  <div style={{ fontSize: '12px', color: '#475569', marginTop: '2px' }} dir="ltr">
                     {data.providerPhone}
                  </div>
                )}
                <div style={{ fontSize: '11.5px', color: '#64748B', marginTop: '2px' }}>
                  طريقة الدفع: <span style={{ fontWeight: '700', color: '#059669' }}>{data.paymentMethod}</span>
                </div>
              </div>
            </div>

            {/* ─── 3. ITEMIZATION TABLE ─── */}
            <div style={{ marginBottom: '24px' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
                <thead>
                  <tr style={{ background: '#00BFA5', color: '#ffffff' }}>
                    <th style={{ padding: '10px 14px', textAlign: 'right', borderTopRightRadius: '6px' }}>#</th>
                    <th style={{ padding: '10px 14px', textAlign: 'right' }}>بيان الصنف / الخدمة</th>
                    <th style={{ padding: '10px 14px', textAlign: 'center' }}>الكمية</th>
                    <th style={{ padding: '10px 14px', textAlign: 'left' }}>سعر الوحدة</th>
                    <th style={{ padding: '10px 14px', textAlign: 'left', borderTopLeftRadius: '6px' }}>الإجمالي</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.length === 0 ? (
                    <tr>
                      <td colSpan={5} style={{ padding: '14px', textAlign: 'center', color: '#64748B', borderBottom: '1px solid #E2E8F0' }}>
                        تفاصيل الخدمة حسب الطلب
                      </td>
                    </tr>
                  ) : (
                    data.items.map((item, idx) => (
                      <tr key={idx} style={{ borderBottom: '1px solid #E2E8F0', background: idx % 2 === 0 ? '#FFFFFF' : '#F8FAFC' }}>
                        <td style={{ padding: '10px 14px', color: '#64748B', fontWeight: '700' }}>{idx + 1}</td>
                        <td style={{ padding: '10px 14px', fontWeight: '700', color: '#0f172a' }}>
                          {item.name}
                          {item.notes && <div style={{ fontSize: '11px', color: '#64748B', fontWeight: 'normal' }}>{item.notes}</div>}
                        </td>
                        <td style={{ padding: '10px 14px', textAlign: 'center', fontWeight: '700' }}>{item.quantity}</td>
                        <td style={{ padding: '10px 14px', textAlign: 'left', color: '#475569' }}>{formatIqd(item.unitPrice)}</td>
                        <td style={{ padding: '10px 14px', textAlign: 'left', fontWeight: '800', color: '#0f172a' }}>{formatIqd(item.totalPrice)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {/* ─── 4. FINANCIAL SUMMARY & TOTALS ─── */}
            <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '20px', marginBottom: '24px' }}>
              {/* QR Code & Digital Verification */}
              <div style={{ padding: '16px', background: '#F8FAFC', borderRadius: '12px', border: '1px solid #E2E8F0', display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div style={{ padding: '8px', background: '#fff', borderRadius: '8px', border: '1px solid #CBD5E1', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <QrCode size={54} color="#0f172a" />
                </div>
                <div style={{ fontSize: '11px', color: '#475569', lineHeight: '1.5' }}>
                  <div style={{ fontWeight: '800', color: '#00897B', marginBottom: '2px' }}> وثيقة رسمية معتمدة رقمياً</div>
                  تم إصدار هذا السند إلكترونياً عبر خوادم منظومة مدار الموحدة بموجب القوانين والأنظمة المعمول بها.
                </div>
              </div>

              {/* Totals Box */}
              <div style={{ background: '#F1F5F9', padding: '16px', borderRadius: '12px', border: '1px solid #CBD5E1' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#475569', marginBottom: '6px' }}>
                  <span>المجموع الفرعي للأصناف:</span>
                  <span style={{ fontWeight: '700' }}>{formatIqd(data.subtotalIqd)}</span>
                </div>
                {data.deliveryFeeIqd > 0 && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#475569', marginBottom: '6px' }}>
                    <span>أجور التوصيل والخدمة:</span>
                    <span style={{ fontWeight: '700' }}>{formatIqd(data.deliveryFeeIqd)}</span>
                  </div>
                )}
                {data.discountIqd > 0 && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#DC2626', marginBottom: '6px' }}>
                    <span>قيمة الخصم / الكوبون:</span>
                    <span style={{ fontWeight: '700' }}>- {formatIqd(data.discountIqd)}</span>
                  </div>
                )}
                <div style={{ borderTop: '2px dashed #94A3B8', paddingTop: '8px', marginTop: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '14px', fontWeight: '900', color: '#0f172a' }}>المبلغ الإجمالي المستحق:</span>
                  <span style={{ fontSize: '17px', fontWeight: '900', color: '#00897B' }}>{formatIqd(data.totalIqd)}</span>
                </div>
              </div>
            </div>

            {/* ─── 5. SIGNATURE & STAMP FOOTER ─── */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', paddingTop: '20px', borderTop: '1px solid #E2E8F0', marginTop: '20px' }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: '11px', color: '#64748B', marginBottom: '40px' }}>توقيع المستلم / العميل</div>
                <div style={{ borderBottom: '1px dashed #94A3B8', width: '160px', margin: '0 auto' }}></div>
              </div>

              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: '11px', color: '#64748B', marginBottom: '6px' }}>الختم الإداري والمالي المعتمد</div>
                <div style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '6px 14px',
                  border: '2px solid #00BFA5',
                  borderRadius: '20px',
                  color: '#00897B',
                  fontWeight: '900',
                  fontSize: '12px',
                  background: '#E6F8F5'
                }}>
                  <ShieldCheck size={16} /> إدارة منظومة مدار — القائم
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
};
