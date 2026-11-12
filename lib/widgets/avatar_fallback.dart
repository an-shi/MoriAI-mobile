import 'package:flutter/material.dart';

/// Stable, muted avatar colours inspired by Telegram's initials avatars.
const _avatarPalette = <Color>[
  Color(0xFF5B9E86),
  Color(0xFF6F927F),
  Color(0xFFB08A6A),
  Color(0xFF7C8FA3),
  Color(0xFF9A8A73),
  Color(0xFF7D9A92),
  Color(0xFFA48686),
  Color(0xFF6F8C9B),
];

Color _seedColor(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

class AvatarFallback extends StatelessWidget {
  const AvatarFallback({
    super.key,
    required this.label,
    required this.size,
    this.icon,
    this.seed,
  });

  final String label;
  final double size;
  final IconData? icon;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final trimmed = label.trim();
    final color = _seedColor(seed == null || seed!.isEmpty ? trimmed : seed!);
    final background = isDark
        ? Color.alphaBlend(
            color.withValues(alpha: 0.56),
            colors.surfaceContainer,
          )
        : color.withValues(alpha: 0.9);
    final foreground = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.white;
    final initial = trimmed.isEmpty ? '' : trimmed.characters.first;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.12), background),
            background,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: icon != null && initial.isEmpty
          ? Icon(icon, size: size * 0.5, color: foreground)
          : Text(
              initial,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: 0,
              ),
            ),
    );
  }
}
