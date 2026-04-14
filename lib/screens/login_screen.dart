import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/social_auth_service.dart';
import '../theme/spendly_auth_theme.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/social_sign_in_section.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthApiService();
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onGoogle() async {
    setState(() => _busy = true);
    try {
      final result = await SocialAuthService.signInWithGoogleForBackend();
      if (!mounted) return;
      if (result == null) return;
      await _auth.loginWithGoogle(result.idToken);
      if (!mounted) return;
      widget.onSignedIn();
    } on AuthApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e, st) {
      if (mounted) _toast(SocialAuthService.describeError(e, st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onApple() async {
    setState(() => _busy = true);
    try {
      final credential = await SocialAuthService.signInWithApple();
      if (!mounted) return;
      final id = credential.userIdentifier ?? 'Apple user';
      _toast('Apple sign-in ($id) — backend not wired yet');
    } catch (e, st) {
      if (mounted) _toast(SocialAuthService.describeError(e, st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSignUp() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignUpScreen(
          onRegistered: () {
            Navigator.of(context).pop();
            widget.onSignedIn();
          },
        ),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  Future<void> _onEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('Enter email and password');
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.login(email: email, password: password);
      if (!mounted) return;
      widget.onSignedIn();
    } on AuthApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w500,
    );
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Material(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBrandHeader(subtitle: 'Sign in to your account'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  style: fieldStyle,
                  decoration: SpendlyAuthTheme.inputDecoration(
                    hint: 'Email',
                    prefix: const Icon(
                      Icons.mail_outline_rounded,
                      color: Colors.black87,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _onEmailLogin(),
                  style: fieldStyle,
                  decoration: SpendlyAuthTheme.inputDecoration(
                    hint: 'Password',
                    prefix: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.black87,
                      size: 22,
                    ),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.black54,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _openForgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        decorationThickness: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _onEmailLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 28),
                SocialSignInSection(
                  busy: _busy,
                  onGooglePressed: _onGoogle,
                  onApplePressed: _onApple,
                ),
                const SizedBox(height: 28),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 8,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: textTheme.bodyMedium?.copyWith(
                          color: SpendlyAuthTheme.mutedGrey,
                        ),
                      ),
                      TextButton(
                        onPressed: _openSignUp,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationThickness: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
