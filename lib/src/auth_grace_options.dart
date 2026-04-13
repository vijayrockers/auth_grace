/// Configuration options for [AuthGrace].
///
/// Pass an [AuthGraceOptions] instance to [AuthGrace] to control grace period
/// length, authentication strictness, and platform-specific behaviour.
///
/// ```dart
/// final auth = AuthGrace(
///   options: const AuthGraceOptions(
///     gracePeriodSeconds: 30,
///     reason: 'Authenticate to open',
///   ),
/// );
/// ```
class AuthGraceOptions {
  /// The number of seconds after the last device unlock during which
  /// authentication is skipped automatically.
  ///
  /// On Android this maps directly to the Keystore key validity window, which
  /// is enforced by the OS at the hardware level.  On iOS it is approximated
  /// using a Keychain timestamp recorded after each successful biometric
  /// prompt.
  ///
  /// Set to `0` to always require authentication (equivalent to
  /// [alwaysRequire] = `true`).
  ///
  /// Defaults to `30`.
  final int gracePeriodSeconds;

  /// When `true`, the grace period is ignored and a biometric/PIN prompt is
  /// always shown — regardless of when the device was last unlocked.
  ///
  /// Use this for high-sensitivity actions such as confirming a payment or
  /// viewing a secret.
  ///
  /// Defaults to `false`.
  final bool alwaysRequire;

  /// The localised message shown in the system biometric dialog.
  ///
  /// Keep this short and action-oriented, e.g. `'Authenticate to open'` or
  /// `'Confirm payment'`.
  ///
  /// Defaults to `'Authenticate to continue'`.
  final String reason;

  /// Whether to fall back to PIN, pattern or password when biometric
  /// authentication is unavailable or fails.
  ///
  /// When `false`, only biometric authentication (fingerprint / face) is
  /// accepted.
  ///
  /// Defaults to `true`.
  final bool allowDeviceCredential;

  /// Whether the biometric prompt stays visible when the app is moved to the
  /// background during authentication.
  ///
  /// When `true` (the default), the prompt remains on screen if the user
  /// switches away mid-authentication — useful when a password manager needs
  /// to briefly background the app to copy a credential.
  ///
  /// Set to `false` to dismiss the prompt automatically on backgrounding.
  ///
  /// Defaults to `true`.
  final bool persistAcrossBackgrounding;

  /// The name used for the underlying Android Keystore key.
  ///
  /// Override this only if you need multiple independent grace windows inside
  /// the same app (e.g. a separate key for payment flows).  The value must be
  /// globally unique — use a reverse-DNS style name to avoid collisions with
  /// other packages.
  ///
  /// Defaults to `'com.authgrace.auth_grace_key'`.
  final String keyName;

  /// Creates an [AuthGraceOptions] with the given settings.
  ///
  /// All parameters are optional; sensible defaults are provided for every
  /// field.
  const AuthGraceOptions({
    this.gracePeriodSeconds = 30,
    this.alwaysRequire = false,
    this.reason = 'Authenticate to continue',
    this.allowDeviceCredential = true,
    this.persistAcrossBackgrounding = true,
    this.keyName = 'com.authgrace.auth_grace_key',
  });
}
