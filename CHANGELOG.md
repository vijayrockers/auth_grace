## 0.0.5

* Fix: Example app now included in published package so pub.dev awards the example score point.
* Fix: Dart formatting applied to `lib/src/auth_grace_base.dart` to pass static analysis on pub.dev.
* Added demo GIF to README.

## 0.0.4

* Fix: README demo GIF now renders correctly on pub.dev.

## 0.0.3

* Fix: `init()` now always regenerates the Keystore key so changes to `gracePeriodSeconds` take effect immediately without requiring a reinstall.
* Fix: Grace period countdown is now driven by `isWithinGracePeriod()` polled every second — locks exactly when the Keystore expires, not based on a drifting Dart timer.
* Fix: `gracePeriodActive` (device-unlock grace) now shows the countdown timer in the example app.
* Example: Added circular countdown UI showing remaining grace window in seconds, turns orange at 2 seconds remaining.
* Example: Grace period timer auto-locks the UI when expired — no automatic re-prompt.

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
