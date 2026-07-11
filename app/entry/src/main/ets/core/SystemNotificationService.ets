import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';

export enum NotificationPublishResult {
  PUBLISHED = 0,
  CONTEXT_UNAVAILABLE = 1,
  FAILED = 2
}

export class SystemNotificationService {
  private static abilityContext: common.UIAbilityContext | null = null;

  static initialize(context: common.UIAbilityContext): void {
    SystemNotificationService.abilityContext = context;
  }

  static clear(): void {
    SystemNotificationService.abilityContext = null;
  }

  static async publishPrototypeNotification(): Promise<NotificationPublishResult> {
    const context: common.UIAbilityContext | null = SystemNotificationService.abilityContext;
    if (context === null) {
      return NotificationPublishResult.CONTEXT_UNAVAILABLE;
    }
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(context);
      }
      const request: notificationManager.NotificationRequest = {
        id: 23001,
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'RiverSide 测试通知',
            text: '你收到了一条新的论坛回复',
            additionalText: '来自原生 UI/UX 设计原型'
          }
        }
      };
      await notificationManager.publish(request);
      return NotificationPublishResult.PUBLISHED;
    } catch (_) {
      return NotificationPublishResult.FAILED;
    }
  }
}
