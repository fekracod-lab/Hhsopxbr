import React, { useState } from 'react';

// ─── 1. REVENUE AREA CURVE CHART ───
export interface ChartDataPoint {
  label: string;
  value: number;
  secondaryValue?: number;
}

interface AreaRevenueChartProps {
  data: ChartDataPoint[];
  height?: number;
  color?: string;
  secondaryColor?: string;
  currencyPrefix?: string;
}

export const AreaRevenueChart: React.FC<AreaRevenueChartProps> = ({
  data,
  height = 180,
  color = '#00BFA5',
  secondaryColor = '#38BDF8',
  currencyPrefix = 'د.ع'
}) => {
  const [hoveredIdx, setHoveredIdx] = useState<number | null>(null);

  if (!data || data.length === 0) {
    return (
      <div style={{ height, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-dim)', fontSize: '12px' }}>
        ماكو بيانات حالياً كافية للرسم البياني
      </div>
    );
  }

  const padding = { top: 20, right: 15, bottom: 25, left: 15 };
  const chartWidth = 600;
  const chartHeight = height;

  const innerWidth = chartWidth - padding.left - padding.right;
  const innerHeight = chartHeight - padding.top - padding.bottom;

  const maxValue = Math.max(...data.map(d => d.value), 1);
  const stepX = innerWidth / (data.length - 1 || 1);

  // Generate SVG path points
  const points = data.map((d, idx) => {
    const x = padding.left + idx * stepX;
    const y = padding.top + innerHeight - (d.value / maxValue) * innerHeight;
    return { x, y, data: d, idx };
  });

  const pathD = points.reduce((acc, p, idx) => {
    if (idx === 0) return `M ${p.x} ${p.y}`;
    const prev = points[idx - 1];
    const cp1x = prev.x + (p.x - prev.x) / 2;
    const cp1y = prev.y;
    const cp2x = prev.x + (p.x - prev.x) / 2;
    const cp2y = p.y;
    return `${acc} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p.x} ${p.y}`;
  }, '');

  const areaD = `${pathD} L ${padding.left + innerWidth} ${padding.top + innerHeight} L ${padding.left} ${padding.top + innerHeight} Z`;

  return (
    <div style={{ width: '100%', position: 'relative' }}>
      <svg 
        viewBox={`0 0 ${chartWidth} ${chartHeight}`} 
        style={{ width: '100%', height: 'auto', overflow: 'visible' }}
      >
        <defs>
          <linearGradient id="areaGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={color} stopOpacity="0.35" />
            <stop offset="100%" stopColor={color} stopOpacity="0.0" />
          </linearGradient>
          <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>

        {/* Grid Lines */}
        {[0, 0.5, 1].map((ratio, idx) => (
          <line
            key={idx}
            x1={padding.left}
            y1={padding.top + innerHeight * ratio}
            x2={padding.left + innerWidth}
            y2={padding.top + innerHeight * ratio}
            stroke="rgba(255, 255, 255, 0.05)"
            strokeDasharray="4 4"
          />
        ))}

        {/* Gradient Area */}
        <path d={areaD} fill="url(#areaGrad)" />

        {/* Smooth Curve Line */}
        <path 
          d={pathD} 
          fill="none" 
          stroke={color} 
          strokeWidth="2.5" 
          strokeLinecap="round"
          filter="url(#glow)"
        />

        {/* Interactive Points */}
        {points.map((p) => {
          const isHov = hoveredIdx === p.idx;
          return (
            <g key={p.idx}>
              <circle
                cx={p.x}
                cy={p.y}
                r={isHov ? 6 : 3.5}
                fill={isHov ? '#fff' : color}
                stroke={color}
                strokeWidth="2"
                style={{ cursor: 'pointer', transition: 'all 0.15s ease' }}
                onMouseEnter={() => setHoveredIdx(p.idx)}
                onMouseLeave={() => setHoveredIdx(null)}
              />
              <text
                x={p.x}
                y={chartHeight - 6}
                textAnchor="middle"
                fill="var(--text-dim)"
                fontSize="9.5"
                fontFamily="IBM Plex Sans Arabic"
              >
                {p.data.label}
              </text>
            </g>
          );
        })}
      </svg>

      {/* Floating Tooltip */}
      {hoveredIdx !== null && points[hoveredIdx] && (
        <div
          style={{
            position: 'absolute',
            top: '8px',
            left: '50%',
            transform: 'translateX(-50%)',
            background: 'rgba(10, 17, 26, 0.95)',
            border: `1px solid ${color}`,
            borderRadius: '8px',
            padding: '6px 12px',
            fontSize: '11.5px',
            fontWeight: '700',
            color: '#fff',
            boxShadow: `0 4px 15px ${color}33`,
            pointerEvents: 'none',
            zIndex: 10
          }}
        >
          <span>{points[hoveredIdx].data.label}: </span>
          <span style={{ color }}>{new Intl.NumberFormat('ar-IQ').format(points[hoveredIdx].data.value)} {currencyPrefix}</span>
        </div>
      )}
    </div>
  );
};

// ─── 2. DOUGHNUT BREAKDOWN CHART ───
export interface DonutSegment {
  label: string;
  value: number;
  color: string;
  icon?: string;
}

interface DonutDistributionChartProps {
  segments: DonutSegment[];
  size?: number;
  centerText?: string;
  centerSub?: string;
}

export const DonutDistributionChart: React.FC<DonutDistributionChartProps> = ({
  segments,
  size = 140,
  centerText,
  centerSub
}) => {
  const total = segments.reduce((sum, s) => sum + s.value, 0) || 1;
  const strokeWidth = 14;
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;

  let accumulated = 0;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '20px', flexWrap: 'wrap' }}>
      <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          {segments.map((seg, idx) => {
            const ratio = seg.value / total;
            const strokeDasharray = `${ratio * circumference} ${circumference}`;
            const strokeDashoffset = -accumulated * circumference;
            accumulated += ratio;

            return (
              <circle
                key={idx}
                cx={size / 2}
                cy={size / 2}
                r={radius}
                fill="transparent"
                stroke={seg.color}
                strokeWidth={strokeWidth}
                strokeDasharray={strokeDasharray}
                strokeDashoffset={strokeDashoffset}
                strokeLinecap="round"
                transform={`rotate(-90 ${size / 2} ${size / 2})`}
                style={{ transition: 'all 0.4s ease' }}
              />
            );
          })}
        </svg>

        {/* Center Text */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
            pointerEvents: 'none'
          }}
        >
          <div style={{ fontSize: '15px', fontWeight: '900', color: '#fff', lineHeight: 1 }}>
            {centerText || total}
          </div>
          {centerSub && (
            <div style={{ fontSize: '9.5px', color: 'var(--text-dim)', marginTop: '2px' }}>
              {centerSub}
            </div>
          )}
        </div>
      </div>

      {/* Legend List */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1, minWidth: '120px' }}>
        {segments.map((seg, idx) => {
          const pct = Math.round((seg.value / total) * 100);
          return (
            <div key={idx} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '11.5px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: seg.color }} />
                <span style={{ color: 'var(--text-sub)' }}>{seg.label}</span>
              </div>
              <span style={{ fontWeight: '800', color: '#fff' }}>{pct}%</span>
            </div>
          );
        })}
      </div>
    </div>
  );
};
