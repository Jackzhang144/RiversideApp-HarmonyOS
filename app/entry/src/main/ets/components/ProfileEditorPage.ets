import { MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';
import { UserEmailInfo, UserProfile } from '../models/ProfileModels';

@Component
export struct ProfileEditorPage {
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
  private Field(label: string, value: string, onChange: (value: string) => void, multiline: boolean = false): void {
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
    Scroll() {
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Button('更换头像', { type: ButtonType.Normal })
            .layoutWeight(1)
            .enabled(!this.busy)
            .onClick(this.onSelectAvatar)
          Button('更换背景图', { type: ButtonType.Normal })
            .layoutWeight(1)
            .enabled(!this.busy && this.profile?.canUploadProfileBackground === true)
            .onClick(this.onSelectBackground)
        }
        .width('100%')
        if (this.mediaState !== null) {
          Text(this.mediaState.kind === MediaUploadStateKind.UPLOADING
            ? `上传中 ${this.mediaState.progressPercent}%`
            : this.mediaState.message)
            .fontSize(12)
            .fontColor(this.mediaState.kind === MediaUploadStateKind.FAILED ? '#C62828' : '#52606D')
            .width('100%')
        }
        this.Field('姓名', this.nameValue, (value: string): void => { this.nameValue = value; })
        this.Field('头衔', this.titleValue, (value: string): void => { this.titleValue = value; })
        this.Field('个人简介', this.bioValue, (value: string): void => { this.bioValue = value; }, true)
        this.Field('所在地', this.locationValue, (value: string): void => { this.locationValue = value; })
        if (this.emails !== null) {
          Column({ space: 7 }) {
            Text('邮箱（只读）').fontSize(14).fontWeight(FontWeight.Bold).width('100%')
            ForEach(this.emails.allEmails(), (email: string): void => {
              Text(email).fontSize(13).fontColor('#52606D').width('100%')
            }, (email: string): string => email)
            Text('新增、移除、重发与确认邮箱暂不开放。')
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#F4F5F7')
          .borderRadius(12)
        }
        if (this.message.length > 0) {
          Text(this.message).fontSize(12).fontColor('#C62828').width('100%')
        }
        Button('保存资料', { type: ButtonType.Normal })
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
    .backgroundColor('#FFFFFF')
  }
}
