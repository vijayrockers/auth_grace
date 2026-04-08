# auth_grace — Flutter Plugin Specification

> Use this document with Claude Code (VS Code) to scaffold and generate the full plugin.
> Prompt: "Read this spec and generate the complete auth_grace Flutter plugin."

---

## 1. Package Overview

| Field | Value |
|---|---|
| Package name | `auth_grace` |
| Type | Flutter federated plugin |
| Platforms | Android, iOS |
| Dart SDK | `>=3.0.0 <4.0.0` |
| Flutter SDK | `>=3.10.0` |
| License | MIT |

### One-line description
> Smart biometric authentication with automatic grace period — skips the prompt if the phone was recently unlocked, exactly like GPay.

### Problem it solves
`local_auth` only shows a biometric prompt. It has no concept of a grace period. Developers building fintech, wallet, or sensitive apps have to manually implement Android Keystore grace period logic + iOS Keychain timestamp tracking. `auth_grace` packages this into a single clean API.

---

## 2. Package Structure

```
auth_grace/
├── android/
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/com/authgrace/
│           ├── AuthGracePlugin.kt
│           └── AuthKeyManager.kt
├── ios/
│   └── Classes/
│       ├── AuthGracePlugin.swift
│       └── AuthGraceSession.swift
├── lib/
│   ├── auth_grace.dart                  ← main export
│   └── src/
│       ├── auth_grace_base.dart         ← core AuthGrace class
│       ├── auth_grace_options.dart      ← AuthGraceOptions model
│       └── auth_grace_result.dart       ← AuthResult + AuthStatus + AuthMethod enums
├── test/
│   └── auth_grace_test.dart
├── example/
│   └── lib/
│       └── main.dart
├── pubspec.yaml
├── CHANGELOG.md
├── README.md
└── LICENSE
```

---

## 3. Dependencies

### pubspec.yaml
```yaml
name: auth_grace
description: Smart biometric auth with grace period. Skips prompt if phone was recently unlocked.
version: 0.0.1
homepage: https://github.com/yourusername/auth_grace

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  local_auth: ^2.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  plugin:
    platforms:
      android:
        package: com.authgrace
        pluginClass: AuthGracePlugin
      ios:
        pluginClass: AuthGracePlugin
```

---

## 4. Dart API

### 4.1 AuthGraceOptions

```dart
class AuthGraceOptions {
  final int gracePeriodSeconds;   // default: 30
  final bool alwaysRequire;       // default: false — set true for payment confirmation
  final String reason;            // biometric dialog message
  final bool allowDeviceCredential; // allow PIN/pattern fallback, default: true
  final String keyName;           // custom keystore key name, default: 'com.authgrace.auth_grace_key'
}
```

### 4.2 AuthResult

```dart
class AuthResult {
  final AuthStatus status;
  final AuthMethod method;
  final String? error;
  bool get isSuccess => status == AuthStatus.success || status == AuthStatus.gracePeriodActive;
}

enum AuthStatus {
  success,           // biometric/PIN passed
  gracePeriodActive, // phone recently unlocked — skipped prompt
  failed,            // biometric failed or cancelled
  notAvailable,      // device has no biometric hardware
  error,             // unexpected error
}

enum AuthMethod {
  biometric,         // face/fingerprint used
  deviceCredential,  // PIN/pattern used
  gracePeriod,       // skipped — recent phone unlock
  none,              // not authenticated
}
```

### 4.3 AuthGrace (main class)

```dart
class AuthGrace {
  AuthGrace({AuthGraceOptions? options});

  // Call once at app startup
  Future<void> init();

  // Main method — smart auth with grace period
  Future<AuthResult> authenticate();

  // Check grace period without prompting
  Future<bool> isWithinGracePeriod();

  // Check device capability
  Future<bool> isAvailable();
  Future<bool> isHardwareBacked();

  // Reset — call on logout or user switch
  Future<void> reset();
}
```

### 4.4 Usage Example

