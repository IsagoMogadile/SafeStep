import 'package:flutter/material.dart';

/// Shared logo + tagline block for the auth screens (Welcome, Log In,
/// Create Account) — kept as one widget so the branding stays consistent
/// instead of three separate copies drifting apart.
class AuthBrandingHeader extends StatelessWidget {
  const AuthBrandingHeader({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.asset(
            'assets/icon/safestep_logo.jpeg',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your Safety Companion',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
