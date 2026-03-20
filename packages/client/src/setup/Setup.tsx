import { useState, useCallback } from 'react';
import { useStore } from '../stores/store';
import { THEMES } from '@ritual-screen/shared';
import type { WSClientMessage } from '@ritual-screen/shared';

interface SetupProps {
  send: (msg: WSClientMessage) => void;
  onClose: () => void;
}

export function Setup({ send, onClose }: SetupProps) {
  const theme = useStore((s) => s.theme);
  const setTheme = useStore((s) => s.setTheme);
  const tokenData = useStore((s) => s.tokenData);
  const t = THEMES[theme];

  const [anthropicKey, setAnthropicKey] = useState('');
  const [openaiKey, setOpenaiKey] = useState('');
  const [saving, setSaving] = useState(false);

  const claudeConnected = tokenData?.sources.claudeCode.connected ?? false;
  const anthropicConnected = tokenData?.sources.anthropicApi.connected ?? false;
  const openaiConnected = tokenData?.sources.openaiApi.connected ?? false;

  const handleSave = useCallback(() => {
    setSaving(true);
    const config: Record<string, string> = {};
    if (anthropicKey.trim()) config.anthropicAdminKey = anthropicKey.trim();
    if (openaiKey.trim()) config.openaiKey = openaiKey.trim();
    send({ type: 'configure', config });
    setTimeout(() => {
      setSaving(false);
      if (anthropicKey.trim() || openaiKey.trim()) {
        setAnthropicKey('');
        setOpenaiKey('');
      }
    }, 1000);
  }, [anthropicKey, openaiKey, send]);

  return (
    <div style={styles.overlay} onClick={(e) => e.stopPropagation()}>
      <div style={{ ...styles.panel, fontFamily: t.dataFont, borderColor: t.textMuted, background: `${t.bg}f2` }}>
        <div style={styles.header}>
          <span style={{ ...styles.title, fontFamily: t.scriptureFont }}>
            Configure
          </span>
          <button onClick={onClose} style={styles.closeBtn}>
            ✕
          </button>
        </div>

        <div style={styles.section}>
          <div style={styles.sectionLabel}>Sources</div>
          <div style={styles.sourceRow}>
            <span style={{ ...styles.dot, background: claudeConnected ? '#4ade80' : '#666' }} />
            <span>Claude Code (auto-detected)</span>
          </div>
          <div style={styles.sourceRow}>
            <span style={{ ...styles.dot, background: anthropicConnected ? '#4ade80' : '#666' }} />
            <span>Anthropic API</span>
          </div>
          <div style={styles.sourceRow}>
            <span style={{ ...styles.dot, background: openaiConnected ? '#4ade80' : '#666' }} />
            <span>OpenAI API</span>
          </div>
        </div>

        <div style={styles.section}>
          <label style={styles.inputLabel}>Anthropic Admin API Key</label>
          <input
            type="password"
            value={anthropicKey}
            onChange={(e) => setAnthropicKey(e.target.value)}
            placeholder={anthropicConnected ? '••••••••' : 'sk-ant-admin-...'}
            style={{ ...styles.input, fontFamily: t.dataFont }}
          />
        </div>

        <div style={styles.section}>
          <label style={styles.inputLabel}>OpenAI API Key</label>
          <input
            type="password"
            value={openaiKey}
            onChange={(e) => setOpenaiKey(e.target.value)}
            placeholder={openaiConnected ? '••••••••' : 'sk-...'}
            style={{ ...styles.input, fontFamily: t.dataFont }}
          />
        </div>

        <button
          onClick={handleSave}
          disabled={saving}
          style={{
            ...styles.saveBtn,
            background: t.fireCore,
            color: t.bg,
            opacity: saving ? 0.5 : 1,
          }}
        >
          {saving ? 'Saving...' : 'Save'}
        </button>

        <div style={styles.section}>
          <div style={styles.sectionLabel}>Theme</div>
          <div style={styles.themeRow}>
            <button
              onClick={() => setTheme('ancient')}
              style={{
                ...styles.themeBtn,
                borderColor: theme === 'ancient' ? THEMES.ancient.fireCore : '#333',
              }}
            >
              Ancient Altar
            </button>
            <button
              onClick={() => setTheme('cyber')}
              style={{
                ...styles.themeBtn,
                borderColor: theme === 'cyber' ? THEMES.cyber.fireCore : '#333',
              }}
            >
              Cyber Shrine
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    width: 360,
    zIndex: 20,
    animation: 'slideIn 0.3s ease-out',
  },
  panel: {
    width: '100%',
    height: '100%',
    background: 'rgba(10, 8, 6, 0.95)',
    borderLeft: '1px solid',
    padding: 24,
    display: 'flex',
    flexDirection: 'column',
    gap: 20,
    overflowY: 'auto',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: {
    fontSize: 22,
    fontWeight: 400,
    color: 'var(--text-primary)',
  },
  closeBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--text-muted)',
    fontSize: 18,
    cursor: 'pointer',
    padding: 4,
  },
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  sectionLabel: {
    fontSize: 10,
    textTransform: 'uppercase',
    letterSpacing: 1.5,
    color: 'var(--text-muted)',
    marginBottom: 4,
  },
  sourceRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 12,
    color: 'var(--text-secondary)',
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 0,
    display: 'inline-block',
    flexShrink: 0,
  },
  inputLabel: {
    fontSize: 11,
    color: 'var(--text-muted)',
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  input: {
    background: 'rgba(255,255,255,0.05)',
    border: '1px solid var(--text-muted)',
    borderRadius: 0,
    color: 'var(--text-primary)',
    padding: '8px 12px',
    fontSize: 13,
    outline: 'none',
    width: '100%',
  },
  saveBtn: {
    border: 'none',
    borderRadius: 0,
    padding: '10px 16px',
    fontSize: 13,
    fontWeight: 500,
    cursor: 'pointer',
    textTransform: 'uppercase',
    letterSpacing: 1,
    transition: 'opacity 0.3s',
  },
  themeRow: {
    display: 'flex',
    gap: 8,
  },
  themeBtn: {
    flex: 1,
    background: 'rgba(255,255,255,0.03)',
    border: '1px solid',
    borderRadius: 0,
    color: 'var(--text-secondary)',
    padding: '8px 12px',
    fontSize: 11,
    cursor: 'pointer',
    textTransform: 'uppercase',
    letterSpacing: 1,
    transition: 'border-color 0.3s',
  },
};
