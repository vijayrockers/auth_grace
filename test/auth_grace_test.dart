import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auth_grace/auth_grace.dart';

// Channel names matching the plugin and local_auth internals
const _authGraceChannel = MethodChannel('auth_grace');
const _localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

/// Sets up mock handlers for both channels before each test.
void _mockChannels({
  bool keyExists = true,
  bool isWithinGracePeriod = false,
  bool isHardwareBacked = true,
  bool localAuthResult = true,
  bool isDeviceSupported = true,
  bool canCheckBiometrics = true,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_authGraceChannel, (call) async {
    switch (call.method) {
      case 'generateKey':
        return true;
      case 'keyExists':
        return keyExists;
      case 'isWithinGracePeriod':
        return isWithinGracePeriod;
      case 'deleteKey':
        return true;
      case 'isHardwareBacked':
        return isHardwareBacked;
      case 'markAuthenticated':
        return true;
      default:
        return null;
    }
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localAuthChannel, (call) async {
    switch (call.method) {
      case 'authenticate':
        return localAuthResult;
      case 'isDeviceSupported':
        return isDeviceSupported;
      case 'canCheckBiometrics':
        return canCheckBiometrics;
      case 'getAvailableBiometrics':
        return canCheckBiometrics ? <String>['fingerprint'] : <String>[];
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

  // ─── AuthGraceOptions ────────────────────────────────────────────────────

  group('AuthGraceOptions', () {
    test('defaults are correct', () {
      const opts = AuthGraceOptions();
      expect(opts.gracePeriodSeconds, 30);
      expect(opts.alwaysRequire, false);
      expect(opts.reason, 'Authenticate to continue');
      expect(opts.allowDeviceCredential, true);
      expect(opts.persistAcrossBackgrounding, true);
      expect(opts.keyName, 'com.authgrace.auth_grace_key');
    });

    test('custom values are applied', () {
      const opts = AuthGraceOptions(
        gracePeriodSeconds: 60,
        alwaysRequire: true,
        reason: 'Pay now',
        allowDeviceCredential: false,
        keyName: 'com.example.custom_key',
      );
      expect(opts.gracePeriodSeconds, 60);
      expect(opts.alwaysRequire, true);
      expect(opts.reason, 'Pay now');
      expect(opts.allowDeviceCredential, false);
      expect(opts.keyName, 'com.example.custom_key');
    });

    test('gracePeriodSeconds of 0 is allowed', () {
      const opts = AuthGraceOptions(gracePeriodSeconds: 0);
      expect(opts.gracePeriodSeconds, 0);
    });
  });

  // ─── AuthResult ──────────────────────────────────────────────────────────

  group('AuthResult', () {
    test('isSuccess is true for success', () {
      const r = AuthResult(status: AuthStatus.success);
      expect(r.isSuccess, true);
    });

    test('isSuccess is true for gracePeriodActive', () {
      const r = AuthResult(status: AuthStatus.gracePeriodActive);
      expect(r.isSuccess, true);
    });

    test('isSuccess is false for failed', () {
      const r = AuthResult(status: AuthStatus.failed);
      expect(r.isSuccess, false);
    });

    test('isSuccess is false for notAvailable', () {
      const r = AuthResult(status: AuthStatus.notAvailable);
      expect(r.isSuccess, false);
    });

    test('isSuccess is false for error', () {
      const r = AuthResult(status: AuthStatus.error, error: 'oops');
      expect(r.isSuccess, false);
      expect(r.error, 'oops');
    });

    test('default method is none', () {
      const r = AuthResult(status: AuthStatus.success);
      expect(r.method, AuthMethod.none);
    });

    test('toString includes status and method', () {
      const r = AuthResult(
        status: AuthStatus.success,
        method: AuthMethod.biometric,
      );
      expect(r.toString(), contains('success'));
      expect(r.toString(), contains('biometric'));
    });

    test('toString includes error when present', () {
      const r = AuthResult(status: AuthStatus.error, error: 'fail');
      expect(r.toString(), contains('fail'));
    });
  });

  // ─── AuthGrace constructor ───────────────────────────────────────────────

  group('AuthGrace', () {
    test('constructs with default options', () {
      final auth = AuthGrace();
      expect(auth.options.gracePeriodSeconds, 30);
    });

    test('constructs with custom options', () {
      final auth = AuthGrace(
        options: const AuthGraceOptions(gracePeriodSeconds: 60),
      );
      expect(auth.options.gracePeriodSeconds, 60);
    });
  });

  // ─── AuthGrace.init() ────────────────────────────────────────────────────

  group('AuthGrace.init()', () {
    test('always calls generateKey', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        calls.add(call.method);
        return true;
      });

      await AuthGrace().init();
      expect(calls, contains('generateKey'));
    });

    test('passes gracePeriodSeconds to generateKey', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        captured = call;
        return true;
      });

      await AuthGrace(
        options: const AuthGraceOptions(gracePeriodSeconds: 15),
      ).init();

      expect(captured?.method, 'generateKey');
      expect(captured?.arguments['gracePeriodSeconds'], 15);
    });

    test('passes custom keyName to generateKey', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        captured = call;
        return true;
      });

      await AuthGrace(
        options: const AuthGraceOptions(keyName: 'com.test.key'),
      ).init();

      expect(captured?.arguments['keyName'], 'com.test.key');
    });
  });

  // ─── AuthGrace.authenticate() ────────────────────────────────────────────

  group('AuthGrace.authenticate()', () {
    test('returns gracePeriodActive when within grace window', () async {
      _mockChannels(isWithinGracePeriod: true);
      final result = await AuthGrace().authenticate();
      expect(result.status, AuthStatus.gracePeriodActive);
      expect(result.method, AuthMethod.gracePeriod);
    });

    test('returns success when grace expired and biometric passes', () async {
      _mockChannels(isWithinGracePeriod: false, localAuthResult: true);
      final result = await AuthGrace().authenticate();
      expect(result.status, AuthStatus.success);
      expect(result.method, AuthMethod.biometric);
    });

    test('returns failed when grace expired and biometric fails', () async {
      _mockChannels(isWithinGracePeriod: false, localAuthResult: false);
      final result = await AuthGrace().authenticate();
      expect(result.status, AuthStatus.failed);
    });

    test('skips grace check when alwaysRequire is true', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        calls.add(call.method);
        return false;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_localAuthChannel, (call) async {
        if (call.method == 'isDeviceSupported') return true;
        if (call.method == 'canCheckBiometrics') return true;
        if (call.method == 'authenticate') return true;
        return null;
      });

      await AuthGrace(
        options: const AuthGraceOptions(alwaysRequire: true),
      ).authenticate();

      expect(calls, isNot(contains('isWithinGracePeriod')));
    });

    test('returns notAvailable when device has no biometrics', () async {
      _mockChannels(
        isWithinGracePeriod: false,
        isDeviceSupported: false,
        canCheckBiometrics: false,
      );
      final result = await AuthGrace().authenticate();
      expect(result.status, AuthStatus.notAvailable);
    });

    test('isSuccess is true for gracePeriodActive result', () async {
      _mockChannels(isWithinGracePeriod: true);
      final result = await AuthGrace().authenticate();
      expect(result.isSuccess, true);
    });

    test('isSuccess is true for biometric success result', () async {
      _mockChannels(isWithinGracePeriod: false, localAuthResult: true);
      final result = await AuthGrace().authenticate();
      expect(result.isSuccess, true);
    });
  });

  // ─── AuthGrace.isWithinGracePeriod() ─────────────────────────────────────

  group('AuthGrace.isWithinGracePeriod()', () {
    test('returns true when native returns true', () async {
      _mockChannels(isWithinGracePeriod: true);
      final result = await AuthGrace().isWithinGracePeriod();
      expect(result, true);
    });

    test('returns false when native returns false', () async {
      _mockChannels(isWithinGracePeriod: false);
      final result = await AuthGrace().isWithinGracePeriod();
      expect(result, false);
    });
  });

  // ─── AuthGrace.isHardwareBacked() ────────────────────────────────────────

  group('AuthGrace.isHardwareBacked()', () {
    test('returns true when native returns true', () async {
      _mockChannels(isHardwareBacked: true);
      expect(await AuthGrace().isHardwareBacked(), true);
    });

    test('returns false when native returns false', () async {
      _mockChannels(isHardwareBacked: false);
      expect(await AuthGrace().isHardwareBacked(), false);
    });
  });

  // ─── AuthGrace.reset() ───────────────────────────────────────────────────

  group('AuthGrace.reset()', () {
    test('calls deleteKey on native side', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        calls.add(call.method);
        return true;
      });

      await AuthGrace().reset();
      expect(calls, contains('deleteKey'));
    });

    test('passes keyName to deleteKey', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        if (call.method == 'deleteKey') captured = call;
        return true;
      });

      await AuthGrace(
        options: const AuthGraceOptions(keyName: 'com.test.key'),
      ).reset();

      expect(captured?.arguments['keyName'], 'com.test.key');
    });
  });
}
