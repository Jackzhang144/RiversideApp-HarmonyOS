import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { Category } from '../models/ForumModels';
import { CategoryCache, CategoryCacheScope } from './CategoryCache';

const PREFERENCES_NAME: string = 'riverside_category_cache';
const CACHE_SCHEMA_VERSION: number = 1;

interface CategoryCacheRecord {
  id?: number;
  name?: string;
  color?: string;
  description?: string;
  position?: number;
  parentCategoryId?: number | null;
  subcategoryIds?: Array<number>;
}

interface CategoryCacheEnvelope {
  version: number;
  categories: Array<CategoryCacheRecord>;
}

function decodeCategory(record: JsonObjectReader): Category | null {
  const id: number | null = record.number('id');
  const name: string | null = record.string('name');
  const color: string | null = record.string('color');
  const description: string | null = record.string('description');
  const position: number | null = record.number('position');
  const rawSubcategoryIds: Array<Object | null> | null = record.array('subcategoryIds');
  if (id === null || name === null || color === null || description === null || position === null ||
    rawSubcategoryIds === null) {
    return null;
  }
  const subcategoryIds: Array<number> = [];
  for (const subcategoryId of rawSubcategoryIds) {
    if (typeof subcategoryId !== 'number' || !Number.isFinite(subcategoryId)) {
      return null;
    }
    subcategoryIds.push(subcategoryId);
  }
  const parentCategoryId: number | null = record.number('parentCategoryId');
  return new Category(
    id,
    name,
    color,
    description,
    position,
    parentCategoryId,
    subcategoryIds
  );
}

function decodeCategories(text: string): Array<Category> | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null || envelope.number('version') !== CACHE_SCHEMA_VERSION) {
    return null;
  }
  const records: Array<Object | null> | null = envelope.array('categories');
  if (records === null) {
    return null;
  }
  const categories: Array<Category> = [];
  for (const value of records) {
    const record: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (record === null) {
      return null;
    }
    const category: Category | null = decodeCategory(record);
    if (category === null) {
      return null;
    }
    categories.push(category);
  }
  return categories;
}

function encodeCategories(categories: Array<Category>): string {
  const records: Array<CategoryCacheRecord> = categories.map((category: Category): CategoryCacheRecord => ({
    id: category.id,
    name: category.name,
    color: category.color,
    description: category.description,
    position: category.position,
    parentCategoryId: category.parentCategoryId,
    subcategoryIds: category.subcategoryIds
  }));
  const envelope: CategoryCacheEnvelope = {
    version: CACHE_SCHEMA_VERSION,
    categories: records
  };
  return JSON.stringify(envelope);
}

export class PreferencesCategoryCache implements CategoryCache {
  private readonly context: common.Context;

  public constructor(context: common.Context) {
    this.context = context;
  }

  public async read(scope: CategoryCacheScope): Promise<Array<Category> | null> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      const value: preferences.ValueType = await store.get(this.storageKey(scope), '');
      if (typeof value !== 'string' || value.length === 0) {
        return null;
      }
      return decodeCategories(value);
    } catch (_) {
      return null;
    }
  }

  public async write(scope: CategoryCacheScope, categories: Array<Category>): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      await store.put(this.storageKey(scope), encodeCategories(categories));
      await store.flush();
    } catch (_) {
      // Cache writes are best effort and never invalidate fresh network content.
    }
  }

  public async sizeBytes(): Promise<number> {
    try {
      const path: string = `${this.context.preferencesDir}/${PREFERENCES_NAME}`;
      if (!await fileIo.access(path)) {
        return 0;
      }
      return Math.max(0, Math.trunc((await fileIo.stat(path)).size));
    } catch (_) {
      return 0;
    }
  }

  public async clearAll(): Promise<void> {
    try {
      await preferences.deletePreferences(this.context, PREFERENCES_NAME);
    } catch (_) {
    }
  }

  private storageKey(scope: CategoryCacheScope): string {
    return `category:${scope.key}`;
  }
}
