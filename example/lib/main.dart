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
