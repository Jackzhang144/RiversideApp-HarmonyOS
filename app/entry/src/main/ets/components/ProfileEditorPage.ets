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
  private Field(label: ResourceStr, value: string, onChange: (value: string) => void, multiline: boolean = false): void {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontWeight(FontWeight.Medium).width('100%')
      TextArea({ text: value, placeholder: label })
        .height(multiline ? 112 : 48)
        .fontSize(14)
        .onChange(onChange)
    }
    .width('100%')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Button($r('app.string.profile_edit_change_avatar'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .enabled(!this.busy)
            .onClick(this.onSelectAvatar)
          Button($r('app.string.profile_edit_change_background'), { type: ButtonType.Normal })
            .layoutWeight(1)
            .enabled(!this.busy && this.profile?.canUploadProfileBackground === true)
            .onClick(this.onSelectBackground)
        }
        .width('100%')
        if (canClearProfileBackground(this.profile)) {
          Button($r('app.string.profile_edit_clear_background'), { type: ButtonType.Normal })
            .width('100%')
            .enabled(!this.busy)
            .fontColor($r('app.color.status_error'))
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
        this.Field($r('app.string.profile_edit_name'), this.nameValue,
          (value: string): void => { this.nameValue = value; })
        this.Field($r('app.string.profile_edit_title'), this.titleValue,
          (value: string): void => { this.titleValue = value; })
        this.Field($r('app.string.profile_edit_bio'), this.bioValue,
          (value: string): void => { this.bioValue = value; }, true)
        this.Field($r('app.string.profile_edit_location'), this.locationValue,
          (value: string): void => { this.locationValue = value; })
        if (this.emails !== null) {
          Column({ space: 7 }) {
            Text($r('app.string.profile_edit_email_readonly')).fontSize(14).fontWeight(FontWeight.Bold).width('100%')
            ForEach(this.emails.allEmails(), (email: string): void => {
              Text(email).fontSize(13).fontColor($r('sys.color.font_secondary')).width('100%')
            }, (email: string): string => email)
            Text($r('app.string.profile_edit_email_unavailable'))
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
          }
          .width('100%')
          .padding($r('app.float.card_content_padding'))
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius($r('app.float.card_corner_radius'))
        }
        if (this.message.length > 0) {
          Text(this.message).fontSize(12).fontColor($r('app.color.status_error')).width('100%')
        }
        Button($r('app.string.profile_edit_save'), { type: ButtonType.Normal })
          .width('100%')
          .height(46)
          .enabled(!this.busy && this.profile !== null)
          .onClick((): void => this.onSave(
            this.nameValue,
            this.titleValue,
            this.bioValue,
            this.locationValue
          ))
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor($r('sys.color.comp_background_primary'))
  }
}
