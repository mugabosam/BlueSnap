/// BlueSnap Sign Up — local-only; collects profile, then avatar-color onboarding
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/shared_widgets.dart';
import '../onboarding/onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SignupScreen({super.key, required this.onComplete});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  void _signUp() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'Please enter your full name', isError: true);
      return;
    }
    // No backend and no password: the account lives on this device and is
    // protected by the app-lock PIN you set next. Carry the details into the
    // avatar-color step, which creates the local profile.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          onComplete: widget.onComplete,
          presetName: name,
          presetUsername: _username.text.trim().isEmpty
              ? null
              : _username.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: BlueSnapTheme.bgPrimary,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create account',
                    style: TextStyle(
                      fontFamily: BlueSnapTheme.fontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: BlueSnapTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join BlueSnap and start connecting with people nearby.',
                    style: BlueSnapTheme.bodyS
                        .copyWith(color: BlueSnapTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  AppTextField(hint: 'Full name', controller: _name),
                  const SizedBox(height: 10),
                  AppTextField(hint: 'Username (optional)', controller: _username),
                  const SizedBox(height: 24),

                  PillButton(label: 'Continue', onTap: _signUp),
                  const SizedBox(height: 16),
                  _terms(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _terms() {
    const base = TextStyle(
      fontFamily: BlueSnapTheme.fontFamily,
      fontSize: 11,
      color: BlueSnapTheme.textTertiary,
      height: 1.4,
    );
    const link = TextStyle(
      fontFamily: BlueSnapTheme.fontFamily,
      fontSize: 11,
      color: BlueSnapTheme.primary,
      height: 1.4,
    );
    return const Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: 'By signing up, you agree to our '),
          TextSpan(text: 'Terms', style: link),
          TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link),
          TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BlueSnapTheme.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: BlueSnapTheme.bodyS.copyWith(
                      color: BlueSnapTheme.textSecondary, fontSize: 13),
                ),
                Text(
                  'Log In',
                  style: TextStyle(
                    fontFamily: BlueSnapTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BlueSnapTheme.primary,
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
