/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';
import { common } from '@kit.AbilityKit';
import { FilterParams, DEFAULT_FILTER_PARAMS, ImageFilterProcessor, FILTER_PRESETS, getPresetNames } from '../utils/ImageFilterProcessor';

/**
 * 滤镜参数调节页面
 * 支持亮度、对比度、饱和度、锐化、曝光等参数的实时调节
 */
@Entry
@Component
struct FilterAdjustPage {
  // 当前显示的图片索引
  @State currentImageIndex: number = 0;
  
  // 滤镜参数 (使用 filter 前缀避免与组件基类属性冲突)
  @State filterBrightness: number = 0;      // -100 ~ 100
  @State filterContrast: number = 1.0;       // 0 ~ 3
  @State filterSaturation: number = 1.0;     // 0 ~ 3
  @State filterSharpness: number = 0;        // 0 ~ 2
  @State filterExposure: number = 0;         // -3 ~ 3
  
  // 原始 PixelMap
  @State originalPixelMap: image.PixelMap | null = null;
  
  // 处理后的 PixelMap
  @State processedPixelMap: image.PixelMap | null = null;
  
  // 是否正在处理
  @State isProcessing: boolean = false;
  
  // 当前选中的预设
  @State selectedPreset: string = 'original';
  
  // 图片资源列表
  private imageResources: Resource[] = [
    $r('app.media.avatar1'),
    $r('app.media.avatar2')
  ];
  
  // 滤镜处理实例
  private filterProcessor: ImageFilterProcessor = ImageFilterProcessor.getInstance();
  
  // 防抖定时器ID
  private debounceTimer: number = -1;
  
  aboutToAppear(): void {
    // 初始化时加载第一张图片
    this.loadImage(0);
  }
  
  /**
   * 加载图片
   */
  private async loadImage(index: number): Promise<void> {
    if (index < 0 || index >= this.imageResources.length) {
      return;
    }
    
    this.currentImageIndex = index;
    this.isProcessing = true;
    
    try {
      // 获取 ResourceManager
      const context = getContext(this) as common.UIAbilityContext;
      const resMgr = context.resourceManager;
      
      // 获取资源内容
      const resource = this.imageResources[index];
      const fileData = await resMgr.getMediaContent(resource);
      const buffer = fileData.buffer as ArrayBuffer;
      
      // 创建 ImageSource
      const imageSource = image.createImageSource(buffer);
      // 创建 PixelMap
      this.originalPixelMap = await imageSource.createPixelMap();
      // 复制一份用于显示
      this.processedPixelMap = await this.clonePixelMap(this.originalPixelMap);
    } catch (error) {
      console.error('FilterAdjustPage: Failed to load image', error);
    }
    
    this.isProcessing = false;
  }
  
