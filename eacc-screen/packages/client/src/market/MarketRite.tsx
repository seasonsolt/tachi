import { useEffect, useMemo, useState } from 'react';
import { THEMES, formatTokenCount } from '@eacc/shared';
import type { MarketBuyerResponse, MarketListing, ThemeName } from '@eacc/shared';
import { useStore } from '../stores/store';
import { marketModeLabel, selectListingId } from './helpers';

interface MarketRiteProps {
  onClose: () => void;
}

interface RiteThemeProfile {
  kicker: string;
  title: string;
  subtitle: string;
  inscription: string;
  emptyListings: string;
  listingWord: string;
  listingPlural: string;
  buyerWord: string;
  sellerWord: string;
  aura: string;
  grain: string;
  glyph: string;
  marks: string[];
  epigraph: string;
}

const RITE_THEME_PROFILES: Record<ThemeName, RiteThemeProfile> = {
  cyber: {
    kicker: 'SHELL RELAY',
    title: 'Laughing Market',
    subtitle: 'Ghost in the Shell // 义体壳层中的镜像契约',
    inscription: 'The key remains in the shell. The rite crosses the wire.',
    emptyListings: 'No ghost-node has opened a relay yet.',
    listingWord: 'relay',
    listingPlural: 'relays',
    buyerWord: 'pilgrim',
    sellerWord: 'custodian',
    aura: 'radial-gradient(circle at 18% 14%, rgba(0,212,255,0.18), transparent 32%), radial-gradient(circle at 88% 10%, rgba(99,102,241,0.16), transparent 26%)',
    grain: 'linear-gradient(135deg, rgba(0,212,255,0.08), transparent 40%, rgba(99,102,241,0.08) 100%)',
    glyph: '⌬',
    marks: ['SECTION-9', 'TACHIKOMA', 'NET DIVE'],
    epigraph: 'A relay without custody is still a covenant of trust.',
  },
  matrix: {
    kicker: 'CODE EXCHANGE',
    title: 'Operator Bazaar',
    subtitle: 'Matrix Code // 母体代码中的绿色供奉',
    inscription: 'No key enters the machine-city. Only the green signal passes.',
    emptyListings: 'No operator has dropped a green thread into the code market.',
    listingWord: 'thread',
    listingPlural: 'threads',
    buyerWord: 'operator',
    sellerWord: 'node',
    aura: 'radial-gradient(circle at 15% 12%, rgba(0,255,65,0.16), transparent 30%), linear-gradient(180deg, rgba(0,255,65,0.07), transparent 26%, transparent 74%, rgba(0,143,17,0.08))',
    grain: 'repeating-linear-gradient(90deg, rgba(0,255,65,0.06) 0px, rgba(0,255,65,0.06) 1px, transparent 1px, transparent 12px)',
    glyph: '∴',
    marks: ['ZION', 'RED PILL', 'GREEN RAIN'],
    epigraph: 'The code market should feel discovered, not merely configured.',
  },
  amber: {
    kicker: 'UNICORN RELIQUARY',
    title: 'Amber Covenant',
    subtitle: 'Origami Unicorn // 折纸独角兽留下的余温契约',
    inscription: 'A shard of neon memory is folded into trade, but never surrendered.',
    emptyListings: 'The amber reliquary is waiting for its first folded offering.',
    listingWord: 'reliquary',
    listingPlural: 'reliquaries',
    buyerWord: 'witness',
    sellerWord: 'keeper',
    aura: 'radial-gradient(circle at 18% 12%, rgba(232,146,42,0.18), transparent 34%), radial-gradient(circle at 86% 16%, rgba(125,13,13,0.16), transparent 28%)',
    grain: 'linear-gradient(135deg, rgba(232,146,42,0.08), transparent 44%, rgba(125,13,13,0.08) 100%)',
    glyph: '◈',
    marks: ['UNICORN', 'TYRELL', 'OFF-WORLD'],
    epigraph: 'What is folded with care should arrive as memory, not residue.',
  },
  void: {
    kicker: 'MONOLITH ARCHIVE',
    title: 'Silent Exchange',
    subtitle: 'The Void // 石碑之内的冷光记录',
    inscription: 'What remains unreadable can still be offered, measured, and returned.',
    emptyListings: 'The archive is blank. No visible inscription has entered the chamber.',
    listingWord: 'inscription',
    listingPlural: 'inscriptions',
    buyerWord: 'observer',
    sellerWord: 'archive',
    aura: 'radial-gradient(circle at 24% 10%, rgba(0,0,0,0.08), transparent 30%), linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0.08) 40%, rgba(0,0,0,0.05) 100%)',
    grain: 'linear-gradient(135deg, rgba(0,0,0,0.035), transparent 36%, rgba(0,0,0,0.05) 100%)',
    glyph: '▮',
    marks: ['ODYSSEY', 'MONOLITH', 'STAR GATE'],
    epigraph: 'Silence, once framed, becomes its own form of exchange.',
  },
};

