/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License,Version 2.0 (the "License");
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

import { CAROUSEL_DATA_SOURCE, FILTER_OPTIONS, FilterOption, ORIGINAL_MATRIX } from '../constants/CommonConstants';
import { router } from '@kit.ArkUI';
import { ContinuationButton } from '../components/ContinuationButton';

@Entry
@Component
struct Index {
  // Tracks the current index of the Swiper
  @State currentSwiperIndex: number = 0;
  // Stores the filter "tag" (value) for EACH image independently.
  @State imageFilterTags: Array<string> = [];

  // [Start aboutToAppear]
  aboutToAppear(): void {
    // 检查是否有流转恢复数据
    const continuationIndex = AppStorage.get<number>('continuation_currentIndex');
    const continuationTags = AppStorage.get<string[]>('continuation_filterTags');

    if (continuationIndex !== undefined && continuationTags !== undefined) {
      // 从流转数据恢复状态
      this.currentSwiperIndex = continuationIndex;
      this.imageFilterTags = continuationTags;

      // 清除流转数据，避免重复恢复
      AppStorage.delete('continuation_currentIndex');
      AppStorage.delete('continuation_filterTags');
    } else {
      // 正常启动：初始化所有图片为'original'滤镜
      this.imageFilterTags = new Array<string>(CAROUSEL_DATA_SOURCE.length).fill('original');
    }
  }

  // 页面即将消失时保存状态到AppStorage，供流转使用
  aboutToDisappear(): void {
    // 将当前状态同步到AppStorage，供流转时保存
    AppStorage.setOrCreate('currentSwiperIndex', this.currentSwiperIndex);
    AppStorage.setOrCreate('imageFilterTags', this.imageFilterTags);
  }
  // [End aboutToAppear]

  build() {
    Stack() {
      Column() {
        // Top Section: Image Carousel (Swiper)
        Column() {
          // [Start swiperUsagePosition]
          Swiper() {
            ForEach(CAROUSEL_DATA_SOURCE, (imgRes: Resource, index: number) => {
              // Container needed for individual scale animation
              Column() {
                // [Start imageUsagePosition]
                Image(imgRes)
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Contain)
                  .borderRadius(16)
                  // Apply the filter corresponding to THIS specific image index
                  .colorFilter(this.getFilterByTag(this.imageFilterTags[index]))
                // [End imageUsagePosition]
              }
              .justifyContent(FlexAlign.Center)
              // Animation: Scale down inactive images for a "Carousel" effect
              .scale({
                x: this.currentSwiperIndex === index ? 1.0 : 0.9,
                y: this.currentSwiperIndex === index ? 1.0 : 0.9
              })
              .animation({
                duration: 300,
                curve: Curve.FastOutSlowIn // Smooth physics curve
              })
            }, (item: Resource, index: number) => index + '_' + JSON.stringify(item))
          }
          .onChange((index: number) => {
            // Update global index state when user swipes
            this.currentSwiperIndex = index;
            // 实时同步状态到AppStorage
            AppStorage.setOrCreate('currentSwiperIndex', index);
          })
          // [End swiperUsagePosition]
          .width('100%')
          .height('100%')
          .itemSpace(20)
          .indicator(
            Indicator.dot()
              .selectedColor($r('sys.color.font_primary'))
              .color($r('sys.color.font_secondary'))
          )
          .loop(false)
          .effectMode(EdgeEffect.Spring)
        }
        .width('100%')
        .height('65%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 16, right: 16, top: 8 })
        .margin({ top: 45 })

        // Bottom Section: Control Panel (Radios)
        Column() {
          Text("Apply Filter")
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .margin({ bottom: 16 })
            .fontColor($r('sys.color.font_primary'))
          // [Start radioUsagePosition]
          Grid() {
            ForEach(FILTER_OPTIONS, (item: FilterOption) => {
              GridItem() {
                Row() {
                  Radio({ value: item.value, group: 'filterGroup' })
                    .checked(this.imageFilterTags[this.currentSwiperIndex] === item.value)
                    .onChange((isChecked: boolean) => {
                      if (isChecked) {
                        this.imageFilterTags[this.currentSwiperIndex] = item.value;
                        // 实时同步状态到AppStorage
                        AppStorage.setOrCreate('imageFilterTags', this.imageFilterTags);
                      }
                    })
                  Text(item.label)
                    .fontSize(14)
                    .fontColor($r('sys.color.font_primary'))
                    .margin({ left: 4 })
                    .onClick(() => {
                      this.imageFilterTags[this.currentSwiperIndex] = item.value;
                      // 实时同步状态到AppStorage
                      AppStorage.setOrCreate('imageFilterTags', this.imageFilterTags);
                    })
                }
                .width('100%')
              }
            }, (item: FilterOption, index: number) => index + '_' + JSON.stringify(item))
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(16)
          .columnsGap(10)
          .width('100%')
          // [End radioUsagePosition]

          // 高级滤镜调节入口
          Button('高级滤镜调节')
            .width('100%')
            .height(44)
            .margin({ top: 16 })
            .backgroundColor($r('sys.color.background_emphasize'))
            .fontColor($r('sys.color.font_on_primary'))
            .onClick(() => {
              router.pushUrl({
                url: 'pages/FilterAdjustPage'
              });
            })
        }
        .layoutWeight(1)
        .padding(24)
        .backgroundColor($r('sys.color.background_primary'))
        .borderRadius(16)
        .margin({
          left: 16,
          right: 16,
          top: 36,
          bottom: 16
        })
      }
      .height('100%')
      .width('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 流转按钮（悬浮在右上角）
      ContinuationButton()
        .position({ x: '85%', y: 50 })
    }
    .width('100%')
    .height('100%')
  }

  // [Start getFilterByTagFunc]
  // Helper: Retrieves the actual filter object based on the tag string
  private getFilterByTag(tag: string): ColorFilter | number[] {
    const option = FILTER_OPTIONS.find(opt => opt.value === tag);
    return option ? option.filter : ORIGINAL_MATRIX;
  }
  // [End getFilterByTagFunc]
}
