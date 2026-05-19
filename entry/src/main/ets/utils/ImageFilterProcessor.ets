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
import { effectKit } from '@kit.ArkGraphics2D';

/**
 * 滤镜参数接口
 */
export interface FilterParams {
  brightness: number;   // 亮度 -100 ~ 100 (UI滑块值)
  contrast: number;     // 对比度 0 ~ 3
  saturation: number;   // 饱和度 0 ~ 3
  sharpness: number;    // 锐化强度 0 ~ 2
  exposure: number;     // 曝光 -3 ~ 3
}

/**
 * 默认滤镜参数
 */
export const DEFAULT_FILTER_PARAMS: FilterParams = {
  brightness: 0,
  contrast: 1.0,
  saturation: 1.0,
  sharpness: 0,
  exposure: 0
};

/**
 * 图像滤镜处理工具类
 * 使用 EffectKit 和 PixelMap 操作实现图像处理
 */
export class ImageFilterProcessor {
  private static instance: ImageFilterProcessor | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): ImageFilterProcessor {
    if (!ImageFilterProcessor.instance) {
      ImageFilterProcessor.instance = new ImageFilterProcessor();
    }
    return ImageFilterProcessor.instance;
  }

  /**
   * 应用滤镜效果到 PixelMap
   * @param pixelMap 输入的 PixelMap
   * @param params 滤镜参数
   * @returns 处理后的 PixelMap
   */
  async applyFilter(pixelMap: image.PixelMap, params: FilterParams): Promise<image.PixelMap | null> {
    try {
      // 获取图像信息
      const imageInfo = await pixelMap.getImageInfo();
      const width = imageInfo.size.width;
      const height = imageInfo.size.height;
      
      // 读取像素数据
      const bufferSize = width * height * 4; // RGBA_8888
      const buffer = new ArrayBuffer(bufferSize);
      await pixelMap.readPixelsToBuffer(buffer);
      
      // 转换为 Uint8Array 进行处理
      const pixels = new Uint8Array(buffer);
      
      // 应用各种滤镜效果
      this.applyBrightness(pixels, width, height, params.brightness);
      this.applyContrast(pixels, width, height, params.contrast);
      this.applySaturation(pixels, width, height, params.saturation);
      this.applySharpen(pixels, width, height, params.sharpness);
      this.applyExposure(pixels, width, height, params.exposure);
      
      // 创建新的 PixelMap
      const opts: image.InitializationOptions = {
        editable: true,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width, height }
      };
      
      const resultPixelMap = await image.createPixelMap(buffer, opts);
      return resultPixelMap;
    } catch (error) {
      console.error('ImageFilterProcessor: Failed to apply filter', error);
      return null;
    }
  }

  /**
   * 应用亮度调整
   * brightness: -100 ~ 100
   */
  private applyBrightness(pixels: Uint8Array, width: number, height: number, brightness: number): void {
    if (Math.abs(brightness) < 0.001) return;
    
    // 转换为 -1.0 ~ 1.0 的范围
    const factor = brightness / 100.0;
    
    for (let i = 0; i < pixels.length; i += 4) {
      for (let c = 0; c < 3; c++) {
        let value = pixels[i + c];
        if (factor > 0) {
          value = value + Math.floor((255 - value) * factor);
        } else {
          value = value + Math.floor(value * factor);
        }
        pixels[i + c] = Math.max(0, Math.min(255, value));
      }
    }
  }

  /**
   * 应用对比度调整
   * contrast: 0 ~ 3 (1.0 为原始)
   */
  private applyContrast(pixels: Uint8Array, width: number, height: number, contrast: number): void {
    if (Math.abs(contrast - 1.0) < 0.001) return;
    
    for (let i = 0; i < pixels.length; i += 4) {
      for (let c = 0; c < 3; c++) {
        let value = pixels[i + c];
        value = Math.floor((value - 128) * contrast + 128);
        pixels[i + c] = Math.max(0, Math.min(255, value));
      }
    }
  }

  /**
   * 应用饱和度调整
   * saturation: 0 ~ 3 (1.0 为原始)
   */
  private applySaturation(pixels: Uint8Array, width: number, height: number, saturation: number): void {
    if (Math.abs(saturation - 1.0) < 0.001) return;
    
    for (let i = 0; i < pixels.length; i += 4) {
      const r = pixels[i];
      const g = pixels[i + 1];
      const b = pixels[i + 2];
      
      // 计算灰度值 (ITU-R BT.709 标准)
      const gray = Math.floor(0.299 * r + 0.587 * g + 0.114 * b);
      
      // 应用饱和度调整: 新颜色 = 灰度 + 饱和度 * (原颜色 - 灰度)
      pixels[i] = Math.max(0, Math.min(255, Math.floor(gray + saturation * (r - gray))));
      pixels[i + 1] = Math.max(0, Math.min(255, Math.floor(gray + saturation * (g - gray))));
      pixels[i + 2] = Math.max(0, Math.min(255, Math.floor(gray + saturation * (b - gray))));
    }
  }

  /**
   * 应用锐化效果 (拉普拉斯锐化)
   * sharpness: 0 ~ 2
   */
  private applySharpen(pixels: Uint8Array, width: number, height: number, sharpness: number): void {
    if (sharpness <= 0.001) return;
    
    const rowSize = width * 4;
    const tempPixels = new Uint8Array(pixels);
    
    for (let y = 1; y < height - 1; y++) {
      for (let x = 1; x < width - 1; x++) {
        const idx = y * rowSize + x * 4;
        const topIdx = (y - 1) * rowSize + x * 4;
        const bottomIdx = (y + 1) * rowSize + x * 4;
        const leftIdx = y * rowSize + (x - 1) * 4;
        const rightIdx = y * rowSize + (x + 1) * 4;
        
        for (let c = 0; c < 3; c++) {
          const center = tempPixels[idx + c];
          const top = tempPixels[topIdx + c];
          const bottom = tempPixels[bottomIdx + c];
          const left = tempPixels[leftIdx + c];
          const right = tempPixels[rightIdx + c];
          
          // 拉普拉斯算子: 5*center - top - bottom - left - right
          const laplacian = 5 * center - top - bottom - left - right;
          const sharpened = center + Math.floor(sharpness * (laplacian - center));
          pixels[idx + c] = Math.max(0, Math.min(255, sharpened));
        }
      }
    }
  }

  /**
   * 应用曝光调整
   * exposure: -3 ~ 3 (0 为原始)
   */
  private applyExposure(pixels: Uint8Array, width: number, height: number, exposure: number): void {
    if (Math.abs(exposure) < 0.001) return;
    
    // 曝光调整因子: 2^exposure
    const factor = Math.pow(2.0, exposure);
    
    for (let i = 0; i < pixels.length; i += 4) {
      for (let c = 0; c < 3; c++) {
        const value = pixels[i + c] * factor;
        pixels[i + c] = Math.max(0, Math.min(255, Math.floor(value)));
      }
    }
  }
}

