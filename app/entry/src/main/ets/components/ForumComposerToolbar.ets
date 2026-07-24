import { ComposerTool } from '../models/AuthoringModels';

interface PopupStateEvent {
  isVisible: boolean;
}

@Component
export struct ForumComposerToolbar {
  @Prop toolbarEnabled: boolean = true;
  @Prop imageEnabled: boolean = true;
  @Prop mentionEnabled: boolean = true;
  @State private moreToolsVisible: boolean = false;
  onToolSelected: (tool: ComposerTool) => void = (_tool: ComposerTool): void => {};
  onEmojiSelected: () => void = (): void => {};
  onImageSelected: () => void = (): void => {};
  onMentionSelected: () => void = (): void => {};

  private selectTool(tool: ComposerTool): void {
    this.moreToolsVisible = false;
    this.onToolSelected(tool);
  }

  @Builder
  private VectorToolButton(
    icon: Resource,
    accessibilityText: string,
    enabled: boolean,
    action: () => void
  ): void {
    Button() {
      Image(icon)
        .width(21)
        .height(21)
        .objectFit(ImageFit.Contain)
        .fillColor(enabled ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
    }
    .width(42)
    .height(42)
    .borderRadius(21)
    .backgroundColor(Color.Transparent)
    .enabled(enabled)
    .onClick(action)
    .accessibilityText(accessibilityText)
  }

  @Builder
  private SymbolToolButton(
    symbol: Resource,
    accessibilityText: string,
    enabled: boolean,
    action: () => void
  ): void {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(20)
        .fontColor([enabled ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary')])
    }
    .width(42)
    .height(42)
    .borderRadius(21)
    .backgroundColor(Color.Transparent)
    .enabled(enabled)
    .onClick(action)
    .accessibilityText(accessibilityText)
  }

  @Builder
  private CommonTools(): void {
    List({ space: 0 }) {
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_smile'),
          '打开 Emoji',
          this.toolbarEnabled,
          this.onEmojiSelected
        )
      }
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_bold'),
          '粗体',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.BOLD)
        )
      }
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_italic'),
          '斜体',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.ITALIC)
        )
      }
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_heading'),
          '二级标题',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.HEADING_2)
        )
      }
      ListItem() {
        this.SymbolToolButton(
          $r('sys.symbol.link'),
          '插入链接',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.LINK)
        )
      }
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_quote'),
          '块引用',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.QUOTE)
        )
      }
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_code'),
          '行内代码',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.INLINE_CODE)
        )
      }
      ListItem() {
        this.SymbolToolButton(
          $r('sys.symbol.ohos_photo'),
          '选择并上传图片',
          this.imageEnabled,
          this.onImageSelected
        )
      }
      ListItem() {
        this.VectorToolButton(
          $r('app.media.composer_bullet_list'),
          '无序列表',
          this.toolbarEnabled,
          (): void => this.selectTool(ComposerTool.BULLET_LIST)
        )
      }
      ListItem() {
        this.SymbolToolButton(
          $r('sys.symbol.at'),
          '插入用户提及',
          this.mentionEnabled,
          this.onMentionSelected
        )
      }
    }
    .width('100%')
    .height(46)
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private MoreToolRow(icon: Resource, label: string, tool: ComposerTool): void {
    Button() {
      Row({ space: 10 }) {
        Image(icon)
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
          .fillColor($r('sys.color.font_secondary'))
        Text(label)
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width('100%')
    }
    .width('100%')
    .height(42)
    .padding({ left: 8, right: 8 })
    .borderRadius(10)
    .backgroundColor(Color.Transparent)
    .enabled(this.toolbarEnabled)
    .onClick((): void => this.selectTool(tool))
    .accessibilityText(label)
  }

  @Builder
  private MoreToolsPopup(): void {
    Column({ space: 6 }) {
      Text('更多工具')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      List({ space: 0 }) {
        ListItem() {
          this.MoreToolRow($r('app.media.composer_heading'), '一级标题', ComposerTool.HEADING_1)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_heading'), '二级标题', ComposerTool.HEADING_2)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_heading'), '三级标题', ComposerTool.HEADING_3)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_heading'), '四级标题', ComposerTool.HEADING_4)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_code'), '代码块', ComposerTool.CODE_BLOCK)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_ordered_list'), '编号列表', ComposerTool.ORDERED_LIST)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_checklist'), '任务清单', ComposerTool.CHECKLIST)
        }
        ListItem() {
          this.MoreToolRow(
            $r('app.media.composer_checklist_done'),
            '已完成任务',
            ComposerTool.CHECKLIST_DONE
          )
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_spoiler'), '剧透', ComposerTool.SPOILER)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_bullet_list'), '目录', ComposerTool.TABLE_OF_CONTENTS)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_poll_single'), '单选投票', ComposerTool.POLL_SINGLE)
        }
        ListItem() {
          this.MoreToolRow(
            $r('app.media.composer_poll_multiple'),
            '多选投票',
            ComposerTool.POLL_MULTIPLE
          )
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_table'), '表格', ComposerTool.TABLE)
        }
        ListItem() {
          this.MoreToolRow($r('app.media.composer_math'), '公式', ComposerTool.MATH)
        }
      }
      .width('100%')
      .height(350)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width(238)
    .padding(8)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
  }

  build() {
    Row({ space: 0 }) {
      Stack() {
        this.CommonTools()
      }
        .height(46)
        .layoutWeight(1)
      Divider()
        .vertical(true)
        .height(26)
        .color($r('sys.color.comp_divider'))
      Button() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(22)
          .fontColor([
            this.moreToolsVisible ? $r('app.color.on_accent') : $r('sys.color.font_primary')
          ])
      }
      .width(44)
      .height(44)
      .margin({ left: 2, right: 2 })
      .borderRadius(22)
      .backgroundColor(
        this.moreToolsVisible ? $r('app.color.brand_primary') : Color.Transparent
      )
      .enabled(this.toolbarEnabled)
      .onClick((): void => {
        this.moreToolsVisible = !this.moreToolsVisible;
      })
      .accessibilityText(this.moreToolsVisible ? '关闭更多工具' : '打开更多工具')
      .bindPopup(this.moreToolsVisible, {
        builder: this.MoreToolsPopup,
        placement: Placement.Bottom,
        width: 254,
        radius: 18,
        enableArrow: true,
        arrowPointPosition: ArrowPointPosition.END,
        targetSpace: 6,
        mask: false,
        showInSubWindow: false,
        keyboardAvoidMode: KeyboardAvoidMode.DEFAULT,
        popupColor: $r('sys.color.comp_background_primary'),
        onStateChange: (event: PopupStateEvent): void => {
          if (!event.isVisible) {
            this.moreToolsVisible = false;
          }
        }
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: 2 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(24)
    .shadow(ShadowStyle.OUTER_DEFAULT_XS)
  }
}
