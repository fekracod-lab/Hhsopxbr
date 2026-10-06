import React, { useState, useEffect } from 'react';
import { Search, X, Navigation, Car, Store, ShieldAlert, Activity, FileText } from 'lucide-react';
import { navItems } from './Sidebar';

export const CommandPaletteModal: React.FC<{ isOpen: boolean; onClose: () => void; onSelect: (id: string) => void }> = ({ isOpen, onClose, onSelect }) => {
  const [query, setQuery] = useState('');

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        isOpen ? onClose() : onSelect('dashboard');
      }
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose, onSelect]);

  if (!isOpen) return null;

  const filteredItems = navItems.filter(item => item.label.includes(query) || item.id.includes(query) || item.section.includes(query));

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0, 0, 0, 0.7)', backdropFilter: 'blur(8px)', zIndex: 9999, display: 'flex', alignItems: 'flex-start', justifyContent: 'center', paddingTop: '100px' }} onClick={onClose}>
      <div
        className="glass-panel"
        style={{ width: '100%', maxWidth: '580px', background: 'var(--bg-secondary)', border: '1px solid var(--border-highlight)', padding: '0', overflow: 'hidden', boxShadow: '0 20px 50px rgba(0,0,0,0.8)' }}
        onClick={e => e.stopPropagation()}
      >
        <div style={{ display: 'flex', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid var(--border-color)', gap: '12px' }}>
          <Search size={18} color="#06b6d4" />
          <input
            type="text"
            placeholder="اكتب اسم الوحدة، السائق، الرحلة، أو Trace ID للانتقال السريع..."
            value={query}
            onChange={e => setQuery(e.target.value)}
            autoFocus
            style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: '#fff', fontSize: '14px', fontFamily: 'var(--font-arabic)' }}
          />
          <button onClick={onClose} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}>
            <X size={18} />
          </button>
        </div>

        <div style={{ maxHeight: '340px', overflowY: 'auto', padding: '8px' }}>
          {filteredItems.map(item => {
            const Icon = item.icon;
            return (
              <div
                key={item.id}
                onClick={() => {
                  onSelect(item.id);
                  onClose();
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 14px',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  transition: 'all 0.15s ease',
                }}
                onMouseEnter={e => (e.currentTarget.style.background = 'rgba(6, 182, 212, 0.15)')}
                onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <Icon size={16} color="#38bdf8" />
                  <span style={{ fontSize: '13px', fontWeight: '600', color: '#fff' }}>{item.label}</span>
                </div>
                <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>{item.section}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
