import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { RepositoryResult } from '../core/RepositoryResult';
import {
  AuthenticatedSession,
  AuthorizationCallbackValidator,
  AuthorizationRequest
} from './AuthModels';

function randomHex(byteCount: number): string | null {
  try {
    const randomData: cryptoFramework.DataBlob = cryptoFramework.createRandom().generateRandomSync(byteCount);
    let value: string = '';
    for (const byte of randomData.data) {
      value += byte.toString(16).padStart(2, '0');
    }
    return value;
  } catch (_) {
    return null;
  }
}

function withBase64Padding(value: string): string {
  const remainder: number = value.length % 4;
  if (remainder === 0) {
    return value;
  }
  return `${value}${'='.repeat(4 - remainder)}`;
}

function decodeDiscoursePayload(value: string): Uint8Array | null {
  const compact: string = value.replace(/ /g, '+').replace(/\s+/g, '').trim();
  if (compact.length === 0) {
    return null;
  }
  const helper: util.Base64Helper = new util.Base64Helper();
  try {
    return helper.decodeSync(withBase64Padding(compact), util.Type.BASIC);
  } catch (_) {
    try {
      return helper.decodeSync(withBase64Padding(compact), util.Type.BASIC_URL_SAFE);
    } catch (_) {
      return null;
    }
  }
}

export interface AuthorizationCryptoSession {
  readonly request: AuthorizationRequest;

  decryptAndValidate(encryptedPayload: string): Promise<RepositoryResult<AuthenticatedSession>>;

  clear(): void;
}

class RsaAuthorizationCryptoSession implements AuthorizationCryptoSession {
  public readonly request: AuthorizationRequest;

  private readonly privateKey: cryptoFramework.PriKey;
  private readonly validator: AuthorizationCallbackValidator;
  private cleared: boolean = false;

  public constructor(request: AuthorizationRequest, privateKey: cryptoFramework.PriKey) {
    this.request = request;
    this.privateKey = privateKey;
    this.validator = new AuthorizationCallbackValidator();
  }

  public async decryptAndValidate(encryptedPayload: string): Promise<RepositoryResult<AuthenticatedSession>> {
    if (this.cleared) {
      return RepositoryResult.failure<AuthenticatedSession>('授权请求已失效');
    }
    const encryptedData: Uint8Array | null = decodeDiscoursePayload(encryptedPayload);
    if (encryptedData === null) {
      return RepositoryResult.failure<AuthenticatedSession>('授权 payload 不是有效 Base64');
    }
    try {
      const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('RSA2048|PKCS1');
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, this.privateKey, null);
      const decrypted: cryptoFramework.DataBlob = await cipher.doFinal({ data: encryptedData });
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { fatal: true });
      const decryptedPayload: string = decoder.decodeToString(decrypted.data);
      return this.validator.validateDecryptedPayload(
        decryptedPayload,
        this.request.clientId,
        this.request.nonce
      );
    } catch (_) {
      return RepositoryResult.failure<AuthenticatedSession>('授权 payload 解密失败');
    }
  }

  public clear(): void {
    if (this.cleared) {
      return;
    }
    this.cleared = true;
    this.privateKey.clearMem();
  }
}

export interface AuthorizationCryptoFactory {
  create(): Promise<RepositoryResult<AuthorizationCryptoSession>>;
}

export class RsaAuthorizationCryptoFactory implements AuthorizationCryptoFactory {
  public async create(): Promise<RepositoryResult<AuthorizationCryptoSession>> {
    try {
      const generator: cryptoFramework.AsyKeyGenerator =
        cryptoFramework.createAsyKeyGenerator('RSA2048|PRIMES_2');
      const keyPair: cryptoFramework.KeyPair = await generator.generateKeyPair();
      try {
        const clientId: string | null = randomHex(32);
        const nonce: string | null = randomHex(16);
        const publicKeyPem: string = keyPair.pubKey.getEncodedPem('PKCS1');
        const request: AuthorizationRequest | null = clientId === null || nonce === null
          ? null
          : AuthorizationRequest.create(publicKeyPem, clientId, nonce);
        if (request === null) {
          keyPair.priKey.clearMem();
          return RepositoryResult.failure<AuthorizationCryptoSession>('无法创建授权请求');
        }
        return RepositoryResult.success<AuthorizationCryptoSession>(
          new RsaAuthorizationCryptoSession(request, keyPair.priKey)
        );
      } catch (_) {
        keyPair.priKey.clearMem();
        return RepositoryResult.failure<AuthorizationCryptoSession>('无法生成 RSA 授权材料');
      }
    } catch (_) {
      return RepositoryResult.failure<AuthorizationCryptoSession>('无法生成 RSA 授权材料');
    }
  }
}
