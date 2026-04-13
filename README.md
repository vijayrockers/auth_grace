# auth_grace

[![pub package](https://img.shields.io/pub/v/auth_grace.svg)](https://pub.dev/packages/auth_grace)
[![pub points](https://img.shields.io/pub/points/auth_grace)](https://pub.dev/packages/auth_grace/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Smart biometric authentication with an automatic grace period — skips the
prompt if the phone was recently unlocked, exactly like Google Pay.

`local_auth` only shows a biometric prompt. `auth_grace` adds the missing
layer: if the device was unlocked within the last N seconds, authentication
is granted silently without interrupting the user.

<p align="center">
  <b>Grace period in action — no prompt while the device is still warm.</b>
</p>

<p align="center">
  <img src="https://github.com/vijayrockers/auth_grace/raw/main/assets/demo.gif" width="300" alt="auth_grace demo" />
</p>

---

## Platform support

| Android | iOS |
|:-------:|:---:|
| ✅ API 23+ | ✅ iOS 12+ |

**Android** — grace period is enforced at the hardware level via an Android
Keystore time-bound AES key (Trusted Execution Environment).

**iOS** — grace period is approximated via a Keychain timestamp recorded after
every successful `local_auth` prompt.

---

## Features

- ⚡ **Zero-friction re-auth** — skips the prompt while the device is still
  "warm" (recently unlocked)
- 🔒 **Strict mode** — `alwaysRequire: true` bypasses the grace period for
  payment confirmation flows
- 🔑 **Hardware-backed** — Android Keystore TEE, iOS Secure Enclave
- 🛡️ **Key invalidation handling** — silently regenerates the key when the
  user changes enrolled biometrics
- 📱 **Emulator-safe** — automatically falls back to `local_auth` on emulators
  (no real TEE)
- 🔄 **Lifecycle-aware** — re-authenticate on app resume via
  `WidgetsBindingObserver`

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  auth_grace: ^0.0.6
```

Then run:

```sh
flutter pub get
```

---

## Android setup

### 1. Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

### 2. MainActivity

`MainActivity` **must** extend `FlutterFragmentActivity` (required by
`local_auth` for the biometric dialog):

```kotlin
// android/app/src/main/kotlin/…/MainActivity.kt
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

---

## iOS setup

Add the `NSFaceIDUsageDescription` key to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Used to authenticate you when opening the app.</string>
```

No other setup is required.

---

## Usage

### Basic — 30-second grace window

```dart
import 'package:auth_grace/auth_grace.dart';

final auth = AuthGrace(
  options: const AuthGraceOptions(
    gracePeriodSeconds: 30,
    reason: 'Authenticate to open',
  ),
);

// Call once at app startup
await auth.init();

// Call whenever identity must be verified
final result = await auth.authenticate();
if (result.isSuccess) {
  // AuthStatus.success  → biometric / PIN passed
  // AuthStatus.gracePeriodActive → device was recently unlocked, prompt skipped
  navigateToHome();
}
```

### Strict mode — always prompt (payments)

```dart
final paymentAuth = AuthGrace(
  options: const AuthGraceOptions(
    alwaysRequire: true,
    reason: 'Confirm payment',
  ),
);

final result = await paymentAuth.authenticate();
```

### Re-authenticate on app resume

```dart
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final result = await auth.authenticate();
    // handle result
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

### Logout / account switch

```dart
// Clears Keystore key (Android) and Keychain timestamp (iOS)
await auth.reset();
```

---

## API reference

### `AuthGrace`

| Method | Returns | Description |
|--------|---------|-------------|
| `AuthGrace({AuthGraceOptions? options})` | — | Constructor. Defaults to a 30-second grace window. |
| `init()` | `Future<void>` | Generate the Keystore/Keychain key. Call once at startup. |
| `authenticate()` | `Future<AuthResult>` | Authenticate — skips prompt if within grace period. |
| `isWithinGracePeriod()` | `Future<bool>` | Check grace status without showing a prompt. |
| `isAvailable()` | `Future<bool>` | `true` if the device has enrolled biometrics or a PIN. |
| `isHardwareBacked()` | `Future<bool>` | `true` if the device has a hardware secure element. |
| `reset()` | `Future<void>` | Delete key/timestamp — call on logout. |

---

### `AuthGraceOptions`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gracePeriodSeconds` | `int` | `30` | Seconds after unlock before re-prompting. |
| `alwaysRequire` | `bool` | `false` | Always prompt regardless of grace period. |
| `reason` | `String` | `'Authenticate to continue'` | Biometric dialog message. |
| `allowDeviceCredential` | `bool` | `true` | Allow PIN/pattern as fallback. |
| `persistAcrossBackgrounding` | `bool` | `true` | Keep the biometric prompt visible when the app is backgrounded mid-auth. |
| `keyName` | `String` | `'com.authgrace.auth_grace_key'` | Custom Keystore key name. |

---

### `AuthResult`

| Property | Type | Description |
|----------|------|-------------|
| `status` | `AuthStatus` | High-level outcome (see below). |
| `method` | `AuthMethod` | How authentication was performed. |
| `error` | `String?` | Error message when `status == AuthStatus.error`. |
| `isSuccess` | `bool` | `true` for `success` **and** `gracePeriodActive`. |

---

### `AuthStatus` enum

| Value | Meaning |
|-------|---------|
| `success` | Biometric or PIN passed. |
| `gracePeriodActive` | Device was recently unlocked — prompt skipped. |
| `failed` | User cancelled or failed too many times. |
| `notAvailable` | No enrolled biometrics on this device. |
| `error` | Unexpected platform error — inspect `AuthResult.error`. |

---

### `AuthMethod` enum

| Value | Meaning |
|-------|---------|
| `biometric` | Face ID, Touch ID, or fingerprint sensor was used. |
| `deviceCredential` | PIN, pattern, or password was used as fallback. |
| `gracePeriod` | Prompt was skipped — device was recently unlocked. |
| `none` | No authentication took place. |

---

## Edge cases

| Scenario | Behaviour |
|----------|-----------|
| Emulator | `isEmulator()` detected — Keystore check skipped, falls through to `local_auth`. |
| Biometric enrolled/removed | `KeyPermanentlyInvalidatedException` caught — key deleted and regenerated silently. |
| No biometric hardware | `isAvailable()` returns `false` → `AuthStatus.notAvailable`. |
| `gracePeriodSeconds = 0` | Always requires authentication — no grace. |
| `alwaysRequire = true` | Grace period check skipped entirely. |
| App backgrounded and resumed | Call `authenticate()` in `didChangeAppLifecycleState`. |
| Logout / user switch | Call `auth.reset()` to delete key and Keychain timestamp. |

---

## Platform notes

**Android** — Grace period is enforced natively by the Android Keystore
hardware (TEE). The OS manages the auth window — your app code cannot
bypass it.

**iOS** — Grace period is simulated via a Keychain timestamp recorded
after each successful authentication. Functionally identical for most
use cases, but software-managed rather than hardware-enforced.

---

## Security model

`auth_grace` is a **UX friction layer**, not a cryptographic access control
system. Understanding its boundaries helps you use it correctly.

**What it protects against**

- A stranger picking up an unlocked phone after the grace period expires — the
  next open will require biometrics.
- Passive shoulder-surfing — the biometric prompt adds meaningful friction for
  casual observers.
- Unauthorized access after the device is re-locked.

**What it does NOT protect against**

- A coerced user (someone forced to authenticate) — no biometric library can
  prevent this.
- Rooted (Android) or jailbroken (iOS) devices — the Keystore / Keychain
  integrity guarantees do not hold on compromised systems.
- Access during the grace window itself — if someone grabs the phone in those
  30 seconds, they get in. That is the intended trade-off.
- iOS Keychain timestamp manipulation — the iOS grace period is
  software-managed. A sophisticated attacker with direct Keychain access could
  theoretically alter the timestamp. Android's TEE-enforced key is not
  vulnerable to this.

**Appropriate use cases**

Confirming the active user's identity before showing sensitive content (account
balance, health data) or initiating a local action (like Google Pay's
tap-to-pay). This mirrors how the OS itself uses biometrics.

**Not appropriate on its own for**

Authorising server-side transactions or protecting encryption keys. Always
pair `auth_grace` with server-side verification for any action with real
financial or security consequences.

---

## Known limitations

- Grace period timing on Android may vary by ±1–2 seconds (OS-level).
- iOS grace period is Keychain-timestamp-based, not hardware-enforced.
- Emulators always skip the grace period check (by design — no real TEE).
- Devices below Android 6.0 (API 23) are not supported.
- `alwaysRequire: true` on iOS still has a brief `LAContext` session (~30 s)
  — this is iOS system behaviour and cannot be overridden.

---

## License

[MIT](LICENSE)
