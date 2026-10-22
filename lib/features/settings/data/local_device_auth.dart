import 'package:bath_wise/features/settings/domain/device_auth.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// [DeviceAuth] via local_auth.
class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // A call or app switch mid-prompt retries instead of failing.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      // Cancelled, locked out, not enrolled…: the lock screen stays and
      // the user can try again.
      return false;
    } on PlatformException {
      return false;
    }
  }
}
