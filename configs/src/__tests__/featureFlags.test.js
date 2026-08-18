const { FeatureFlagManager, featureFlagManager, isFeatureEnabled, activateKillSwitch } = require('../featureFlags');

describe('🚩 Enterprise Feature Flag Manager Test Suite', () => {

  test('Should return default value for defined flags', () => {
    expect(isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(true);
    expect(isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW')).toBe(false);
    expect(isFeatureEnabled('ENABLE_CRYPTO_STAKING')).toBe(false);
  });

  test('Should return false for unknown feature flags', () => {
    expect(isFeatureEnabled('NON_EXISTENT_FEATURE_FLAG')).toBe(false);
  });

  test('Should disable feature when Kill-Switch is activated', () => {
    const manager = new FeatureFlagManager();
    expect(manager.isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(true);
    
    // Activating Kill-Switch
    const success = manager.activateKillSwitch('ENABLE_BIOMETRIC_AUTH');
    expect(success).toBe(true);
    expect(manager.isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(false);

    // Deactivating Kill-Switch
    manager.deactivateKillSwitch('ENABLE_BIOMETRIC_AUTH');
    expect(manager.isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(true);
  });

  test('Should handle activate/deactivate Kill-Switch for unknown flag', () => {
    const manager = new FeatureFlagManager();
    expect(manager.activateKillSwitch('UNKNOWN')).toBe(false);
    expect(manager.deactivateKillSwitch('UNKNOWN')).toBe(false);
  });

  test('Should apply Remote Config Overrides correctly', () => {
    const manager = new FeatureFlagManager();
    manager.init({
      ENABLE_NEW_PAYMENT_FLOW: { enabled: true },
      ENABLE_BIOMETRIC_AUTH: { enabled: false }
    });

    expect(manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW')).toBe(true);
    expect(manager.isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(false);
  });

  test('Should honor Remote Kill-Switch even if remote enabled is true', () => {
    const manager = new FeatureFlagManager();
    manager.init({
      ENABLE_BIOMETRIC_AUTH: { enabled: true, killSwitchActive: true }
    });

    expect(manager.isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(false);
  });

  test('🎯 Deterministic User Bucketing (DJB2 Hash): User ALWAYS gets exact same bucket', () => {
    const manager = new FeatureFlagManager();
    
    // Call 100 times for user_998877 - must ALWAYS yield identical boolean result
    const firstCall = manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW', 'user_998877');
    for (let i = 0; i < 100; i++) {
      const subsequentCall = manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW', 'user_998877');
      expect(subsequentCall).toBe(firstCall);
    }
  });

  test('🎯 Gradual Rollout Expansion (10% -> 50% -> 100%): Users never lose access', () => {
    const manager = new FeatureFlagManager();

    // 10% Rollout
    manager.init({ ENABLE_NEW_PAYMENT_FLOW: { rolloutPercentage: 10 } });
    const isUserEnabled10 = manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW', 'user_alpha');

    // Increase Rollout to 50%
    manager.init({ ENABLE_NEW_PAYMENT_FLOW: { rolloutPercentage: 50 } });
    const isUserEnabled50 = manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW', 'user_alpha');

    // If user was enabled at 10%, they MUST stay enabled at 50%
    if (isUserEnabled10) {
      expect(isUserEnabled50).toBe(true);
    }

    // 0% Rollout -> False for all
    manager.init({ ENABLE_NEW_PAYMENT_FLOW: { rolloutPercentage: 0 } });
    expect(manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW', 'user_alpha')).toBe(false);

    // 100% Rollout -> True for all
    manager.init({ ENABLE_NEW_PAYMENT_FLOW: { rolloutPercentage: 100 } });
    expect(manager.isFeatureEnabled('ENABLE_NEW_PAYMENT_FLOW', 'user_alpha')).toBe(true);
  });

  test('Should return status map of all flags via getAllFlagsStatus', () => {
    const manager = new FeatureFlagManager();
    const allFlags = manager.getAllFlagsStatus();

    expect(allFlags).toHaveProperty('ENABLE_BIOMETRIC_AUTH');
    expect(allFlags).toHaveProperty('ENABLE_NEW_PAYMENT_FLOW');
    expect(allFlags).toHaveProperty('ENABLE_CRYPTO_STAKING');
  });

  test('Should test exported global helper functions', () => {
    expect(typeof isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe('boolean');
    expect(activateKillSwitch('ENABLE_BIOMETRIC_AUTH')).toBe(true);
    expect(isFeatureEnabled('ENABLE_BIOMETRIC_AUTH')).toBe(false);
  });
});
