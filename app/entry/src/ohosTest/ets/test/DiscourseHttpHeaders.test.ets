import { describe, expect, it } from '@ohos/hypium';
import { AuthenticatedSession } from '../../../main/ets/auth/AuthModels';
import { AppMetadata } from '../../../main/ets/core/AppMetadata';
import {
  AuthenticatedSessionProvider,
  DiscourseHeaders,
  DiscourseRequestHeadersFactory,
  DiscourseRequestPolicy,
  executeTopicGetWithRetry,
  HttpTextRequestAttempt,
  HttpTextResult,
  httpFailureForErrorCode,
  httpTextResultForSuccessfulResponse
} from '../../../main/ets/network/DiscourseHttpClient';
import { RepositoryFailureCode } from '../../../main/ets/core/RepositoryResult';

const CLIENT_ID: string = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

class StubSessionProvider implements AuthenticatedSessionProvider {
  public session: AuthenticatedSession | null = null;

  public currentSession(): AuthenticatedSession | null {
    return this.session;
  }
}

export default function discourseHttpHeadersTest(): void {
  describe('Discourse authenticated request headers', () => {
    it('omits User API Key headers without an Authenticated Session', 0, () => {
      const provider: StubSessionProvider = new StubSessionProvider();
      const headers: DiscourseHeaders = new DiscourseRequestHeadersFactory(provider).create();

      expect(headers.userAgent).assertEqual(AppMetadata.current().userAgent());
      expect(headers.accept).assertEqual('application/json');
      expect(headers.userApiKey).assertNull();
      expect(headers.userApiClientId).assertNull();
    });

    it('adds both User API Key headers from the current session', 0, () => {
      const provider: StubSessionProvider = new StubSessionProvider();
      const session: AuthenticatedSession | null = AuthenticatedSession.create('user-api-key', CLIENT_ID);
      expect(session === null).assertFalse();
      if (session === null) {
        return;
      }
      provider.session = session;

      const headers: DiscourseHeaders = new DiscourseRequestHeadersFactory(provider).create();

      expect(headers.userApiKey).assertEqual('user-api-key');
      expect(headers.userApiClientId).assertEqual(CLIENT_ID);
    });

    it('gives interactive Topic requests a bounded timeout', 0, () => {
      const policy: DiscourseRequestPolicy = new DiscourseRequestPolicy();

      expect(policy.connectTimeoutMs).assertEqual(15000);
      expect(policy.transferTimeoutMs).assertEqual(30000);
    });

    it('reports HarmonyOS operation timeouts separately from other network failures', 0, () => {
      const timeout = httpFailureForErrorCode(1007900028);
      const networkFailure = httpFailureForErrorCode(1007900007);

      expect(timeout.failureCode).assertEqual(RepositoryFailureCode.TIMEOUT);
      expect(timeout.message).assertEqual('请求超时，请重试');
      expect(networkFailure.failureCode).assertEqual(RepositoryFailureCode.NETWORK);
      expect(networkFailure.message).assertEqual('网络连接失败');
    });

    it('accepts a successful HTTP response with no body', 0, () => {
      const result: HttpTextResult = httpTextResultForSuccessfulResponse(200, undefined, null);

      expect(result.isSuccess()).assertTrue();
      expect(result.body).assertEqual('');
    });

    it('rejects a non-empty successful response that cannot be decoded as UTF-8', 0, () => {
      const result: HttpTextResult =
        httpTextResultForSuccessfulResponse(200, new ArrayBuffer(1), null);

      expect(result.isSuccess()).assertFalse();
      expect(result.message).assertEqual('服务器响应格式无效');
    });

    it('retries an idempotent Topic GET once after an operation timeout', 0, async (done: Function) => {
      const results: Array<HttpTextResult> = [
        httpFailureForErrorCode(1007900028),
        HttpTextResult.success(200, '{"id":2725}')
      ];
      let attempts: number = 0;
      const operation: HttpTextRequestAttempt = new HttpTextRequestAttempt(
        (): Promise<HttpTextResult> => {
          attempts += 1;
          return Promise.resolve(results.shift() ?? HttpTextResult.failure(0, 'unexpected retry'));
        }
      );

      const result: HttpTextResult =
        await executeTopicGetWithRetry('/t/2725.json', operation);

      expect(attempts).assertEqual(2);
      expect(result.isSuccess()).assertTrue();
      done();
    });

    it('does not retry non-Topic GETs or non-timeout failures', 0, async (done: Function) => {
      let attempts: number = 0;
      const operation: HttpTextRequestAttempt = new HttpTextRequestAttempt(
        (): Promise<HttpTextResult> => {
          attempts += 1;
          return Promise.resolve(HttpTextResult.failure(503, '服务器返回 503'));
        }
      );

      await executeTopicGetWithRetry('/t/2725.json', operation);
      await executeTopicGetWithRetry('/latest.json', operation);

      expect(attempts).assertEqual(2);
      done();
    });
  });
}
