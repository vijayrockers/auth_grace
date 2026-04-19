import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auth_grace/auth_grace.dart';

const _authGraceChannel = MethodChannel('auth_grace');
const _localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

/// Sets up standard mock handlers for both channels.
///
/// [isWithinGracePeriod] controls what the grace period check returns.
/// Defaults to false (grace period expired) to match `auth_grace_test.dart` convention.
void _mockChannels({bool isWithinGracePeriod = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_authGraceChannel, (call) async {
    switch (call.method) {
      case 'generateKey':
        return true;
      case 'isWithinGracePeriod':
        return isWithinGracePeriod;
      case 'markAuthenticated':
        return true;
      case 'isHardwareBacked':
        return true;
      case 'deleteKey':
        return true;
      default:
        return null;
    }
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localAuthChannel, (call) async {
    switch (call.method) {
      case 'authenticate':
        return true;
      case 'isDeviceSupported':
        return true;
      case 'canCheckBiometrics':
        return true;
      case 'getAvailableBiometrics':
        return <String>['fingerprint'];
      default:
        return null;
    }
  });
}

void _clearMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_authGraceChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localAuthChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(_clearMocks);
}
