import { i18n } from '@kit.LocalizationKit';

const MILLISECONDS_PER_MINUTE: number = 60 * 1000;

function twoDigit(value: number): string {
  return value < 10 ? `0${value}` : value.toString();
}

function resolvedOffsetMinutes(timestamp: number, timezoneOffsetMinutes: number | null): number {
  if (timezoneOffsetMinutes !== null && Number.isFinite(timezoneOffsetMinutes)) {
    return timezoneOffsetMinutes;
  }
  try {
    const systemOffsetMilliseconds: number = i18n.getTimeZone().getOffset(timestamp);
    if (Number.isFinite(systemOffsetMilliseconds)) {
      return systemOffsetMilliseconds / MILLISECONDS_PER_MINUTE;
    }
  } catch (_error) {
  }
  return -new Date(timestamp).getTimezoneOffset();
}

export function localCalendarDate(
  timestamp: number,
  timezoneOffsetMinutes: number | null = null
): Date {
  const offsetMinutes: number = resolvedOffsetMinutes(timestamp, timezoneOffsetMinutes);
  return new Date(timestamp + offsetMinutes * MILLISECONDS_PER_MINUTE);
}

export function formatLocalDateTime(
  value: string,
  timezoneOffsetMinutes: number | null = null
): string {
  const normalized: string = value.trim();
  if (normalized.length === 0) {
    return '';
  }
  const timestamp: number = Date.parse(normalized);
  if (!Number.isFinite(timestamp)) {
    return normalized;
  }
  const local: Date = localCalendarDate(timestamp, timezoneOffsetMinutes);
  return `${local.getUTCFullYear()}-${twoDigit(local.getUTCMonth() + 1)}-` +
    `${twoDigit(local.getUTCDate())} ${twoDigit(local.getUTCHours())}:` +
    `${twoDigit(local.getUTCMinutes())}`;
}
