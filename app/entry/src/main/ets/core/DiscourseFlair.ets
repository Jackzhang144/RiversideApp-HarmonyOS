import { RIVERSIDE_URL_RESOLVER } from './RiversideEnvironment';

const HEX_COLOR_PATTERN: RegExp = /^[0-9a-fA-F]{6}$/;

export function isDiscourseFlairImage(value: string): boolean {
  return value.trim().includes('/');
}

export function absoluteDiscourseFlairUrl(value: string): string {
  const normalizedValue: string = value.trim();
  return isDiscourseFlairImage(normalizedValue)
    ? RIVERSIDE_URL_RESOLVER.absolute(normalizedValue)
    : normalizedValue;
}

export function normalizedDiscourseFlairColor(value: string): string {
  const normalizedValue: string = value.trim().replace(/^#/, '');
  return HEX_COLOR_PATTERN.test(normalizedValue) ? `#${normalizedValue.toUpperCase()}` : '';
}
