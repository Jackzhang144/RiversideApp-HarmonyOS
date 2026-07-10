import { describe, expect, it } from '@ohos/hypium';
import { AuthenticatedSession } from '../../../main/ets/auth/AuthModels';
import {
  AuthenticatedSessionProvider,
  DiscourseHeaders,
  DiscourseRequestHeadersFactory
} from '../../../main/ets/network/DiscourseHttpClient';

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

      expect(headers.userAgent).assertEqual('RiversideApp/0.1');
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
  });
}
