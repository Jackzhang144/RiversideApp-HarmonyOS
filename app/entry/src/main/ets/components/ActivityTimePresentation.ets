import { localCalendarDate } from '../models/LocalTimeModels';

const MILLISECONDS_PER_MINUTE: number = 60 * 1000;
const MILLISECONDS_PER_DAY: number = 24 * 60 * MILLISECONDS_PER_MINUTE;

function twoDigit(value: number): string {
  return value < 10 ? `0${value}` : value.toString();
}

function localDayNumber(value: Date): number {
  return Math.floor(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()) /
    MILLISECONDS_PER_DAY);
}

function weekdayLabel(value: Date): string {
  const labels: Array<string> = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return labels[value.getUTCDay()];
}

export function compactActivityTime(
  value: string,
  nowMilliseconds: number = Date.now(),
  timezoneOffsetMinutes: number | null = null
): string {
  const normalized: string = value.trim();
  if (normalized.length === 0) {
    return '';
  }
  const timestamp: number = Date.parse(normalized);
  if (!Number.isFinite(timestamp) || !Number.isFinite(nowMilliseconds)) {
    return normalized;
  }
  const target: Date = localCalendarDate(timestamp, timezoneOffsetMinutes);
  const now: Date = localCalendarDate(nowMilliseconds, timezoneOffsetMinutes);
  const dayDifference: number = localDayNumber(now) - localDayNumber(target);
  const time: string = `${twoDigit(target.getUTCHours())}:${twoDigit(target.getUTCMinutes())}`;
  if (dayDifference === 0) {
    return time;
  }
  if (dayDifference === 1) {
    return `昨天 ${time}`;
  }
  if (dayDifference > 1 && dayDifference < 7) {
    return `${weekdayLabel(target)} ${time}`;
  }
  const monthAndDay: string = `${twoDigit(target.getUTCMonth() + 1)}-${twoDigit(target.getUTCDate())}`;
  return target.getUTCFullYear() === now.getUTCFullYear()
    ? monthAndDay
    : `${target.getUTCFullYear()}-${monthAndDay}`;
}
