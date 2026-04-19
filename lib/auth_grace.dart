/// Smart biometric authentication with automatic grace period.
///
/// `auth_grace` provides a simple API for biometric authentication that skips
/// the prompt if the user's phone was recently unlocked — exactly like Google Pay.
///
/// **Key Features:**
/// - Automatic grace period after unlock (configurable, default 30 seconds)
/// - Skips biometric prompt during grace period
/// - Supports strict mode for sensitive operations (payments, transfers)
/// - Hardware-backed keystore on Android, Keychain on iOS
/// - Handles key invalidation on biometric change
/// - Graceful fallback on unsupported devices
///
/// **Quick Start:**
///
/// ```dart
/// final auth = AuthGrace(
///   options: AuthGraceOptions(
///     gracePeriodSeconds: 30,
///     reason: 'Authenticate to open',
///   ),
/// );
///
/// await auth.init();
/// final result = await auth.authenticate();
///
/// if (result.isSuccess) {
///   // User authenticated or grace period active
/// }
/// ```
///
/// **For Payment Flows (strict mode):**
///
/// ```dart
/// final strictAuth = AuthGrace(
///   options: AuthGraceOptions(alwaysRequire: true),
/// );
/// await strictAuth.authenticate();
/// ```
///
/// **Lifecycle Management:**
///
/// Call [AuthGrace.init] once at app startup to set up the keystore/keychain.
/// Call [AuthGrace.reset] on logout or user account switch to clear the grace period.
/// Call [AuthGrace.authenticate] when you need to verify user identity.
///
/// See also:
/// - [AuthGrace] - main class for authentication
/// - [AuthGraceOptions] - configuration options
/// - [AuthResult] - authentication result with status and method
library;

export 'src/auth_grace_base.dart';
export 'src/auth_grace_builder.dart';
export 'src/auth_grace_options.dart';
export 'src/auth_grace_result.dart';
