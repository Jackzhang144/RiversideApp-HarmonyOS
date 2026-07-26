import { AppCacheManager } from '../storage/AppCacheManager';
import {
  AppCacheCategoryKind,
  AppCacheCategoryUsage,
  AppCacheSnapshot,
  formatCacheBytes,
  selectedCacheBytes
} from '../storage/AppCacheModels';

@Component
export struct StorageDiagnosticsPage {
  scroller: Scroller = new Scroller();
  manager: AppCacheManager | null = null;

  @State snapshot: AppCacheSnapshot = AppCacheSnapshot.empty();
  @State selected: Array<AppCacheCategoryKind> = [];
  @State recentLogs: Array<string> = [];
  @State loading: boolean = true;
  @State clearing: boolean = false;
  @State statusMessage: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    const manager: AppCacheManager | null = this.manager;
    if (manager === null) {
      this.loading = false;
      this.statusMessage = '无法读取应用存储信息';
      return;
    }
    this.loading = true;
    this.snapshot = await manager.snapshot();
    this.recentLogs = await manager.readRecentLogs(6);
    if (this.selected.length === 0) {
      this.selected = this.snapshot.categories
        .filter((category: AppCacheCategoryUsage): boolean => category.bytes > 0)
        .map((category: AppCacheCategoryUsage): AppCacheCategoryKind => category.kind);
    }
    this.loading = false;
  }

  private isSelected(kind: AppCacheCategoryKind): boolean {
    return this.selected.includes(kind);
  }

  private toggleSelection(kind: AppCacheCategoryKind): void {
    if (this.isSelected(kind)) {
      this.selected = this.selected.filter(
        (candidate: AppCacheCategoryKind): boolean => candidate !== kind
      );
      return;
    }
    this.selected = this.selected.concat(kind);
  }

  private selectedBytes(): number {
    return selectedCacheBytes(this.snapshot, this.selected);
  }

  private cacheIcon(kind: AppCacheCategoryKind): Resource {
    if (kind === AppCacheCategoryKind.MEDIA) {
      return $r('sys.symbol.ohos_photo');
    }
    if (kind === AppCacheCategoryKind.PAGE_RESOURCES) {
      return $r('sys.symbol.link');
    }
    if (kind === AppCacheCategoryKind.BROWSE_DATA) {
      return $r('sys.symbol.folder');
    }
    return $r('sys.symbol.doc_plaintext_and_pencil');
  }

  private confirmClear(): void {
    const bytes: number = this.selectedBytes();
    if (this.clearing || this.selected.length === 0 || bytes <= 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '清除所选缓存？',
      message: `将释放约 ${formatCacheBytes(bytes)}。登录状态、设置、草稿与账号数据不会被删除。`,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '清除',
        action: (): void => {
          this.clearSelected();
        }
      },
      cancel: (): void => {}
    });
  }

  private async clearSelected(): Promise<void> {
    const manager: AppCacheManager | null = this.manager;
    if (manager === null || this.clearing) {
      return;
    }
    const previousTotal: number = this.snapshot.totalBytes;
    this.clearing = true;
    this.statusMessage = '';
    this.snapshot = await manager.clear(this.selected);
    this.recentLogs = await manager.readRecentLogs(6);
    const released: number = Math.max(0, previousTotal - this.snapshot.totalBytes);
    this.selected = this.snapshot.categories
      .filter((category: AppCacheCategoryUsage): boolean => category.bytes > 0)
      .map((category: AppCacheCategoryUsage): AppCacheCategoryKind => category.kind);
    this.statusMessage = released > 0
      ? `已释放 ${formatCacheBytes(released)}`
      : '所选缓存已是空的';
    this.clearing = false;
  }

  @Builder
  private OverviewCard(): void {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(24)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(48)
      .height(48)
      .borderRadius(15)
      .backgroundColor($r('app.color.brand_tint_surface'))

      Column({ space: 3 }) {
        Text('可管理缓存')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
        Text(formatCacheBytes(this.snapshot.totalBytes))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button({ type: ButtonType.Normal }) {
        if (this.loading) {
          LoadingProgress()
            .width(20)
            .height(20)
        } else {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(20)
            .fontColor([$r('app.color.brand_primary')])
        }
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .enabled(!this.loading && !this.clearing)
      .onClick((): void => {
        this.refresh();
      })
      .accessibilityText('重新统计缓存')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private CacheCategoryRow(category: AppCacheCategoryUsage): void {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph(this.cacheIcon(category.kind))
          .fontSize(20)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(38)
      .height(38)
      .borderRadius(12)
      .backgroundColor($r('app.color.brand_tint_surface'))

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(category.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          Text(formatCacheBytes(category.bytes))
            .fontSize(12)
            .fontColor(category.bytes > 0
              ? $r('sys.color.font_secondary')
              : $r('sys.color.font_tertiary'))
        }
        .width('100%')
        Text(category.description)
          .fontSize(11)
          .lineHeight(16)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph(this.isSelected(category.kind)
        ? $r('sys.symbol.checkmark_circle_fill')
        : $r('sys.symbol.circle'))
        .fontSize(22)
        .fontColor([
          this.isSelected(category.kind)
            ? $r('app.color.brand_primary')
            : $r('sys.color.font_tertiary')
        ])
    }
    .width('100%')
    .constraintSize({ minHeight: 82 })
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .opacity(category.bytes > 0 ? 1 : 0.72)
    .enabled(category.bytes > 0 && !this.clearing)
    .onClick((): void => {
      this.toggleSelection(category.kind);
    })
    .accessibilityText(
      `${category.title}，${formatCacheBytes(category.bytes)}，${this.isSelected(category.kind) ? '已选择' : '未选择'}`
    )
  }

  @Builder
  private RecentLogsCard(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.doc_plaintext_and_pencil'))
          .fontSize(18)
          .fontColor([$r('app.color.brand_primary')])
        Text('最近运行记录')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Text(`${this.recentLogs.length} 条`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')

      if (this.recentLogs.length === 0) {
        Text('暂无诊断记录')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      } else {
        ForEach(
          this.recentLogs,
          (line: string, index: number): void => {
            Text(line)
              .fontSize(10)
              .lineHeight(15)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (index < this.recentLogs.length - 1) {
              Divider().color($r('sys.color.comp_divider'))
            }
          },
          (line: string, index: number): string => `${index}:${line}`
        )
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        this.OverviewCard()

        Text('按类别清理')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')

        Column() {
          ForEach(
            this.snapshot.categories,
            (category: AppCacheCategoryUsage, index: number): void => {
              this.CacheCategoryRow(category)
              if (index < this.snapshot.categories.length - 1) {
                Divider()
                  .margin({ left: 64 })
                  .color($r('sys.color.comp_divider'))
              }
            },
            (category: AppCacheCategoryUsage): string => `${category.kind}:${category.bytes}`
          )
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .border({ width: 1, color: $r('sys.color.comp_divider') })

        Button() {
          Row({ space: 8 }) {
            if (this.clearing) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color($r('app.color.on_accent'))
            } else {
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(18)
                .fontColor([$r('app.color.on_accent')])
            }
            Text(this.clearing
              ? '正在清理'
              : `清除所选 · ${formatCacheBytes(this.selectedBytes())}`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_accent'))
          }
        }
        .width('100%')
        .height(48)
        .borderRadius(16)
        .backgroundColor($r('app.color.brand_primary'))
        .enabled(!this.loading && !this.clearing && this.selectedBytes() > 0)
        .opacity(!this.loading && !this.clearing && this.selectedBytes() > 0 ? 1 : 0.45)
        .onClick((): void => {
          this.confirmClear();
        })

        if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontSize(12)
            .fontColor($r('app.color.brand_primary'))
            .width('100%')
            .textAlign(TextAlign.Center)
        }

        this.RecentLogsCard()

        Text('这里只清理可重新下载或重新生成的数据；Authenticated Session、设置、草稿和账号资料不在清理范围内。')
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 0, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
