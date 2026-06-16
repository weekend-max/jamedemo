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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { continuationManager } from '@kit.AbilityKit';

const DOMAIN = 0x0000;
const TAG = 'ContinuationManager';

/**
 * 流转管理工具类
 * 提供设备发现、流转状态管理等功能
 */
export class ContinuationManager {
  private static instance: ContinuationManager;
  private token: number = -1;

  private constructor() {}

  /**
   * 获取单例实例
   */
  public static getInstance(): ContinuationManager {
    if (!ContinuationManager.instance) {
      ContinuationManager.instance = new ContinuationManager();
    }
    return ContinuationManager.instance;
  }

  /**
   * 注册流转管理服务
   */
  public async register(): Promise<number> {
    try {
      this.token = await continuationManager.registerContinuation();
      hilog.info(DOMAIN, TAG, 'Continuation registered, token: %{public}d', this.token);
      return this.token;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to register continuation: %{public}s', JSON.stringify(err));
      return -1;
    }
  }

  /**
   * 注销流转管理服务
   */
  public async unregister(): Promise<void> {
    if (this.token === -1) {
      return;
    }
    try {
      continuationManager.unregisterContinuation(this.token);
      hilog.info(DOMAIN, TAG, 'Continuation unregistered');
      this.token = -1;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to unregister continuation: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 监听设备选择事件
   */
  public onDeviceSelected(callback: (devices: Array<continuationManager.ContinuationResult>) => void): void {
    if (this.token === -1) {
      hilog.error(DOMAIN, TAG, 'Token not available, please register first');
      return;
    }
    try {
      continuationManager.on('deviceSelected', this.token, callback);
      hilog.info(DOMAIN, TAG, 'Device selected listener registered');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to register device selected listener: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 监听设备取消选择事件
   */
  public onDeviceUnselected(callback: (devices: Array<continuationManager.ContinuationResult>) => void): void {
    if (this.token === -1) {
      hilog.error(DOMAIN, TAG, 'Token not available, please register first');
      return;
    }
    try {
      continuationManager.on('deviceUnselected', this.token, callback);
      hilog.info(DOMAIN, TAG, 'Device unselected listener registered');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to register device unselected listener: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 拉起设备选择器
   */
  public async showDeviceManager(): Promise<void> {
    if (this.token === -1) {
      hilog.error(DOMAIN, TAG, 'Token not available, please register first');
      return;
    }
    try {
      await continuationManager.startContinuationDeviceManager(this.token);
      hilog.info(DOMAIN, TAG, 'Device manager started');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to start device manager: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 获取当前token
   */
  public getToken(): number {
    return this.token;
  }

  /**
   * 释放资源
   */
  public async release(): Promise<void> {
    await this.unregister();
  }
}

/**
 * 流转状态枚举
 */
export enum ContinuationState {
  IDLE = 'idle',           // 空闲状态
  SAVING = 'saving',       // 保存状态中
  RESTORING = 'restoring', // 恢复状态中
  COMPLETED = 'completed'  // 流转完成
}

/**
 * 流转数据接口
 */
export interface ContinuationData {
  currentSwiperIndex: number;
  imageFilterTags: string[];
  timestamp: number;
}
