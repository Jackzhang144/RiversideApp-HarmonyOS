import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { webview } from '@kit.ArkWeb';
import { PreferencesCategoryCache } from '../cache/PreferencesCategoryCache';
import { AppLogger, DiagnosticLogStore } from '../logging/DiagnosticLogStore';
import {
  AppCacheCategoryKind,
  AppCacheCategoryUsage,
  AppCacheSnapshot
} from './AppCacheModels';

const MEDIA_DIRECTORY_NAME: string = 'media';
const LOG_DIRECTORY_NAME: string = 'diagnostics';

export class AppCacheManager {
  private readonly context: common.Context;
  private readonly categoryCache: PreferencesCategoryCache;
  private readonly diagnosticLogStore: DiagnosticLogStore;

  public constructor(
    context: common.Context,
    categoryCache: PreferencesCategoryCache,
    diagnosticLogStore: DiagnosticLogStore
  ) {
    this.context = context;
    this.categoryCache = categoryCache;
    this.diagnosticLogStore = diagnosticLogStore;
  }

  public async snapshot(): Promise<AppCacheSnapshot> {
    const mediaBytes: number = await this.directorySize(`${this.context.cacheDir}/${MEDIA_DIRECTORY_NAME}`);
    const logBytes: number = await this.diagnosticLogStore.sizeBytes();
    const pageResourceBytes: number = await this.pageResourceSize();
    const browseBytes: number = await this.categoryCache.sizeBytes();
    return new AppCacheSnapshot([
      new AppCacheCategoryUsage(
        AppCacheCategoryKind.MEDIA,
        '图片与上传',
        '图片预览、待上传图片与保存到相册前的临时副本',
        mediaBytes
      ),
      new AppCacheCategoryUsage(
        AppCacheCategoryKind.PAGE_RESOURCES,
        '页面资源',
        '网页、图片预加载与可重新生成的系统渲染资源',
        pageResourceBytes
      ),
      new AppCacheCategoryUsage(
        AppCacheCategoryKind.BROWSE_DATA,
        '版块浏览',
        '用于加快分类页面首次显示的本地数据',
        browseBytes
      ),
      new AppCacheCategoryUsage(
        AppCacheCategoryKind.DIAGNOSTIC_LOGS,
        '诊断日志',
        '仅记录运行状态和错误码，不包含正文与认证信息',
        logBytes
      )
    ]);
  }

  public async clear(categories: Array<AppCacheCategoryKind>): Promise<AppCacheSnapshot> {
    for (const category of categories) {
      if (category === AppCacheCategoryKind.MEDIA) {
        await this.removeDirectory(`${this.context.cacheDir}/${MEDIA_DIRECTORY_NAME}`);
      } else if (category === AppCacheCategoryKind.PAGE_RESOURCES) {
        await this.clearPageResources();
      } else if (category === AppCacheCategoryKind.BROWSE_DATA) {
        await this.categoryCache.clearAll();
      } else if (category === AppCacheCategoryKind.DIAGNOSTIC_LOGS) {
        await this.diagnosticLogStore.clear();
      }
    }
    if (!categories.includes(AppCacheCategoryKind.DIAGNOSTIC_LOGS)) {
      AppLogger.info('Cache', `Cleared ${categories.length} cache categories`);
    }
    return await this.snapshot();
  }

  public readRecentLogs(limit: number = 80): Promise<Array<string>> {
    return this.diagnosticLogStore.readRecent(limit);
  }

  private async pageResourceSize(): Promise<number> {
    let total: number = 0;
    try {
      const entries: Array<string> = await fileIo.listFile(this.context.cacheDir);
      for (const entry of entries) {
        if (entry === MEDIA_DIRECTORY_NAME || entry === LOG_DIRECTORY_NAME) {
          continue;
        }
        total += await this.directorySize(`${this.context.cacheDir}/${entry}`);
      }
    } catch (_) {
      return total;
    }
    return total;
  }

  private async clearPageResources(): Promise<void> {
    try {
      webview.WebviewController.removeAllCache(true);
    } catch (_) {
    }
    try {
      const entries: Array<string> = await fileIo.listFile(this.context.cacheDir);
      for (const entry of entries) {
        if (entry === MEDIA_DIRECTORY_NAME || entry === LOG_DIRECTORY_NAME) {
          continue;
        }
        await this.removePath(`${this.context.cacheDir}/${entry}`);
      }
    } catch (_) {
    }
  }

  private async directorySize(path: string): Promise<number> {
    try {
      if (!await fileIo.access(path)) {
        return 0;
      }
      const stat: fileIo.Stat = await fileIo.stat(path);
      if (stat.isFile()) {
        return Math.max(0, Math.trunc(stat.size));
      }
      if (!stat.isDirectory()) {
        return 0;
      }
      const entries: Array<string> = await fileIo.listFile(path);
      let total: number = 0;
      for (const entry of entries) {
        total += await this.directorySize(`${path}/${entry}`);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  private async removePath(path: string): Promise<void> {
    try {
      if (!await fileIo.access(path)) {
        return;
      }
      const stat: fileIo.Stat = await fileIo.stat(path);
      if (stat.isDirectory()) {
        await fileIo.rmdir(path);
      } else if (stat.isFile()) {
        await fileIo.unlink(path);
      }
    } catch (_) {
    }
  }

  private async removeDirectory(path: string): Promise<void> {
    try {
      if (await fileIo.access(path)) {
        await fileIo.rmdir(path);
      }
    } catch (_) {
    }
  }
}
