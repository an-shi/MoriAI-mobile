import 'package:flutter/material.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/moribot/mori_cached_image.dart';

class MoriCharacterAvatar extends StatelessWidget {
  const MoriCharacterAvatar({
    super.key,
    required this.character,
    this.size = 46,
  });

  final MoriCharacter character;
  final double size;

  String get _initial {
    final name = character.displayName.trim();
    if (name.isEmpty) {
      return '?';
    }
    final runes = name.runes;
    return String.fromCharCode(runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.primary.withValues(alpha: 0.55),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: character.avatar.trim().isEmpty
              ? fallback
              : MoriCachedImage(
                  url: character.avatar,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  placeholder: fallback,
                ),
        ),
      ),
    );
  }
}

class MoriConversationAvatar extends StatelessWidget {
  const MoriConversationAvatar({
    super.key,
    required this.conversation,
    this.size = 46,
  });

  final MoriConversation conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MoriCharacterAvatar(
      character: MoriCharacter(
        id: conversation.characterId,
        name: conversation.characterName,
        avatar: conversation.characterAvatar,
        chatAvailable: conversation.characterAvailable,
      ),
      size: size,
    );
  }
}

/// A soft status pill used on character cards and chat headers.
class MoriAvailabilityPill extends StatelessWidget {
  const MoriAvailabilityPill({
    super.key,
    required this.label,
    required this.available,
    this.icon,
  });

  final String label;
  final bool available;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = available
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant.withValues(alpha: 0.72);
    final background = available
        ? colors.primaryContainer.withValues(alpha: 0.72)
        : colors.surfaceContainerHighest.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MoriRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.5, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