/**
 * 创建滤镜参数
 */
export function createFilterParams(options: FilterParams | undefined): FilterParams {
  if (options === undefined) {
    return {
      brightness: DEFAULT_FILTER_PARAMS.brightness,
      contrast: DEFAULT_FILTER_PARAMS.contrast,
      saturation: DEFAULT_FILTER_PARAMS.saturation,
      sharpness: DEFAULT_FILTER_PARAMS.sharpness,
      exposure: DEFAULT_FILTER_PARAMS.exposure
    };
  }
  return {
    brightness: options.brightness,
    contrast: options.contrast,
    saturation: options.saturation,
    sharpness: options.sharpness,
    exposure: options.exposure
  };
}

/**
 * 预设滤镜效果映射
 */
export const FILTER_PRESETS: Map<string, FilterParams> = new Map([
  ['original', createFilterParams(undefined)],
  
  // 亮度增强
  ['bright', createFilterParams({ brightness: 30, contrast: 1.0, saturation: 1.0, sharpness: 0, exposure: 0 })],
  ['dark', createFilterParams({ brightness: -30, contrast: 1.0, saturation: 1.0, sharpness: 0, exposure: 0 })],
  
  // 对比度增强
  ['highContrast', createFilterParams({ brightness: 0, contrast: 1.5, saturation: 1.0, sharpness: 0, exposure: 0 })],
  ['lowContrast', createFilterParams({ brightness: 0, contrast: 0.7, saturation: 1.0, sharpness: 0, exposure: 0 })],
  
  // 饱和度增强
  ['vivid', createFilterParams({ brightness: 0, contrast: 1.0, saturation: 1.5, sharpness: 0, exposure: 0 })],
  ['muted', createFilterParams({ brightness: 0, contrast: 1.0, saturation: 0.7, sharpness: 0, exposure: 0 })],
  
  // 锐化
  ['sharp', createFilterParams({ brightness: 0, contrast: 1.0, saturation: 1.0, sharpness: 0.8, exposure: 0 })],
  ['sharper', createFilterParams({ brightness: 0, contrast: 1.0, saturation: 1.0, sharpness: 1.5, exposure: 0 })],
  
  // 曝光
  ['overexposed', createFilterParams({ brightness: 0, contrast: 1.0, saturation: 1.0, sharpness: 0, exposure: 1.0 })],
  ['underexposed', createFilterParams({ brightness: 0, contrast: 1.0, saturation: 1.0, sharpness: 0, exposure: -1.0 })],
  
  // 组合效果
  ['dramatic', createFilterParams({ brightness: 0, contrast: 1.3, saturation: 1.2, sharpness: 0.5, exposure: 0 })],
  ['soft', createFilterParams({ brightness: 10, contrast: 0.9, saturation: 0.9, sharpness: 0, exposure: 0 })],
  ['vintage', createFilterParams({ brightness: 15, contrast: 1.1, saturation: 0.8, sharpness: 0, exposure: 0 })],
]);

/**
 * 获取预设名称列表
 */
export function getPresetNames(): string[] {
  return ['original', 'bright', 'dark', 'highContrast', 'lowContrast', 'vivid', 'muted', 
          'sharp', 'sharper', 'overexposed', 'underexposed', 'dramatic', 'soft', 'vintage'];
}