```dart
// Simple usage
final auth = AuthGrace(
  options: AuthGraceOptions(
    gracePeriodSeconds: 30,
    reason: 'Authenticate to open',
  ),
);

await auth.init();

final result = await auth.authenticate();
if (result.isSuccess) {
  // open app
}

// Strict mode — always require (for payments)
final strictAuth = AuthGrace(
  options: AuthGraceOptions(alwaysRequire: true),
);
await strictAuth.authenticate();
```

---

## 5. MethodChannel Contract

Channel name: `"auth_grace"`

| Method | Arguments | Returns | Description |
|---|---|---|---|
| `generateKey` | `gracePeriodSeconds: int` | `bool` | Create Keystore key with grace window |
| `isWithinGracePeriod` | none | `bool` | Check if phone unlocked recently |
| `keyExists` | none | `bool` | Check if key already generated |
| `deleteKey` | none | `bool` | Delete key on logout/reset |
| `isHardwareBacked` | none | `bool` | Check if device has secure TEE |

---

## 6. Android Native — Full Implementation

### 6.1 AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />
</manifest>
```

### 6.2 AuthKeyManager.kt

```kotlin
package com.authgrace

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.UserNotAuthenticatedException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

object AuthKeyManager {

    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    // IMPORTANT: namespaced key name to avoid collision with other packages
    private const val DEFAULT_KEY_NAME = "com.authgrace.auth_grace_key"
    private const val TRANSFORMATION =
        "${KeyProperties.KEY_ALGORITHM_AES}/" +
        "${KeyProperties.BLOCK_MODE_CBC}/" +
        "${KeyProperties.ENCRYPTION_PADDING_PKCS7}"

    fun generateKey(gracePeriodSeconds: Int, keyName: String = DEFAULT_KEY_NAME) {
        val builder = KeyGenParameterSpec.Builder(
            keyName,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            .setUserAuthenticationRequired(true)

        // Android 11+ (API 30): use newer API for better auth type control
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                gracePeriodSeconds,
                KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(gracePeriodSeconds)
        }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        keyGenerator.init(builder.build())
        keyGenerator.generateKey()
    }

    fun isWithinGracePeriod(keyName: String = DEFAULT_KEY_NAME): Boolean {
        // Emulator has no real TEE — skip Keystore check entirely
        if (isEmulator()) return false

        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)

