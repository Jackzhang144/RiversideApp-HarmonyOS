import {
  ForumComposerMode,
  ForumComposerPresentation,
  ForumComposerStatus
} from './ForumComposerPresentation';
import {
  applyComposerTool,
  ComposerEdit,
  ComposerTool,
  insertComposerText
} from '../models/AuthoringModels';

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
  onSaveDraft: () => void = (): void => {};
  onDiscard: () => void = (): void => {};
  onReauthenticate: () => void = (): void => {};
  private readonly bodyController: TextAreaController = new TextAreaController();
  private selectionStart: number = 0;
  private selectionEnd: number = 0;

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

  private applyTool(tool: ComposerTool): void {
    const edit: ComposerEdit = applyComposerTool(
      this.presentation.bodyDraft,
      this.selectionStart,
      this.selectionEnd,
      tool
    );
    this.applyEdit(edit);
  }

  private insertText(text: string): void {
    this.applyEdit(insertComposerText(
      this.presentation.bodyDraft,
      this.selectionStart,
      this.selectionEnd,
      text
    ));
  }

  private applyEdit(edit: ComposerEdit): void {
    this.selectionStart = edit.selectionStart;
    this.selectionEnd = edit.selectionEnd;
    this.onBodyChange(edit.text);
    setTimeout((): void => {
      this.bodyController.setTextSelection(edit.selectionStart, edit.selectionEnd);
    }, 0);
  }

  @Builder
  private ToolButton(label: string, tool: ComposerTool, accessibilityText: string): void {
    Button(label)
      .height(34)
      .fontSize(12)
      .enabled(!this.presentation.isBusy())
      .backgroundColor('#EAF2FF')
      .fontColor('#2068C9')
      .margin({ right: 7, bottom: 7 })
      .onClick((): void => this.applyTool(tool))
      .accessibilityText(accessibilityText)
  }

  @Builder
  private ComposerTools(): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      this.ToolButton('B', ComposerTool.BOLD, '粗体')
      this.ToolButton('I', ComposerTool.ITALIC, '斜体')
      this.ToolButton('H1', ComposerTool.HEADING_1, '一级标题')
      this.ToolButton('H2', ComposerTool.HEADING_2, '二级标题')
      this.ToolButton('H3', ComposerTool.HEADING_3, '三级标题')
      this.ToolButton('链接', ComposerTool.LINK, '插入链接')
      this.ToolButton('引用', ComposerTool.QUOTE, '块引用')
      this.ToolButton('代码', ComposerTool.CODE_BLOCK, '代码块')
      this.ToolButton('• 列表', ComposerTool.BULLET_LIST, '无序列表')
      this.ToolButton('1. 列表', ComposerTool.ORDERED_LIST, '有序列表')
      this.ToolButton('单选投票', ComposerTool.POLL_SINGLE, '插入单选投票模板')
      this.ToolButton('多选投票', ComposerTool.POLL_MULTIPLE, '插入多选投票模板')
      Button('😀')
        .height(34)
        .fontSize(16)
        .enabled(!this.presentation.isBusy())
        .backgroundColor('#EAF2FF')
        .margin({ right: 7, bottom: 7 })
        .onClick((): void => this.insertText('😀'))
        .accessibilityText('插入 Emoji')
      Button() {
        SymbolGlyph($r('sys.symbol.ohos_photo'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width(42)
      .height(34)
      .enabled(this.presentation.imageActionAvailable)
      .backgroundColor('#F5F6F8')
      .margin({ right: 7, bottom: 7 })
      .accessibilityText(this.presentation.imageActionAccessibilityText)
    }
    .width('100%')
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

  @Builder
  private DraftActions(): void {
    if (this.presentation.showsDraftActions) {
      Row({ space: 10 }) {
        Button('保存草稿')
          .layoutWeight(1)
          .height(42)
          .enabled(!this.presentation.isBusy())
          .backgroundColor('#EAF2FF')
          .fontColor('#2068C9')
          .onClick(this.onSaveDraft)
          .accessibilityText('保存服务端草稿')
        Button('舍弃')
          .layoutWeight(1)
          .height(42)
          .enabled(!this.presentation.isBusy())
          .backgroundColor('#F5F6F8')
          .fontColor('#C62828')
          .onClick(this.onDiscard)
          .accessibilityText('舍弃草稿并关闭编辑器')
      }
      .width('100%')
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
          placeholder: this.presentation.bodyPlaceholder,
          controller: this.bodyController
        })
          .height(190)
          .enabled(!this.presentation.isBusy())
          .backgroundColor('#F5F6F8')
          .borderRadius(10)
          .onChange((value: string): void => this.onBodyChange(value))
          .onTextSelectionChange((selectionStart: number, selectionEnd: number): void => {
            this.selectionStart = selectionStart;
            this.selectionEnd = selectionEnd;
          })
          .accessibilityText(
            this.presentation.mode === ForumComposerMode.REPLY ||
            this.presentation.mode === ForumComposerMode.EDIT_POST
              ? 'Reply 内容'
              : 'Topic 正文'
          )
        Text(`${this.presentation.characterCount()} 字符 · 支持 Markdown 与服务端草稿`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
        this.ComposerTools()
        Row() {
          Text('图片上传将在媒体切片接入')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        this.StatusMessage()
        this.DraftActions()
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
