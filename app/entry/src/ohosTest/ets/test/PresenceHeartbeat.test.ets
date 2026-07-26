import { describe, expect, it } from '@ohos/hypium';
import { HttpTextResult, PresenceHttpClient } from '../../../main/ets/network/DiscourseHttpClient';
import { AuthenticationLifecycle } from '../../../main/ets/app/AuthenticationLifecycle';
import {
  DiscoursePresenceUpdater,
  PresenceHeartbeat,
  PresenceScheduler,
  PresenceUpdater,
  shouldRunPresenceHeartbeat
} from '../../../main/ets/app/PresenceHeartbeat';

class StubPresenceScheduler implements PresenceScheduler {
  public scheduleCount: number = 0;
  public cancelCount: number = 0;
  public intervalMs: number = 0;
  private callback: (() => void) | null = null;

  public scheduleRepeating(callback: () => void, intervalMs: number): number {
    this.scheduleCount += 1;
    this.intervalMs = intervalMs;
    this.callback = callback;
    return 37;
  }

  public cancel(_handle: number): void {
    this.cancelCount += 1;
  }

  public fire(): void {
    this.callback?.();
  }
}

class ControlledPresenceUpdate {
  public readonly promise: Promise<HttpTextResult>;
  private resolver: ((result: HttpTextResult) => void) | null = null;
  private rejecter: ((error: Error) => void) | null = null;

  public constructor() {
    this.promise = new Promise<HttpTextResult>(
      (resolve: (result: HttpTextResult) => void, reject: (error: Error) => void): void => {
        this.resolver = resolve;
        this.rejecter = reject;
      }
    );
  }

  public resolve(result: HttpTextResult): void {
    const resolve: ((result: HttpTextResult) => void) | null = this.resolver;
    this.resolver = null;
    resolve?.(result);
  }

  public reject(error: Error): void {
    const reject: ((error: Error) => void) | null = this.rejecter;
    this.rejecter = null;
    reject?.(error);
  }
}

class StubPresenceUpdater implements PresenceUpdater {
  public callCount: number = 0;
  public tasks: Array<Promise<HttpTextResult>> = [];

  public updatePresence(): Promise<HttpTextResult> {
    this.callCount += 1;
    return this.tasks.shift() ?? Promise.resolve(HttpTextResult.success(200, '{}'));
  }
}

class StubPresenceAuthenticationLifecycle implements AuthenticationLifecycle {
  public unauthorizedCallCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCallCount += 1;
  }
}

class RejectingPresenceAuthenticationLifecycle implements AuthenticationLifecycle {
  public handleUnauthorized(): Promise<void> {
    return Promise.reject(new Error('logout failed'));
  }
}

class StubPresenceHttpClient implements PresenceHttpClient {
  public requests: Array<string> = [];

  public async postForm(path: string, body: string): Promise<HttpTextResult> {
    this.requests.push(`${path}|${body}`);
    return HttpTextResult.success(200, '{}');
  }
}

async function flushPromises(): Promise<void> {
  await Promise.resolve(true);
  await Promise.resolve(true);
}

