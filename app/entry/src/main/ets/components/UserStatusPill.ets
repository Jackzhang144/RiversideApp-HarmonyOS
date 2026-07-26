import { DiscourseUserStatus } from '../models/DiscourseUserStatus';

@Component
export struct UserStatusPill {
  @Require @Prop status: DiscourseUserStatus;
  @State emojiFailed: boolean = false;

  build() {
    Row({ space: 5 }) {
      if (this.status.emojiUrl().length > 0 && !this.emojiFailed) {
        Image(this.status.emojiUrl())
          .width(14)
          .height(14)
          .objectFit(ImageFit.Contain)
          .onError((): void => {
            this.emojiFailed = true;
          })
      } else {
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(13)
          .fontColor([$r('app.color.brand_primary')])
      }
      Text(this.status.description)
        .fontSize(11)
        .fontColor($r('app.color.brand_selected_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .padding({ left: 7, right: 8 })
    .backgroundColor($r('app.color.brand_tint_surface'))
    .borderRadius(12)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityText(`用户状态：${this.status.description}`)
  }
}
