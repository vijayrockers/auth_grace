/// The high-level outcome of an [AuthGrace.authenticate] call.
///
/// Use [AuthResult.isSuccess] as the primary gate — it returns `true` for
/// both [success] and [gracePeriodActive], the two cases in which the caller
/// should proceed.
enum AuthStatus {
  /// The user passed biometric or PIN authentication.
  success,

  /// Authentication was skipped because the device was unlocked within the
  /// configured grace window.  Treat this the same as [success].
  gracePeriodActive,

  /// The user cancelled the prompt, failed too many times, or the biometric
  /// hardware rejected the attempt.
  failed,

  /// The device has no biometric hardware or the user has not enrolled any
  /// biometrics.
  notAvailable,

  /// An unexpected platform error occurred.  Inspect [AuthResult.error] for
  /// details.
  error,
}

/// The mechanism that produced the [AuthResult].
enum AuthMethod {
  /// Face ID, Touch ID, or a fingerprint sensor was used.
  biometric,

  /// A PIN, pattern, or password was used as a fallback.
  deviceCredential,

  /// The prompt was skipped because the device was recently unlocked.
  gracePeriod,

  /// No authentication took place (e.g. [AuthStatus.notAvailable] or
  /// [AuthStatus.error]).
  none,
}

/// The result returned by [AuthGrace.authenticate].
///
/// Check [isSuccess] first; then inspect [status] and [method] for details.
///
/// ```dart
/// final result = await auth.authenticate();
/// if (result.isSuccess) {
///   // proceed — either biometric passed or grace period is still active
/// } else if (result.status == AuthStatus.notAvailable) {
///   // device has no enrolled biometrics
/// }
/// ```
class AuthResult {
  /// The high-level outcome of the authentication attempt.
  final AuthStatus status;

  /// How authentication was (or was not) performed.
  final AuthMethod method;

  /// A human-readable error description when [status] is [AuthStatus.error].
  ///
  /// `null` for all other statuses.
  final String? error;

  /// Creates an [AuthResult].
  const AuthResult({
    required this.status,
    this.method = AuthMethod.none,
    this.error,
  });

  /// Returns `true` when the caller should be allowed to proceed.
  ///
  /// Equivalent to checking whether [status] is [AuthStatus.success] **or**
  /// [AuthStatus.gracePeriodActive].
  bool get isSuccess =>
      status == AuthStatus.success || status == AuthStatus.gracePeriodActive;

  @override
  String toString() =>
      'AuthResult(status: $status, method: $method, error: $error)';
}
