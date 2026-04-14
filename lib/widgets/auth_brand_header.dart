import 'package:flutter/material.dart';

import '../theme/spendly_auth_theme.dart';

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.subtitle,
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Semantics(
            label: 'Spendly',
            child: Image.asset(
              'assets/images/spendly_logo.png',
              height: 96,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Spendly',
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: SpendlyAuthTheme.mutedGrey,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
