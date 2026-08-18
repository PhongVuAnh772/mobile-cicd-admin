const defaultFlagsConfig = require('./config/featureFlags.json');

/**
 * 🚩 ENTERPRISE FEATURE FLAG MANAGER FOR MOBILE APPS
 * Hỗ trợ: Remote Config, Instant Kill-Switch, User Targeting, Deterministic Percentage Rollout, Offline Fallback
 */
class FeatureFlagManager {
  constructor() {
    this.flags = { ...defaultFlagsConfig.flags };
    this.remoteOverrides = {};
    this.isRemoteSyncEnabled = false;
  }

  /**
   * Khởi tạo và nạp Remote Overrides (LaunchDarkly / Unleash / Firebase / S3 Config)
   * @param {Object} remoteConfig Config từ server
   */
  init(remoteConfig = {}) {
    if (remoteConfig && typeof remoteConfig === 'object') {
      this.remoteOverrides = { ...remoteConfig };
      this.isRemoteSyncEnabled = true;
    }
  }

  /**
   * Kiểm tra trạng thái của 1 Feature Flag cho 1 User cụ thể
   * @param {string} flagKey Tên flag (VD: 'ENABLE_NEW_PAYMENT_FLOW')
   * @param {string} [userId] ID người dùng cho Deterministic Percentage Rollout (0-99)
   * @returns {boolean} True nếu feature được bật cho user này
   */
  isFeatureEnabled(flagKey, userId = null) {
    const flagDef = this.flags[flagKey];
    if (!flagDef) {
      return false;
    }

    // ──────────────────────────────────────────────────────────────────
    // BƯỚC 1: UY TIÊN TỐI CAO — CHECK KILL-SWITCH (CẤP LOCAL HOẶC REMOTE)
    // ──────────────────────────────────────────────────────────────────
    if (flagDef.killSwitchActive === true) {
      return false; // Tắt khẩn cấp ngay lập tức!
    }

    const remoteFlag = this.remoteOverrides[flagKey];
    if (remoteFlag) {
      if (remoteFlag.killSwitchActive === true) {
        return false;
      }
      if (typeof remoteFlag.enabled === 'boolean') {
        return remoteFlag.enabled;
      }
    }

    // Lấy phần trăm Rollout hiện tại (% từ Remote hoặc Default local)
    const rolloutPercentage = (remoteFlag && typeof remoteFlag.rolloutPercentage === 'number')
      ? remoteFlag.rolloutPercentage
      : flagDef.rolloutPercentage;

    // ──────────────────────────────────────────────────────────────────
    // BƯỚC 2: TÍNH THUẬT TOÁN HASH USER ID (DETERMINISTIC BUCKETING 0-99)
    // ──────────────────────────────────────────────────────────────────
    if (userId && typeof rolloutPercentage === 'number') {
      // 0% -> Tắt cho tất cả
      if (rolloutPercentage <= 0) return false;
      // 100% -> Mở cho tất cả
      if (rolloutPercentage >= 100) return true;

      // Hash kết hợp (userId + flagKey) để mỗi flag phân phối nhóm user ngẫu nhiên khác nhau
      const bucket = this._calculateUserBucket(userId, flagKey);

      // Nếu Bucket người dùng (0-99) nhỏ hơn % Rollout -> USER NHẬN TÍNH NĂNG
      return bucket < rolloutPercentage;
    }

    // ──────────────────────────────────────────────────────────────────
    // BƯỚC 3: GIÁ TRỊ MẶC ĐỊNH KHI KHÔNG CÓ USER ID / OFFLINE
    // ──────────────────────────────────────────────────────────────────
    return flagDef.defaultValue;
  }

  /**
   * Kích hoạt Kill-Switch từ xa khẩn cấp
   */
  activateKillSwitch(flagKey) {
    if (this.flags[flagKey]) {
      this.flags[flagKey].killSwitchActive = true;
      return true;
    }
    return false;
  }

  /**
   * Tắt Kill-Switch khôi phục trạng thái
   */
  deactivateKillSwitch(flagKey) {
    if (this.flags[flagKey]) {
      this.flags[flagKey].killSwitchActive = false;
      return true;
    }
    return false;
  }

  /**
   * 🧮 THUẬT TOÁN HASH BẮT BUỘC ĐỒNG NHẤT (DETERMINISTIC DJB2 HASH)
   * Biến đổi (userId + flagKey) ➔ Số nguyên cố định ➔ Modulo 100 lấy Bucket (0-99)
   * Đảm bảo User A lần nào mở app cũng rơi vào ĐÚNG Bucket đó (không bị trập trùng UI)
   * @private
   */
  _calculateUserBucket(userId, flagKey) {
    const combinedKey = `${String(userId)}:${flagKey}`;
    let hash = 5381;
    for (let i = 0; i < combinedKey.length; i++) {
      hash = (hash * 33) ^ combinedKey.charCodeAt(i);
    }
    // Modulo 100 trả về vị trí bucket từ 0 đến 99
    return Math.abs(hash) % 100;
  }

  getAllFlagsStatus(userId = null) {
    const status = {};
    Object.keys(this.flags).forEach(key => {
      status[key] = this.isFeatureEnabled(key, userId);
    });
    return status;
  }
}

const featureFlagManager = new FeatureFlagManager();

module.exports = {
  FeatureFlagManager,
  featureFlagManager,
  isFeatureEnabled: (flagKey, userId) => featureFlagManager.isFeatureEnabled(flagKey, userId),
  activateKillSwitch: (flagKey) => featureFlagManager.activateKillSwitch(flagKey)
};
