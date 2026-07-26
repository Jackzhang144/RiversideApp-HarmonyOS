import { describe, expect, it } from '@ohos/hypium';
import {
  AppCacheCategoryKind,
  AppCacheCategoryUsage,
  AppCacheSnapshot,
  formatCacheBytes,
  selectedCacheBytes
} from '../../../main/ets/storage/AppCacheModels';
import {
  diagnosticLogLine,
  DiagnosticLogLevel,
  sanitizeDiagnosticMessage
} from '../../../main/ets/logging/DiagnosticLogStore';

export default function appCacheModelsTest(): void {
  describe('App cache models', () => {
    it('formats cache byte totals for readable settings copy', 0, () => {
      expect(formatCacheBytes(0)).assertEqual('0 B');
      expect(formatCacheBytes(1023)).assertEqual('1023 B');
      expect(formatCacheBytes(1536)).assertEqual('1.5 KB');
      expect(formatCacheBytes(5 * 1024 * 1024)).assertEqual('5.0 MB');
      expect(formatCacheBytes(3 * 1024 * 1024 * 1024)).assertEqual('3.0 GB');
    });

    it('totals only the cache categories selected for clearing', 0, () => {
      const snapshot: AppCacheSnapshot = new AppCacheSnapshot([
        new AppCacheCategoryUsage(AppCacheCategoryKind.MEDIA, '图片', '', 1200),
        new AppCacheCategoryUsage(AppCacheCategoryKind.PAGE_RESOURCES, '页面', '', 3400),
        new AppCacheCategoryUsage(AppCacheCategoryKind.DIAGNOSTIC_LOGS, '日志', '', 500)
      ]);
      expect(snapshot.totalBytes).assertEqual(5100);
      expect(selectedCacheBytes(snapshot, [
        AppCacheCategoryKind.MEDIA,
        AppCacheCategoryKind.DIAGNOSTIC_LOGS
      ])).assertEqual(1700);
    });

    it('keeps diagnostic logs single-line and free of raw control characters', 0, () => {
      expect(sanitizeDiagnosticMessage(' request\n failed\t now ')).assertEqual('request failed now');
      expect(diagnosticLogLine(
        DiagnosticLogLevel.WARNING,
        'Network',
        'GET /t/1 failed',
        Date.parse('2026-07-27T04:00:00Z')
      )).assertEqual('2026-07-27T04:00:00.000Z | WARN | Network | GET /t/1 failed');
    });
  });
}
