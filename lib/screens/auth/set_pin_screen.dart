/// BlueSnap Set-PIN screen — creates the app-lock during onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/pin_pad.dart';

class SetPinScreen extends StatefulWidget {
  /// Called once a PIN is set (and biometrics optionally enabled).
  final VoidCallback onComplete;
  const SetPinScreen({super.key, required this.onComplete});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _auth = AuthService();
  String _entry = '';
  String _firstEntry = '';
  bool _confirming = false;
  bool _mismatch = false;

  void _onDigit(String d) {
    if (_entry.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entry += d;
      _mismatch = false;
    });
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    // Require a full 6-digit PIN — meaningfully harder to guess than 4.
    if (_entry.length < 6) return;
    if (!_confirming) {
      setState(() {
        _firstEntry = _entry;
        _entry = '';
        _confirming = true;
      });
      return;
    }
    if (_entry != _firstEntry) {
      HapticFeedback.heavyImpact();
      setState(() {
        _mismatch = true;
        _entry = '';
        _firstEntry = '';
        _confirming = false;
      });
      return;
    }
    await _auth.setPin(_entry);
    // Offer biometrics if the device supports them.
    if (await _auth.biometricsAvailable && mounted) {
      final enable = await _askBiometric();
      await _auth.setBiometricEnabled(enable);
    }
    if (mounted) widget.onComplete();
  }

  Future<bool> _askBiometric() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BlueSnapTheme.bgCard,
        title: const Text('Enable biometric unlock?', style: BlueSnapTheme.headingS),
        content: Text(
          'Use your fingerprint or face to unlock BlueSnap faster. You can still use your PIN anytime.',
          style: BlueSnapTheme.bodyS,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now', style: TextStyle(color: BlueSnapTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable', style: TextStyle(color: BlueSnapTheme.primary)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline_rounded, size: 44, color: BlueSnapTheme.primary),
            const SizedBox(height: 16),
            Text(
              _confirming ? 'Confirm your PIN' : 'Create a PIN',
              style: BlueSnapTheme.headingS,
            ),
            const SizedBox(height: 6),
            Text(
              _mismatch
                  ? "PINs didn't match — try again"
                  : 'Locks your messages on this device (6 digits)',
              style: BlueSnapTheme.bodyS.copyWith(
                color: _mismatch ? BlueSnapTheme.accentRed : BlueSnapTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            _dots(),
            const Spacer(),
            PinPad(onDigit: _onDigit, onBackspace: _onBackspace, onSubmit: _submit),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < _entry.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? BlueSnapTheme.primary : Colors.transparent,
            border: Border.all(
              color: filled ? BlueSnapTheme.primary : BlueSnapTheme.textTertiary,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}
