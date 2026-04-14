import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/social_auth_service.dart';
import '../theme/spendly_auth_theme.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/social_sign_in_section.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.onRegistered});

  final VoidCallback onRegistered;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthApiService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      widget.onRegistered();
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

  Future<void> _onCreateAccount() async {
    if (_passwordController.text != _confirmController.text) {
      _toast('Passwords do not match');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _toast('Enter email and password');
      return;
    }
    if (password.length < 8) {
      _toast('Password must be at least 8 characters');
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.register(email: email, password: password, name: name.isEmpty ? null : name);
      if (!mounted) return;
      widget.onRegistered();
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
                const AuthBrandHeader(subtitle: 'Create your account'),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: fieldStyle,
                  decoration: SpendlyAuthTheme.inputDecoration(
                    hint: 'Full name',
                    prefix: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.black87,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _onCreateAccount(),
                  style: fieldStyle,
                  decoration: SpendlyAuthTheme.inputDecoration(
                    hint: 'Confirm password',
                    prefix: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.black87,
                      size: 22,
                    ),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.black54,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _onCreateAccount,
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
                    child: const Text('Create account'),
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
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: SpendlyAuthTheme.mutedGrey,
                            ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                          'Log in',
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
