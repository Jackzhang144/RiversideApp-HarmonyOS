import {
  ForumComposerMode,
  ForumComposerPresentation,
  ForumComposerStatus
} from './ForumComposerPresentation';

@Component
export struct ForumComposer {
  @Prop presentation: ForumComposerPresentation = ForumComposerPresentation.reply(
    0,
    '',
    null,
    '',
    ForumComposerStatus.EDITING,
    ''
  );
  onTitleChange: (title: string) => void = (_title: string): void => {};
  onBodyChange: (body: string) => void = (_body: string): void => {};
  onSubmit: () => void = (): void => {};
  onReauthenticate: () => void = (): void => {};

  @Builder
  private ComposerContext(): void {
    Row({ space: 8 }) {
      SymbolGlyph(this.presentation.mode === ForumComposerMode.REPLY
        ? $r('sys.symbol.message')
        : $r('sys.symbol.square_and_pencil'))
        .fontSize(18)
        .fontColor(['#317AF7'])
      Column({ space: 2 }) {
        Text(this.presentation.contextTitle)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
        Text(this.presentation.contextDescription)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(this.presentation.contextBadge)
        .fontSize(11)
        .fontColor('#2068C9')
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor('#EAF2FF')
        .borderRadius(12)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F5F7FA')
    .borderRadius(12)
  }

  @Builder
  private PlaceholderTools(): void {
    Row({ space: 10 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.ohos_photo'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width(40)
      .height(40)
      .enabled(false)
      .backgroundColor('#F5F6F8')
      .accessibilityText('图片，未实现')
      Button() {
        Text('@')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width(40)
      .height(40)
      .enabled(false)
      .backgroundColor('#F5F6F8')
      .accessibilityText('@ 提及，未实现')
      Text('图片 / @ · 未实现')
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
    }
  }

  @Builder
  private StatusMessage(): void {
    if (this.presentation.message.length > 0) {
      Text(this.presentation.message)
        .fontSize(12)
        .fontColor(
          this.presentation.status === ForumComposerStatus.ERROR || this.presentation.needsAuthentication()
            ? $r('sys.color.font_emphasize')
            : $r('sys.color.font_secondary')
        )
        .width('100%')
    }
  }

  @Builder
  private PrimaryAction(): void {
    if (this.presentation.needsAuthentication()) {
      Button('重新登录后继续')
        .width('100%')
        .height(48)
        .onClick(this.onReauthenticate)
        .accessibilityText('重新登录并保留编辑器草稿')
    } else {
      Button(this.presentation.submitLabel())
        .width('100%')
        .height(48)
        .enabled(this.presentation.canSubmit())
        .onClick(this.onSubmit)
        .accessibilityText(this.presentation.status === ForumComposerStatus.ERROR
          ? '再次确认后显式重试发布'
          : this.presentation.submitLabel())
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.ComposerContext()
        if (this.presentation.showsTitleInput) {
          TextInput({
            text: this.presentation.titleDraft,
            placeholder: this.presentation.titlePlaceholder
          })
            .height(44)
            .enabled(!this.presentation.isBusy())
            .backgroundColor('#F5F6F8')
            .onChange((value: string): void => this.onTitleChange(value))
            .accessibilityText('Topic 标题')
        }
        TextArea({
          text: this.presentation.bodyDraft,
          placeholder: this.presentation.bodyPlaceholder
        })
          .height(150)
          .enabled(!this.presentation.isBusy())
          .backgroundColor('#F5F6F8')
          .borderRadius(10)
          .onChange((value: string): void => this.onBodyChange(value))
          .accessibilityText(this.presentation.mode === ForumComposerMode.REPLY ? 'Reply 内容' : 'Topic 正文')
        Row() {
          Text(`${this.presentation.characterCount()} 字符 · 草稿仅保存在本次运行内存中`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .layoutWeight(1)
          this.PlaceholderTools()
        }
        .width('100%')
        this.StatusMessage()
        this.PrimaryAction()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
  }
}
