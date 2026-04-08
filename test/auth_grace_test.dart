import 'package:flutter_test/flutter_test.dart';
import 'package:auth_grace/auth_grace.dart';

void main() {
  group('AuthGraceOptions', () {
    test('defaults are correct', () {
      const opts = AuthGraceOptions();
      expect(opts.gracePeriodSeconds, 30);
      expect(opts.alwaysRequire, false);
      expect(opts.reason, 'Authenticate to continue');
      expect(opts.allowDeviceCredential, true);
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
  });

  group('AuthResult', () {
    test('isSuccess is true for success status', () {
      const result = AuthResult(status: AuthStatus.success);
      expect(result.isSuccess, true);
    });

    test('isSuccess is true for gracePeriodActive status', () {
      const result = AuthResult(status: AuthStatus.gracePeriodActive);
      expect(result.isSuccess, true);
    });

    test('isSuccess is false for failed status', () {
      const result = AuthResult(status: AuthStatus.failed);
      expect(result.isSuccess, false);
    });

    test('isSuccess is false for notAvailable status', () {
      const result = AuthResult(status: AuthStatus.notAvailable);
      expect(result.isSuccess, false);
    });

    test('isSuccess is false for error status', () {
      const result = AuthResult(status: AuthStatus.error, error: 'test error');
      expect(result.isSuccess, false);
      expect(result.error, 'test error');
    });

    test('toString includes status and method', () {
      const result = AuthResult(
        status: AuthStatus.success,
        method: AuthMethod.biometric,
      );
      expect(result.toString(), contains('success'));
      expect(result.toString(), contains('biometric'));
    });
  });

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
}
