/// BlueSnap numeric PIN pad — used by the lock screen and PIN setup.
library;

import 'package:flutter/material.dart';
import '../core/theme.dart';

class PinPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool showBiometric;
  final VoidCallback? onBiometric;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    this.showBiometric = false,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final d in row) _key(d)],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              showBiometric
                  ? _iconKey(Icons.fingerprint, onBiometric ?? () {})
                  : const SizedBox(width: 72),
              _key('0'),
              _iconKey(Icons.backspace_outlined, onBackspace),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSubmit,
              style: TextButton.styleFrom(
                foregroundColor: BlueSnapTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Confirm',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(String digit) {
    return _KeyBase(
      onTap: () => onDigit(digit),
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: BlueSnapTheme.fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: BlueSnapTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback onTap) {
    return _KeyBase(
      onTap: onTap,
      child: Icon(icon, size: 24, color: BlueSnapTheme.textSecondary),
    );
  }
}

class _KeyBase extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _KeyBase({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
