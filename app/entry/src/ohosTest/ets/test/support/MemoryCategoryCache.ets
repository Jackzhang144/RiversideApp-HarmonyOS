import { CategoryCache, CategoryCacheScope } from '../../../../main/ets/cache/CategoryCache';
import { Category } from '../../../../main/ets/models/ForumModels';

export class MemoryCategoryCache implements CategoryCache {
  public stored: Array<Category> | null = null;
  public readScope: CategoryCacheScope | null = null;
  public writeScope: CategoryCacheScope | null = null;

  public async read(scope: CategoryCacheScope): Promise<Array<Category> | null> {
    this.readScope = scope;
    return this.stored;
  }

  public async write(scope: CategoryCacheScope, categories: Array<Category>): Promise<void> {
    this.writeScope = scope;
    this.stored = categories;
  }
}