export default function presenceHeartbeatTest(): void {
  describe('Foreground Presence heartbeat', () => {
    it('runs only for an authenticated foreground session with a default network', 0, () => {
      expect(shouldRunPresenceHeartbeat(true, true, true)).assertTrue();
      expect(shouldRunPresenceHeartbeat(false, true, true)).assertFalse();
      expect(shouldRunPresenceHeartbeat(true, false, true)).assertFalse();
      expect(shouldRunPresenceHeartbeat(true, true, false)).assertFalse();
    });

    it('posts immediately and installs only one 28-second repeating timer', 0, async (done: Function) => {
      const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
      const updater: StubPresenceUpdater = new StubPresenceUpdater();
      const lifecycle: StubPresenceAuthenticationLifecycle = new StubPresenceAuthenticationLifecycle();
      const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(updater, lifecycle, scheduler);

      heartbeat.start();
      heartbeat.start();

      expect(updater.callCount).assertEqual(1);
      expect(scheduler.scheduleCount).assertEqual(1);
      expect(scheduler.intervalMs).assertEqual(28000);
      await flushPromises();
      scheduler.fire();
      expect(updater.callCount).assertEqual(2);
      done();
    });

    it('does not overlap slow requests and coalesces repeated timer ticks', 0, async (done: Function) => {
      const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
      const updater: StubPresenceUpdater = new StubPresenceUpdater();
      const first: ControlledPresenceUpdate = new ControlledPresenceUpdate();
      updater.tasks.push(first.promise);
      const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(
        updater,
        new StubPresenceAuthenticationLifecycle(),
        scheduler
      );

      heartbeat.start();
      scheduler.fire();
      scheduler.fire();
      expect(updater.callCount).assertEqual(1);

      first.resolve(HttpTextResult.success(200, '{}'));
      await flushPromises();
      expect(updater.callCount).assertEqual(2);
      done();
    });

    it('stops the timer and invalidates the session after an unauthorized response', 0,
      async (done: Function) => {
        const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
        const updater: StubPresenceUpdater = new StubPresenceUpdater();
        updater.tasks.push(Promise.resolve(HttpTextResult.unauthorized()));
        const lifecycle: StubPresenceAuthenticationLifecycle = new StubPresenceAuthenticationLifecycle();
        const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(updater, lifecycle, scheduler);

        heartbeat.start();
        await flushPromises();

        expect(heartbeat.isActive()).assertFalse();
        expect(scheduler.cancelCount).assertEqual(1);
        expect(lifecycle.unauthorizedCallCount).assertEqual(1);
        done();
      });

    it('ignores an old unauthorized response after stop and restart', 0, async (done: Function) => {
      const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
      const updater: StubPresenceUpdater = new StubPresenceUpdater();
      const oldUpdate: ControlledPresenceUpdate = new ControlledPresenceUpdate();
      updater.tasks.push(oldUpdate.promise);
      const lifecycle: StubPresenceAuthenticationLifecycle = new StubPresenceAuthenticationLifecycle();
      const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(updater, lifecycle, scheduler);

      heartbeat.start();
      heartbeat.stop();
      heartbeat.start();
      expect(updater.callCount).assertEqual(1);

      oldUpdate.resolve(HttpTextResult.unauthorized());
      await flushPromises();

      expect(lifecycle.unauthorizedCallCount).assertEqual(0);
      expect(heartbeat.isActive()).assertTrue();
      expect(updater.callCount).assertEqual(2);
      expect(scheduler.scheduleCount).assertEqual(2);
      done();
    });

    it('continues after an updater rejection without overlapping requests', 0, async (done: Function) => {
      const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
      const updater: StubPresenceUpdater = new StubPresenceUpdater();
      const failedUpdate: ControlledPresenceUpdate = new ControlledPresenceUpdate();
      updater.tasks.push(failedUpdate.promise);
      const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(
        updater,
        new StubPresenceAuthenticationLifecycle(),
        scheduler
      );

      heartbeat.start();
      scheduler.fire();
      expect(updater.callCount).assertEqual(1);

      failedUpdate.reject(new Error('network failed'));
      await flushPromises();
      expect(updater.callCount).assertEqual(2);
      expect(heartbeat.isActive()).assertTrue();
      done();
    });

    it('contains an authentication lifecycle rejection after unauthorized', 0, async (done: Function) => {
      const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
      const updater: StubPresenceUpdater = new StubPresenceUpdater();
      updater.tasks.push(Promise.resolve(HttpTextResult.unauthorized()));
      const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(
        updater,
        new RejectingPresenceAuthenticationLifecycle(),
        scheduler
      );

      heartbeat.start();
      await flushPromises();

      expect(heartbeat.isActive()).assertFalse();
      expect(scheduler.cancelCount).assertEqual(1);
      done();
    });

    it('stops on background or disposal and ignores later scheduler callbacks', 0,
      async (done: Function) => {
        const scheduler: StubPresenceScheduler = new StubPresenceScheduler();
        const updater: StubPresenceUpdater = new StubPresenceUpdater();
        const heartbeat: PresenceHeartbeat = new PresenceHeartbeat(
          updater,
          new StubPresenceAuthenticationLifecycle(),
          scheduler
        );

        heartbeat.start();
        await flushPromises();
        heartbeat.stop();
        scheduler.fire();
        expect(updater.callCount).assertEqual(1);
        expect(scheduler.cancelCount).assertEqual(1);

        heartbeat.start();
        await flushPromises();
        heartbeat.dispose();
        scheduler.fire();
        expect(updater.callCount).assertEqual(2);
        expect(scheduler.cancelCount).assertEqual(2);
        done();
      });

    it('uses the Flutter-compatible Presence endpoint contract', 0, async (done: Function) => {
      const client: StubPresenceHttpClient = new StubPresenceHttpClient();
      const updater: DiscoursePresenceUpdater = new DiscoursePresenceUpdater(
        client,
        (): string | null => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      );

      await updater.updatePresence();

      expect(client.requests[0]).assertEqual(
        '/presence/update.json|present_channels[]=/whos-online/online&client_id=' +
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      );
      done();
    });
  });
}
