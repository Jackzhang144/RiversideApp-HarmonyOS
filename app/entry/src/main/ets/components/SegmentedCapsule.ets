export class SegmentedCapsuleItem {
  public readonly id: string;
  public readonly label: string;
  public readonly icon: Resource;

  public constructor(id: string, label: string, icon: Resource) {
    this.id = id;
    this.label = label;
    this.icon = icon;
  }
}

@Component
export struct SegmentedCapsule {
  @Require @Prop items: Array<SegmentedCapsuleItem>;
  @Require @Prop selectedId: string;
  onSelect: (id: string) => void = (_id: string): void => {};

  @Builder
  private Segment(item: SegmentedCapsuleItem): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 7 }) {
        SymbolGlyph(item.icon)
          .fontSize(17)
          .fontColor([
            this.selectedId === item.id
              ? $r('app.color.brand_selected_text')
              : $r('sys.color.font_secondary')
          ])
        Text(item.label)
          .fontSize(13)
          .fontWeight(this.selectedId === item.id ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(
            this.selectedId === item.id
              ? $r('app.color.brand_selected_text')
              : $r('sys.color.font_primary')
          )
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .hitTestBehavior(HitTestMode.None)
    }
    .layoutWeight(1)
    .height(38)
    .padding({ left: 6, right: 6 })
    .borderRadius(19)
    .backgroundColor(
      this.selectedId === item.id
        ? $r('app.color.brand_selected_surface')
        : Color.Transparent
    )
    .animation({ duration: 190, curve: Curve.EaseOut })
    .onClick((): void => this.onSelect(item.id))
    .accessibilityText(`${item.label}${this.selectedId === item.id ? '，已选择' : ''}`)
  }

  build() {
    Row({ space: 3 }) {
      ForEach(this.items, (item: SegmentedCapsuleItem): void => {
        this.Segment(item)
      }, (item: SegmentedCapsuleItem): string => item.id)
    }
    .width('100%')
    .height(46)
    .padding(4)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(23)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .clip(true)
  }
}
