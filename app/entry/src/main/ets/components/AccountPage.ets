import { AuthState, AuthStateKind } from '../auth/AuthRepository';
import { UserProfile } from '../models/ProfileModels';
import {
  AccountPlaceholder,
  AccountPlaceholderKind,
  AccountPlaceholderSection,
  AccountPresentation,
  AccountPrimaryAction,
  accountPresentationFor
} from './AccountPresentation';

@Component
export struct AccountPage {
  @Prop state: AuthState = AuthState.idle();
  @Prop identity: UserProfile | null = null;
  @Prop identityLoading: boolean = false;
  @Prop identityError: string = '';
  onLogin: () => void = (): void => {};
  onLogout: () => void = (): void => {};
  onRetryIdentity: () => void = (): void => {};
  onOpenPlaceholder: (kind: AccountPlaceholderKind) => void = (): void => {};
  onOpenUiPrototype: () => void = (): void => {};

  private placeholderIcon(kind: AccountPlaceholderKind): Resource {
    if (kind === AccountPlaceholderKind.PERSONAL_INFORMATION) {
      return $r('sys.symbol.person_text_rectangle');
    }
    if (kind === AccountPlaceholderKind.RSC_WALLET) {
      return $r('sys.symbol.wallet');
    }
    if (kind === AccountPlaceholderKind.MY_TOPICS) {
      return $r('sys.symbol.folder');
    }
    if (kind === AccountPlaceholderKind.MY_REPLIES) {
      return $r('sys.symbol.message');
    }
    if (kind === AccountPlaceholderKind.MY_DRAFTS) {
      return $r('sys.symbol.doc_plaintext_and_pencil');
    }
    if (kind === AccountPlaceholderKind.MY_BOOKMARKS) {
      return $r('sys.symbol.bookmark');
    }
    if (kind === AccountPlaceholderKind.APP_SETTINGS) {
      return $r('sys.symbol.gearshape');
    }
    return $r('sys.symbol.info_circle');
  }

  @Builder
  private AccountHeader(presentation: AccountPresentation): void {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
            .fontSize(42)
            .fontColor([$r('app.color.brand_primary')])
          if (presentation.avatarUrl.length > 0) {
            Image(presentation.avatarUrl)
              .width(64)
              .height(64)
              .borderRadius(32)
              .objectFit(ImageFit.Cover)
          }
        }
        .width(64)
        .height(64)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(32)

        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(presentation.title)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            if (presentation.busy) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color($r('app.color.brand_primary'))
            }
          }
          Text(presentation.detail)
            .fontSize(13)
            .fontColor(presentation.error ? $r('app.color.status_error') : $r('sys.color.font_secondary'))
            .lineHeight(19)
          if (presentation.capabilityDetail.length > 0) {
            Text(presentation.capabilityDetail)
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .lineHeight(18)
          }
          if (this.state.kind === AuthStateKind.AUTHENTICATED && this.identityError.length > 0) {
            Button('重新加载身份', { type: ButtonType.Normal })
              .height(32)
              .fontSize(12)
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('app.color.brand_primary'))
              .onClick(this.onRetryIdentity)
              .accessibilityText('重新加载 RiverSide 身份')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (presentation.primaryAction === AccountPrimaryAction.LOGIN) {
        Button('登录并授权 RiverSide', { type: ButtonType.Normal })
          .width('100%')
          .height(44)
          .borderRadius($r('app.float.card_corner_radius'))
          .onClick(this.onLogin)
          .accessibilityText('登录并授权 RiverSide 账户')
      } else if (presentation.primaryAction === AccountPrimaryAction.LOGOUT) {
        Button('退出登录', { type: ButtonType.Normal })
          .width('100%')
          .height(44)
          .fontColor($r('app.color.status_error'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('sys.color.comp_divider') })
          .borderRadius($r('app.float.card_corner_radius'))
          .onClick(this.onLogout)
          .accessibilityText('退出 RiverSide 账户')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private PlaceholderRow(placeholder: AccountPlaceholder): void {
    Row({ space: 12 }) {
      SymbolGlyph(this.placeholderIcon(placeholder.kind))
        .fontSize(21)
        .fontColor([$r('sys.color.font_tertiary')])
      Text(placeholder.label)
        .fontSize(15)
        .fontColor(placeholder.available ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
        .layoutWeight(1)
      if (placeholder.available) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
      } else {
        Text('未实现')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(10)
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .opacity(placeholder.available ? 1 : 0.72)
    .enabled(placeholder.available)
    .onClick((): void => {
      if (placeholder.available) {
        this.onOpenPlaceholder(placeholder.kind);
      }
    })
    .accessibilityText(placeholder.accessibilityText)
  }

  @Builder
  private PlaceholderGroup(section: AccountPlaceholderSection): void {
    Column() {
      ForEach(section.placeholders, (placeholder: AccountPlaceholder, index: number) => {
        this.PlaceholderRow(placeholder)
        if (index < section.placeholders.length - 1) {
          Divider()
            .margin({ left: 52 })
            .color($r('sys.color.comp_divider'))
        }
      }, (placeholder: AccountPlaceholder): string => placeholder.kind)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private PrototypeCapsule(): void {
    Button('UI 原型', { type: ButtonType.Normal })
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.on_accent'))
      .backgroundColor($r('app.color.prototype_entry_surface'))
      .borderRadius(16)
      .height(32)
      .padding({ left: 16, right: 16 })
      .margin({ right: 12, bottom: 92 })
      .onClick(this.onOpenUiPrototype)
      .accessibilityText('打开原生 UI UX 设计原型')
  }

  @Builder
  private AccountContent(presentation: AccountPresentation): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column({ space: 12 }) {
          Text('我的')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
          this.AccountHeader(presentation)
          ForEach(presentation.placeholderSections, (section: AccountPlaceholderSection) => {
            this.PlaceholderGroup(section)
          }, (section: AccountPlaceholderSection): string => section.kind)
          Text('RiverSide')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 196 })
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)

      if (presentation.prototypeEntryVisible) {
        this.PrototypeCapsule()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    this.AccountContent(accountPresentationFor(
      this.state,
      this.identity,
      this.identityLoading,
      this.identityError
    ))
  }
}
