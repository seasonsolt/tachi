import { describe, expect, it } from 'vitest';
import {
  createCtaClickEvent,
  createNewsletterSignupEvent,
  getWeekStart,
  hashNewsletterEmail,
  normalizeContentPath,
} from './contracts.js';

describe('content-ops/contracts', () => {
  it('normalizes paths from absolute URLs and strips query/hash noise', () => {
    expect(normalizeContentPath('https://e-acc.ai/workflow/claude-code?utm_source=test#section')).toBe('/workflow/claude-code');
    expect(normalizeContentPath('workflow/claude-code')).toBe('/workflow/claude-code');
    expect(normalizeContentPath('')).toBe('/');
  });

  it('derives Monday-based week buckets in UTC', () => {
    expect(getWeekStart('2026-04-16T12:00:00Z')).toBe('2026-04-13');
    expect(getWeekStart('2026-04-19T12:00:00Z')).toBe('2026-04-13');
  });

  it('creates CTA click events with normalized attribution', () => {
    const event = createCtaClickEvent({
      attribution: {
        path: 'workflow/claude-code',
        pageType: 'workflow',
        slug: 'claude-code',
        cluster: 'ai-coding-workflows',
      },
      ctaId: 'cta-1',
      ctaLabel: 'Open Claude Code guide',
      destination: 'https://affiliate.example/claude-code',
      placement: 'inline',
      monetization: 'affiliate',
    });

    expect(event.name).toBe('cta_click');
    expect(event.attribution.path).toBe('/workflow/claude-code');
    expect(event.attribution.domain).toBe('e-acc.ai');
    expect(event.placement).toBe('inline');
    expect(event.monetization).toBe('affiliate');
  });

  it('hashes newsletter emails before emitting signup events', () => {
    const expectedHash = hashNewsletterEmail(' Builder@Example.com ');
    const event = createNewsletterSignupEvent({
      attribution: {
        path: '/workflow/claude-code',
        pageType: 'workflow',
      },
      formId: 'newsletter-main',
      email: 'Builder@Example.com',
      consent: true,
      provider: 'buttondown',
    });

    expect(event.name).toBe('newsletter_signup');
    expect(event.emailHash).toBe(expectedHash);
    expect(event.emailHash).not.toContain('Builder');
  });
});
