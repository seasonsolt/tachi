import { useState, useCallback, useEffect } from 'react';
import { useStore } from '../stores/store';
import { THEMES } from '@eacc/shared';
import { LS_ANTHROPIC_KEY, LS_OPENAI_KEY } from '../hooks/useApiPolling';
import { DEFAULT_YOUTUBE_URL, useAudio } from '../hooks/useAudio';
import { useFocusTimer } from '../hooks/useFocusTimer';
import { getServerUrl, setServerUrl } from '../hooks/useWebSocket';
import type { WSClientMessage } from '@eacc/shared';

interface SetupProps {
  send: (msg: WSClientMessage) => void;
  onClose: () => void;
}

export function Setup({ send, onClose }: SetupProps) {
  const theme = useStore((s) => s.theme);
  const setTheme = useStore((s) => s.setTheme);
  const tokenData = useStore((s) => s.tokenData);
  const mode = useStore((s) => s.mode);
  const t = THEMES[theme];
  const {
    audioSource,
    error: audioError,
    playing,
    ready,
    play,
    pause,
    useDefaultTrack,
    useYouTubeTrack,
    useLocalFile,
  } = useAudio();
  const {
    durationMinutes,
    remainingLabel,
    running: focusRunning,
    setDuration,
    start: startFocus,
    pause: pauseFocus,
    reset: resetFocus,
  } = useFocusTimer();

  const isWeb = mode === 'web';

  const [anthropicKey, setAnthropicKey] = useState('');
  const [openaiKey, setOpenaiKey] = useState('');
  const [serverUrl, setServerUrlInput] = useState(getServerUrl() || '');
  const [saving, setSaving] = useState(false);
  const [youtubeUrl, setYouTubeUrl] = useState(audioSource.kind === 'youtube' ? audioSource.url : DEFAULT_YOUTUBE_URL);

  const claudeConnected = tokenData?.sources.claudeCode.connected ?? false;
  const anthropicConnected = tokenData?.sources.anthropicApi.connected ?? false;
  const openaiConnected = tokenData?.sources.openaiApi.connected ?? false;

  useEffect(() => {
    if (audioSource.kind === 'youtube') {
      setYouTubeUrl(audioSource.url);
    }
  }, [audioSource]);

  const handleSave = useCallback(() => {
    setSaving(true);

    if (isWeb) {
      if (anthropicKey.trim()) localStorage.setItem(LS_ANTHROPIC_KEY, anthropicKey.trim());
      if (openaiKey.trim()) localStorage.setItem(LS_OPENAI_KEY, openaiKey.trim());
      // Trigger a re-poll by dispatching a storage event won't work same-tab,
      // so we just reload the polling cycle via a brief delay
      setTimeout(() => {
        setSaving(false);
        setAnthropicKey('');
        setOpenaiKey('');
        // Force re-render to pick up new keys
        window.dispatchEvent(new Event('ritual-keys-updated'));
      }, 500);
    } else {
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
    }
  }, [anthropicKey, openaiKey, send, isWeb]);

  const handleUseYouTube = useCallback(() => {
    if (!youtubeUrl.trim()) return;
    const applied = useYouTubeTrack(youtubeUrl);
    if (applied) {
      play();
    }
  }, [play, useYouTubeTrack, youtubeUrl]);

  const handleLocalFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    const applied = useLocalFile(file);
    if (applied) {
      play();
    }
    e.target.value = '';
  }, [play, useLocalFile]);

  return (
    <div style={styles.overlay} onClick={(e) => e.stopPropagation()}>
      <div
        style={{
          ...styles.panel,
          fontFamily: t.dataFont,
          borderColor: t.surfaceBorder,
          background: t.surfaceStrong,
          boxShadow: `-24px 0 48px rgba(0, 0, 0, 0.28)`,
        }}
      >
        <div style={styles.header}>
          <span style={{ ...styles.title, fontFamily: t.scriptureFont }}>
            Configure
          </span>
          <button onClick={onClose} style={styles.closeBtn}>
            ✕
          </button>
        </div>

        {isWeb && (
          <div style={{ ...styles.modeBadge, color: t.fireCore, borderColor: t.fireCore }}>
            WEB MODE
          </div>
        )}

        <div style={styles.section}>
          <div style={styles.sectionLabel}>Local Server</div>
          <div style={styles.sourceRow}>
            <span style={{ ...styles.dot, background: useStore.getState().wsConnected ? '#4ade80' : '#666' }} />
            <span>{useStore.getState().wsConnected ? 'Connected' : 'Disconnected'}</span>
          </div>
          <label style={styles.inputLabel}>Server Address</label>
          <div style={styles.inlineRow}>
            <input
              type="text"
              value={serverUrl}
              onChange={(e) => setServerUrlInput(e.target.value)}
              placeholder="localhost:3666"
              style={{ ...styles.input, ...styles.flexInput, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
            />
            <button
              type="button"
              onClick={() => {
                const url = serverUrl.trim() || null;
                setServerUrl(url);
                window.location.reload();
              }}
              style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, color: t.textSecondary }}
            >
              Connect
            </button>
          </div>
          <div style={styles.audioHint}>
            Enter the address of your local CLI server (e.g. localhost:3666). The page will reload to connect.
          </div>
        </div>

        <div style={styles.section}>
          <div style={styles.sectionLabel}>Audio</div>
          <div style={styles.audioStatusRow}>
            <span style={styles.audioLabel}>{audioSource.label}</span>
            <span style={styles.audioMeta}>{audioSource.kind} · {ready ? (playing ? 'playing' : 'ready') : 'loading'}</span>
          </div>
          {audioError && <div style={styles.audioError}>{audioError}</div>}
          <div style={styles.audioActions}>
            <button
              type="button"
              onClick={useDefaultTrack}
              style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, color: t.textSecondary }}
            >
              Default ambient
            </button>
            <button
              type="button"
              onClick={playing ? pause : play}
              style={{ ...styles.utilityBtn, borderColor: t.fireCore, color: t.fireCore }}
            >
              {playing ? 'Pause' : 'Play'}
            </button>
          </div>
          <label style={styles.inputLabel}>YouTube Link</label>
          <div style={styles.inlineRow}>
            <input
              type="url"
              value={youtubeUrl}
              onChange={(e) => setYouTubeUrl(e.target.value)}
              placeholder="https://www.youtube.com/watch?v=..."
              style={{ ...styles.input, ...styles.flexInput, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
            />
            <button
              type="button"
              onClick={handleUseYouTube}
              style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, color: t.textSecondary }}
            >
              Use link
            </button>
          </div>
          <label style={styles.inputLabel}>Local File</label>
          <label style={{ ...styles.uploadBtn, borderColor: t.surfaceBorder, color: t.textSecondary, background: t.surfaceSoft }}>
            <input
              type="file"
              accept="audio/*"
              onChange={handleLocalFileChange}
              style={styles.fileInput}
            />
            Upload audio
          </label>
          <div style={styles.audioHint}>
            YouTube uses the embedded player. Local files stay in this browser session only.
          </div>
        </div>

        <div style={styles.section}>
          <div style={styles.sectionLabel}>Focus</div>
          <div style={styles.audioStatusRow}>
            <span style={styles.audioLabel}>{remainingLabel}</span>
            <span style={styles.audioMeta}>{focusRunning ? 'ritual live' : 'ritual ready'}</span>
          </div>
          <div style={styles.presetRow}>
            {[25, 45, 60].map((preset) => (
              <button
                key={preset}
                type="button"
                onClick={() => setDuration(preset)}
                style={{
                  ...styles.utilityBtn,
                  borderColor: durationMinutes === preset ? t.fireCore : t.surfaceBorder,
                  color: durationMinutes === preset ? t.fireCore : t.textSecondary,
                }}
              >
                {preset}m
              </button>
            ))}
          </div>
          <label style={styles.inputLabel}>Custom Duration</label>
          <input
            type="number"
            min={5}
            max={180}
            step={5}
            value={durationMinutes}
            onChange={(e) => setDuration(Number(e.target.value))}
            style={{ ...styles.input, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
          />
          <div style={styles.audioActions}>
            <button
              type="button"
              onClick={focusRunning ? pauseFocus : startFocus}
              style={{ ...styles.utilityBtn, borderColor: t.fireCore, color: t.fireCore }}
            >
              {focusRunning ? 'Pause' : 'Start'}
            </button>
            <button
              type="button"
              onClick={resetFocus}
              style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, color: t.textSecondary }}
            >
              Reset
            </button>
          </div>
        </div>

        <div style={styles.section}>
          <div style={styles.sectionLabel}>Sources</div>
          <div style={styles.sourceRow}>
            <span style={{ ...styles.dot, background: claudeConnected ? '#4ade80' : '#666' }} />
            <span>Claude Code {isWeb ? '(CLI mode only)' : '(auto-detected)'}</span>
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
            style={{ ...styles.input, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
          />
        </div>

        <div style={styles.section}>
          <label style={styles.inputLabel}>OpenAI API Key</label>
          <input
            type="password"
            value={openaiKey}
            onChange={(e) => setOpenaiKey(e.target.value)}
            placeholder={openaiConnected ? '••••••••' : 'sk-...'}
            style={{ ...styles.input, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
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
          <div style={styles.themeGrid}>
            {Object.values(THEMES).map((th) => (
              <button
                key={th.name}
                onClick={() => {
                  setTheme(th.name);
                  send({ type: 'theme_change', theme: th.name });
                }}
                style={{
                  ...styles.themeBtn,
                  borderColor: theme === th.name ? th.fireCore : th.surfaceBorder,
                  background: th.surfaceSoft,
                }}
              >
                <span
                  style={{
                    width: 8,
                    height: 8,
                    background: th.fireCore,
                    display: 'inline-block',
                    marginRight: 6,
                    flexShrink: 0,
                  }}
                />
                {th.label}
              </button>
            ))}
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
    borderLeft: '1px solid',
    padding: 24,
    display: 'flex',
    flexDirection: 'column',
    gap: 20,
    overflowY: 'auto',
    backdropFilter: 'blur(12px)',
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
  modeBadge: {
    fontSize: 9,
    letterSpacing: 2,
    textTransform: 'uppercase',
    border: '1px solid',
    padding: '4px 8px',
    alignSelf: 'flex-start',
  },
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  inlineRow: {
    display: 'flex',
    alignItems: 'stretch',
    gap: 8,
  },
  flexInput: {
    flex: 1,
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
  audioStatusRow: {
    display: 'flex',
    flexDirection: 'column',
    gap: 4,
    padding: '10px 12px',
    border: '1px solid var(--surface-border)',
    background: 'var(--surface-soft)',
  },
  audioLabel: {
    color: 'var(--text-primary)',
    fontSize: 12,
    lineHeight: 1.3,
  },
  audioMeta: {
    color: 'var(--text-muted)',
    fontSize: 10,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  audioError: {
    color: '#ff7a7a',
    fontSize: 11,
    lineHeight: 1.5,
  },
  audioActions: {
    display: 'flex',
    gap: 8,
  },
  presetRow: {
    display: 'flex',
    gap: 8,
  },
  audioHint: {
    color: 'var(--text-muted)',
    fontSize: 10,
    lineHeight: 1.5,
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
    border: '1px solid var(--text-muted)',
    borderRadius: 0,
    color: 'var(--text-primary)',
    padding: '8px 12px',
    fontSize: 13,
    outline: 'none',
    width: '100%',
  },
  utilityBtn: {
    background: 'transparent',
    border: '1px solid',
    borderRadius: 0,
    padding: '10px 12px',
    fontSize: 10,
    textTransform: 'uppercase',
    letterSpacing: 1,
    cursor: 'pointer',
    fontFamily: 'inherit',
    whiteSpace: 'nowrap' as const,
  },
  uploadBtn: {
    border: '1px solid',
    borderRadius: 0,
    padding: '10px 12px',
    fontSize: 10,
    textTransform: 'uppercase',
    letterSpacing: 1,
    cursor: 'pointer',
    fontFamily: 'inherit',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 40,
  },
  fileInput: {
    position: 'absolute',
    width: 1,
    height: 1,
    padding: 0,
    margin: -1,
    overflow: 'hidden',
    clip: 'rect(0, 0, 0, 0)',
    whiteSpace: 'nowrap' as const,
    border: 0,
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
  themeGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: 8,
  },
  themeBtn: {
    border: '1px solid',
    borderRadius: 0,
    color: 'var(--text-secondary)',
    padding: '8px 10px',
    fontSize: 10,
    cursor: 'pointer',
    textTransform: 'uppercase',
    letterSpacing: 1,
    transition: 'border-color 0.3s',
    display: 'flex',
    alignItems: 'center',
    fontFamily: 'inherit',
  },
};
