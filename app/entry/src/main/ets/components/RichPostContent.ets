import {
  RichContentBlock,
  RichContentBlockKind,
  RichContentInlineFragment,
  RichContentInlineFragmentKind,
  RichContentListItem
} from '../models/RichContentBlocks';
import { parseRichPostContent } from '../models/RichContentParser';
import { RichEmbedProvider } from '../models/RichNavigationPolicy';

class RichContentImageRatio {
  public readonly url: string;
  public readonly ratio: number;

  public constructor(url: string, ratio: number) {
    this.url = url;
    this.ratio = ratio;
  }
}

@Component
export struct RichPostContent {
  @Prop cooked: string = '';
  @Prop raw: string = '';
  @State revealedSpoilers: Array<number> = [];
  @State failedImages: Array<string> = [];
  @State imageRatios: Array<RichContentImageRatio> = [];
  onOpenLink: (url: string) => void = (_url: string): void => {};
  onOpenEmbed: (url: string, provider: RichEmbedProvider, title: string) => void = (
    _url: string,
    _provider: RichEmbedProvider,
    _title: string
  ): void => {};
  onOpenImage: (url: string, title: string) => void = (_url: string, _title: string): void => {};

  private blocks(): Array<RichContentBlock> {
    return parseRichPostContent(this.cooked, this.raw);
  }

  private toggleSpoiler(index: number): void {
    this.revealedSpoilers = this.revealedSpoilers.includes(index)
      ? this.revealedSpoilers.filter((value: number): boolean => value !== index)
      : this.revealedSpoilers.concat([index]);
  }

  private recordImageFailure(url: string): void {
    if (!this.failedImages.includes(url)) {
      this.failedImages = this.failedImages.concat([url]);
    }
  }

  private imageAspectRatio(block: RichContentBlock): number {
    for (const imageRatio of this.imageRatios) {
      if (imageRatio.url === block.url) {
        return imageRatio.ratio;
      }
    }
    if (block.sourceWidth > 0 && block.sourceHeight > 0) {
      return block.sourceWidth / block.sourceHeight;
    }
    return 4 / 3;
  }

