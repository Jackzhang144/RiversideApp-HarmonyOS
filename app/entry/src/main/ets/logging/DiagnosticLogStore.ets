import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const APP_LOG_DOMAIN: number = 0x0000;
const APP_LOG_TAG: string = 'RiverSide';
const LOG_DIRECTORY_NAME: string = 'diagnostics';
const LOG_FILE_NAME: string = 'events.log';
const MAX_LOG_BYTES: number = 512 * 1024;

export enum DiagnosticLogLevel {
  INFO = 'INFO',
  WARNING = 'WARN',
  ERROR = 'ERROR'
}

export function sanitizeDiagnosticMessage(message: string): string {
  return message
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s{2,}/g, ' ')
    .trim()
    .slice(0, 512);
}

export function diagnosticLogLine(
  level: DiagnosticLogLevel,
  component: string,
  message: string,
  timestamp: number = Date.now()
): string {
  const normalizedComponent: string = sanitizeDiagnosticMessage(component).slice(0, 40);
  const normalizedMessage: string = sanitizeDiagnosticMessage(message);
  return `${new Date(timestamp).toISOString()} | ${level} | ${normalizedComponent} | ${normalizedMessage}`;
}

export class DiagnosticLogStore {
  private readonly context: common.Context;
  private pendingWrite: Promise<void> = Promise.resolve();

  public constructor(context: common.Context) {
    this.context = context;
  }

  public append(level: DiagnosticLogLevel, component: string, message: string): void {
    const line: string = `${diagnosticLogLine(level, component, message)}\n`;
    const write: () => Promise<void> = async (): Promise<void> => {
      await this.persist(line);
    };
    this.pendingWrite = this.pendingWrite.then(write, write);
  }

  public async sizeBytes(): Promise<number> {
    await this.pendingWrite;
    try {
      if (!await fileIo.access(this.logFilePath())) {
        return 0;
      }
      return Math.max(0, Math.trunc((await fileIo.stat(this.logFilePath())).size));
    } catch (_) {
      return 0;
    }
  }

  public async readRecent(limit: number = 80): Promise<Array<string>> {
    await this.pendingWrite;
    const normalizedLimit: number = Math.max(1, Math.min(200, Math.trunc(limit)));
    try {
      if (!await fileIo.access(this.logFilePath())) {
        return [];
      }
      const lines: Array<string> = (await fileIo.readText(this.logFilePath()))
        .split('\n')
        .map((line: string): string => line.trim())
        .filter((line: string): boolean => line.length > 0);
      return lines.slice(Math.max(0, lines.length - normalizedLimit)).reverse();
    } catch (_) {
      return [];
    }
  }

  public async clear(): Promise<void> {
    await this.pendingWrite;
    try {
      if (await fileIo.access(this.logDirectoryPath())) {
        await fileIo.rmdir(this.logDirectoryPath());
      }
    } catch (_) {
    }
  }

  private async persist(line: string): Promise<void> {
    let file: fileIo.File | null = null;
    try {
      const directory: string = this.logDirectoryPath();
      if (!await fileIo.access(directory)) {
        await fileIo.mkdir(directory, true);
      }
      const path: string = this.logFilePath();
      if (await fileIo.access(path) && (await fileIo.stat(path)).size >= MAX_LOG_BYTES) {
        await fileIo.truncate(path, 0);
      }
      file = await fileIo.open(
        path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.APPEND
      );
      await fileIo.write(file.fd, line);
    } catch (_) {
    } finally {
      if (file !== null) {
        try {
          await fileIo.close(file);
        } catch (_) {
        }
      }
    }
  }

  private logDirectoryPath(): string {
    return `${this.context.cacheDir}/${LOG_DIRECTORY_NAME}`;
  }

  private logFilePath(): string {
    return `${this.logDirectoryPath()}/${LOG_FILE_NAME}`;
  }
}

export class AppLogger {
  private static store: DiagnosticLogStore | null = null;

  public static initialize(context: common.Context): DiagnosticLogStore {
    if (AppLogger.store === null) {
      AppLogger.store = new DiagnosticLogStore(context);
    }
    return AppLogger.store;
  }

  public static diagnosticStore(): DiagnosticLogStore | null {
    return AppLogger.store;
  }

  public static info(component: string, message: string): void {
    const normalized: string = sanitizeDiagnosticMessage(message);
    hilog.info(APP_LOG_DOMAIN, APP_LOG_TAG, '%{public}s: %{public}s', component, normalized);
    AppLogger.store?.append(DiagnosticLogLevel.INFO, component, normalized);
  }

  public static warning(component: string, message: string): void {
    const normalized: string = sanitizeDiagnosticMessage(message);
    hilog.warn(APP_LOG_DOMAIN, APP_LOG_TAG, '%{public}s: %{public}s', component, normalized);
    AppLogger.store?.append(DiagnosticLogLevel.WARNING, component, normalized);
  }

  public static error(component: string, message: string): void {
    const normalized: string = sanitizeDiagnosticMessage(message);
    hilog.error(APP_LOG_DOMAIN, APP_LOG_TAG, '%{public}s: %{public}s', component, normalized);
    AppLogger.store?.append(DiagnosticLogLevel.ERROR, component, normalized);
  }
}