const FIELD_IDS = {
  sellerAlias: 'market-rite-seller-alias',
  model: 'market-rite-model',
  publicNote: 'market-rite-public-note',
  hubUrl: 'market-rite-hub-url',
  endpoint: 'market-rite-endpoint',
  apiKey: 'market-rite-api-key',
  passphrase: 'market-rite-passphrase',
  buyerAlias: 'market-rite-buyer-alias',
  buyerPrompt: 'market-rite-buyer-prompt',
  operatorSecret: 'market-rite-operator-secret',
} as const;

interface RiteChipProps {
  label: string;
  value?: string;
  accent: string;
  textColor: string;
  borderColor: string;
  background: string;
}

function RiteChip({ label, value, accent, textColor, borderColor, background }: RiteChipProps) {
  return (
    <div
      style={{
        border: `1px solid ${borderColor}`,
        background,
        padding: '8px 12px',
        minWidth: 92,
        boxShadow: `inset 0 1px 0 ${accent}22`,
      }}
    >
      <div style={{ fontSize: 9, letterSpacing: '0.18em', textTransform: 'uppercase', color: accent, opacity: 0.88 }}>
        {label}
      </div>
      {value && (
        <div style={{ marginTop: 4, fontSize: 12, color: textColor, letterSpacing: '0.08em' }}>{value}</div>
      )}
    </div>
  );
}

interface RiteSectionProps {
  label: string;
  title: string;
  note?: string;
  accent: string;
  borderColor: string;
  background: string;
  children: React.ReactNode;
}

function RiteSection({ label, title, note, accent, borderColor, background, children }: RiteSectionProps) {
  return (
    <section
      style={{
        border: `1px solid ${borderColor}`,
        background,
        padding: 16,
        boxShadow: `inset 0 1px 0 ${accent}22`,
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, alignItems: 'baseline' }}>
        <div>
          <div style={{ fontSize: 10, letterSpacing: '0.22em', textTransform: 'uppercase', color: accent, opacity: 0.8 }}>{label}</div>
          <div style={{ marginTop: 6, fontSize: 16, lineHeight: 1.2 }}>{title}</div>
        </div>
        {note && (
          <div style={{ maxWidth: 220, textAlign: 'right', fontSize: 11, lineHeight: 1.5, opacity: 0.62 }}>{note}</div>
        )}
      </div>
      <div style={{ marginTop: 14 }}>{children}</div>
    </section>
  );
}

interface RitualStatProps {
  label: string;
  value: string;
  accent: string;
  background: string;
  borderColor: string;
}

function RitualStat({ label, value, accent, background, borderColor }: RitualStatProps) {
  return (
    <div
      style={{
        border: `1px solid ${borderColor}`,
        background,
        padding: '10px 12px',
        minWidth: 92,
        flex: 1,
      }}
    >
      <div style={{ fontSize: 9, letterSpacing: '0.18em', textTransform: 'uppercase', color: accent, opacity: 0.72 }}>{label}</div>
      <div style={{ marginTop: 8, fontSize: 18, lineHeight: 1 }}>{value}</div>
    </div>
  );
}