  private recordImageRatio(url: string, width: number, height: number): void {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
      return;
    }
    const ratio: number = width / height;
    for (const imageRatio of this.imageRatios) {
      if (imageRatio.url === url && Math.abs(imageRatio.ratio - ratio) < 0.001) {
        return;
      }
    }
    this.imageRatios = this.imageRatios
      .filter((imageRatio: RichContentImageRatio): boolean => imageRatio.url !== url)
      .concat([new RichContentImageRatio(url, ratio)]);
  }

  @Builder
  private InlineText(
    fragments: Array<RichContentInlineFragment>,
    fallback: string,
    fontSize: number,
    lineHeight: number,
    textWeight: FontWeight = FontWeight.Regular,
    linkWeight: FontWeight = FontWeight.Medium
  ): void {
    Text() {
      if (fragments.length > 0) {
        ForEach(fragments, (fragment: RichContentInlineFragment) => {
          if (fragment.kind === RichContentInlineFragmentKind.EMOJI) {
            ImageSpan(fragment.imageUrl)
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
              .verticalAlign(ImageSpanAlignment.CENTER)
          } else if (fragment.kind === RichContentInlineFragmentKind.LINK) {
            Span(fragment.text)
              .fontColor($r('app.color.text_link'))
              .fontWeight(linkWeight)
              .onClick((): void => this.onOpenLink(fragment.url))
          } else {
            Span(fragment.text)
              .fontColor($r('sys.color.font_primary'))
              .fontWeight(textWeight)
          }
        }, (fragment: RichContentInlineFragment, index: number): string =>
          `${index}-${fragment.kind}-${fragment.url}-${fragment.imageUrl}-${fragment.text}`)
      } else {
        Span(fallback)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(textWeight)
      }
    }
      .fontSize(fontSize)
      .lineHeight(lineHeight)
      .width('100%')
      .copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  private TextBlock(block: RichContentBlock): void {
    this.InlineText(block.inlineFragments, block.text, 14, 22)
  }

  @Builder
  private HeadingBlock(block: RichContentBlock): void {
    this.InlineText(
      block.inlineFragments,
      block.text,
      block.level <= 1 ? 22 : block.level === 2 ? 19 : 16,
      block.level <= 1 ? 30 : 26,
      FontWeight.Bold,
      FontWeight.Bold
    )
  }

  @Builder
  private QuoteBlock(block: RichContentBlock): void {
    Column({ space: 6 }) {
      if (block.title.length > 0) {
        Text(`@${block.title}`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_link'))
      }
      Text(block.text)
        .fontSize(14)
        .lineHeight(21)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .copyOption(CopyOptions.LocalDevice)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: { left: 3 }, color: $r('app.color.quote_border') })
    .borderRadius(8)
    .accessibilityText(`${block.title.length > 0 ? `${block.title} 的` : ''}引用：${block.text}`)
  }

  @Builder
  private CodeBlock(block: RichContentBlock): void {
    Scroll() {
      Text(block.text)
        .fontSize(13)
        .lineHeight(20)
        .fontFamily('monospace')
        .fontColor($r('app.color.code_text'))
        .copyOption(CopyOptions.LocalDevice)
        .padding(12)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .backgroundColor($r('app.color.code_surface'))
    .borderRadius(8)
    .accessibilityText(`代码：${block.text}`)
  }

  @Builder
  private FormulaBlock(block: RichContentBlock): void {
    Row({ space: 8 }) {
      Text('fx')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_link'))
      Text(block.text)
        .fontSize(15)
        .fontFamily('serif')
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(8)
    .accessibilityText(`公式：${block.text}`)
  }

  @Builder
  private SpoilerBlock(block: RichContentBlock, index: number): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        SymbolGlyph(this.revealedSpoilers.includes(index)
          ? $r('sys.symbol.eye_slash')
          : $r('sys.symbol.eye'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_secondary')])
        Text(this.revealedSpoilers.includes(index) ? block.text : '点击显示剧透内容')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(8)
    .onClick((): void => this.toggleSpoiler(index))
    .accessibilityText(this.revealedSpoilers.includes(index) ? `剧透：${block.text}` : '显示剧透内容')
  }

  @Builder
  private ListBlock(block: RichContentBlock): void {
    Column({ space: 7 }) {
      ForEach(block.listItems, (item: RichContentListItem, index: number) => {
        Row({ space: 8 }) {
          Text(block.ordered ? `${index + 1}.` : '•')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_link'))
          Column() {
            this.InlineText(item.inlineFragments, item.text, 14, 21)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }, (item: RichContentListItem, index: number): string => `${index}-${item.text}`)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private TableCell(value: string, header: boolean): void {
    Text(value)
      .fontSize(12)
      .fontWeight(header ? FontWeight.Bold : FontWeight.Regular)
      .fontColor($r('sys.color.font_primary'))
      .width(140)
      .height(40)
      .padding(8)
      .backgroundColor(header
        ? $r('sys.color.background_secondary')
        : $r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  private TableBlock(block: RichContentBlock): void {
    Scroll() {
      Column() {
        ForEach(block.rows, (row: Array<string>, rowIndex: number) => {
          Row() {
            ForEach(row, (cell: string, cellIndex: number) => {
              this.TableCell(cell, rowIndex === 0)
            }, (cell: string, cellIndex: number): string => `${cellIndex}-${cell}`)
          }
        }, (row: Array<string>, rowIndex: number): string => `${rowIndex}-${row.join('|')}`)
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .borderRadius(8)
    .accessibilityText($r('app.string.rich_post_table_accessibility'))
  }

  @Builder
  private ImageBlock(block: RichContentBlock): void {
    Column({ space: 6 }) {
      if (this.failedImages.includes(block.url)) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.ohos_photo'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])
          Text($r('app.string.rich_post_image_failed'))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(8)
      } else {
        Image(block.url)
          .width('100%')
          .aspectRatio(this.imageAspectRatio(block))
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
          .borderRadius(8)
          .clip(true)
          .onComplete((event): void => {
            if (event !== undefined && event.loadingStatus === 1) {
              this.recordImageRatio(block.url, event.width, event.height);
            }
          })
          .onError((): void => this.recordImageFailure(block.url))
          .onClick((): void => this.onOpenImage(block.url, block.title))
          .accessibilityText(block.title)
      }
      if (block.title.length > 0) {
        Text(block.title)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
  }

  @Builder
  private OneboxBlock(block: RichContentBlock): void {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Text(block.title.length > 0 ? block.title : block.url)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(block.text.length > 0 ? block.text : block.url)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .height(68)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(8)
    .onClick((): void => this.onOpenLink(block.url))
    .accessibilityText(`打开链接卡片：${block.title}`)
  }

  @Builder
  private VideoBlock(block: RichContentBlock): void {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.play_circle_fill'))
          .fontSize(44)
          .fontColor([$r('app.color.on_accent')])
        Text(block.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
        Text($r('app.string.rich_post_play_isolated'))
          .fontSize(11)
          .fontColor($r('app.color.code_text'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(190)
    .backgroundColor($r('app.color.code_surface'))
    .borderRadius(8)
    .onClick((): void => this.onOpenEmbed(block.url, block.embedProvider, block.title))
    .accessibilityText(`播放${block.title}`)
  }

  @Builder
  private Block(block: RichContentBlock, index: number): void {
    if (block.kind === RichContentBlockKind.TEXT) {
      this.TextBlock(block)
    } else if (block.kind === RichContentBlockKind.HEADING) {
      this.HeadingBlock(block)
    } else if (block.kind === RichContentBlockKind.QUOTE) {
      this.QuoteBlock(block)
    } else if (block.kind === RichContentBlockKind.CODE) {
      this.CodeBlock(block)
    } else if (block.kind === RichContentBlockKind.FORMULA) {
      this.FormulaBlock(block)
    } else if (block.kind === RichContentBlockKind.SPOILER) {
      this.SpoilerBlock(block, index)
    } else if (block.kind === RichContentBlockKind.LIST) {
      this.ListBlock(block)
    } else if (block.kind === RichContentBlockKind.TABLE) {
      this.TableBlock(block)
    } else if (block.kind === RichContentBlockKind.IMAGE) {
      this.ImageBlock(block)
    } else if (block.kind === RichContentBlockKind.ONEBOX) {
      this.OneboxBlock(block)
    } else if (block.kind === RichContentBlockKind.VIDEO) {
      this.VideoBlock(block)
    }
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.blocks(), (block: RichContentBlock, index: number) => {
        this.Block(block, index)
      }, (block: RichContentBlock, index: number): string =>
        `${index}-${block.kind}-${block.url}-${block.text.slice(0, 24)}`)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
