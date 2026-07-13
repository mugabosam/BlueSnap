/// BlueSnap Lock Screen — real on-device app lock (PIN + optional biometric).
///
/// Shown on launch whenever a profile exists. Nothing in the app is reachable
/// until the correct PIN is entered (or biometrics succeed). This replaces the
/// former placeholder login that accepted any password.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../data/database/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/pin_pad.dart';

class LockScreen extends StatefulWidget {
  /// Called once the user successfully unlocks.
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = AuthService();
  String _entry = '';
  bool _error = false;
  bool _checking = false;
  bool _biometricReady = false;
  String? _lockMsg; // shown when the account is temporarily locked out

  @override
  void initState() {
    super.initState();
    _maybeBiometric();
  }

  Future<void> _maybeBiometric() async {
    final ready = await _auth.biometricEnabled && await _auth.biometricsAvailable;
    if (mounted) setState(() => _biometricReady = ready);
    if (ready) {
      final ok = await _auth.authenticateBiometric();
      if (ok && mounted) widget.onUnlocked();
    }
  }

  Future<void> _onDigit(String d) async {
    if (_checking || _entry.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entry += d;
      _error = false;
    });
    if (_entry.length >= 4) {
      // Allow up to 6 but verify eagerly at 4+ on submit via a short debounce.
    }
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    if (_entry.length < 4) return;
    setState(() => _checking = true);

    final lock = await _auth.lockoutRemaining();
    if (lock > Duration.zero) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _lockMsg = 'Too many attempts. Try again in ${_fmt(lock)}.';
        _entry = '';
        _checking = false;
      });
      return;
    }

    final ok = await _auth.verifyPin(_entry);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      final after = await _auth.lockoutRemaining();
      if (!mounted) return;
      setState(() {
        _error = true;
        _lockMsg = after > Duration.zero
            ? 'Too many attempts. Try again in ${_fmt(after)}.'
            : null;
        _entry = '';
        _checking = false;
      });
    }
  }

  String _fmt(Duration d) => d.inMinutes >= 1
      ? '${d.inMinutes} min'
      : '${d.inSeconds} sec';

  @override
  Widget build(BuildContext context) {
    final user = DatabaseService().currentUser;
    return Scaffold(
      backgroundColor: BlueSnapTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            UserAvatar(
              name: user?.displayName ?? 'BlueSnap',
              colorIndex: user?.avatarColorIndex ?? 0,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              user != null ? 'Welcome back, ${user.displayName.split(' ').first}'
                            : 'Enter your PIN',
              style: BlueSnapTheme.headingS,
            ),
            const SizedBox(height: 6),
            Text(
              _lockMsg ??
                  (_error ? 'Wrong PIN, try again' : 'Enter your PIN to unlock'),
              textAlign: TextAlign.center,
              style: BlueSnapTheme.bodyS.copyWith(
                color: (_error || _lockMsg != null)
                    ? BlueSnapTheme.accentRed
                    : BlueSnapTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            _dots(),
            const Spacer(),
            PinPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onSubmit: _submit,
              showBiometric: _biometricReady,
              onBiometric: _maybeBiometric,
            ),
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
              color: _error
                  ? BlueSnapTheme.accentRed
                  : filled
                      ? BlueSnapTheme.primary
                      : BlueSnapTheme.textTertiary,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}
