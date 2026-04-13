import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart'
    show LocalAuthentication, LocalAuthException, LocalAuthExceptionCode;
import 'auth_grace_options.dart';
import 'auth_grace_result.dart';

/// Smart biometric authentication with an automatic grace period.
///
/// [AuthGrace] wraps `local_auth` and adds a grace window — if the device was
/// unlocked recently the biometric prompt is skipped entirely, giving the same
/// frictionless experience as Google Pay.
///
/// ## Typical lifecycle
///
/// ```dart
/// // 1. Create once (e.g. in a singleton or provider)
/// final auth = AuthGrace(
///   options: const AuthGraceOptions(gracePeriodSeconds: 30),
/// );
///
/// // 2. Initialise at app startup — generates the Keystore/Keychain key
/// await auth.init();
///
/// // 3. Authenticate whenever the app moves to the foreground
/// final result = await auth.authenticate();
/// if (result.isSuccess) {
///   // allow access
/// }
///
/// // 4. Reset on logout or account switch
/// await auth.reset();
/// ```
///
/// ## Platform notes
///
/// * **Android** — grace period is enforced by the Android Keystore at the
///   hardware (TEE) level using a time-bound AES key.  The key validity window
///   is set via [AuthGraceOptions.gracePeriodSeconds].
/// * **iOS** — grace period is approximated by recording a Keychain timestamp
///   after every successful `local_auth` prompt and comparing it on the next
///   call.  This is not hardware-enforced like the Android implementation.
class AuthGrace {
  /// The options controlling grace period behaviour.
  final AuthGraceOptions options;

  final _localAuth = LocalAuthentication();
  static const _channel = MethodChannel('auth_grace');

  /// Creates an [AuthGrace] instance.
  ///
  /// [options] defaults to [AuthGraceOptions] with a 30-second grace window.
  /// Call [init] before the first [authenticate] call.
  AuthGrace({AuthGraceOptions? options})
      : options = options ?? const AuthGraceOptions();

  /// Initialises the plugin.
  ///
  /// Generates the Android Keystore key (or confirms it already exists) so
  /// that [isWithinGracePeriod] works correctly on the first call.
  ///
  /// Call this once at app startup, before the first [authenticate] call.
  Future<void> init() async {
    // Always regenerate the key so that changes to gracePeriodSeconds take
    // effect immediately. The key is only used for grace period checking,
    // not for encrypting user data, so regenerating is safe.
    await _invokeMethod<bool>('generateKey', {
      'gracePeriodSeconds': options.gracePeriodSeconds,
      'keyName': options.keyName,
    });
  }

  /// Authenticates the user, honouring the configured grace period.
  ///
  /// Returns immediately with [AuthStatus.gracePeriodActive] if the device was
  /// unlocked within [AuthGraceOptions.gracePeriodSeconds] seconds — no
  /// biometric prompt is shown.
  ///
  /// When the grace window has expired (or [AuthGraceOptions.alwaysRequire] is
  /// `true`) the system biometric / PIN dialog is presented via `local_auth`.
  ///
  /// Possible return values:
  ///
  /// | [AuthStatus]         | Meaning |
  /// |----------------------|---------|
  /// | `gracePeriodActive`  | Device was recently unlocked — prompt skipped |
  /// | `success`            | Biometric or PIN passed |
  /// | `failed`             | User cancelled or failed too many times |
  /// | `notAvailable`       | No enrolled biometrics on this device |
  /// | `error`              | Unexpected platform error — check [AuthResult.error] |
  Future<AuthResult> authenticate() async {
    // Always require mode — skip grace period entirely
    if (!options.alwaysRequire) {
      final inGrace = await isWithinGracePeriod();
      if (inGrace) {
        return const AuthResult(
          status: AuthStatus.gracePeriodActive,
          method: AuthMethod.gracePeriod,
        );
      }
    }

    // Check device capability
    final available = await isAvailable();
    if (!available) {
      return const AuthResult(
        status: AuthStatus.notAvailable,
        method: AuthMethod.none,
        error: 'Biometric authentication not available on this device',
      );
    }

    // Show biometric prompt via local_auth
    try {
      final success = await _localAuth.authenticate(
        localizedReason: options.reason,
        biometricOnly: !options.allowDeviceCredential,
        persistAcrossBackgrounding: options.persistAcrossBackgrounding,
      );

      if (success) {
        // Mark auth time for iOS grace period tracking
        await _markAuthenticated();
        return const AuthResult(
          status: AuthStatus.success,
          method: AuthMethod.biometric,
        );
      }

      return const AuthResult(
        status: AuthStatus.failed,
        method: AuthMethod.none,
      );
    } on LocalAuthException catch (e) {
      return AuthResult(
        status: _statusFromException(e.code),
        method: AuthMethod.none,
        error: e.description,
      );
    } catch (e) {
      return AuthResult(
        status: AuthStatus.error,
        method: AuthMethod.none,
        error: e.toString(),
      );
    }
  }

  /// Returns `true` if the device was unlocked within the grace window,
  /// without showing any authentication prompt.
  ///
  /// Use this to conditionally show a lock overlay before calling
  /// [authenticate].
  Future<bool> isWithinGracePeriod() async {
    return await _invokeMethod<bool>('isWithinGracePeriod', {
          'gracePeriodSeconds': options.gracePeriodSeconds,
          'keyName': options.keyName,
        }) ??
        false;
  }

  /// Returns `true` if the device supports biometric or device-credential
  /// authentication.
  ///
  /// Returns `false` on devices with no biometric hardware or when the user
  /// has not enrolled any biometrics/PIN.
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if the device has a hardware-backed secure element (TEE
  /// on Android, Secure Enclave on iOS).
  ///
  /// On Android this requires API 31+; earlier devices return `false`.
  /// On iOS this always returns `true` for supported hardware.
  Future<bool> isHardwareBacked() async {
    return await _invokeMethod<bool>('isHardwareBacked') ?? false;
  }

  /// Deletes the Keystore key (Android) and Keychain timestamp (iOS), ending
  /// the current grace window immediately.
  ///
  /// Call this on logout or when the active user account changes.  After
  /// [reset], call [init] again before the next [authenticate] call.
  Future<void> reset() async {
    await _invokeMethod<bool>('deleteKey', {'keyName': options.keyName});
  }

  /// Records the current timestamp on iOS after a successful biometric prompt.
  ///
  /// On Android the Keystore handles grace period tracking natively.
  Future<void> _markAuthenticated() async {
    await _invokeMethod<bool>('markAuthenticated');
  }

  AuthStatus _statusFromException(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return AuthStatus.notAvailable;
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return AuthStatus.failed;
      default:
        return AuthStatus.error;
    }
  }

  Future<T?> _invokeMethod<T>(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }
}
