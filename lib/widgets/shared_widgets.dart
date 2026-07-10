/// BlueSnap shared widgets — warm light theme
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import '../core/constants.dart';

// ══════════════════════════════════════════════════════════
// MEDIA IMAGE — renders a bundled asset OR a local file path
// ══════════════════════════════════════════════════════════
/// Resolves a media path to the right [ImageProvider]: bundled demo content
/// lives under `assets/`, real captured/received media is an absolute file path.
ImageProvider mediaImageProvider(String path) => path.startsWith('assets/')
    ? AssetImage(path)
    : FileImage(File(path)) as ImageProvider;

/// Displays media from [path] with a cover fit and a graceful fallback tile
/// if the file is missing or unreadable (so the feed never shows a broken box).
class MediaImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color fallbackColor;
  final bool isVideo;

  const MediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackColor = BlueSnapTheme.primary,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image(
      image: mediaImageProvider(path),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: fallbackColor.withValues(alpha: 0.08),
        child: Center(
          child: Icon(
            isVideo ? Icons.play_circle_outline : Icons.image_outlined,
            size: 44,
            color: fallbackColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// PRESSABLE — scale + haptic tap feedback for any child
// ══════════════════════════════════════════════════════════
/// Wrap any tappable element to get a subtle press-scale animation plus an
/// optional haptic tick. Gives the whole app that "responsive" premium feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// APP CARD — flat white surface (no border, no shadow)
// ══════════════════════════════════════════════════════════
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final bool elevated;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BlueSnapTheme.spaceM),
    this.margin,
    this.onTap,
    this.radius = BlueSnapTheme.radiusL,
    this.elevated = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? BlueSnapTheme.bgCard,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

// ══════════════════════════════════════════════════════════
// PILL BUTTON — primary (filled blue) / secondary (grey)
// ══════════════════════════════════════════════════════════
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool fullWidth;
  final double height;
  final Widget? leading;
  final bool loading;

  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = true,
    this.fullWidth = true,
    this.height = 44,
    this.leading,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? BlueSnapTheme.primary : BlueSnapTheme.surface2;
    final fg = primary ? Colors.white : BlueSnapTheme.textPrimary;
    return Pressable(
      onTap: loading ? null : onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: height,
        padding: fullWidth
            ? null
            : const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(primary ? BlueSnapTheme.radiusFull : 8),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(fg),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: BlueSnapTheme.fontFamily,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// APP TEXT FIELD — 44px, surface-2 fill, focus glow, eye toggle
// ══════════════════════════════════════════════════════════
class AppTextField extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final double height;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    required this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.prefix,
    this.height = 44,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: BlueSnapTheme.surface2,
        borderRadius: BorderRadius.circular(BlueSnapTheme.radiusM),
        border: Border.all(
          color: _focused
              ? BlueSnapTheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (widget.prefix != null) ...[
            widget.prefix!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              style: BlueSnapTheme.bodyM,
              cursorColor: BlueSnapTheme.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle:
                    BlueSnapTheme.bodyM.copyWith(color: BlueSnapTheme.textTertiary),
              ),
            ),
          ),
          if (widget.obscure)
            GestureDetector(
              onTap: () => setState(() => _hidden = !_hidden),
              child: Icon(
                _hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: BlueSnapTheme.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// THIN DIVIDER — 0.5px #EBEBEB
// ══════════════════════════════════════════════════════════
class ThinDivider extends StatelessWidget {
  final double indent;
  final double height;
  const ThinDivider({super.key, this.indent = 0, this.height = 0.5});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: indent),
      height: height,
      color: BlueSnapTheme.divider,
    );
  }
}

// ══════════════════════════════════════════════════════════
// SKELETON LOADERS (shimmer)
// ══════════════════════════════════════════════════════════
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = BlueSnapTheme.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: BlueSnapTheme.surface2,
      highlightColor: BlueSnapTheme.surface3,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: BlueSnapTheme.surface2,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A list of shimmering placeholder rows (avatar + two text lines).
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(BlueSnapTheme.spaceL),
      itemCount: count,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: BlueSnapTheme.spaceL),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: BlueSnapTheme.surface2,
              highlightColor: BlueSnapTheme.surface3,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: BlueSnapTheme.surface2,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: BlueSnapTheme.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 13),
                  SizedBox(height: 8),
                  SkeletonBox(width: 220, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// USER AVATAR
// ══════════════════════════════════════════════════════════
class UserAvatar extends StatelessWidget {
  final String name;
  final int colorIndex;
  final double size;
  final bool showOnlineIndicator;
  final bool hasStory;
  final bool storyViewed;
  final String? imagePath;
  final Color ringGapColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.colorIndex = 0,
    this.size = 48,
    this.showOnlineIndicator = false,
    this.hasStory = false,
    this.storyViewed = false,
    this.imagePath,
    this.ringGapColor = BlueSnapTheme.bgSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final color = AvatarColors.fromIndex(colorIndex);
    final initials = _getInitials(name);

    Widget avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: imagePath != null
          ? MediaImage(path: imagePath!, width: size, height: size)
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  fontFamily: BlueSnapTheme.fontFamily,
                ),
              ),
            ),
    );

    if (hasStory) {
      // Unviewed → warm gradient ring; viewed → thin grey ring.
      avatar = Container(
        padding: EdgeInsets.all(storyViewed ? 1 : 2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: storyViewed ? null : BlueSnapTheme.storyGradient,
          color: storyViewed ? BlueSnapTheme.divider : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringGapColor,
          ),
          child: avatar,
        ),
      );
    }

    if (showOnlineIndicator) {
      final dot = size * 0.26;
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: BlueSnapTheme.onlineGreen,
                shape: BoxShape.circle,
                border: Border.all(color: BlueSnapTheme.bgSecondary, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════
// PULSE ANIMATION (subtle concentric pulse — used in discovery)
// ══════════════════════════════════════════════════════════
class PulseAnimation extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const PulseAnimation({
    super.key,
    this.size = 200,
    this.color = BlueSnapTheme.primary,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: widget.duration,
      )..repeat();
    });

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 700), () {
        if (mounted) _controllers[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: _controllers.map((controller) {
          return AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final scale = 0.3 + controller.value * 0.7;
              final opacity = (1.0 - controller.value) * 0.25;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: opacity),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: BlueSnapTheme.surface2,
              ),
              child: Icon(icon, size: 40, color: BlueSnapTheme.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(title, style: BlueSnapTheme.headingS, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: BlueSnapTheme.bodyS, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              PillButton(
                label: actionLabel!,
                onTap: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
    );
  }
}

// ══════════════════════════════════════════════════════════
// THEMED SNACKBAR
// ══════════════════════════════════════════════════════════
/// A branded, floating snackbar with an icon and rounded corners.
/// Use instead of stock `SnackBar(content: Text(...))` for a consistent voice.
void showAppSnack(
  BuildContext context,
  String message, {
  IconData? icon,
  bool isError = false,
}) {
  final accent = isError ? BlueSnapTheme.accentRed : BlueSnapTheme.primary;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BlueSnapTheme.textPrimary,
        elevation: 0,
        margin: const EdgeInsets.all(BlueSnapTheme.spaceL),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BlueSnapTheme.radiusL),
        ),
        content: Row(
          children: [
            Icon(
                icon ??
                    (isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded),
                color: accent,
                size: 20),
            const SizedBox(width: BlueSnapTheme.spaceM),
            Expanded(
              child: Text(
                message,
                style: BlueSnapTheme.bodyM.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
}
