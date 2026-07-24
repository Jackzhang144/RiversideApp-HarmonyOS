import { describe, expect, it } from '@ohos/hypium';
import {
  runStartupRequestSequence,
  StartupRequestTasks
} from '../../../main/ets/app/StartupRequestSequence';

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

async function flushPromises(): Promise<void> {
  await Promise.resolve(true);
  await Promise.resolve(true);
}

export default function startupRequestSequenceTest(): void {
  describe('Startup network request sequencing', () => {
    it('defers Presence and online users until Home and Category requests finish', 0,
      async (done: Function) => {
        const home: ControlledVoid = new ControlledVoid();
        const categories: ControlledVoid = new ControlledVoid();
        const events: Array<string> = [];
        const tasks: StartupRequestTasks = new StartupRequestTasks(
          (): Promise<void> => {
            events.push('home');
            return home.promise;
          },
          (): Promise<void> => {
            events.push('categories');
            return categories.promise;
          },
          (): void => {
            events.push('presence');
          },
          (): void => {
            events.push('online');
          }
        );

        const sequence: Promise<void> = runStartupRequestSequence(tasks);
        expect(events.join(',')).assertEqual('home,categories');

        home.complete();
        await flushPromises();
        expect(events.join(',')).assertEqual('home,categories');

        categories.complete();
        await sequence;
        expect(events.join(',')).assertEqual('home,categories,presence,online');
        done();
      });
  });
}
