import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
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
  version?: number;
  categories?: Array<CategoryCacheRecord>;
}

function decodeEnvelope(text: string): CategoryCacheEnvelope | null {
  try {
    const value: Object | null = JSON.parse(text);
    if (value === null || Array.isArray(value)) {
      return null;
    }
    // Preferences stores untrusted persisted text; mapping validates every field below.
    return value as CategoryCacheEnvelope;
  } catch (_) {
    return null;
  }
}

function decodeCategory(record: CategoryCacheRecord): Category | null {
  if (
    typeof record.id !== 'number' ||
    typeof record.name !== 'string' ||
    typeof record.color !== 'string' ||
    typeof record.description !== 'string' ||
    typeof record.position !== 'number' ||
    !Array.isArray(record.subcategoryIds)
  ) {
    return null;
  }
  const subcategoryIds: Array<number> = [];
  for (const id of record.subcategoryIds) {
    if (typeof id !== 'number') {
      return null;
    }
    subcategoryIds.push(id);
  }
  const parentCategoryId: number | null = typeof record.parentCategoryId === 'number'
    ? record.parentCategoryId
    : null;
  return new Category(
    record.id,
    record.name,
    record.color,
    record.description,
    record.position,
    parentCategoryId,
    subcategoryIds
  );
}

function decodeCategories(text: string): Array<Category> | null {
  const envelope: CategoryCacheEnvelope | null = decodeEnvelope(text);
  if (
    envelope === null ||
    envelope.version !== CACHE_SCHEMA_VERSION ||
    !Array.isArray(envelope.categories)
  ) {
    return null;
  }
  const categories: Array<Category> = [];
  for (const record of envelope.categories) {
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

  private storageKey(scope: CategoryCacheScope): string {
    return `category:${scope.key}`;
  }
}
