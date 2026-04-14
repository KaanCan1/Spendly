import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_api_service.dart';
import 'services/social_auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SpendlyApp());
}

class SpendlyApp extends StatelessWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        onSurface: Colors.black,
        primary: Colors.black,
        onPrimary: Colors.white,
      ),
    );

    return MaterialApp(
      title: 'Spendly',
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: false,
          iconColor: Colors.black87,
          prefixIconColor: Colors.black87,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthApiService();
  bool _loading = true;
  bool _signedIn = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    Map<String, dynamic>? me;
    try {
      me = await _auth.fetchMe().timeout(const Duration(seconds: 5));
    } on Object {
      me = null;
    }
    if (!mounted) return;
    setState(() {
      _profile = me;
      _signedIn = me != null;
      _loading = false;
    });
  }

  void _onSignedIn() {
    _bootstrap();
  }

  Future<void> _onSignOut() async {
    await SocialAuthService.signOutGoogle();
    await _auth.signOut();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _profile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_signedIn && _profile != null) {
      final email = _profile!['email'] as String? ?? '';
      final name = _profile!['name'] as String?;
      return HomeScreen(
        userEmail: email,
        userName: name,
        onSignOut: _onSignOut,
      );
    }

    return LoginScreen(onSignedIn: _onSignedIn);
  }
}
