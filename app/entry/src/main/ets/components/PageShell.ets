import { window } from '@kit.ArkUI';
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  HideMode,
  ScrollEffectType,
  TextStyleMode,
  TitleBarContentOptions
} from '@kit.UIDesignKit';
import { AppSystemBarPalette } from '../settings/AppThemeSettings';

export enum PageSurface {
  STANDARD = 'standard',
  MEDIA = 'media'
}

export class NavigationChrome {
  public static statusBarStyle(darkMode: boolean, surface: PageSurface): window.SystemBarStyle {
    const lightContent: boolean = darkMode || surface === PageSurface.MEDIA;
    return {
      statusBarContentColor: lightContent
        ? AppSystemBarPalette.darkContent
        : AppSystemBarPalette.lightStatusContent
    };
  }

  public static rootTitleBar(
    content: TitleBarContentOptions,
    surface: PageSurface = PageSurface.STANDARD
  ): HdsNavigationTitleBarOptions {
    const backgroundColor: ResourceColor = surface === PageSurface.MEDIA
      ? $r('app.color.image_viewer_surface')
      : $r('sys.color.background_secondary');
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      content,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor,
            maskExtraHeight: 0,
            blurRadius: 12
          },
          contentStyle: {
            backIconStyle: {
              iconColor: $r('sys.color.font_primary')
            },
            subIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              textColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              textColor: $r('sys.color.font_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor,
            maskExtraHeight: 0,
            blurRadius: 12
          },
          contentStyle: {
            backIconStyle: {
              iconColor: $r('sys.color.font_primary')
            },
            subIconStyle: {
              iconColor: $r('sys.color.font_primary'),
              textColor: $r('sys.color.font_primary')
            },
            menuStyle: {
              iconColor: $r('sys.color.font_primary'),
              textColor: $r('sys.color.font_primary')
            }
          }
        }
      }
    };
  }

  public static destinationTitleBar(
    title: ResourceStr,
    surface: PageSurface,
    backLabel: ResourceStr
  ): HdsNavigationTitleBarOptions {
    const backgroundColor: ResourceColor = surface === PageSurface.MEDIA
      ? $r('app.color.image_viewer_surface')
      : $r('sys.color.background_secondary');
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      content: {
        title: { mainTitle: '' },
        backIcon: { label: backLabel },
        subIcon: {
          content: {
            label: title,
            type: TextStyleMode.NORMAL
          }
        }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor,
            maskExtraHeight: 0,
            blurRadius: 12
          },
          contentStyle: {
            backIconStyle: {
              iconColor: $r('sys.color.font_primary')
            },
            subIconStyle: {
              textColor: $r('sys.color.font_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor,
            maskExtraHeight: 0,
            blurRadius: 12
          },
          contentStyle: {
            backIconStyle: {
              iconColor: $r('sys.color.font_primary')
            },
            subIconStyle: {
              textColor: $r('sys.color.font_primary')
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
  @Prop hideBackButton: boolean = true;
  @Prop dynamicTitleBarOnScroll: boolean = false;
  @Prop titleBarRevision: string = '';
  titleBarOptions: () => HdsNavigationTitleBarOptions = (): HdsNavigationTitleBarOptions => {
    return NavigationChrome.rootTitleBar({
      title: { mainTitle: '' }
    });
  };

  @Builder
  private emptyContent(): void {
  }

  @Builder
  private emptyDestination(_name: string, _param: Object): void {
  }

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
    .titleBar(this.titleBarOptions())
    .systemBarStyle(
      NavigationChrome.statusBarStyle(this.darkMode, PageSurface.STANDARD),
      NavigationChrome.statusBarStyle(this.darkMode, PageSurface.STANDARD)
    )
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideTitleBar(false)
    .dynamicHideTitleBar({
      hideTitleArea: this.dynamicTitleBarOnScroll,
      hideStatusBar: this.dynamicTitleBarOnScroll,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1
    })
    .hideBackButton(this.hideBackButton)
    .navDestination(this.destinationBuilder)
    .bindToScrollable(this.scrollables)
    .id(`root-navigation-${this.titleBarRevision}`)
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
  @Prop dynamicTitleBarOnScroll: boolean = false;
  scrollables: Array<Scroller> = [];
  onBackPressed: () => boolean = (): boolean => false;
  onShown: () => void = (): void => {};
  onHidden: () => void = (): void => {};

  @Builder
  private emptyContent(): void {
  }

  @BuilderParam content: () => void = this.emptyContent;

  build() {
    HdsNavDestination() {
      this.content()
    }
    .titleBar(NavigationChrome.destinationTitleBar(
      this.title,
      this.surface,
      this.backLabel
    ))
    .systemBarStyle(
      NavigationChrome.statusBarStyle(this.darkMode, this.surface),
      NavigationChrome.statusBarStyle(this.darkMode, this.surface)
    )
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable(this.scrollables)
    .dynamicHideTitleBar({
      hideTitleArea: this.dynamicTitleBarOnScroll,
      hideStatusBar: this.dynamicTitleBarOnScroll,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1
    })
    .backgroundColor(NavigationChrome.pageBackground(this.surface))
    .onShown(this.onShown)
    .onHidden(this.onHidden)
    .onBackPressed(this.onBackPressed)
  }
}
