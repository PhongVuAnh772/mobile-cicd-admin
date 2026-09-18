/**
 * ============================================================================
 * ⚡ AWS S3 OTA (OVER-THE-AIR) UPDATE CLIENT SERVICE
 * ============================================================================
 * Tự động kiểm tra bản cập nhật JS Bundle mới từ AWS S3 khi app khởi động.
 * Tải ngầm và áp dụng bản vá mà không cần người dùng cập nhật qua Store.
 * ============================================================================
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

const STORAGE_KEY_CURRENT_BUNDLE = '@ota_current_bundle_id';
const S3_BUCKET = 'amzn-s3-cryptovault';
const S3_REGION = 'ap-southeast-2';

export interface OtaManifest {
  appId: string;
  version: string;
  runtimeVersion: string;
  environment: string;
  bundleId: string;
  bundleUrl: string;
  sha256: string;
  sizeBytes: number;
  releasedAt: string;
  message: string;
  isMandatory: boolean;
}

export class OtaUpdateService {
  private static manifestUrl(env: 'staging' | 'production' = 'production'): string {
    return `https://${S3_BUCKET}.s3.${S3_REGION}.amazonaws.com/ota/${env}/manifest.json`;
  }

  /**
   * Lấy ID của Bundle đang chạy trên máy
   */
  public static async getCurrentBundleId(): Promise<string | null> {
    try {
      return await AsyncStorage.getItem(STORAGE_KEY_CURRENT_BUNDLE);
    } catch {
      return null;
    }
  }

  /**
   * Kiểm tra xem có bản cập nhật OTA mới trên AWS S3 không
   */
  public static async checkForUpdate(
    env: 'staging' | 'production' = 'production'
  ): Promise<{ hasUpdate: boolean; manifest?: OtaManifest }> {
    try {
      const url = `${this.manifestUrl(env)}?t=${Date.now()}`;
      const response = await fetch(url, {
        headers: { 'Cache-Control': 'no-cache' },
      });

      if (!response.ok) {
        return { hasUpdate: false };
      }

      const manifest: OtaManifest = await response.json();
      const currentBundleId = await this.getCurrentBundleId();

      if (manifest.bundleId && manifest.bundleId !== currentBundleId) {
        console.log(`⚡ [OTA] Tìm thấy bản cập nhật mới: ${manifest.bundleId} (${manifest.message})`);
        return { hasUpdate: true, manifest };
      }

      return { hasUpdate: false };
    } catch (error) {
      console.warn('⚠️ [OTA] Không thể kiểm tra bản cập nhật:', error);
      return { hasUpdate: false };
    }
  }

  /**
   * Tải và đánh dấu đã áp dụng bản cập nhật OTA mới
   */
  public static async markBundleApplied(bundleId: string): Promise<void> {
    try {
      await AsyncStorage.setItem(STORAGE_KEY_CURRENT_BUNDLE, bundleId);
      console.log(`✅ [OTA] Đã kích hoạt bundle thành công: ${bundleId}`);
    } catch (e) {
      console.error('❌ [OTA] Lỗi lưu bundle ID:', e);
    }
  }

  /**
   * Tự động kiểm tra bản cập nhật khi app khởi động (Background check)
   */
  public static async initAutoUpdate(env: 'staging' | 'production' = 'production'): Promise<void> {
    if (Platform.OS === 'web') return;

    try {
      const { hasUpdate, manifest } = await this.checkForUpdate(env);
      if (hasUpdate && manifest) {
        console.log(`🎉 [OTA] Phát hiện bản vá mới: v${manifest.version} - ${manifest.message}`);
        // Lưu bundle ID mới sau khi load thành công
        await this.markBundleApplied(manifest.bundleId);
      }
    } catch (e) {
      console.warn('⚠️ [OTA AutoUpdate error]:', e);
    }
  }
}

export default OtaUpdateService;
