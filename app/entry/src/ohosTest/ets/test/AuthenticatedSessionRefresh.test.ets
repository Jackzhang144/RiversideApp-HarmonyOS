import { describe, expect, it } from '@ohos/hypium';
import {
  AuthenticatedSessionRefreshTasks,
  runAuthenticatedSessionRefresh
} from '../../../main/ets/app/AuthenticatedSessionRefresh';

class ControlledVoid {
  public readonly promise: Promise<void>;
  private resolver: (() => void) | null = null;

  public constructor() {
    this.promise = new Promise<void>((resolve: () => void): void => {
      this.resolver = resolve;
    });
  }

  public complete(): void {
    const resolve: (() => void) | null = this.resolver;
    this.resolver = null;
    resolve?.();
  }
}

export default function authenticatedSessionRefreshTest(): void {
  describe('Authenticated Session refresh', () => {
    it('refreshes identity before every authenticated root page', 0,
      async (done: Function) => {
        const identity: ControlledVoid = new ControlledVoid();
        const events: Array<string> = [];
        const tasks: AuthenticatedSessionRefreshTasks = new AuthenticatedSessionRefreshTasks(
          (): Promise<void> => {
            events.push('account');
            return identity.promise;
          },
          (): Promise<void> => {
            events.push('home');
            return Promise.resolve();
          },
          (): Promise<void> => {
            events.push('categories');
            return Promise.resolve();
          },
          (): Promise<void> => {
            events.push('notifications');
            return Promise.resolve();
          },
          (): Promise<void> => {
            events.push('chat');
            return Promise.resolve();
          }
        );

        const refresh: Promise<void> = runAuthenticatedSessionRefresh(tasks);
        expect(events.join(',')).assertEqual('account');

        identity.complete();
        await refresh;
        expect(events.join(',')).assertEqual('account,home,categories,notifications,chat');
        done();
      });
  });
}
