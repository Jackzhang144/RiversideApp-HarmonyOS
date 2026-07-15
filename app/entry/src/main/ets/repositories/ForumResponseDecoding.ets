import { JsonObjectReader } from '../core/JsonObjectReader';

export function textOrEmpty(value: string | null): string {
  return typeof value === 'string' ? value : '';
}

export function numberOrZero(value: number | null): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

export function booleanOrFalse(value: boolean | null): boolean {
  return value === true;
}

export function integerFromReader(reader: JsonObjectReader, names: Array<string>): number | null {
  for (const name of names) {
    const numeric: number | null = reader.number(name);
    if (numeric !== null && Number.isInteger(numeric)) {
      return numeric;
    }
    const text: string | null = reader.string(name);
    if (text !== null && /^\d+$/.test(text.trim())) {
      const parsed: number = Number.parseInt(text.trim(), 10);
      if (Number.isInteger(parsed)) {
        return parsed;
      }
    }
  }
  return null;
}

export function decodeNumberArray(source: JsonObjectReader, name: string): Array<number> | null {
  const values: Array<Object | null> | null = source.array(name);
  if (values === null) {
    return null;
  }
  const numbers: Array<number> = [];
  for (const value of values) {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return null;
    }
    numbers.push(value);
  }
  return numbers;
}
