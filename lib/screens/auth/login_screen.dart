/// BlueSnap Welcome — shown only on a fresh install (no local profile yet).
///
/// There is no server login: identity lives entirely on this device. This
/// screen just introduces the app and routes into sign up, which creates the
/// local profile, identity key, and app-lock PIN.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/shared_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  /// Called once a local profile + PIN exist and the app should open.
  final VoidCallback onComplete;
  const LoginScreen({super.key, required this.onComplete});

  void _getStarted(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(onComplete: onComplete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // ── Brand ──────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'BlueSnap',
                style: TextStyle(
                  fontFamily: BlueSnapTheme.fontFamily,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: BlueSnapTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Connect with people around you.\nNo internet. No accounts on a server.',
                textAlign: TextAlign.center,
                style: BlueSnapTheme.bodyM.copyWith(color: BlueSnapTheme.textSecondary),
              ),
              const Spacer(flex: 3),
              PillButton(label: 'Get Started', onTap: () => _getStarted(context)),
              const SizedBox(height: 14),
              Text(
                'Your profile and messages stay on this device.',
                textAlign: TextAlign.center,
                style: BlueSnapTheme.caption.copyWith(color: BlueSnapTheme.textTertiary),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
