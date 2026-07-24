import { window } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { AppSystemBarPalette } from '../settings/AppThemeSettings';
import { ImmersiveFloatingHeader } from './ImmersiveFloatingHeader';

export enum PageSurface {
  STANDARD = 'standard',
  MEDIA = 'media'
}

class NavigationChrome {
  public static statusBarStyle(darkMode: boolean, surface: PageSurface): window.SystemBarStyle {
    const lightContent: boolean = darkMode || surface === PageSurface.MEDIA;
    return {
      statusBarContentColor: lightContent
        ? AppSystemBarPalette.darkContent
        : AppSystemBarPalette.lightStatusContent
    };
  }

  public static titleBar(
    stackBuilder: () => void,
    surface: PageSurface,
    backLabel: ResourceStr | null = null
  ): HdsNavigationTitleBarOptions {
    const backgroundColor: ResourceColor = surface === PageSurface.MEDIA
      ? $r('app.color.image_viewer_surface')
      : $r('sys.color.background_secondary');
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      content: {
        title: { mainTitle: '' },
        backIcon: backLabel === null ? undefined : { label: backLabel },
        stackBuilder
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor,
            maskExtraHeight: 32,
            blurRadius: 16
          },
          contentStyle: {
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.font_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor,
            maskExtraHeight: 32,
            blurRadius: 16
          },
          contentStyle: {
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.font_primary')
            }
          }
        }
      }
    };
  }

  public static pageBackground(surface: PageSurface): ResourceColor {
    return surface === PageSurface.MEDIA
      ? $r('app.color.image_viewer_surface')
      : $r('sys.color.background_secondary');
  }
}

@Component
export struct RootPageShell {
  pathStack: NavPathStack = new NavPathStack();
  scrollables: Array<Scroller> = [];
  @Prop darkMode: boolean = false;

  @Builder
  private emptyContent(): void {
  }

  @Builder
  private emptyDestination(_name: string, _param: Object): void {
  }

  @BuilderParam header: () => void = this.emptyContent;
  @BuilderParam content: () => void = this.emptyContent;
  @BuilderParam destination: (name: string, param: Object) => void = this.emptyDestination;

  @Builder
  private destinationBuilder(name: string, param: Object): void {
    this.destination(name, param);
  }

  build() {
    HdsNavigation(this.pathStack) {
      this.content()
    }
    .titleBar(NavigationChrome.titleBar(
      (): void => {
        this.header();
      },
      PageSurface.STANDARD
    ))
    .systemBarStyle(
      NavigationChrome.statusBarStyle(this.darkMode, PageSurface.STANDARD),
      NavigationChrome.statusBarStyle(this.darkMode, PageSurface.STANDARD)
    )
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideTitleBar(false)
    .hideBackButton(true)
    .navDestination(this.destinationBuilder)
    .bindToScrollable(this.scrollables)
    .width('100%')
    .height('100%')
    .backgroundColor(NavigationChrome.pageBackground(PageSurface.STANDARD))
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}

@Component
export struct DestinationPageShell {
  @Prop title: ResourceStr = '';
  @Prop backLabel: ResourceStr = '';
  @Prop darkMode: boolean = false;
  @Prop surface: PageSurface = PageSurface.STANDARD;
  scrollables: Array<Scroller> = [];
  onBackPressed: () => boolean = (): boolean => false;
  onShown: () => void = (): void => {};
  onHidden: () => void = (): void => {};

  @Builder
  private emptyContent(): void {
  }

  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  private header(): void {
    ImmersiveFloatingHeader({
      title: this.title,
      leadingInset: 48
    })
  }

  build() {
    HdsNavDestination() {
      this.content()
    }
    .titleBar(NavigationChrome.titleBar(
      (): void => {
        this.header();
      },
      this.surface,
      this.backLabel
    ))
    .systemBarStyle(
      NavigationChrome.statusBarStyle(this.darkMode, this.surface),
      NavigationChrome.statusBarStyle(this.darkMode, this.surface)
    )
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable(this.scrollables)
    .backgroundColor(NavigationChrome.pageBackground(this.surface))
    .onShown(this.onShown)
    .onHidden(this.onHidden)
    .onBackPressed(this.onBackPressed)
  }
}
