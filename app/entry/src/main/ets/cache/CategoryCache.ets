import { Category } from '../models/ForumModels';

export class CategoryCacheScope {
  public readonly key: string;

  private constructor(key: string) {
    this.key = key;
  }

  public static anonymous(): CategoryCacheScope {
    return new CategoryCacheScope('anonymous');
  }

  public static authenticated(clientId: string): CategoryCacheScope | null {
    const normalizedClientId: string = clientId.trim();
    if (normalizedClientId.length === 0) {
      return null;
    }
    return new CategoryCacheScope(`authenticated:${normalizedClientId}`);
  }
}

export interface CategoryCache {
  read(scope: CategoryCacheScope): Promise<Array<Category> | null>;

  write(scope: CategoryCacheScope, categories: Array<Category>): Promise<void>;
}
