import { useState, useCallback, useEffect, useRef } from 'react';
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
  onOpenMarket: () => void;
  hasMarketSignals: boolean;
}

export function Setup({ send, onClose, onOpenMarket, hasMarketSignals }: SetupProps) {
  const theme = useStore((s) => s.theme);
  const setTheme = useStore((s) => s.setTheme);
  const tokenData = useStore((s) => s.tokenData);
  const mode = useStore((s) => s.mode);
  const wsConnected = useStore((s) => s.wsConnected);
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
  const [showAmbientControls, setShowAmbientControls] = useState(false);
  const [showAppearanceControls, setShowAppearanceControls] = useState(false);
  const [showAdvancedControls, setShowAdvancedControls] = useState(false);
  const localServerRef = useRef<HTMLElement | null>(null);
  const dataSourcesRef = useRef<HTMLElement | null>(null);

  const claudeConnected = tokenData?.sources.claudeCode.connected ?? false;
  const anthropicConnected = tokenData?.sources.anthropicApi.connected ?? false;
  const openaiConnected = tokenData?.sources.openaiApi.connected ?? false;
  const hasLiveSource = claudeConnected || anthropicConnected || openaiConnected;
  const isAltarLive = wsConnected && hasLiveSource;

  useEffect(() => {
    if (audioSource.kind === 'youtube') {
      setYouTubeUrl(audioSource.url);
    }
  }, [audioSource]);

  useEffect(() => {
    if (isAltarLive) return;
    if (showAmbientControls) setShowAmbientControls(false);
    if (showAppearanceControls) setShowAppearanceControls(false);
  }, [isAltarLive, showAmbientControls, showAppearanceControls]);

  useEffect(() => {
    let target: HTMLElement | null = null;
    if (isWeb || !wsConnected) {
      target = localServerRef.current;
    } else if (!hasLiveSource) {
      target = dataSourcesRef.current;
    }
    if (!target) return;
    const frame = requestAnimationFrame(() => {
      target.scrollIntoView({ block: 'nearest' });
    });
    return () => cancelAnimationFrame(frame);
  }, [isWeb, wsConnected, hasLiveSource]);

  let quickstartTitle = 'Light The Altar';
  let quickstartCopy = 'Start with Local Server. If you do not have a running CLI server yet, you can still save browser-side API keys below.';
  if (isWeb) {
    quickstartTitle = 'Return To CLI Mode';
    quickstartCopy = 'You are in fallback mode. Reconnect the local server first, then save keys only if you still need browser-side usage data.';
  } else if (wsConnected) {
    if (hasLiveSource) {
      quickstartTitle = 'Altar Is Live';
      quickstartCopy = 'The main path is already working. Use the optional controls below only after you are happy with the data path.';
    } else {
      quickstartTitle = 'Add Your First Source';
      quickstartCopy = 'Your local server is connected. The next useful move is adding an API source so the altar stops showing placeholders.';
    }
  }

  let localServerStatus = 'Waiting';
  let localServerStatusTone = '#666';
  if (wsConnected) {
    localServerStatus = 'Connected';
    localServerStatusTone = '#4ade80';
  } else if (isWeb) {
    localServerStatus = 'Fallback active';
    localServerStatusTone = t.fireCore;
  }

  const sourceStatus = hasLiveSource ? 'Live data found' : 'Needs a source';
  const sourceHint = isWeb
    ? 'In WEB MODE, saved keys stay in this browser. Claude Code remains unavailable here.'
    : 'On the CLI path, Save sends API keys to the local server. Claude Code appears automatically when the server finds active sessions.';
  const sourceTitle = isWeb ? 'Optional Browser Keys' : 'Data Sources';
  const sourceStepLabel = isWeb ? 'Optional' : 'Step 2';
  const recoverySteps = [
    'Check the local CLI server address first.',
    'Press Connect to save it and reload the page.',
    'After reload, confirm WEB MODE disappears and Local Server shows Connected.',
  ];
  const optionalIntro = hasLiveSource || wsConnected
    ? 'These controls shape atmosphere and appearance. They do not change whether usage data arrives.'
    : 'Leave these alone until Local Server or Data Sources are working. They will not help the altar come alive.';
  const playbackStatus = ready ? (playing ? 'playing' : 'ready') : 'loading';
  let ambientLabel = 'Ambient';
  if (audioSource.kind === 'youtube') {
    ambientLabel = 'YouTube';
  } else if (audioSource.kind === 'local') {
    ambientLabel = 'Local file';
  }
  const ambientSummary = `${ambientLabel} · ${playbackStatus}`;
  const focusSummary = focusRunning ? `${remainingLabel} · live` : `${remainingLabel} · ready`;
  const marketSummary = hasMarketSignals ? 'Signals detected' : 'No market signals';
  const themeSummary = wsConnected
    ? `${t.label} · local + shared`
    : `${t.label} · local only`;
  let localServerCopy = 'Connect here first if you want the default CLI route.';
  if (wsConnected) {
    localServerCopy = 'The altar is on the local CLI path.';
  } else if (isWeb) {
    localServerCopy = 'Reconnect here to leave WEB MODE.';
  }

  const handleSave = useCallback(() => {
    setSaving(true);
    const nextAnthropicKey = anthropicKey.trim();
    const nextOpenAIKey = openaiKey.trim();

    if (isWeb) {
      if (nextAnthropicKey) localStorage.setItem(LS_ANTHROPIC_KEY, nextAnthropicKey);
      if (nextOpenAIKey) localStorage.setItem(LS_OPENAI_KEY, nextOpenAIKey);
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
      if (nextAnthropicKey) config.anthropicAdminKey = nextAnthropicKey;
      if (nextOpenAIKey) config.openaiKey = nextOpenAIKey;
      send({ type: 'configure', config });
      setTimeout(() => {
        setSaving(false);
        if (nextAnthropicKey || nextOpenAIKey) {
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

        {isWeb && (
          <section style={{ ...styles.recoveryCard, borderColor: t.fireCore, background: t.surfaceSoft }}>
            <div style={{ ...styles.recoveryKicker, color: t.fireCore }}>Fallback Recovery</div>
            <div style={styles.recoveryTitle}>Return to the default CLI path first.</div>
            <div style={styles.recoveryCopy}>
              The browser can still show API usage here, but Claude Code and session-driven signals stay limited until the local WebSocket path comes back.
            </div>
            <div style={styles.recoveryList}>
              {recoverySteps.map((step, index) => (
                <div key={step} style={styles.recoveryRow}>
                  <div style={{ ...styles.recoveryIndex, color: t.fireCore, borderColor: t.surfaceBorder }}>
                    0{index + 1}
                  </div>
                  <div style={styles.recoveryText}>{step}</div>
                </div>
              ))}
            </div>
            <div style={styles.recoverySignals}>
              <div style={{ ...styles.recoverySignal, borderColor: t.surfaceBorder, background: t.surfaceStrong }}>
                <div style={styles.recoverySignalLabel}>Success signal</div>
                <div style={styles.recoverySignalValue}>WEB MODE disappears</div>
              </div>
              <div style={{ ...styles.recoverySignal, borderColor: t.surfaceBorder, background: t.surfaceStrong }}>
                <div style={styles.recoverySignalLabel}>Success signal</div>
                <div style={styles.recoverySignalValue}>Local Server = Connected</div>
              </div>
            </div>
          </section>
        )}

        <section style={{ ...styles.heroCard, borderColor: t.surfaceBorder, background: t.surfaceSoft }}>
          <div style={{ ...styles.heroKicker, color: t.fireCore }}>Quick Start</div>
          <div style={{ ...styles.heroTitle, fontFamily: t.scriptureFont }}>{quickstartTitle}</div>
          <div style={styles.heroCopy}>{quickstartCopy}</div>
          <div style={styles.heroGrid}>
            <div style={{ ...styles.heroStat, borderColor: t.surfaceBorder, background: t.surfaceStrong }}>
              <div style={styles.heroStatLabel}>Path</div>
              <div style={{ ...styles.heroStatValue, color: isWeb ? t.fireCore : t.textPrimary }}>
                {isWeb ? 'WEB FALLBACK' : wsConnected ? 'CLI LIVE' : 'CLI WAITING'}
              </div>
            </div>
            <div style={{ ...styles.heroStat, borderColor: t.surfaceBorder, background: t.surfaceStrong }}>
              <div style={styles.heroStatLabel}>Data</div>
              <div style={{ ...styles.heroStatValue, color: hasLiveSource ? t.fireCore : t.textPrimary }}>
                {hasLiveSource ? 'LIVE' : 'NEEDS SOURCE'}
              </div>
            </div>
          </div>
        </section>

        <section
          ref={localServerRef}
          style={{ ...styles.primaryCard, borderColor: t.surfaceBorder, background: t.surfaceStrong }}
        >
          <div style={styles.primaryHeader}>
            <div>
              <div style={{ ...styles.primaryStep, color: t.fireCore }}>Step 1</div>
              <div style={styles.primaryTitle}>Local Server</div>
            </div>
            <div style={{ ...styles.primaryBadge, borderColor: t.surfaceBorder, color: wsConnected ? t.fireCore : t.textSecondary }}>
              {localServerStatus}
            </div>
          </div>
          <div style={styles.sourceRow}>
            <span style={{ ...styles.dot, background: localServerStatusTone }} />
            <span>{localServerCopy}</span>
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
        </section>

        <section
          ref={dataSourcesRef}
          style={{ ...styles.primaryCard, borderColor: t.surfaceBorder, background: t.surfaceStrong }}
        >
          <div style={styles.primaryHeader}>
            <div>
              <div style={{ ...styles.primaryStep, color: t.fireCore }}>{sourceStepLabel}</div>
              <div style={styles.primaryTitle}>{sourceTitle}</div>
            </div>
            <div style={{ ...styles.primaryBadge, borderColor: t.surfaceBorder, color: hasLiveSource ? t.fireCore : t.textSecondary }}>
              {sourceStatus}
            </div>
          </div>
          <div style={styles.audioHint}>{sourceHint}</div>
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
          <label style={styles.inputLabel}>Anthropic Admin API Key</label>
          <input
            type="password"
            value={anthropicKey}
            onChange={(e) => setAnthropicKey(e.target.value)}
            placeholder={anthropicConnected ? '••••••••' : 'sk-ant-admin-...'}
            style={{ ...styles.input, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
          />
          <label style={styles.inputLabel}>OpenAI API Key</label>
          <input
            type="password"
            value={openaiKey}
            onChange={(e) => setOpenaiKey(e.target.value)}
            placeholder={openaiConnected ? '••••••••' : 'sk-...'}
            style={{ ...styles.input, fontFamily: t.dataFont, background: t.surfaceSoft, borderColor: t.surfaceBorder }}
          />
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
            {saving ? 'Saving...' : isWeb ? 'Save browser keys' : 'Save to local server'}
          </button>
        </section>

        <section style={{ ...styles.optionalIntroCard, borderColor: t.surfaceBorder, background: t.surfaceSoft }}>
          <div style={{ ...styles.secondaryLabel, color: t.textMuted }}>
            Optional after the altar is live
          </div>
          <div style={styles.optionalIntroCopy}>{optionalIntro}</div>
        </section>

        <section style={{ ...styles.sectionFold, borderColor: t.surfaceBorder, background: t.surfaceSoft }}>
          <button
            type="button"
            onClick={() => setShowAmbientControls((value) => !value)}
            style={{ ...styles.foldButton, color: t.textPrimary }}
          >
            <span>
              <span style={{ ...styles.foldKicker, color: t.fireCore }}>Ambient</span>
              <span style={styles.foldTitle}>Audio & Focus</span>
            </span>
            <span style={styles.foldMetaWrap}>
              <span style={{ ...styles.foldSummary, color: t.textSecondary }}>{ambientSummary}</span>
              <span style={{ ...styles.foldSummary, color: t.textSecondary }}>{focusSummary}</span>
              <span style={{ ...styles.foldMeta, color: t.textSecondary }}>
                {showAmbientControls ? 'Hide' : 'Open'}
              </span>
            </span>
          </button>
          {showAmbientControls && (
            <div style={styles.foldBody}>
              <div style={styles.section}>
                <div style={styles.foldNotice}>Atmosphere only. None of these controls affect whether usage data arrives.</div>
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
                    style={{ ...styles.input, ...styles.flexInput, fontFamily: t.dataFont, background: t.surfaceStrong, borderColor: t.surfaceBorder }}
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
                <label style={{ ...styles.uploadBtn, borderColor: t.surfaceBorder, color: t.textSecondary, background: t.surfaceStrong }}>
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
                  style={{ ...styles.input, fontFamily: t.dataFont, background: t.surfaceStrong, borderColor: t.surfaceBorder }}
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
            </div>
          )}
        </section>

        <section style={{ ...styles.sectionFold, borderColor: t.surfaceBorder, background: t.surfaceSoft }}>
          <button
            type="button"
            onClick={() => setShowAdvancedControls((value) => !value)}
            style={{ ...styles.foldButton, color: t.textPrimary }}
          >
            <span>
              <span style={{ ...styles.foldKicker, color: t.fireCore }}>Advanced</span>
              <span style={styles.foldTitle}>Market Rite</span>
            </span>
            <span style={styles.foldMetaWrap}>
              <span style={{ ...styles.foldSummary, color: t.textSecondary }}>{marketSummary}</span>
              <span style={{ ...styles.foldMeta, color: t.textSecondary }}>
                {showAdvancedControls ? 'Hide' : 'Open'}
              </span>
            </span>
          </button>
          {showAdvancedControls && (
            <div style={styles.foldBody}>
              <div style={styles.section}>
                <div style={styles.foldNotice}>Conditional path only. Keep this out of the first-use flow unless you already know you need it.</div>
                <div style={styles.sectionLabel}>Market Rite</div>
                <div style={styles.audioHint}>
                  This is a conditional path. It is not required for first-time setup and it stays quieter here until the altar is already live.
                </div>
                <div style={styles.audioStatusRow}>
                  <span style={styles.audioLabel}>{hasMarketSignals ? 'Market signals detected' : 'No active market signals yet'}</span>
                  <span style={styles.audioMeta}>{hasMarketSignals ? 'advanced path available' : 'open only if you want to configure it manually'}</span>
                </div>
                <button
                  type="button"
                  onClick={onOpenMarket}
                  style={{ ...styles.utilityBtn, borderColor: t.fireCore, color: t.fireCore, alignSelf: 'flex-start' }}
                >
                  Open Market Rite
                </button>
              </div>
            </div>
          )}
        </section>

        <section style={{ ...styles.sectionFold, borderColor: t.surfaceBorder, background: t.surfaceSoft }}>
          <button
            type="button"
            onClick={() => setShowAppearanceControls((value) => !value)}
            style={{ ...styles.foldButton, color: t.textPrimary }}
          >
            <span>
              <span style={{ ...styles.foldKicker, color: t.fireCore }}>Appearance</span>
              <span style={styles.foldTitle}>Theme</span>
            </span>
            <span style={styles.foldMetaWrap}>
              <span style={{ ...styles.foldSummary, color: t.textSecondary }}>{themeSummary}</span>
              <span style={{ ...styles.foldMeta, color: t.textSecondary }}>
                {showAppearanceControls ? 'Hide' : 'Open'}
              </span>
            </span>
          </button>
          {showAppearanceControls && (
            <div style={styles.foldBody}>
              <div style={styles.section}>
                <div style={styles.foldNotice}>Visual only. Theme changes do not fix connection or source issues.</div>
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
                        background: t.surfaceStrong,
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
          )}
        </section>
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
    width: 392,
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
  recoveryCard: {
    border: '1px solid',
    padding: 16,
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
  },
  recoveryKicker: {
    fontSize: 10,
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  recoveryTitle: {
    fontSize: 18,
    lineHeight: 1.2,
    color: 'var(--text-primary)',
  },
  recoveryCopy: {
    fontSize: 12,
    color: 'var(--text-secondary)',
    lineHeight: 1.6,
  },
  recoveryList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  recoveryRow: {
    display: 'flex',
    gap: 10,
    alignItems: 'flex-start',
  },
  recoveryIndex: {
    width: 28,
    minWidth: 28,
    height: 28,
    border: '1px solid',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 10,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  recoveryText: {
    fontSize: 12,
    color: 'var(--text-secondary)',
    lineHeight: 1.5,
    paddingTop: 5,
  },
  recoverySignals: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: 8,
  },
  recoverySignal: {
    border: '1px solid',
    padding: '10px 12px',
    display: 'flex',
    flexDirection: 'column',
    gap: 6,
  },
  recoverySignalLabel: {
    fontSize: 9,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
    color: 'var(--text-muted)',
  },
  recoverySignalValue: {
    fontSize: 11,
    lineHeight: 1.4,
    color: 'var(--text-primary)',
  },
  heroCard: {
    border: '1px solid',
    padding: 16,
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
  },
  heroKicker: {
    fontSize: 10,
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  heroTitle: {
    fontSize: 24,
    fontWeight: 400,
    color: 'var(--text-primary)',
    lineHeight: 1.1,
  },
  heroCopy: {
    fontSize: 12,
    color: 'var(--text-secondary)',
    lineHeight: 1.6,
  },
  heroGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: 8,
  },
  heroStat: {
    border: '1px solid',
    padding: '10px 12px',
    display: 'flex',
    flexDirection: 'column',
    gap: 6,
  },
  heroStatLabel: {
    fontSize: 9,
    letterSpacing: 1.6,
    textTransform: 'uppercase',
    color: 'var(--text-muted)',
  },
  heroStatValue: {
    fontSize: 12,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  primaryCard: {
    border: '1px solid',
    padding: 16,
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
  },
  primaryHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
  },
  primaryStep: {
    fontSize: 9,
    letterSpacing: 1.6,
    textTransform: 'uppercase',
  },
  primaryTitle: {
    marginTop: 4,
    fontSize: 17,
    lineHeight: 1.2,
    color: 'var(--text-primary)',
  },
  primaryBadge: {
    border: '1px solid',
    padding: '5px 8px',
    fontSize: 9,
    letterSpacing: 1.4,
    textTransform: 'uppercase',
    whiteSpace: 'nowrap' as const,
  },
  secondaryLabel: {
    fontSize: 10,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  optionalIntroCard: {
    border: '1px solid',
    padding: '12px 14px',
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  optionalIntroCopy: {
    fontSize: 11,
    lineHeight: 1.6,
    color: 'var(--text-secondary)',
  },
  sectionFold: {
    border: '1px solid',
  },
  foldButton: {
    width: '100%',
    background: 'transparent',
    border: 'none',
    padding: 16,
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    cursor: 'pointer',
    textAlign: 'left' as const,
    fontFamily: 'inherit',
    gap: 16,
  },
  foldKicker: {
    display: 'block',
    fontSize: 9,
    letterSpacing: 1.6,
    textTransform: 'uppercase',
  },
  foldTitle: {
    display: 'block',
    marginTop: 4,
    fontSize: 14,
    lineHeight: 1.2,
  },
  foldMeta: {
    fontSize: 10,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  foldMetaWrap: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-end',
    gap: 4,
    minWidth: 110,
  },
  foldSummary: {
    fontSize: 10,
    lineHeight: 1.4,
    textAlign: 'right' as const,
  },
  foldBody: {
    padding: '0 16px 16px',
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
  },
  foldNotice: {
    fontSize: 11,
    lineHeight: 1.5,
    color: 'var(--text-muted)',
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
