import { describe, expect, it } from 'vitest';
import { createSellerVault, decryptVault } from './vault.js';

describe('market vault', () => {
  it('encrypts secrets and decrypts them with the correct passphrase', () => {
    const saved = createSellerVault({
      sellerAlias: 'thin',
      endpoint: 'https://provider.example.com/v1/chat/completions',
      model: 'gpt-4o-mini',
      publicNote: 'night shift capacity',
      apiKey: 'sk-market-secret',
      passphrase: 'ritual-passphrase',
    });

    expect(saved.localConfig.sellerAlias).toBe('thin');
    expect(saved.localConfig.endpointHost).toBe('provider.example.com');
    expect(saved.vault.ciphertext).not.toContain('sk-market-secret');
    expect(JSON.stringify(saved.vault)).not.toContain('sk-market-secret');

    const decrypted = decryptVault(saved.vault, 'ritual-passphrase');
    expect(decrypted.apiKey).toBe('sk-market-secret');
    expect(decrypted.capabilityToken.length).toBeGreaterThan(16);
  });

  it('rejects the wrong passphrase', () => {
    const saved = createSellerVault({
      sellerAlias: 'thin',
      endpoint: 'https://provider.example.com/v1/chat/completions',
      model: 'gpt-4o-mini',
      apiKey: 'sk-market-secret',
      passphrase: 'ritual-passphrase',
    });

    expect(() => decryptVault(saved.vault, 'wrong-passphrase')).toThrow();
  });
});
