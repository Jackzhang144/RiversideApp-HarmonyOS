import { JSON as ArkJSON } from '@kit.ArkTS';

export class JsonObjectReader {
  private readonly value: Object;

  private constructor(value: Object) {
    this.value = value;
  }

  public static parse(text: string): JsonObjectReader | null {
    try {
      const value: Object | null = ArkJSON.parse(text);
      return JsonObjectReader.fromValue(value);
    } catch (_) {
      return null;
    }
  }

  public static parseArray(text: string): Array<Object | null> | null {
    try {
      const value: Object | null = ArkJSON.parse(text);
      return Array.isArray(value) ? Array.from<Object | null>(value) : null;
    } catch (_) {
      return null;
    }
  }

  public static fromValue(value: Object | null): JsonObjectReader | null {
    if (value === null || Array.isArray(value) || typeof value !== 'object') {
      return null;
    }
    return new JsonObjectReader(value);
  }

  public string(name: string): string | null {
    const value: Object | null = this.property(name);
    return typeof value === 'string' ? value : null;
  }

  public number(name: string): number | null {
    const value: Object | null = this.property(name);
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
  }

  public boolean(name: string): boolean | null {
    const value: Object | null = this.property(name);
    return typeof value === 'boolean' ? value : null;
  }

  public object(name: string): JsonObjectReader | null {
    return JsonObjectReader.fromValue(this.property(name));
  }

  public has(name: string): boolean {
    const entries: Array<[string, Object]> = Object.entries(this.value);
    for (const entry of entries) {
      if (entry[0] === name) {
        return true;
      }
    }
    return false;
  }

  public isNull(name: string): boolean {
    return this.has(name) && this.property(name) === null;
  }

  public array(name: string): Array<Object | null> | null {
    const value: Object | null = this.property(name);
    if (!Array.isArray(value)) {
      return null;
    }
    const source: Array<Object | null> = Array.from<Object | null>(value);
    const items: Array<Object | null> = [];
    for (const item of source) {
      items.push(item);
    }
    return items;
  }

  public entries(): Array<[string, Object]> {
    return Object.entries(this.value);
  }

  private property(name: string): Object | null {
    const entries: Array<[string, Object]> = Object.entries(this.value);
    for (const entry of entries) {
      if (entry[0] === name) {
        return entry[1];
      }
    }
    return null;
  }
}
