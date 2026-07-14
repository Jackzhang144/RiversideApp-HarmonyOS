import { common } from '@kit.AbilityKit';

export class AbilityContextRegistry {
  private static context: common.UIAbilityContext | null = null;

  public static initialize(context: common.UIAbilityContext): void {
    AbilityContextRegistry.context = context;
  }

  public static clear(): void {
    AbilityContextRegistry.context = null;
  }

  public static current(): common.UIAbilityContext | null {
    return AbilityContextRegistry.context;
  }
}
