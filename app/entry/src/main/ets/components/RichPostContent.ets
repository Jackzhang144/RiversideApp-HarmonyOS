import {
  parseRichPostContent,
  RichContentBlock,
  RichContentBlockKind,
  RichContentLink,
  RichEmbedProvider
} from '../models/RichContentModels';

@Component
export struct RichPostContent {
  @Prop cooked: string = '';
  @Prop raw: string = '';
  @State revealedSpoilers: Array<number> = [];
  @State failedImages: Array<string> = [];
  onOpenLink: (url: string) => void = (_url: string): void => {};
  onOpenEmbed: (url: string, provider: RichEmbedProvider, title: string) => void = (
    _url: string,
    _provider: RichEmbedProvider,
    _title: string
  ): void => {};

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

  @Builder
  private LinkAction(link: RichContentLink): void {
    Button(link.label, { type: ButtonType.Normal })
      .height(34)
      .fontSize(12)
      .fontColor('#2068C9')
      .backgroundColor('#EAF2FF')
      .borderRadius(17)
      .padding({ left: 12, right: 12 })
      .margin({ right: 6, top: 6 })
      .onClick((): void => this.onOpenLink(link.url))
      .accessibilityText(`打开链接：${link.label}`)
  }

  @Builder
  private TextBlock(block: RichContentBlock): void {
    Column({ space: 4 }) {
      Text(block.text)
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .copyOption(CopyOptions.LocalDevice)
      if (block.links.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          ForEach(block.links, (link: RichContentLink) => {
            this.LinkAction(link)
          }, (link: RichContentLink): string => `${link.url}-${link.label}`)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private HeadingBlock(block: RichContentBlock): void {
    Text(block.text)
      .fontSize(block.level <= 1 ? 22 : block.level === 2 ? 19 : 16)
      .fontWeight(FontWeight.Bold)
      .lineHeight(block.level <= 1 ? 30 : 26)
      .width('100%')
      .copyOption(CopyOptions.LocalDevice)
  }

  @Builder
  private QuoteBlock(block: RichContentBlock): void {
    Column({ space: 6 }) {
      if (block.title.length > 0) {
        Text(`@${block.title}`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2068C9')
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
    .backgroundColor('#F1F5FA')
    .border({ width: { left: 3 }, color: '#5B8CCB' })
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
        .fontColor('#D7E3F4')
        .copyOption(CopyOptions.LocalDevice)
        .padding(12)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .backgroundColor('#202A36')
    .borderRadius(8)
    .accessibilityText(`代码：${block.text}`)
  }

  @Builder
  private FormulaBlock(block: RichContentBlock): void {
    Row({ space: 8 }) {
      Text('fx')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2068C9')
      Text(block.text)
        .fontSize(15)
        .fontFamily('serif')
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F6F8FB')
    .border({ width: 1, color: '#DDE4ED' })
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
          .fontColor(['#52606D'])
        Text(this.revealedSpoilers.includes(index) ? block.text : '点击显示剧透内容')
          .fontSize(13)
          .fontColor('#52606D')
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#E9EDF2')
    .borderRadius(8)
    .onClick((): void => this.toggleSpoiler(index))
    .accessibilityText(this.revealedSpoilers.includes(index) ? `剧透：${block.text}` : '显示剧透内容')
  }

  @Builder
  private ListBlock(block: RichContentBlock): void {
    Column({ space: 7 }) {
      ForEach(block.items, (item: string, index: number) => {
        Row({ space: 8 }) {
          Text(block.ordered ? `${index + 1}.` : '•')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2068C9')
          Text(item)
            .fontSize(14)
            .lineHeight(21)
            .layoutWeight(1)
            .copyOption(CopyOptions.LocalDevice)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }, (item: string, index: number): string => `${index}-${item}`)
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
      .backgroundColor(header ? '#EAF2FF' : '#FFFFFF')
      .border({ width: 0.5, color: '#DDE4ED' })
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
    .accessibilityText('Post 表格')
  }

  @Builder
  private ImageBlock(block: RichContentBlock): void {
    Column({ space: 6 }) {
      if (this.failedImages.includes(block.url)) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.ohos_photo'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_tertiary')])
          Text('图片加载失败')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F4F5F7')
        .borderRadius(8)
      } else {
        Image(block.url)
          .width('100%')
          .height(220)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
          .backgroundColor('#F4F5F7')
          .borderRadius(8)
          .onError((): void => this.recordImageFailure(block.url))
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
          .fontColor('#24262B')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(block.text.length > 0 ? block.text : block.url)
          .fontSize(11)
          .fontColor('#667085')
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .height(68)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#F8FAFC')
    .border({ width: 1, color: '#DDE4ED' })
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
          .fontColor(['#FFFFFF'])
        Text(block.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text('在隔离 ArkWeb 中播放')
          .fontSize(11)
          .fontColor('#D7E3F4')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(190)
    .backgroundColor('#202A36')
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
