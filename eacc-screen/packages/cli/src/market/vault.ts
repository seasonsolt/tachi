import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
  randomUUID,
  scryptSync,
} from 'node:crypto';
import type {
  MarketSellerLocalConfig,
  MarketSellerSecretBundle,
  MarketVaultRecord,
} from '@eacc/shared';
import { MARKET_VAULT_PATH, readJsonFile, writeJsonFile } from './storage.js';

interface SaveSellerVaultInput {
  sellerAlias: string;
  endpoint: string;
  model: string;
  publicNote?: string;
  apiKey: string;
  passphrase: string;
  existing?: MarketSellerLocalConfig | null;
}

export interface SavedSellerVault {
  vault: MarketVaultRecord;
  localConfig: MarketSellerLocalConfig;
  secrets: MarketSellerSecretBundle;
}

function endpointHost(endpoint: string): string {
  return new URL(endpoint).host;
}

function deriveKey(passphrase: string, salt: Buffer): Buffer {
  return scryptSync(passphrase, salt, 32);
}

function toBase64(value: Buffer): string {
  return value.toString('base64');
}

function fromBase64(value: string): Buffer {
  return Buffer.from(value, 'base64');
}

function encryptSecrets(
  passphrase: string,
  secrets: MarketSellerSecretBundle,
): Pick<MarketVaultRecord, 'salt' | 'iv' | 'authTag' | 'ciphertext'> {
  const salt = randomBytes(16);
  const iv = randomBytes(12);
  const key = deriveKey(passphrase, salt);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plaintext = Buffer.from(JSON.stringify(secrets), 'utf-8');
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return {
    salt: toBase64(salt),
    iv: toBase64(iv),
    authTag: toBase64(cipher.getAuthTag()),
    ciphertext: toBase64(ciphertext),
  };
}

export function decryptVault(
  record: MarketVaultRecord,
  passphrase: string,
): MarketSellerSecretBundle {
  const key = deriveKey(passphrase, fromBase64(record.salt));
  const decipher = createDecipheriv('aes-256-gcm', key, fromBase64(record.iv));
  decipher.setAuthTag(fromBase64(record.authTag));
  const plaintext = Buffer.concat([
    decipher.update(fromBase64(record.ciphertext)),
    decipher.final(),
  ]);
  return JSON.parse(plaintext.toString('utf-8')) as MarketSellerSecretBundle;
}

export function createSellerVault(input: SaveSellerVaultInput): SavedSellerVault {
  const now = Date.now();
  const sellerId = input.existing?.sellerId ?? randomUUID();
  const listingId = input.existing?.listingId ?? randomUUID();
  const capabilityToken = randomUUID().replace(/-/g, '');
  const capabilityTokenPreview = capabilityToken.slice(0, 8);
  const secrets: MarketSellerSecretBundle = {
    apiKey: input.apiKey,
    capabilityToken,
  };
  const encrypted = encryptSecrets(input.passphrase, secrets);
  const host = endpointHost(input.endpoint);
  const vault: MarketVaultRecord = {
    version: 1,
    sellerId,
    listingId,
    sellerAlias: input.sellerAlias.trim(),
    endpoint: input.endpoint.trim(),
    endpointHost: host,
    model: input.model.trim(),
    publicNote: input.publicNote?.trim() || undefined,
    createdAt: input.existing ? now : now,
    updatedAt: now,
    ...encrypted,
  };
  const localConfig: MarketSellerLocalConfig = {
    sellerId,
    listingId,
    sellerAlias: vault.sellerAlias,
    endpoint: vault.endpoint,
    endpointHost: vault.endpointHost,
    model: vault.model,
    publicNote: vault.publicNote,
    capabilityTokenPreview,
    enabled: true,
  };
  return { vault, localConfig, secrets };
}

export function readSellerVault(): MarketVaultRecord | null {
  return readJsonFile<MarketVaultRecord>(MARKET_VAULT_PATH);
}

export function writeSellerVault(record: MarketVaultRecord): void {
  writeJsonFile(MARKET_VAULT_PATH, record);
}
