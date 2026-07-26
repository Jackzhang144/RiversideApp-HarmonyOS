export enum AppCacheCategoryKind {
  MEDIA = 'media',
  PAGE_RESOURCES = 'page-resources',
  BROWSE_DATA = 'browse-data',
  DIAGNOSTIC_LOGS = 'diagnostic-logs'
}

export class AppCacheCategoryUsage {
  public readonly kind: AppCacheCategoryKind;
  public readonly title: string;
  public readonly description: string;
  public readonly bytes: number;

  public constructor(
    kind: AppCacheCategoryKind,
    title: string,
    description: string,
    bytes: number
  ) {
    this.kind = kind;
    this.title = title;
    this.description = description;
    this.bytes = Math.max(0, Math.trunc(bytes));
  }
}

export class AppCacheSnapshot {
  public readonly categories: Array<AppCacheCategoryUsage>;
  public readonly totalBytes: number;

  public constructor(categories: Array<AppCacheCategoryUsage>) {
    this.categories = categories.slice();
    this.totalBytes = this.categories.reduce(
      (total: number, category: AppCacheCategoryUsage): number => total + category.bytes,
      0
    );
  }

  public static empty(): AppCacheSnapshot {
    return new AppCacheSnapshot([]);
  }
}

export function formatCacheBytes(bytes: number): string {
  const normalized: number = Math.max(0, Math.trunc(bytes));
  if (normalized < 1024) {
    return `${normalized} B`;
  }
  const kilobytes: number = normalized / 1024;
  if (kilobytes < 1024) {
    return `${kilobytes.toFixed(kilobytes >= 100 ? 0 : 1)} KB`;
  }
  const megabytes: number = kilobytes / 1024;
  if (megabytes < 1024) {
    return `${megabytes.toFixed(megabytes >= 100 ? 0 : 1)} MB`;
  }
  const gigabytes: number = megabytes / 1024;
  return `${gigabytes.toFixed(gigabytes >= 100 ? 0 : 1)} GB`;
}

export function selectedCacheBytes(
  snapshot: AppCacheSnapshot,
  selected: Array<AppCacheCategoryKind>
): number {
  return snapshot.categories.reduce(
    (total: number, category: AppCacheCategoryUsage): number => {
      return selected.includes(category.kind) ? total + category.bytes : total;
    },
    0
  );
}
