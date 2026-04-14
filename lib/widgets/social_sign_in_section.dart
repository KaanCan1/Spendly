import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/spendly_auth_theme.dart';

/// Divider + outlined Google / Apple buttons (minimal monochrome style).
class SocialSignInSection extends StatelessWidget {
  const SocialSignInSection({
    super.key,
    required this.onGooglePressed,
    required this.onApplePressed,
    this.busy = false,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: SpendlyAuthTheme.borderGrey)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: textTheme.bodySmall?.copyWith(
                  color: SpendlyAuthTheme.mutedGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(child: Divider(color: SpendlyAuthTheme.borderGrey)),
          ],
        ),
        const SizedBox(height: 20),
        _SocialButton(
          label: 'Continue with Google',
          icon: FontAwesomeIcons.google,
          onPressed: busy ? null : onGooglePressed,
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: 'Continue with Apple',
          icon: FontAwesomeIcons.apple,
          onPressed: busy ? null : onApplePressed,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: SpendlyAuthTheme.borderGrey, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}
