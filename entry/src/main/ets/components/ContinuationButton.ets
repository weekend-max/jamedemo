/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { ContinuationManager } from '../utils/ContinuationManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { continuationManager } from '@kit.AbilityKit';

const DOMAIN = 0x0000;
const TAG = 'ContinuationButton';

/**
 * 流转UI组件
 * 提供流转图标按钮和设备选择面板
 */
@Component
export struct ContinuationButton {
  @State isPanelVisible: boolean = false;
  @State selectedDevices: Array<continuationManager.ContinuationResult> = [];
  @State isRegistering: boolean = false;

  private continuationManager: ContinuationManager = ContinuationManager.getInstance();

  aboutToAppear(): void {
    this.initializeContinuation();
  }

  aboutToDisappear(): void {
    this.continuationManager.release();
  }

  /**
   * 初始化流转功能
   */
  private async initializeContinuation(): Promise<void> {
    this.isRegistering = true;
    const token = await this.continuationManager.register();
    this.isRegistering = false;
    
    if (token !== -1) {
      // 注册设备选择监听
      this.continuationManager.onDeviceSelected((devices: Array<continuationManager.ContinuationResult>) => {
        hilog.info(DOMAIN, TAG, 'Devices selected: %{public}d', devices.length);
        this.selectedDevices = devices;
        this.isPanelVisible = false;
      });
      
      hilog.info(DOMAIN, TAG, 'Continuation initialized successfully');
    } else {
      hilog.error(DOMAIN, TAG, 'Failed to initialize continuation');
    }
  }

  build() {
    Stack() {
      // 流转图标按钮
      Button() {
        Row() {
          // 使用系统流转图标
          SymbolGlyph($r('sys.symbol.share'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_on_primary')])
        }
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor($r('sys.color.background_emphasize'))
      .enabled(!this.isRegistering)
      .onClick(() => {
        this.showDeviceManager();
      })

      // 流转面板
      if (this.isPanelVisible) {
        this.buildContinuationPanel();
      }
    }
  }

  /**
   * 显示设备管理器
   */
  private async showDeviceManager(): Promise<void> {
    await this.continuationManager.showDeviceManager();
  }

  /**
   * 构建流转面板
   */
  @Builder
  buildContinuationPanel() {
    Column() {
      // 标题栏
      Row() {
        Text('流转到其他设备')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.isPanelVisible = false;
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })

      Divider().color($r('sys.color.font_secondary'))

      // 设备列表
      if (this.selectedDevices.length === 0) {
        // 无设备状态
        Column() {
          SymbolGlyph($r('sys.symbol.share'))
            .fontSize(48)
            .fontColor([$r('sys.color.font_secondary')])

          Text('未发现可流转设备')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 12 })

          Text('请确保其他设备已登录同一华为账号\n并开启Wi-Fi和蓝牙')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else {
        // 设备列表
        List() {
          ForEach(this.selectedDevices, (device: continuationManager.ContinuationResult) => {
            ListItem() {
              this.buildDeviceItem(device);
            }
          }, (device: continuationManager.ContinuationResult) => device.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
      }

      // 底部提示
      Column() {
        Text('提示：流转需要双端登录同一华为账号')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('sys.color.background_secondary'))
    }
    .width('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .borderRadius(16)
    .shadow({
      radius: 20,
      color: 'rgba(0, 0, 0, 0.3)',
      offsetX: 0,
      offsetY: -5
    })
  }

  /**
   * 构建设备列表项
   */
  @Builder
  buildDeviceItem(device: continuationManager.ContinuationResult) {
    Row() {
      // 设备图标
      SymbolGlyph($r('sys.symbol.share'))
        .fontSize(24)
        .fontColor([$r('sys.color.font_primary')])
        .margin({ right: 12 })

      // 设备信息
      Column() {
        Text(device.name ?? '未知设备')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Text(`设备ID: ${device.id?.substring(0, 8)}...`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 状态指示
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(20)
        .fontColor([$r('sys.color.font_primary')])
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(8)
    .margin({ bottom: 8 })
  }
}
