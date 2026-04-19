import 'package:flutter/material.dart';
import 'auth_grace_base.dart';
import 'auth_grace_result.dart';

/// A widget that wraps [AuthGrace.authenticate] with automatic Flutter
/// lifecycle management.
///
/// Calls [AuthGrace.authenticate] once on mount and again each time the app
/// returns to the foreground ([AppLifecycleState.resumed]).
///
/// The caller is responsible for calling [AuthGrace.init] before this widget
/// is first rendered.
///
/// ```dart
/// AuthGraceBuilder(
///   auth: myAuthGrace,
///   builder: (context, result) {
///     if (result.isSuccess) return const HomePage();
///     return const LockScreen();
///   },
/// )
/// ```
class AuthGraceBuilder extends StatefulWidget {
  /// The [AuthGrace] instance to authenticate with.
  ///
  /// The caller is responsible for calling [AuthGrace.init] before this
  /// widget is first rendered.
  final AuthGrace auth;

  /// Builds the widget tree given the latest [AuthResult].
  ///
  /// Not called until the first [AuthGrace.authenticate] completes.
  final Widget Function(BuildContext context, AuthResult result) builder;

  /// Called after every [AuthGrace.authenticate] completes, including the
  /// initial call triggered from [State.initState].
  ///
  /// Fires for **all** [AuthStatus] values — [AuthStatus.success],
  /// [AuthStatus.gracePeriodActive], [AuthStatus.failed],
  /// [AuthStatus.notAvailable], and [AuthStatus.error].
  ///
  /// Fires **after** [setState] — the builder has already re-rendered with
  /// the new result before this callback is invoked.
  ///
  /// Not called if the widget is disposed while an auth call is in-flight.
  ///
  /// Use for logging, analytics, or navigation side effects.
  final void Function(AuthResult result)? onResult;

  /// Shown while the first [AuthGrace.authenticate] call is in progress.
  ///
  /// Defaults to `Center(child: CircularProgressIndicator())` when `null`.
  final Widget? loadingWidget;

  /// Creates an [AuthGraceBuilder].
  const AuthGraceBuilder({
    super.key,
    required this.auth,
    required this.builder,
    this.onResult,
    this.loadingWidget,
  });

  @override
  State<AuthGraceBuilder> createState() => _AuthGraceBuilderState();
}

class _AuthGraceBuilderState extends State<AuthGraceBuilder>
    with WidgetsBindingObserver {
  AuthResult? _result;
  bool _isAuthInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runAuth();
    }
  }

  Future<void> _runAuth() async {
    if (_isAuthInFlight) return;
    _isAuthInFlight = true;

    AuthResult? result;
    try {
      result = await widget.auth.authenticate();
    } finally {
      _isAuthInFlight = false;
    }

    if (!mounted || result == null) return;
    setState(() => _result = result);
    widget.onResult?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, result);
  }
}
