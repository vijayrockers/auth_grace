import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auth_grace/auth_grace.dart';

const _authGraceChannel = MethodChannel('auth_grace');
const _localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

/// Sets up standard mock handlers for both channels.
///
/// [isWithinGracePeriod] controls what the grace period check returns.
/// Defaults to false (grace period expired) to match `auth_grace_test.dart` convention.
void _mockChannels({bool isWithinGracePeriod = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_authGraceChannel, (call) async {
    switch (call.method) {
      case 'generateKey':
        return true;
      case 'isWithinGracePeriod':
        return isWithinGracePeriod;
      case 'markAuthenticated':
        return true;
      case 'isHardwareBacked':
        return true;
      case 'deleteKey':
        return true;
      default:
        return null;
    }
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localAuthChannel, (call) async {
    switch (call.method) {
      case 'authenticate':
        return true;
      case 'isDeviceSupported':
        return true;
      case 'canCheckBiometrics':
        return true;
      case 'getAvailableBiometrics':
        return <String>['fingerprint'];
      default:
        return null;
    }
  });
}

void _clearMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_authGraceChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localAuthChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(_clearMocks);

  group('AuthGraceBuilder', () {
    testWidgets('shows loadingWidget while first auth is in progress',
        (tester) async {
      // Use a Completer to hold isWithinGracePeriod in-flight reliably.
      final completer = Completer<dynamic>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        if (call.method == 'isWithinGracePeriod') return await completer.future;
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_localAuthChannel, (call) async => null);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGraceBuilder(
            auth: AuthGrace(),
            builder: (ctx, result) => const Text('done'),
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('loading'), findsOneWidget);
      expect(find.text('done'), findsNothing);

      completer.complete(true); // grace period active → auth completes
      await tester.pumpAndSettle();

      expect(find.text('done'), findsOneWidget);
      expect(find.text('loading'), findsNothing);
    });

    testWidgets('calls authenticate() exactly once on initState and passes result to builder',
        (tester) async {
      int gracePeriodCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        if (call.method == 'isWithinGracePeriod') {
          gracePeriodCallCount++;
          return true; // grace period active
        }
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_localAuthChannel, (call) async => null);

      AuthResult? received;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGraceBuilder(
            auth: AuthGrace(),
            builder: (ctx, result) {
              received = result;
              return const Text('done');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(gracePeriodCallCount, 1); // authenticate() called exactly once
      expect(received, isNotNull);
      expect(received!.status, AuthStatus.gracePeriodActive);
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('calls onResult with the result after setState', (tester) async {
      // Default mock: grace period active → AuthStatus.gracePeriodActive
      _mockChannels(isWithinGracePeriod: true);

      final results = <AuthResult>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGraceBuilder(
            auth: AuthGrace(),
            builder: (ctx, result) => const Text('done'),
            onResult: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first.status, AuthStatus.gracePeriodActive);
    });

    testWidgets('re-auths when AppLifecycleState.resumed fires', (tester) async {
      int gracePeriodCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authGraceChannel, (call) async {
        if (call.method == 'isWithinGracePeriod') {
          gracePeriodCallCount++;
          return true; // grace period active — fast path, no local_auth needed
        }
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_localAuthChannel, (call) async => null);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGraceBuilder(
            auth: AuthGrace(),
            builder: (ctx, result) => const Text('done'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(gracePeriodCallCount, 1); // initial call

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(gracePeriodCallCount, 2); // resume triggered a second call
    });
  });
}