export function MarketRite({ onClose }: MarketRiteProps) {
  const theme = useStore((s) => s.theme);
  const marketState = useStore((s) => s.marketState);
  const buyerAlias = useStore((s) => s.buyerAlias);
  const setBuyerAlias = useStore((s) => s.setBuyerAlias);
  const t = THEMES[theme];
  const profile = RITE_THEME_PROFILES[theme];

  const [sellerAlias, setSellerAlias] = useState('');
  const [hubUrl, setHubUrl] = useState('');
  const [endpoint, setEndpoint] = useState('');
  const [model, setModel] = useState('gpt-4o-mini');
  const [publicNote, setPublicNote] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [passphrase, setPassphrase] = useState('');
  const [buyerPrompt, setBuyerPrompt] = useState('Describe the vault-market proof.');
  const [selectedListingId, setSelectedListingId] = useState<string | null>(null);
  const [operatorSecret, setOperatorSecret] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [invokeResult, setInvokeResult] = useState<MarketBuyerResponse | null>(null);

  useEffect(() => {
    const seller = marketState?.seller;
    if (!seller) return;
    setSellerAlias((value) => value || seller.sellerAlias);
    setHubUrl((value) => value || seller.hubUrl || marketState?.hubUrl || '');
    setEndpoint((value) => value || seller.endpoint || `https://${seller.endpointHost}/v1/chat/completions`);
    setModel((value) => value || seller.model);
    setPublicNote((value) => value || seller.publicNote || '');
  }, [marketState]);

  useEffect(() => {
    setSelectedListingId((current) => selectListingId(marketState?.listings || [], current));
  }, [marketState]);

  const selectedListing = useMemo(() => {
    return marketState?.listings.find((listing) => listing.listingId === selectedListingId) || null;
  }, [marketState, selectedListingId]);

  const chipBackground = `linear-gradient(135deg, ${t.surfaceSoft}, ${t.accentGlow})`;
  const sectionBackground = `linear-gradient(135deg, ${t.surfaceStrong}, ${t.accentGlow})`;
  const fieldBackground = `linear-gradient(135deg, ${t.surfaceSoft}, rgba(0,0,0,0.02))`;
  const ceremonialLine = `linear-gradient(90deg, transparent, ${t.fireCore}, ${t.surfaceBorder}, transparent)`;

  async function saveVault() {
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/market/local-vault', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sellerAlias,
          hubUrl,
          endpoint,
          model,
          publicNote,
          apiKey,
          passphrase,
        }),
      });
      const body = await response.json() as { error?: string };
      if (!response.ok) throw new Error(body.error || 'Failed to save vault');
      setApiKey('');
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Failed to save vault');
    } finally {
      setBusy(false);
    }
  }

  async function unlockVault() {
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/market/unlock', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passphrase }),
      });
      const body = await response.json() as { error?: string };
      if (!response.ok) throw new Error(body.error || 'Failed to unlock vault');
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Failed to unlock vault');
    } finally {
      setBusy(false);
    }
  }

  async function lockVault() {
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/market/lock', { method: 'POST' });
      const body = await response.json() as { error?: string };
      if (!response.ok) throw new Error(body.error || 'Failed to lock vault');
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Failed to lock vault');
    } finally {
      setBusy(false);
    }
  }

  async function invokeListing(listing: MarketListing) {
    setBusy(true);
    setError(null);
    setInvokeResult(null);
    try {
      const response = await fetch('/api/market/request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          listingId: listing.listingId,
          prompt: buyerPrompt,
          buyerAlias: buyerAlias || undefined,
        }),
      });
      const body = await response.json() as MarketBuyerResponse & { error?: string };
      if (!response.ok) throw new Error(body.error || 'Invocation failed');
      setInvokeResult(body);
      if (body.error) setError(body.error);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Invocation failed');
    } finally {
      setBusy(false);
    }
  }

  async function toggleListing(listing: MarketListing, disabled: boolean) {
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/market/admin/disable', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-market-operator-secret': operatorSecret,
        },
        body: JSON.stringify({ listingId: listing.listingId, disabled }),
      });
      const body = await response.json() as { error?: string };
      if (!response.ok) throw new Error(body.error || 'Failed to update listing');
    } catch (value) {
      setError(value instanceof Error ? value.message : 'Failed to update listing');
    } finally {
      setBusy(false);
    }
  }

  const modeLabel = marketModeLabel(marketState?.serverMode);
  const listingCount = marketState?.listings.length ?? 0;
  const sellerSummary = marketState?.seller;
  const listingCountLabel = `${listingCount} ${listingCount === 1 ? profile.listingWord : profile.listingPlural}`;

  return (
    <div style={styles.overlay} onClick={(event) => event.stopPropagation()}>
      <div style={{ ...styles.backdrop, background: theme === 'void' ? 'rgba(255,255,255,0.28)' : 'rgba(0,0,0,0.24)' }} />
      <div
        style={{
          ...styles.panel,
          borderColor: t.surfaceBorder,
          background: `linear-gradient(180deg, ${t.surfaceStrong}, ${t.surfaceSoft})`,
          color: t.textPrimary,
          boxShadow: `-30px 0 90px rgba(0,0,0,0.42), inset 1px 0 0 ${t.surfaceBorder}`,
        }}
      >
        <div style={{ ...styles.chromeAura, backgroundImage: `${profile.aura}, ${profile.grain}` }} />
        <div style={{ ...styles.edgeLine, background: ceremonialLine }} />

        <div style={styles.inner}>
          <div style={styles.headerRow}>
            <div style={styles.headerCopy}>
              <div style={{ ...styles.kicker, color: t.fireCore }}>{profile.kicker}</div>
              <div style={{ ...styles.title, fontFamily: t.scriptureFont }}>{profile.title}</div>
              <div style={{ ...styles.subtitle, color: t.textSecondary }}>{profile.subtitle}</div>
            </div>
            <button onClick={onClose} style={{ ...styles.closeBtn, color: t.textSecondary }} aria-label="Close Market Rite">
              ✕
            </button>
          </div>

          <div style={{ ...styles.inscription, borderColor: t.surfaceBorder, color: t.textSecondary }}>
            <span style={{ color: t.fireCore }}>{profile.glyph}</span>
            <span>{profile.inscription}</span>
          </div>

          <div style={styles.markRow}>
            {profile.marks.map((mark) => (
              <div
                key={mark}
                style={{
                  ...styles.markChip,
                  borderColor: t.surfaceBorder,
                  background: fieldBackground,
                  color: t.textSecondary,
                }}
              >
                {mark}
              </div>
            ))}
          </div>

          <div style={styles.chipRow}>
            <RiteChip label="mode" value={modeLabel} accent={t.fireCore} textColor={t.textPrimary} borderColor={t.surfaceBorder} background={chipBackground} />
            <RiteChip label="market" value={listingCountLabel} accent={t.fireCore} textColor={t.textPrimary} borderColor={t.surfaceBorder} background={chipBackground} />
            <RiteChip label="law" value="vault-first" accent={t.fireCore} textColor={t.textPrimary} borderColor={t.surfaceBorder} background={chipBackground} />
          </div>

          {error && (
            <div style={{ ...styles.error, borderColor: t.fireCore, background: `linear-gradient(135deg, ${t.surfaceStrong}, ${t.accentGlow})`, color: t.fireCore }}>
              {error}
            </div>
          )}

          {marketState?.serverMode === 'seller' && (
            <div style={styles.stack}>
              <RiteSection
                label={`${profile.sellerWord} sigil`}
                title="Seller Reliquary"
                note="The seller keeps the living key; the hub receives only metadata, pulse, and capability proof."
                accent={t.fireCore}
                borderColor={t.surfaceBorder}
                background={sectionBackground}
              >
                <div style={styles.gridTwo}>
                  <div>
                    <label htmlFor={FIELD_IDS.sellerAlias} style={styles.inputLabel}>Seller Alias</label>
                    <input id={FIELD_IDS.sellerAlias} value={sellerAlias} onChange={(event) => setSellerAlias(event.target.value)} style={{ ...styles.input, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
                  </div>
                  <div>
                    <label htmlFor={FIELD_IDS.model} style={styles.inputLabel}>Model Seal</label>
                    <input id={FIELD_IDS.model} value={model} onChange={(event) => setModel(event.target.value)} style={{ ...styles.input, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
                  </div>
                </div>
                <label htmlFor={FIELD_IDS.publicNote} style={styles.inputLabel}>Public Note</label>
                <textarea id={FIELD_IDS.publicNote} value={publicNote} onChange={(event) => setPublicNote(event.target.value)} rows={2} style={{ ...styles.textarea, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
              </RiteSection>

              <RiteSection
                label="relay host"
                title="Bridge Alignment"
                note="Seller-local mode mirrors hub state downward while the outbound bridge carries the rite upward."
                accent={t.fireCore}
                borderColor={t.surfaceBorder}
                background={sectionBackground}
              >
                <label htmlFor={FIELD_IDS.hubUrl} style={styles.inputLabel}>Hub URL</label>
                <input id={FIELD_IDS.hubUrl} value={hubUrl} onChange={(event) => setHubUrl(event.target.value)} placeholder="http://hub-host:3666" style={{ ...styles.input, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
                <label htmlFor={FIELD_IDS.endpoint} style={styles.inputLabel}>Endpoint</label>
                <input id={FIELD_IDS.endpoint} value={endpoint} onChange={(event) => setEndpoint(event.target.value)} placeholder="https://provider.example.com/v1/chat/completions" style={{ ...styles.input, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
              </RiteSection>

              <RiteSection
                label="sealed key"
                title="Vault Lock"
                note="Plaintext enters only this local chamber. It is sealed before the market can witness it."
                accent={t.fireCore}
                borderColor={t.surfaceBorder}
                background={sectionBackground}
              >
                <div style={styles.gridTwo}>
                  <div>
                    <label htmlFor={FIELD_IDS.apiKey} style={styles.inputLabel}>API Key</label>
                    <input id={FIELD_IDS.apiKey} type="password" value={apiKey} onChange={(event) => setApiKey(event.target.value)} style={{ ...styles.input, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
                  </div>
                  <div>
                    <label htmlFor={FIELD_IDS.passphrase} style={styles.inputLabel}>Passphrase</label>
                    <input id={FIELD_IDS.passphrase} type="password" value={passphrase} onChange={(event) => setPassphrase(event.target.value)} style={{ ...styles.input, borderColor: t.surfaceBorder, background: fieldBackground, color: t.textPrimary }} />
                  </div>
                </div>
                <div style={styles.actionRow}>
                  <button onClick={saveVault} disabled={busy} style={{ ...styles.primaryBtn, borderColor: t.fireCore, background: t.accentGlow, color: t.textPrimary }}>
                    Seal Vault
                  </button>
                  <button onClick={unlockVault} disabled={busy} style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, background: 'transparent', color: t.textSecondary }}>
                    Unlock + Bridge
                  </button>
                  <button onClick={lockVault} disabled={busy} style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, background: 'transparent', color: t.textSecondary }}>
                    Lock
                  </button>
                </div>
                {sellerSummary && (
                  <div style={{ ...styles.statusStrip, borderColor: t.surfaceBorder }}>
                    <RiteChip label="status" value={sellerSummary.status} accent={t.fireCore} textColor={t.textPrimary} borderColor={t.surfaceBorder} background={fieldBackground} />
                    <RiteChip label="token" value={sellerSummary.capabilityTokenPreview} accent={t.fireCore} textColor={t.textPrimary} borderColor={t.surfaceBorder} background={fieldBackground} />
                    <RiteChip label="hub" value={sellerSummary.hubUrl || 'not set'} accent={t.fireCore} textColor={t.textPrimary} borderColor={t.surfaceBorder} background={fieldBackground} />
                  </div>
                )}
              </RiteSection>
            </div>
          )}

          <RiteSection
            label="public offerings"
            title="Market Gallery"
            note="A public sign must exist: the buyer should feel a living market, not only a hidden proof."
            accent={t.fireCore}
            borderColor={t.surfaceBorder}
            background={sectionBackground}
          >
            {!marketState?.listings.length && (
              <div style={{ ...styles.emptyState, color: t.textSecondary }}>{profile.emptyListings}</div>
            )}
            <div style={styles.listings}>
              {marketState?.listings.map((listing) => {
                const selected = listing.listingId === selectedListingId;
                const listingGlow = selected ? t.accentGlow : 'transparent';
                return (
                  <button
                    key={listing.listingId}
                    type="button"
                    onClick={() => setSelectedListingId(listing.listingId)}
                    style={{
                      ...styles.listing,
                      borderColor: selected ? t.fireCore : t.surfaceBorder,
                      background: `linear-gradient(135deg, ${selected ? t.surfaceStrong : t.surfaceSoft}, ${listingGlow})`,
                      boxShadow: selected ? `0 0 0 1px ${t.fireCore} inset, 0 0 24px ${t.accentGlow}` : 'none',
                      color: t.textPrimary,
                    }}
                  >
                    <div style={{ ...styles.listingSigil, background: t.fireCore }} />
                    <div style={styles.listingHeader}>
                      <div>
                        <div style={styles.listingTitle}>{listing.sellerAlias}</div>
                        <div style={{ ...styles.metaLine, color: t.textSecondary }}>{listing.model} · {listing.endpointHost}</div>
                      </div>
                      <div style={{ ...styles.statusBadge, borderColor: listing.disabled ? t.fireCore : t.surfaceBorder, color: listing.disabled ? t.fireCore : t.textSecondary, background: fieldBackground }}>
                        {listing.status}
                      </div>
                    </div>
                    {listing.publicNote && <div style={{ ...styles.note, color: t.textSecondary }}>{listing.publicNote}</div>}
                    <div style={styles.listingStats}>
                      <RitualStat label="rites" value={String(listing.requestCount)} accent={t.fireCore} background={fieldBackground} borderColor={t.surfaceBorder} />
                      <RitualStat label="total" value={formatTokenCount(listing.totalTokens)} accent={t.fireCore} background={fieldBackground} borderColor={t.surfaceBorder} />
                      <RitualStat label="seal" value={listing.capabilityTokenPreview} accent={t.fireCore} background={fieldBackground} borderColor={t.surfaceBorder} />
                    </div>
                  </button>
                );
              })}
            </div>

            {selectedListing && (
              <div style={{ ...styles.invokePanel, borderColor: t.surfaceBorder, background: fieldBackground }}>
                <div style={styles.invokeHeader}>
                  <div>
                    <div style={{ ...styles.kicker, color: t.fireCore }}>Buyer Rite</div>
                    <div style={styles.invokeTitle}>Invoke {selectedListing.sellerAlias}</div>
                  </div>
                  <div style={{ ...styles.invokeAside, color: t.textSecondary }}>{profile.buyerWord} → {profile.listingWord}</div>
                </div>
                <label htmlFor={FIELD_IDS.buyerAlias} style={styles.inputLabel}>Buyer Alias</label>
                <input id={FIELD_IDS.buyerAlias} value={buyerAlias} onChange={(event) => setBuyerAlias(event.target.value)} style={{ ...styles.input, borderColor: t.surfaceBorder, background: sectionBackground, color: t.textPrimary }} />
                <label htmlFor={FIELD_IDS.buyerPrompt} style={styles.inputLabel}>Invocation Prompt</label>
                <textarea id={FIELD_IDS.buyerPrompt} value={buyerPrompt} onChange={(event) => setBuyerPrompt(event.target.value)} rows={4} style={{ ...styles.textarea, borderColor: t.surfaceBorder, background: sectionBackground, color: t.textPrimary }} />
                <div style={styles.actionRow}>
                  <button onClick={() => invokeListing(selectedListing)} disabled={busy || selectedListing.disabled} style={{ ...styles.primaryBtn, borderColor: t.fireCore, background: t.accentGlow, color: t.textPrimary }}>
                    Invoke Offering
                  </button>
                  {marketState?.operatorControlsAvailable && (
                    <>
                      <input id={FIELD_IDS.operatorSecret} type="password" aria-label="Operator secret" value={operatorSecret} onChange={(event) => setOperatorSecret(event.target.value)} placeholder="operator secret" style={{ ...styles.inlineSecret, borderColor: t.surfaceBorder, background: sectionBackground, color: t.textPrimary }} />
                      <button onClick={() => toggleListing(selectedListing, !selectedListing.disabled)} disabled={busy} style={{ ...styles.utilityBtn, borderColor: t.surfaceBorder, background: 'transparent', color: t.textSecondary }}>
                        {selectedListing.disabled ? 'Enable' : 'Disable'}
                      </button>
                    </>
                  )}
                </div>
              </div>
            )}
          </RiteSection>

          {invokeResult && (
            <RiteSection
              label="answered rite"
              title="Response Ledger"
              note="A successful market invocation should feel witnessed, counted, and culturally legible."
              accent={t.fireCore}
              borderColor={t.surfaceBorder}
              background={sectionBackground}
            >
              <div style={styles.resultHeader}>
                <div>
                  <div style={styles.listingTitle}>{invokeResult.sellerAlias}</div>
                  <div style={{ ...styles.metaLine, color: t.textSecondary }}>{invokeResult.model}</div>
                </div>
                <div style={{ ...styles.statusBadge, borderColor: invokeResult.error ? t.fireCore : t.surfaceBorder, color: invokeResult.error ? t.fireCore : t.textSecondary, background: fieldBackground }}>
                  {invokeResult.error ? 'fracture' : 'accepted'}
                </div>
              </div>
              <div style={styles.listingStats}>
                <RitualStat label="input" value={String(invokeResult.usage.inputTokens)} accent={t.fireCore} background={fieldBackground} borderColor={t.surfaceBorder} />
                <RitualStat label="output" value={String(invokeResult.usage.outputTokens)} accent={t.fireCore} background={fieldBackground} borderColor={t.surfaceBorder} />
                <RitualStat label="total" value={String(invokeResult.usage.totalTokens)} accent={t.fireCore} background={fieldBackground} borderColor={t.surfaceBorder} />
              </div>
              <div style={{ ...styles.resultText, borderColor: t.surfaceBorder, background: fieldBackground, color: invokeResult.error ? t.fireCore : t.textPrimary }}>
                {invokeResult.outputText || invokeResult.error || 'No response text returned.'}
              </div>
            </RiteSection>
          )}

          <div style={{ ...styles.epigraph, color: t.textMuted, borderColor: t.surfaceBorder }}>
            {profile.epigraph}
          </div>
        </div>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    justifyContent: 'flex-end',
    pointerEvents: 'auto',
    zIndex: 18,
  },
  backdrop: {
    position: 'absolute',
    inset: 0,
  },
  panel: {
    position: 'relative',
    width: 560,
    maxWidth: '100vw',
    height: '100%',
    borderLeftWidth: 1,
    borderLeftStyle: 'solid',
    overflowY: 'auto',
    fontFamily: 'var(--data-font)',
  },
  chromeAura: {
    position: 'absolute',
    inset: 0,
    pointerEvents: 'none',
    opacity: 1,
  },
  edgeLine: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 1,
    height: '100%',
    opacity: 0.95,
  },
  inner: {
    position: 'relative',
    padding: 24,
  },
  headerRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 16,
  },
  headerCopy: {
    minWidth: 0,
  },
  kicker: {
    fontSize: 10,
    letterSpacing: '0.24em',
    textTransform: 'uppercase',
    opacity: 0.88,
  },
  title: {
    marginTop: 10,
    fontSize: 34,
    lineHeight: 1.02,
  },
  subtitle: {
    marginTop: 10,
    fontSize: 13,
    lineHeight: 1.6,
  },
  closeBtn: {
    appearance: 'none',
    background: 'transparent',
    border: 0,
    borderRadius: 0,
    fontSize: 22,
    cursor: 'pointer',
    padding: 0,
    lineHeight: 1,
    minWidth: 44,
    minHeight: 44,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  inscription: {
    marginTop: 18,
    padding: '12px 14px',
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderTopStyle: 'solid',
    borderBottomStyle: 'solid',
    fontSize: 12,
    lineHeight: 1.7,
    display: 'flex',
    gap: 10,
    alignItems: 'center',
  },
  chipRow: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 18,
  },
  markRow: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 14,
  },
  markChip: {
    borderWidth: 1,
    borderStyle: 'solid',
    padding: '6px 10px',
    fontSize: 9,
    letterSpacing: '0.18em',
    textTransform: 'uppercase',
    opacity: 0.72,
  },
  error: {
    marginTop: 18,
    padding: '12px 14px',
    borderWidth: 1,
    borderStyle: 'solid',
    fontSize: 12,
    lineHeight: 1.6,
  },
  stack: {
    display: 'grid',
    gap: 16,
    marginTop: 22,
  },
  inputLabel: {
    display: 'block',
    marginTop: 12,
    marginBottom: 6,
    fontSize: 10,
    letterSpacing: '0.18em',
    textTransform: 'uppercase',
    opacity: 0.7,
  },
  gridTwo: {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, minmax(0, 1fr))',
    gap: 12,
  },
  input: {
    width: '100%',
    borderWidth: 1,
    borderStyle: 'solid',
    borderRadius: 0,
    padding: '12px 14px',
    fontSize: 13,
    minHeight: 44,
    lineHeight: 1.4,
  },
  textarea: {
    width: '100%',
    borderWidth: 1,
    borderStyle: 'solid',
    borderRadius: 0,
    padding: '12px 14px',
    fontSize: 13,
    minHeight: 96,
    lineHeight: 1.6,
    resize: 'vertical',
  },
  actionRow: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 16,
    alignItems: 'center',
  },
  primaryBtn: {
    appearance: 'none',
    borderWidth: 1,
    borderStyle: 'solid',
    borderRadius: 0,
    padding: '11px 16px',
    cursor: 'pointer',
    fontSize: 11,
    letterSpacing: '0.18em',
    textTransform: 'uppercase',
    minHeight: 44,
  },
  utilityBtn: {
    appearance: 'none',
    borderWidth: 1,
    borderStyle: 'solid',
    borderRadius: 0,
    padding: '11px 16px',
    cursor: 'pointer',
    fontSize: 11,
    letterSpacing: '0.12em',
    minHeight: 44,
  },
  statusStrip: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
    gap: 10,
    marginTop: 16,
    borderTopWidth: 1,
    borderTopStyle: 'solid',
    paddingTop: 14,
  },
  emptyState: {
    fontSize: 13,
    lineHeight: 1.7,
  },
  listings: {
    display: 'grid',
    gap: 12,
  },
  listing: {
    position: 'relative',
    appearance: 'none',
    textAlign: 'left',
    borderWidth: 1,
    borderStyle: 'solid',
    borderRadius: 0,
    padding: 16,
    cursor: 'pointer',
    overflow: 'hidden',
  },
  listingSigil: {
    position: 'absolute',
    inset: '0 auto 0 0',
    width: 2,
  },
  listingHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
  },
  listingTitle: {
    fontSize: 15,
    lineHeight: 1.2,
  },
  statusBadge: {
    borderWidth: 1,
    borderStyle: 'solid',
    padding: '6px 10px',
    fontSize: 10,
    letterSpacing: '0.18em',
    textTransform: 'uppercase',
    whiteSpace: 'nowrap',
  },
  note: {
    marginTop: 10,
    fontSize: 12,
    lineHeight: 1.6,
  },
  metaLine: {
    fontSize: 11,
    lineHeight: 1.5,
    marginTop: 6,
  },
  listingStats: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
    gap: 8,
    marginTop: 14,
  },
  invokePanel: {
    marginTop: 16,
    borderWidth: 1,
    borderStyle: 'solid',
    padding: 16,
  },
  invokeHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    gap: 16,
    alignItems: 'baseline',
  },
  invokeTitle: {
    marginTop: 8,
    fontSize: 18,
    lineHeight: 1.2,
  },
  invokeAside: {
    fontSize: 11,
    lineHeight: 1.5,
    textAlign: 'right',
  },
  inlineSecret: {
    borderWidth: 1,
    borderStyle: 'solid',
    borderRadius: 0,
    padding: '11px 12px',
    fontSize: 12,
    minWidth: 150,
    minHeight: 44,
    lineHeight: 1.4,
  },
  resultHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    gap: 12,
    alignItems: 'flex-start',
  },
  resultText: {
    marginTop: 14,
    borderWidth: 1,
    borderStyle: 'solid',
    padding: '14px 16px',
    whiteSpace: 'pre-wrap',
    lineHeight: 1.7,
    fontSize: 14,
  },
  epigraph: {
    marginTop: 24,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopStyle: 'solid',
    fontSize: 11,
    lineHeight: 1.7,
    letterSpacing: '0.06em',
    opacity: 0.72,
  },
};
