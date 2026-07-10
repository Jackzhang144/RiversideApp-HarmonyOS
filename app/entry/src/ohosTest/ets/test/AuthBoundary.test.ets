import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import {
  AuthenticatedSession,
  AuthorizationCallbackValidator,
  AuthorizationRequest
} from '../../../main/ets/auth/AuthModels';

const CLIENT_ID: string = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const NONCE: string = '0123456789abcdef0123456789abcdef';
const PUBLIC_KEY_PEM: string = '-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKCAQEA\n-----END RSA PUBLIC KEY-----';

export default function authBoundaryTest(): void {
  describe('User API Key authorization boundary', () => {
    it('builds the canonical RiverSide authorization request', 0, () => {
      const request: AuthorizationRequest | null = AuthorizationRequest.create(PUBLIC_KEY_PEM, CLIENT_ID, NONCE);

      expect(request === null).assertFalse();
      if (request === null) {
        return;
      }
      expect(request.authorizationUrl.startsWith('https://river-side.cc/user-api-key/new?')).assertTrue();
      expect(request.authorizationUrl.includes('scopes=read%2Cwrite%2Csession_info')).assertTrue();
      expect(request.authorizationUrl.includes('auth_redirect=riverside%3A%2F%2Fauth_redirect')).assertTrue();
      expect(request.authorizationUrl.includes('padding=pkcs1')).assertTrue();
    });

    it('accepts only the main-frame Riverside callback with a payload', 0, () => {
      const validator: AuthorizationCallbackValidator = new AuthorizationCallbackValidator();
      const valid: RepositoryResult<string> = validator.extractPayload(
        'riverside://auth_redirect?payload=encrypted%2Bpayload%3D',
        true
      );
      const iframe: RepositoryResult<string> = validator.extractPayload(
        'riverside://auth_redirect?payload=encrypted',
        false
      );
      const wrongHost: RepositoryResult<string> = validator.extractPayload(
        'riverside://other?payload=encrypted',
        true
      );
      const missingPayload: RepositoryResult<string> = validator.extractPayload(
        'riverside://auth_redirect',
        true
      );

      expect(valid.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(valid.data).assertEqual('encrypted+payload=');
      expect(iframe.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(wrongHost.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(missingPayload.kind).assertEqual(RepositoryResultKind.FAILURE);
    });

    it('creates a session only when decrypted key and nonce are valid', 0, () => {
      const validator: AuthorizationCallbackValidator = new AuthorizationCallbackValidator();
      const valid: RepositoryResult<AuthenticatedSession> = validator.validateDecryptedPayload(
        '{"key":"user-api-key","nonce":"0123456789abcdef0123456789abcdef"}',
        CLIENT_ID,
        NONCE
      );
      const mismatch: RepositoryResult<AuthenticatedSession> = validator.validateDecryptedPayload(
        '{"key":"user-api-key","nonce":"ffffffffffffffffffffffffffffffff"}',
        CLIENT_ID,
        NONCE
      );
      const missingKey: RepositoryResult<AuthenticatedSession> = validator.validateDecryptedPayload(
        '{"nonce":"0123456789abcdef0123456789abcdef"}',
        CLIENT_ID,
        NONCE
      );

      expect(valid.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(valid.data?.key).assertEqual('user-api-key');
      expect(valid.data?.clientId).assertEqual(CLIENT_ID);
      expect(mismatch.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(missingKey.kind).assertEqual(RepositoryResultKind.FAILURE);
    });
  });
}
