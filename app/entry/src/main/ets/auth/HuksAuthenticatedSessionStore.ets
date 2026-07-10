import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryResult } from '../core/RepositoryResult';
import { AuthenticatedSession } from './AuthModels';

const PRODUCTION_KEY_ALIAS: string = 'riverside_session_v1';
const PRODUCTION_PREFERENCES: string = 'riverside_authenticated_session';
const TEST_KEY_ALIAS: string = 'riverside_session_test_v1';
const TEST_PREFERENCES: string = 'riverside_authenticated_session_ohos_test';
const SESSION_RECORD_KEY: string = 'encrypted-session';
const SESSION_SCHEMA_VERSION: number = 1;
const GCM_TAG_LENGTH: number = 16;
const ASSOCIATED_DATA_TEXT: string = 'riverside.authenticated-session.v1';

interface SessionPlaintext {
  key: string;
  clientId: string;
}

interface EncryptedSessionEnvelope {
  version: number;
  nonce: string;
  cipherText: string;
}

class EncryptedSessionData {
  public readonly nonce: Uint8Array;
  public readonly cipherText: Uint8Array;

  public constructor(nonce: Uint8Array, cipherText: Uint8Array) {
    this.nonce = nonce;
    this.cipherText = cipherText;
  }
}

export enum SessionLoadKind {
  EMPTY = 'empty',
  SESSION = 'session',
  FAILURE = 'failure'
}

export class SessionLoadResult {
  public readonly kind: SessionLoadKind;
  public readonly session: AuthenticatedSession | null;
  public readonly message: string;

  private constructor(kind: SessionLoadKind, session: AuthenticatedSession | null, message: string) {
    this.kind = kind;
    this.session = session;
    this.message = message;
  }

  public static empty(): SessionLoadResult {
    return new SessionLoadResult(SessionLoadKind.EMPTY, null, '');
  }

  public static session(session: AuthenticatedSession): SessionLoadResult {
    return new SessionLoadResult(SessionLoadKind.SESSION, session, '');
  }

  public static failure(message: string): SessionLoadResult {
    return new SessionLoadResult(SessionLoadKind.FAILURE, null, message);
  }
}

export interface AuthenticatedSessionStore {
  load(): Promise<SessionLoadResult>;

  save(session: AuthenticatedSession): Promise<RepositoryResult<boolean>>;

  clear(): Promise<RepositoryResult<boolean>>;
}

function base64Encode(value: Uint8Array): string | null {
  try {
    return new util.Base64Helper().encodeToStringSync(value, util.Type.BASIC);
  } catch (_) {
    return null;
  }
}

function base64Decode(value: string): Uint8Array | null {
  try {
    return new util.Base64Helper().decodeSync(value, util.Type.BASIC);
  } catch (_) {
    return null;
  }
}

function encodeEnvelope(data: EncryptedSessionData): string | null {
  const nonce: string | null = base64Encode(data.nonce);
  const cipherText: string | null = base64Encode(data.cipherText);
  if (nonce === null || cipherText === null) {
    return null;
  }
  const envelope: EncryptedSessionEnvelope = {
    version: SESSION_SCHEMA_VERSION,
    nonce: nonce,
    cipherText: cipherText
  };
  return JSON.stringify(envelope);
}

function decodeEnvelope(text: string): EncryptedSessionData | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null || envelope.number('version') !== SESSION_SCHEMA_VERSION) {
    return null;
  }
  const nonceText: string | null = envelope.string('nonce');
  const cipherTextValue: string | null = envelope.string('cipherText');
  if (nonceText === null || cipherTextValue === null) {
    return null;
  }
  const nonce: Uint8Array | null = base64Decode(nonceText);
  const cipherText: Uint8Array | null = base64Decode(cipherTextValue);
  if (nonce === null || nonce.length !== 12 || cipherText === null || cipherText.length <= GCM_TAG_LENGTH) {
    return null;
  }
  return new EncryptedSessionData(nonce, cipherText);
}

function caughtErrorCode(error: Object): number | null {
  try {
    return JsonObjectReader.parse(JSON.stringify(error))?.number('code') ?? null;
  } catch (_) {
    return null;
  }
}

function generateKeyProperties(): Array<huks.HuksParam> {
  return [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
    {
      tag: huks.HuksTag.HUKS_TAG_PURPOSE,
      value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
    }
  ];
}

function operationProperties(
  purpose: huks.HuksKeyPurpose,
  nonce: Uint8Array,
  authenticationTag: Uint8Array | null
): Array<huks.HuksParam> {
  const encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
  const properties: Array<huks.HuksParam> = [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
    { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
    { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: encoder.encodeInto(ASSOCIATED_DATA_TEXT) }
  ];
  if (authenticationTag !== null) {
    properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: authenticationTag });
  }
  return properties;
}

export class HuksAuthenticatedSessionStore implements AuthenticatedSessionStore {
  private readonly context: common.Context;
  private readonly keyAlias: string;
  private readonly preferencesName: string;

  private constructor(context: common.Context, keyAlias: string, preferencesName: string) {
    this.context = context;
    this.keyAlias = keyAlias;
    this.preferencesName = preferencesName;
  }

  public static create(context: common.Context): HuksAuthenticatedSessionStore {
    return new HuksAuthenticatedSessionStore(context, PRODUCTION_KEY_ALIAS, PRODUCTION_PREFERENCES);
  }

