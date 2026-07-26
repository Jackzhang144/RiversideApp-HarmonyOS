import { JsonObjectReader } from '../core/JsonObjectReader';
import { DiscourseUserStatus } from '../models/DiscourseUserStatus';

export function discourseUserStatusFromReader(
  reader: JsonObjectReader | null,
  nowMs: number = Date.now()
): DiscourseUserStatus | null {
  if (reader === null) {
    return null;
  }
  return DiscourseUserStatus.create(
    reader.string('description') ?? '',
    reader.string('emoji') ?? '',
    reader.string('ends_at'),
    nowMs
  );
}
