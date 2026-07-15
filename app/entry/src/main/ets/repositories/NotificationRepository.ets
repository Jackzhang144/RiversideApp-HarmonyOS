import { RepositoryResult } from '../core/RepositoryResult';
import { NotificationBucket, NotificationItem } from '../models/NotificationModels';

export interface NotificationRepository {
  loadNotificationItems(
    username: string,
    bucket: NotificationBucket,
    page: number,
    offset: number
  ): Promise<RepositoryResult<Array<NotificationItem>>>;
}
