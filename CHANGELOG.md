## 0.0.2

* Fix: Updated `authenticate()` call for `local_auth` 3.x API — `AuthenticationOptions` replaced with flat parameters (`biometricOnly`, `persistAcrossBackgrounding`).
* `allowDeviceCredential: false` now correctly maps to `biometricOnly: true` in the prompt.
* Added pub.dev topic tags: `authentication`, `biometrics`, `security`, `local-auth`.
* Raised minimum Dart SDK constraint to `>=3.9.0` to align with `flutter_lints ^6.0.0`.
* Upgraded `flutter_lints` to `^6.0.0` — zero lint issues.
* Fix: `LocalAuthException` codes now map to correct `AuthStatus` instead of always returning `AuthStatus.error`.
  * `noCredentialsSet`, `noBiometricsEnrolled`, `noBiometricHardware` → `AuthStatus.notAvailable`.
  * `userCanceled`, `timeout`, `systemCanceled`, `userRequestedFallback` → `AuthStatus.failed`.
  * All other codes (lockout, device error, etc.) remain `AuthStatus.error`.

## 0.0.1

* Initial release.
* Smart biometric authentication with automatic grace period.
* Android implementation using Keystore with time-bound keys.
* iOS implementation using Keychain timestamp tracking.
* Support for `alwaysRequire` mode for payment confirmation flows.
