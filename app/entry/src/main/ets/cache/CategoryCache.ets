import { Category } from '../models/ForumModels';

export class CategoryCacheScope {
  public readonly key: string;

  private constructor(key: string) {
    this.key = key;
  }

  public static anonymous(): CategoryCacheScope {
    return new CategoryCacheScope('anonymous');
  }

  public static authenticated(clientId: string): CategoryCacheScope {
    if (clientId.trim().length === 0) {
      return CategoryCacheScope.anonymous();
    }
    return new CategoryCacheScope(`authenticated:${clientId}`);
  }
}

export interface CategoryCache {
  read(scope: CategoryCacheScope): Promise<Array<Category> | null>;

  write(scope: CategoryCacheScope, categories: Array<Category>): Promise<void>;
}