            val key = keyStore.getKey(keyName, null) as? SecretKey ?: return false

            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)

            // Success = phone was unlocked within grace period
            true

        } catch (e: UserNotAuthenticatedException) {
            // Grace period expired
            false

        } catch (e: KeyPermanentlyInvalidatedException) {
            // User changed biometrics — silently delete and regenerate
            deleteKey(keyName)
            false

        } catch (e: Exception) {
            false
        }
    }

    fun keyExists(keyName: String = DEFAULT_KEY_NAME): Boolean {
        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)
            keyStore.containsAlias(keyName)
        } catch (e: Exception) {
            false
        }
    }

    fun deleteKey(keyName: String = DEFAULT_KEY_NAME) {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)
            if (keyStore.containsAlias(keyName)) {
                keyStore.deleteEntry(keyName)
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    fun isHardwareBacked(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
                keyStore.load(null)
                true // If we can load AndroidKeyStore on API 31+, TEE exists
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || Build.BRAND.startsWith("generic"))
    }
}
```

### 6.3 AuthGracePlugin.kt

```kotlin
package com.authgrace

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AuthGracePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "auth_grace")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val keyName = call.argument<String>("keyName") ?: "com.authgrace.auth_grace_key"

        when (call.method) {
            "generateKey" -> {
                val seconds = call.argument<Int>("gracePeriodSeconds") ?: 30
                try {
                    AuthKeyManager.generateKey(seconds, keyName)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("KEY_GEN_FAILED", e.message, null)
                }
            }
            "isWithinGracePeriod" -> {
                result.success(AuthKeyManager.isWithinGracePeriod(keyName))
            }
            "keyExists" -> {
                result.success(AuthKeyManager.keyExists(keyName))
            }
            "deleteKey" -> {
                AuthKeyManager.deleteKey(keyName)
                result.success(true)
            }
            "isHardwareBacked" -> {
                result.success(AuthKeyManager.isHardwareBacked())
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
```

---

## 7. iOS Native — Full Implementation

### 7.1 AuthGraceSession.swift
```swift
import Foundation
import Security

class AuthGraceSession {

    private static let keychainKey = "com.authgrace.last_auth_time"

    // Save current timestamp after successful auth
    static func markAuthenticated() {
        let timestamp = Date().timeIntervalSince1970
        let data = withUnsafeBytes(of: timestamp) { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary) // delete old value
        SecItemAdd(query as CFDictionary, nil)
    }

    // Check if last auth is within grace window
    static func isWithinGracePeriod(seconds: Int) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              data.count == MemoryLayout<Double>.size else {
            return false
        }

        let lastAuth = data.withUnsafeBytes { $0.load(as: Double.self) }
        let elapsed = Date().timeIntervalSince1970 - lastAuth
        return elapsed < Double(seconds)
    }

    // Clear on logout
    static func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### 7.2 AuthGracePlugin.swift
```swift
import Flutter
import LocalAuthentication

public class AuthGracePlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "auth_grace", binaryMessenger: registrar.messenger())
        let instance = AuthGracePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let gracePeriodSeconds = args?["gracePeriodSeconds"] as? Int ?? 30

        switch call.method {
        case "generateKey":
            // iOS: no key generation needed — we use Keychain timestamp
            result(true)

        case "isWithinGracePeriod":
            result(AuthGraceSession.isWithinGracePeriod(seconds: gracePeriodSeconds))

        case "keyExists":
            // Always true on iOS — we use timestamp approach
            result(true)

        case "deleteKey":
            AuthGraceSession.clearSession()
            result(true)

        case "isHardwareBacked":
            // iOS always uses Secure Enclave on supported devices
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

> **Note for Claude Code:** On iOS, grace period is tracked via Keychain timestamp (last successful `local_auth` call). Call `AuthGraceSession.markAuthenticated()` after every successful biometric prompt.

---

## 8. Dart Layer — Full Implementation

### 8.1 auth_grace_options.dart
```dart
class AuthGraceOptions {
  final int gracePeriodSeconds;
  final bool alwaysRequire;
  final String reason;
  final bool allowDeviceCredential;
  final String keyName;

  const AuthGraceOptions({
    this.gracePeriodSeconds = 30,
    this.alwaysRequire = false,
    this.reason = 'Authenticate to continue',
    this.allowDeviceCredential = true,
    this.keyName = 'com.authgrace.auth_grace_key',
  });
}
```

### 8.2 auth_grace_result.dart
```dart
enum AuthStatus { success, gracePeriodActive, failed, notAvailable, error }
enum AuthMethod { biometric, deviceCredential, gracePeriod, none }

class AuthResult {
  final AuthStatus status;
  final AuthMethod method;
  final String? error;

  const AuthResult({
    required this.status,
    this.method = AuthMethod.none,
    this.error,
  });

  bool get isSuccess =>
      status == AuthStatus.success || status == AuthStatus.gracePeriodActive;

  @override
  String toString() => 'AuthResult(status: $status, method: $method, error: $error)';
}
```

### 8.3 auth_grace_base.dart
```dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_grace_options.dart';
import 'auth_grace_result.dart';

class AuthGrace {
  final AuthGraceOptions options;
  final _localAuth = LocalAuthentication();
  static const _channel = MethodChannel('auth_grace');

  AuthGrace({AuthGraceOptions? options})
      : options = options ?? const AuthGraceOptions();

  // Call once at app startup
  Future<void> init() async {
    final exists = await _invokeMethod<bool>('keyExists') ?? false;
    if (!exists) {
      await _invokeMethod<bool>('generateKey', {
        'gracePeriodSeconds': options.gracePeriodSeconds,
        'keyName': options.keyName,
      });
    }
  }

  // Main auth method
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
        options: AuthenticationOptions(
          biometricOnly: !options.allowDeviceCredential,
          stickyAuth: true,
        ),
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

    } catch (e) {
      return AuthResult(
        status: AuthStatus.error,
        method: AuthMethod.none,
        error: e.toString(),
      );
    }
  }

  Future<bool> isWithinGracePeriod() async {
    return await _invokeMethod<bool>('isWithinGracePeriod', {
          'gracePeriodSeconds': options.gracePeriodSeconds,
          'keyName': options.keyName,
        }) ??
        false;
  }

  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isHardwareBacked() async {
    return await _invokeMethod<bool>('isHardwareBacked') ?? false;
  }

  // Call on logout or user account switch
  Future<void> reset() async {
    await _invokeMethod<bool>('deleteKey', {'keyName': options.keyName});
  }

  Future<void> _markAuthenticated() async {
    // iOS only — Android handles this natively via Keystore
    await _invokeMethod<bool>('markAuthenticated');
  }

  Future<T?> _invokeMethod<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }
}
```

### 8.4 auth_grace.dart (main export)
```dart
library auth_grace;

