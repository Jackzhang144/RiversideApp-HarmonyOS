/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AbilityContextRegistry } from '../core/AbilityContextRegistry';
import { SystemNotificationService } from '../core/SystemNotificationService';
import {
  AppSystemBarPalette,
  AppThemeMode,
  appThemePlatformColorMode
} from '../settings/AppThemeSettings';
import { PreferencesAppThemeSettingsStore } from '../settings/PreferencesAppThemeSettingsStore';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private themeRestore: Promise<void> = Promise.resolve();
  private restoredThemeMode: AppThemeMode = AppThemeMode.SYSTEM;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AbilityContextRegistry.initialize(this.context);
    SystemNotificationService.initialize(this.context);
    this.themeRestore = this.restoreThemeMode();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private async restoreThemeMode(): Promise<void> {
    try {
      const store: PreferencesAppThemeSettingsStore = new PreferencesAppThemeSettingsStore(this.context);
      this.restoredThemeMode = await store.read();
      this.context.getApplicationContext().setColorMode(appThemePlatformColorMode(this.restoredThemeMode));
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    AbilityContextRegistry.clear();
    SystemNotificationService.clear();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.loadContentAfterThemeRestore(windowStage);
  }

  private async loadContentAfterThemeRestore(windowStage: window.WindowStage): Promise<void> {
    await this.themeRestore;
    windowStage.loadContent('pages/Index', async (err): Promise<void> => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      try {
        const mainWindow: window.Window = windowStage.getMainWindowSync();
        await mainWindow.setWindowLayoutFullScreen(true);
        const systemDark: boolean = this.context.config.colorMode ===
          ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        const dark: boolean = this.restoredThemeMode === AppThemeMode.DARK ||
          (this.restoredThemeMode === AppThemeMode.SYSTEM && systemDark);
        const systemBarProperties: window.SystemBarProperties = {
          statusBarColor: dark
            ? AppSystemBarPalette.transparent
            : AppSystemBarPalette.lightContentBackground,
          navigationBarColor: AppSystemBarPalette.transparent,
          statusBarContentColor: dark
            ? AppSystemBarPalette.darkContent
            : AppSystemBarPalette.lightStatusContent,
          navigationBarContentColor: dark
            ? AppSystemBarPalette.darkContent
            : AppSystemBarPalette.lightNavigationContent
        };
        await mainWindow.setWindowSystemBarProperties(systemBarProperties);
        hilog.info(DOMAIN, 'testTag', 'Succeeded in enabling immersive main-window layout.');
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'Failed to configure the main window. Cause: %{public}s', JSON.stringify(err));
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
