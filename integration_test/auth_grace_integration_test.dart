import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:auth_grace/auth_grace.dart';

/// Integration tests for auth_grace.
///
/// These tests run on a real device or emulator and exercise the native
/// Keystore / Keychain layer. They do NOT trigger the biometric prompt —
/// only the non-interactive native calls are tested here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AuthGrace auth;

  setUp(() async {
    auth = AuthGrace(
      options: const AuthGraceOptions(
        gracePeriodSeconds: 5,
        keyName: 'com.authgrace.integration_test_key',
      ),
    );
    // Reset before each test to start with a clean state
    await auth.reset();
  });

  tearDown(() async {
    await auth.reset();
  });

  // ─── init() ──────────────────────────────────────────────────────────────

  group('init()', () {
    testWidgets('completes without error', (tester) async {
      await expectLater(auth.init(), completes);
    });

    testWidgets('can be called multiple times', (tester) async {
      await auth.init();
      await expectLater(auth.init(), completes);
    });

    testWidgets('works with custom grace period', (tester) async {
      final custom = AuthGrace(
        options: const AuthGraceOptions(
          gracePeriodSeconds: 30,
          keyName: 'com.authgrace.integration_test_key_30s',
        ),
      );
      await expectLater(custom.init(), completes);
      await custom.reset();
    });
  });

  // ─── isWithinGracePeriod() ────────────────────────────────────────────────

  group('isWithinGracePeriod()', () {
    testWidgets('returns a bool', (tester) async {
      await auth.init();
      final result = await auth.isWithinGracePeriod();
      expect(result, isA<bool>());
    });

    testWidgets('returns false before any authentication', (tester) async {
      await auth.init();
      // Key exists but no auth has occurred, so grace window is not active
      final result = await auth.isWithinGracePeriod();
      expect(result, false);
    });
  });

  // ─── isHardwareBacked() ───────────────────────────────────────────────────

  group('isHardwareBacked()', () {
    testWidgets('returns a bool', (tester) async {
      final result = await auth.isHardwareBacked();
      expect(result, isA<bool>());
    });
  });

  // ─── reset() ──────────────────────────────────────────────────────────────

  group('reset()', () {
    testWidgets('completes without error', (tester) async {
      await auth.init();
      await expectLater(auth.reset(), completes);
    });

    testWidgets('can be called when key does not exist', (tester) async {
      // reset() was already called in setUp — calling again should be safe
      await expectLater(auth.reset(), completes);
    });

    testWidgets('grace period is false after reset', (tester) async {
      await auth.init();
      await auth.reset();
      await auth.init();
      final inGrace = await auth.isWithinGracePeriod();
      expect(inGrace, false);
    });
  });

  // ─── isAvailable() ────────────────────────────────────────────────────────

  group('isAvailable()', () {
    testWidgets('returns a bool', (tester) async {
      final result = await auth.isAvailable();
      expect(result, isA<bool>());
    });
  });

  // ─── AuthGraceOptions ─────────────────────────────────────────────────────

  group('AuthGraceOptions round-trip', () {
    testWidgets('custom keyName is preserved on the instance', (tester) async {
      const opts = AuthGraceOptions(
        keyName: 'com.example.mykey',
        gracePeriodSeconds: 10,
      );
      final a = AuthGrace(options: opts);
      expect(a.options.keyName, 'com.example.mykey');
      expect(a.options.gracePeriodSeconds, 10);
    });
  });
}