export 'src/auth_grace_base.dart';
export 'src/auth_grace_options.dart';
export 'src/auth_grace_result.dart';
```

---

## 9. Example App

```dart
// example/lib/main.dart
import 'package:flutter/material.dart';
import 'package:auth_grace/auth_grace.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(home: const HomeScreen());
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _auth = AuthGrace(
    options: const AuthGraceOptions(gracePeriodSeconds: 30),
  );
  bool _authenticated = false;
  String _status = 'Not authenticated';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _auth.init();
    _checkAuth();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAuth();
  }

  Future<void> _checkAuth() async {
    final result = await _auth.authenticate();
    setState(() {
      _authenticated = result.isSuccess;
      _status = '${result.status} via ${result.method}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('auth_grace example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _authenticated ? Icons.lock_open : Icons.lock,
              size: 64,
              color: _authenticated ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(_status),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkAuth,
              child: const Text('Authenticate'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 10. Edge Cases to Handle

| Case | Handling |
|---|---|
| Emulator | `isEmulator()` check — skip Keystore, fall through to `local_auth` |
| Key invalidated after biometric change | Catch `KeyPermanentlyInvalidatedException` — delete and regenerate |
| No biometric hardware | `isAvailable()` check — return `AuthStatus.notAvailable` |
| `gracePeriodSeconds = 0` | Always require biometric — no grace |
| `alwaysRequire = true` | Skip grace period check — always prompt |
| App resumed from background | Re-check auth in `didChangeAppLifecycleState` |
| Logout / user switch | Call `auth.reset()` — deletes Keystore key and Keychain timestamp |

---

## 11. Known Limitations

- Grace period on Android is managed by OS Keystore — exact timing may vary by 1–2 seconds
- iOS grace period is approximated via Keychain timestamp — not hardware-enforced like Android
- Emulators always skip grace period (by design)
- Devices below Android 6.0 (API 23) are not supported
- `alwaysRequire: true` on iOS still has a brief LAContext session (~30s) — this is iOS system behavior and cannot be overridden

---

## 12. Pub.dev Publishing Checklist

- [ ] `dart analyze` — zero issues
- [ ] `flutter test` — all pass
- [ ] `dart pub publish --dry-run` — no errors
- [ ] All public APIs have `dartdoc` comments
- [ ] `CHANGELOG.md` has version `0.0.1` entry
- [ ] `README.md` has install, usage, and platform table
- [ ] Example app runs on real Android device
- [ ] Example app runs on real iOS device
- [ ] Tested with `gracePeriodSeconds: 0` (strict mode)
- [ ] Tested biometric change invalidation flow

---

## 13. Prompt for Claude Code

Use this exact prompt in Claude Code (VS Code):

```
Read the auth_grace_plugin_spec.md file and generate the complete Flutter plugin.
Create all files exactly as specified in Section 2 (Package Structure).
Use the full code from Sections 6, 7, and 8 for native and Dart implementations.
Make sure MainActivity.kt in the example app extends FlutterFragmentActivity.
After generating all files, run `flutter pub get` in the example directory.
```
