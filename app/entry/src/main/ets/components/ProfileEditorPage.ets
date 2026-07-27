import { MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';
import { UserEmailInfo, UserProfile } from '../models/ProfileModels';
import { canClearProfileBackground } from './ProfileEditorPresentation';

@Component
export struct ProfileEditorPage {
  scroller: Scroller = new Scroller();
  @Prop profile: UserProfile | null = null;
  @Prop emails: UserEmailInfo | null = null;
  @Prop mediaState: MediaUploadState | null = null;
  @Prop busy: boolean = false;
  @Prop message: string = '';
  @State nameValue: string = '';
  @State titleValue: string = '';
  @State bioValue: string = '';
  @State locationValue: string = '';
  onSave: (name: string, title: string, bio: string, location: string) => void = (): void => {};
  onSelectAvatar: () => void = (): void => {};
  onSelectBackground: () => void = (): void => {};
  onClearBackground: () => void = (): void => {};

  aboutToAppear(): void {
    const profile: UserProfile | null = this.profile;
    if (profile !== null) {
      this.nameValue = profile.name;
      this.titleValue = profile.title;
      this.bioValue = profile.bioRaw;
      this.locationValue = profile.location;
    }
  }

  @Builder
  private SectionHeader(icon: Resource, title: ResourceStr, subtitle: ResourceStr): void {
    Row({ space: 10 }) {
      Stack() {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(34)
      .height(34)
      .borderRadius(11)
      .backgroundColor($r('app.color.brand_tint_surface'))
      Column({ space: 2 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text(subtitle)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private MediaAction(
    icon: Resource,
    label: ResourceStr,
    enabled: boolean,
    action: () => void
  ): void {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: 7 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([$r('app.color.brand_primary')])
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
      }
    }
    .layoutWeight(1)
    .height(48)
    .enabled(enabled)
    .backgroundColor($r('app.color.brand_tint_surface'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick(action)
  }

  @Builder
  private SingleLineField(
    label: ResourceStr,
    value: string,
    onChange: (value: string) => void
  ): void {
    Column({ space: 7 }) {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      TextInput({ text: value, placeholder: label })
        .height(46)
        .fontSize(14)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .borderRadius(14)
        .onChange(onChange)
    }
    .width('100%')
  }

  @Builder
  private MultilineField(
    label: ResourceStr,
    value: string,
    onChange: (value: string) => void
  ): void {
    Column({ space: 7 }) {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      TextArea({ text: value, placeholder: label })
        .height(112)
        .fontSize(14)
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .borderRadius(14)
        .onChange(onChange)
    }
    .width('100%')
  }

  @Builder
  private MediaCard(): void {
    Column({ space: 12 }) {
      this.SectionHeader(
        $r('sys.symbol.person_crop_circle_fill_1'),
        '个人形象',
        '管理头像和个人页背景'
      )
      Row({ space: 10 }) {
        this.MediaAction(
          $r('sys.symbol.person_crop_circle_fill_1'),
          $r('app.string.profile_edit_change_avatar'),
          !this.busy,
          this.onSelectAvatar
        )
        this.MediaAction(
          $r('sys.symbol.ohos_photo'),
          $r('app.string.profile_edit_change_background'),
          !this.busy && this.profile?.canUploadProfileBackground === true,
          this.onSelectBackground
        )
      }
      .width('100%')
      if (canClearProfileBackground(this.profile)) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 7 }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(17)
              .fontColor([$r('app.color.status_error')])
            Text($r('app.string.profile_edit_clear_background'))
              .fontSize(13)
              .fontColor($r('app.color.status_error'))
          }
        }
        .width('100%')
        .height(40)
        .enabled(!this.busy)
        .backgroundColor(Color.Transparent)
        .borderRadius(12)
        .onClick(this.onClearBackground)
        .accessibilityText($r('app.string.profile_edit_clear_background_accessibility'))
      }
      if (this.mediaState !== null) {
        Text(this.mediaState.kind === MediaUploadStateKind.UPLOADING
          ? `上传中 ${this.mediaState.progressPercent}%`
          : this.mediaState.message)
          .fontSize(12)
          .fontColor(this.mediaState.kind === MediaUploadStateKind.FAILED
            ? $r('app.color.status_error')
            : $r('sys.color.font_secondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private DetailsCard(): void {
    Column({ space: 14 }) {
      this.SectionHeader(
        $r('sys.symbol.person_text_rectangle'),
        '基础资料',
        '这些内容会展示在你的个人页'
      )
      this.SingleLineField(
        $r('app.string.profile_edit_name'),
        this.nameValue,
        (value: string): void => { this.nameValue = value; }
      )
      this.SingleLineField(
        $r('app.string.profile_edit_title'),
        this.titleValue,
        (value: string): void => { this.titleValue = value; }
      )
      this.MultilineField(
        $r('app.string.profile_edit_bio'),
        this.bioValue,
        (value: string): void => { this.bioValue = value; }
      )
      this.SingleLineField(
        $r('app.string.profile_edit_location'),
        this.locationValue,
        (value: string): void => { this.locationValue = value; }
      )
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private EmailCard(): void {
    if (this.emails !== null) {
      Column({ space: 10 }) {
        this.SectionHeader(
          $r('sys.symbol.envelope'),
          $r('app.string.profile_edit_email_readonly'),
          $r('app.string.profile_edit_email_unavailable')
        )
        ForEach(this.emails.allEmails(), (email: string): void => {
          Text(email)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
        }, (email: string): string => email)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        this.MediaCard()
        this.DetailsCard()
        this.EmailCard()
        if (this.message.length > 0) {
          Text(this.message).fontSize(12).fontColor($r('app.color.status_error')).width('100%')
        }
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(18)
              .fontColor([Color.White])
            Text($r('app.string.profile_edit_save'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(46)
        .enabled(!this.busy && this.profile !== null)
        .backgroundColor($r('app.color.brand_primary'))
        .borderRadius(15)
        .onClick((): void => this.onSave(
          this.nameValue,
          this.titleValue,
          this.bioValue,
          this.locationValue
        ))
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 12, right: 12, top: 12, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
