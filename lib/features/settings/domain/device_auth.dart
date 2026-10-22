/// The device's own authentication: biometrics, or the passcode as a
/// fallback.
abstract interface class DeviceAuth {
  /// Whether the device has biometrics or a screen lock set up.
  Future<bool> isAvailable();

  /// Shows the system prompt. False if cancelled or failed.
  Future<bool> authenticate(String reason);
}