  public static forTesting(context: common.Context): HuksAuthenticatedSessionStore {
    return new HuksAuthenticatedSessionStore(context, TEST_KEY_ALIAS, TEST_PREFERENCES);
  }

  public async load(): Promise<SessionLoadResult> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, this.preferencesName);
      const value: preferences.ValueType = await store.get(SESSION_RECORD_KEY, '');
      if (typeof value !== 'string' || value.length === 0) {
        return SessionLoadResult.empty();
      }
      const encrypted: EncryptedSessionData | null = decodeEnvelope(value);
      if (encrypted === null) {
        return SessionLoadResult.failure('本地认证会话格式无效');
      }
      const plaintext: Uint8Array | null = await this.decrypt(encrypted);
      if (plaintext === null) {
        return SessionLoadResult.failure('无法解密本地认证会话');
      }
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { fatal: true });
      const record: JsonObjectReader | null = JsonObjectReader.parse(decoder.decodeToString(plaintext));
      const key: string | null = record?.string('key') ?? null;
      const clientId: string | null = record?.string('clientId') ?? null;
      if (key === null || clientId === null) {
        return SessionLoadResult.failure('本地认证会话内容无效');
      }
      const session: AuthenticatedSession | null = AuthenticatedSession.create(key, clientId);
      return session === null
        ? SessionLoadResult.failure('本地认证会话内容无效')
        : SessionLoadResult.session(session);
    } catch (_) {
      return SessionLoadResult.failure('无法读取本地认证会话');
    }
  }

  public async save(session: AuthenticatedSession): Promise<RepositoryResult<boolean>> {
    try {
      await this.ensureKey();
      const record: SessionPlaintext = { key: session.key, clientId: session.clientId };
      const encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
      const encrypted: EncryptedSessionData | null = await this.encrypt(encoder.encodeInto(JSON.stringify(record)));
      if (encrypted === null) {
        return RepositoryResult.failure<boolean>('无法加密认证会话');
      }
      const envelope: string | null = encodeEnvelope(encrypted);
      if (envelope === null) {
        return RepositoryResult.failure<boolean>('无法编码认证会话');
      }
      const store: preferences.Preferences = await preferences.getPreferences(this.context, this.preferencesName);
      await store.put(SESSION_RECORD_KEY, envelope);
      await store.flush();
      return RepositoryResult.success<boolean>(true);
    } catch (_) {
      return RepositoryResult.failure<boolean>('无法保存认证会话');
    }
  }

  public async clear(): Promise<RepositoryResult<boolean>> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, this.preferencesName);
      await store.delete(SESSION_RECORD_KEY);
      await store.flush();
      const options: huks.HuksOptions = { properties: [] };
      if (await this.keyExists(options)) {
        await huks.deleteKeyItem(this.keyAlias, options);
      }
      return RepositoryResult.success<boolean>(true);
    } catch (_) {
      return RepositoryResult.failure<boolean>('无法清除认证会话');
    }
  }

  private async ensureKey(): Promise<void> {
    const emptyOptions: huks.HuksOptions = { properties: [] };
    if (await this.keyExists(emptyOptions)) {
      return;
    }
    const options: huks.HuksOptions = { properties: generateKeyProperties() };
    try {
      await huks.generateKeyItem(this.keyAlias, options);
    } catch (_) {
      throw new Error('HUKS key generation failed');
    }
  }

  private async keyExists(options: huks.HuksOptions): Promise<boolean> {
    try {
      return await huks.isKeyItemExist(this.keyAlias, options);
    } catch (error) {
      if (caughtErrorCode(error) === 12000011) {
        return false;
      }
      throw new Error('HUKS key query failed');
    }
  }

  private async encrypt(plaintext: Uint8Array): Promise<EncryptedSessionData | null> {
    let nonce: Uint8Array;
    try {
      nonce = cryptoFramework.createRandom().generateRandomSync(12).data;
    } catch (_) {
      return null;
    }
    const options: huks.HuksOptions = {
      properties: operationProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, nonce, null),
      inData: plaintext
    };
    const cipherText: Uint8Array | null = await this.finishOperation(options);
    return cipherText === null || cipherText.length <= GCM_TAG_LENGTH
      ? null
      : new EncryptedSessionData(nonce, cipherText);
  }

  private async decrypt(encrypted: EncryptedSessionData): Promise<Uint8Array | null> {
    const authenticationTag: Uint8Array = encrypted.cipherText.slice(-GCM_TAG_LENGTH);
    const cipherText: Uint8Array = encrypted.cipherText.slice(0, -GCM_TAG_LENGTH);
    const options: huks.HuksOptions = {
      properties: operationProperties(
        huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
        encrypted.nonce,
        authenticationTag
      ),
      inData: cipherText
    };
    return await this.finishOperation(options);
  }

  private async finishOperation(options: huks.HuksOptions): Promise<Uint8Array | null> {
    let session: huks.HuksSessionHandle;
    try {
      session = await huks.initSession(this.keyAlias, options);
    } catch (_) {
      return null;
    }
    try {
      const result: huks.HuksReturnResult = await huks.finishSession(session.handle, options);
      return result.outData === undefined ? null : new Uint8Array(result.outData);
    } catch (_) {
      try {
        await huks.abortSession(session.handle, options);
      } catch (_) {
        // The primary operation failure is returned to the caller.
      }
      return null;
    }
  }
}