  /**
   * 克隆 PixelMap
   */
  private async clonePixelMap(source: image.PixelMap): Promise<image.PixelMap | null> {
    try {
      const imageInfo = await source.getImageInfo();
      const width = imageInfo.size.width;
      const height = imageInfo.size.height;
      
      const bufferSize = width * height * 4;
      const buffer = new ArrayBuffer(bufferSize);
      await source.readPixelsToBuffer(buffer);
      
      const opts: image.InitializationOptions = {
        editable: true,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width, height }
      };
      
      return await image.createPixelMap(buffer, opts);
    } catch (error) {
      console.error('FilterAdjustPage: Failed to clone PixelMap', error);
      return null;
    }
  }
  
  /**
   * 应用滤镜效果（带防抖）
   */
  private applyFilterDebounced(): void {
    // 清除之前的定时器
    if (this.debounceTimer !== -1) {
      clearTimeout(this.debounceTimer);
    }
    // 延迟 100ms 执行，避免频繁调用
    this.debounceTimer = setTimeout(() => {
      this.applyFilter();
      this.debounceTimer = -1;
    }, 100);
  }
  
  /**
   * 应用滤镜效果
   */
  private async applyFilter(): Promise<void> {
    if (!this.originalPixelMap || this.isProcessing) {
      return;
    }
    
    this.isProcessing = true;
    
    try {
      const params: FilterParams = {
        brightness: this.filterBrightness,
        contrast: this.filterContrast,
        saturation: this.filterSaturation,
        sharpness: this.filterSharpness,
        exposure: this.filterExposure
      };
      
      // 应用滤镜
      const result = await this.filterProcessor.applyFilter(this.originalPixelMap, params);
      if (result) {
        this.processedPixelMap = result;
      }
    } catch (error) {
      console.error('FilterAdjustPage: Failed to apply filter', error);
    }
    
    this.isProcessing = false;
  }
  
  /**
   * 重置所有参数
   */
  private resetParams(): void {
    this.filterBrightness = 0;
    this.filterContrast = 1.0;
    this.filterSaturation = 1.0;
    this.filterSharpness = 0;
    this.filterExposure = 0;
    this.selectedPreset = 'original';
    // 重新加载原始图片
    this.loadImage(this.currentImageIndex);
  }
  
  /**
   * 应用预设效果
   */
  private applyPreset(presetName: string): void {
    const preset = FILTER_PRESETS.get(presetName);
    if (preset) {
      this.filterBrightness = preset.brightness;
      this.filterContrast = preset.contrast;
      this.filterSaturation = preset.saturation;
      this.filterSharpness = preset.sharpness;
      this.filterExposure = preset.exposure;
      this.selectedPreset = presetName;
      this.applyFilter();
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('图像滤镜调节')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('sys.color.background_primary'))
      
      // 图片显示区域
      Column() {
        if (this.processedPixelMap) {
          Image(this.processedPixelMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(12)
        } else {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
            Text('加载中...')
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 8 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('35%')
      .padding(16)
      
      // 预设效果选择
      Column() {
        Text('预设效果')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ bottom: 12 })
          .fontColor($r('sys.color.font_primary'))
        
        Scroll() {
          Row({ space: 8 }) {
            ForEach(getPresetNames(), (preset: string) => {
              Button(preset === 'original' ? '原图' : preset)
                .fontSize(12)
                .height(32)
                .backgroundColor(this.selectedPreset === preset ? 
                  $r('sys.color.background_emphasize') : 
                  $r('sys.color.background_secondary'))
                .fontColor(this.selectedPreset === preset ? 
                  $r('sys.color.font_on_primary') : 
                  $r('sys.color.font_primary'))
                .onClick(() => this.applyPreset(preset))
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.background_primary'))
      
      // 参数调节区域
      Scroll() {
        Column({ space: 16 }) {
          // 亮度调节
          this.buildSliderItem(
            '亮度',
            this.filterBrightness,
            -100,
            100,
            (value: number) => {
              this.filterBrightness = value;
              this.selectedPreset = '';
              this.applyFilterDebounced();
            }
          )
          
          // 对比度调节
          this.buildSliderItem(
            '对比度',
            this.filterContrast,
            0,
            3,
            (value: number) => {
              this.filterContrast = value;
              this.selectedPreset = '';
              this.applyFilterDebounced();
            }
          )
          
          // 饱和度调节
          this.buildSliderItem(
            '饱和度',
            this.filterSaturation,
            0,
            3,
            (value: number) => {
              this.filterSaturation = value;
              this.selectedPreset = '';
              this.applyFilterDebounced();
            }
          )
          
          // 锐化调节
          this.buildSliderItem(
            '锐化',
            this.filterSharpness,
            0,
            2,
            (value: number) => {
              this.filterSharpness = value;
              this.selectedPreset = '';
              this.applyFilterDebounced();
            }
          )
          
          // 曝光调节
          this.buildSliderItem(
            '曝光',
            this.filterExposure,
            -3,
            3,
            (value: number) => {
              this.filterExposure = value;
              this.selectedPreset = '';
              this.applyFilterDebounced();
            }
          )
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor($r('sys.color.background_secondary'))
      
      // 底部操作按钮
      Row({ space: 12 }) {
        Button('重置')
          .width('30%')
          .height(44)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => this.resetParams())
        
        Button('应用')
          .width('30%')
          .height(44)
          .backgroundColor($r('sys.color.background_emphasize'))
          .fontColor($r('sys.color.font_on_primary'))
          .onClick(() => this.applyFilter())
          .enabled(!this.isProcessing)
        
        // 图片切换按钮
        Button('下一张')
          .width('30%')
          .height(44)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            const nextIndex = (this.currentImageIndex + 1) % this.imageResources.length;
            this.loadImage(nextIndex);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('sys.color.background_primary'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
  
  /**
   * 构建滑块调节项
   */
  @Builder
  buildSliderItem(
    label: string,
    value: number,
    min: number,
    max: number,
    onChange: (value: number) => void
  ) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
        
        Blank()
        
        Text(value.toFixed(2))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .margin({ bottom: 8 })
      
      Slider({
        value: value,
        min: min,
        max: max,
        step: (max - min) / 100,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .trackColor($r('sys.color.background_secondary'))
        .selectedColor($r('sys.color.background_emphasize'))
        .blockColor($r('sys.color.font_primary'))
        .onChange((sliderValue: number) => {
          onChange(sliderValue);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.background_primary'))
    .borderRadius(8)
  }
}
