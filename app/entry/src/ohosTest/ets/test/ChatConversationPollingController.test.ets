import { describe, expect, it } from '@ohos/hypium';
import {
  ChatConversationPollingController,
  ChatPollingTimer
} from '../../../main/ets/app/ChatConversationPollingController';

class FakeChatPollingTimer implements ChatPollingTimer {
  public delays: Array<number> = [];
  public clearCalls: Array<number> = [];
  private callbacks: Array<(() => Promise<void>) | null> = [null];
  private nextHandle: number = 1;

  public setInterval(callback: () => Promise<void>, delayMilliseconds: number): number {
    this.delays.push(delayMilliseconds);
    const handle: number = this.nextHandle;
    this.nextHandle += 1;
    this.callbacks.push(callback);
    return handle;
  }

  public clearInterval(handle: number): void {
    this.clearCalls.push(handle);
  }

  public async fire(handle: number = this.nextHandle - 1): Promise<void> {
    const callback: (() => Promise<void>) | null = this.callbacks[handle] ?? null;
    if (callback !== null) {
      await callback();
    }
  }
}

class DeferredVoid {
  public readonly promise: Promise<void>;
  private resolvePromise: () => void = (): void => {};

  public constructor() {
    this.promise = new Promise<void>((resolve: () => void): void => {
      this.resolvePromise = resolve;
    });
  }

  public resolve(): void {
    this.resolvePromise();
  }
}

export default function chatConversationPollingControllerTest(): void {
  describe('ChatConversationPollingController public behavior', () => {
    it('starts one 30-second timer only for an authenticated active foreground conversation', 0, () => {
      const timer: FakeChatPollingTimer = new FakeChatPollingTimer();
      const controller: ChatConversationPollingController = new ChatConversationPollingController(
        timer,
        async (): Promise<void> => {}
      );

      controller.setForeground(true);
      controller.setAuthenticated(true);
      expect(timer.delays.length).assertEqual(0);

      controller.setActiveConversation(true);
      controller.setActiveConversation(true);

      expect(timer.delays.length).assertEqual(1);
      expect(timer.delays[0]).assertEqual(30000);
    });

    it('stops polling when leaving, backgrounding, logging out or destroying the page', 0, () => {
      const timer: FakeChatPollingTimer = new FakeChatPollingTimer();
      const controller: ChatConversationPollingController = new ChatConversationPollingController(
        timer,
        async (): Promise<void> => {}
      );
      controller.setForeground(true);
      controller.setAuthenticated(true);
      controller.setActiveConversation(true);

      controller.setActiveConversation(false);
      controller.setActiveConversation(true);
      controller.setForeground(false);
      controller.setForeground(true);
      controller.setAuthenticated(false);
      controller.setAuthenticated(true);
      controller.destroy();
      controller.setForeground(true);
      controller.setAuthenticated(true);
      controller.setActiveConversation(true);

      expect(timer.clearCalls.join(',')).assertEqual('1,2,3,4');
      expect(timer.delays.length).assertEqual(4);
    });

    it('suppresses overlapping refreshes and resumes after the active refresh completes', 0,
      async (done: Function) => {
        const timer: FakeChatPollingTimer = new FakeChatPollingTimer();
        const firstRefresh: DeferredVoid = new DeferredVoid();
        let refreshCalls: number = 0;
        const controller: ChatConversationPollingController = new ChatConversationPollingController(
          timer,
          async (): Promise<void> => {
            refreshCalls += 1;
            if (refreshCalls === 1) {
              await firstRefresh.promise;
            }
          }
        );
        controller.setForeground(true);
        controller.setAuthenticated(true);
        controller.setActiveConversation(true);

        const firstTask: Promise<void> = timer.fire();
        await timer.fire();
        expect(refreshCalls).assertEqual(1);

        firstRefresh.resolve();
        await firstTask;
        await timer.fire();
        expect(refreshCalls).assertEqual(2);
        done();
      });

    it('ignores a queued timer callback after the conversation is covered', 0, async (done: Function) => {
      const timer: FakeChatPollingTimer = new FakeChatPollingTimer();
      let refreshCalls: number = 0;
      const controller: ChatConversationPollingController = new ChatConversationPollingController(
        timer,
        async (): Promise<void> => {
          refreshCalls += 1;
        }
      );
      controller.setForeground(true);
      controller.setAuthenticated(true);
      controller.setActiveConversation(true);

      controller.setActiveConversation(false);
      await timer.fire(1);

      expect(timer.clearCalls.join(',')).assertEqual('1');
      expect(refreshCalls).assertEqual(0);
      done();
    });

    it('contains a refresh exception and permits the next timer tick', 0, async (done: Function) => {
      const timer: FakeChatPollingTimer = new FakeChatPollingTimer();
      let refreshCalls: number = 0;
      const controller: ChatConversationPollingController = new ChatConversationPollingController(
        timer,
        async (): Promise<void> => {
          refreshCalls += 1;
          if (refreshCalls === 1) {
            throw new Error('controlled polling failure');
          }
        }
      );
      controller.setForeground(true);
      controller.setAuthenticated(true);
      controller.setActiveConversation(true);

      await timer.fire();
      await timer.fire();

      expect(refreshCalls).assertEqual(2);
      done();
    });
  });
}
