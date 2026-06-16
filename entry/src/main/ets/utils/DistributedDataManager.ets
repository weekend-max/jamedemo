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

import { distributedDataObject } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'DistributedDataManager';

/**
 * 流转数据结构定义
 */
export class ContinuationData {
  // 当前图片索引
  currentImageIndex: number = 0;
  // 图片滤镜标签数组
  imageFilterTags: string[] = [];
  // 当前页面路径
  currentPage: string = 'Index';
  // 滤镜参数
  filterBrightness: number = 0;
  filterContrast: number = 1.0;
  filterSaturation: number = 1.0;
  filterSharpness: number = 0;
  filterExposure: number = 0;
  // 当前选中的预设
  selectedPreset: string = 'original';

  constructor(
    currentImageIndex: number = 0,
    imageFilterTags: string[] = [],
    currentPage: string = 'Index',
    filterBrightness: number = 0,
    filterContrast: number = 1.0,
    filterSaturation: number = 1.0,
    filterSharpness: number = 0,
    filterExposure: number = 0,
    selectedPreset: string = 'original'
  ) {
    this.currentImageIndex = currentImageIndex;
    this.imageFilterTags = imageFilterTags;
    this.currentPage = currentPage;
    this.filterBrightness = filterBrightness;
    this.filterContrast = filterContrast;
    this.filterSaturation = filterSaturation;
    this.filterSharpness = filterSharpness;
    this.filterExposure = filterExposure;
    this.selectedPreset = selectedPreset;
  }
}

/**
 * 分布式数据管理器
 * 用于管理应用流转数据的保存和恢复
 */
export class DistributedDataManager {
  private static instance: DistributedDataManager;
  private context: common.UIAbilityContext | null = null;
  private distributedObject: distributedDataObject.DataObject | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): DistributedDataManager {
    if (!DistributedDataManager.instance) {
      DistributedDataManager.instance = new DistributedDataManager();
    }
    return DistributedDataManager.instance;
  }

  /**
   * 初始化上下文
   */
  initContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 创建分布式数据对象并保存数据
   * @param sessionId 会话ID
   * @param data 要保存的流转数据
   * @returns 分布式数据对象
   */
  async createDistributedObject(sessionId: string, data: ContinuationData): Promise<distributedDataObject.DataObject | null> {
    if (!this.context) {
      hilog.error(DOMAIN, TAG, 'Context is null, cannot create distributed object');
      return null;
    }

    try {
      // 创建分布式数据对象
      this.distributedObject = distributedDataObject.create(this.context, data);
      
      // 设置会话ID，激活分布式数据对象
      await this.distributedObject.setSessionId(sessionId);
      
      hilog.info(DOMAIN, TAG, 'Distributed object created and activated with sessionId: %{public}s', sessionId);
      return this.distributedObject;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to create distributed object: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 保存分布式数据对象到指定设备
   * @param deviceId 目标设备ID
   */
  async saveDistributedObject(deviceId: string): Promise<boolean> {
    if (!this.distributedObject) {
      hilog.error(DOMAIN, TAG, 'Distributed object is null, cannot save');
      return false;
    }

    try {
      await this.distributedObject.save(deviceId);
      hilog.info(DOMAIN, TAG, 'Distributed object saved to device: %{public}s', deviceId);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save distributed object: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 恢复分布式数据对象
   * @param sessionId 会话ID
   * @param onRestored 数据恢复回调
   */
  async restoreDistributedObject(
    sessionId: string,
    onRestored: (data: ContinuationData) => void
  ): Promise<void> {
    if (!this.context) {
      hilog.error(DOMAIN, TAG, 'Context is null, cannot restore distributed object');
      return;
    }

    try {
      // 创建空的分布式数据对象
      const emptyData = new ContinuationData();
      this.distributedObject = distributedDataObject.create(this.context, emptyData);

      // 监听数据恢复状态
      this.distributedObject.on('status', (sessionId: string, networkId: string, status: string) => {
        hilog.info(DOMAIN, TAG, 'Distributed object status changed: %{public}s, status: %{public}s', networkId, status);
        
        if (status === 'restored' && this.distributedObject) {
          // 数据已恢复，读取数据
          const restoredData = new ContinuationData(
            this.distributedObject['currentImageIndex'] as number,
            this.distributedObject['imageFilterTags'] as string[],
            this.distributedObject['currentPage'] as string,
            this.distributedObject['filterBrightness'] as number,
            this.distributedObject['filterContrast'] as number,
            this.distributedObject['filterSaturation'] as number,
            this.distributedObject['filterSharpness'] as number,
            this.distributedObject['filterExposure'] as number,
            this.distributedObject['selectedPreset'] as string
          );
          
          hilog.info(DOMAIN, TAG, 'Data restored: %{public}s', JSON.stringify(restoredData));
          onRestored(restoredData);
        }
      });

      // 设置会话ID，加入组网
      await this.distributedObject.setSessionId(sessionId);
      hilog.info(DOMAIN, TAG, 'Distributed object restored with sessionId: %{public}s', sessionId);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to restore distributed object: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 生成会话ID
   */
  generateSessionId(): string {
    return distributedDataObject.genSessionId();
  }

  /**
   * 销毁分布式数据对象
   */
  destroyDistributedObject(): void {
    if (this.distributedObject) {
      try {
        // 设置空会话ID，退出组网
        this.distributedObject.setSessionId('');
        this.distributedObject = null;
        hilog.info(DOMAIN, TAG, 'Distributed object destroyed');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to destroy distributed object: %{public}s', JSON.stringify(error));
      }
    }
  }
}
