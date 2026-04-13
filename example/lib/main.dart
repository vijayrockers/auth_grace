import 'dart:async';
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
  static const _gracePeriodSeconds = 7;

  final _auth = AuthGrace(
    options: const AuthGraceOptions(gracePeriodSeconds: _gracePeriodSeconds),
  );

  bool _authenticated = false;
  String _status = 'Not authenticated';
  int _countdown = 0;
  Timer? _countdownTicker;

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
      _status = '${result.status.name} via ${result.method.name}';
    });

    if (result.status == AuthStatus.success) {
      // Real biometric/PIN auth — start a fresh countdown from the full window
      _startCountdown();
    } else if (result.status == AuthStatus.gracePeriodActive) {
      // Device was recently unlocked — show countdown only if not already running
      if (_countdownTicker == null) _startCountdown();
    } else {
      // failed / notAvailable / error — clear timer, stay locked
      _cancelCountdown();
    }
  }

  void _startCountdown() {
    _cancelCountdown();
    setState(() => _countdown = _gracePeriodSeconds - 1);

    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Ask the Keystore directly — this is the source of truth.
      // Handles device-unlock grace (where we don't know the exact start time)
      // and absorbs Timer.periodic drift automatically.
      final stillValid = await _auth.isWithinGracePeriod();

      if (!stillValid) {
        _cancelCountdown();
        setState(() {
          _countdown = 0;
          _authenticated = false;
          _status = 'Grace period expired';
        });
        return;
      }

      if (_countdown <= 0) {
        _cancelCountdown();
        setState(() {
          _authenticated = false;
          _status = 'Grace period expired';
        });
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
  }

  @override
  void dispose() {
    _cancelCountdown();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        _gracePeriodSeconds > 0 ? _countdown / _gracePeriodSeconds : 0.0;

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
            const SizedBox(height: 24),
            Text(_status, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),

            // Countdown ring — only while authenticated and timer is running
            if (_authenticated && _countdown > 0) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.green.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _countdown <= 2 ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _countdown <= 2 ? Colors.orange : Colors.green,
                        ),
                      ),
                      Text(
                        'sec',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Grace window closes in $_countdown second${_countdown == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
            ] else ...[
              const SizedBox(height: 144),
            ],

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
