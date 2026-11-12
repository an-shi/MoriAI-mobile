import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

/// A muted section heading used above grouped list content.
class MoriSectionHeader extends StatelessWidget {
  const MoriSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 8),
  });

  final String label;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A Telegram-style grouped surface. Items are separated by light dividers
/// instead of each becoming its own card.
class MoriSettingsGroup extends StatelessWidget {
  const MoriSettingsGroup({
    super.key,
    required this.children,
    this.padding,
    this.dividerIndent = 60,
    this.margin = EdgeInsets.zero,
    this.color,
  });

  final List<Widget> children;
  final EdgeInsets? padding;
  final double dividerIndent;
  final EdgeInsets margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final content = <Widget>[];
    if (padding != null) {
      content.add(
        Padding(
          padding: padding!,
          child: Column(children: children),
        ),
      );
    } else {
      for (var index = 0; index < children.length; index++) {
        if (index > 0) {
          content.add(
            Divider(
              height: 0.8,
              thickness: 0.8,
              indent: dividerIndent,
              endIndent: 14,
              color: colors.outlineVariant,
            ),
          );
        }
        content.add(children[index]);
      }
    }

    return Padding(
      padding: margin,
      child: Material(
        color:
            color ??
            (isLight
                ? colors.surfaceContainerLowest
                : colors.surfaceContainerLow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoriRadius.large),
          side: BorderSide(
            color: colors.outlineVariant.withValues(
              alpha: isLight ? 0.58 : 0.42,
            ),
            width: 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: content),
      ),
    );
  }
}

/// A compact Telegram-like list row used across settings and memory pages.
class MoriSettingsTile extends StatelessWidget {
  const MoriSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showChevron = true,
    this.danger = false,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showChevron;
  final bool danger;
  final bool enabled;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = danger ? colors.error : colors.onSurface;
    final leadingWidget =
        leading ??
        (icon == null
            ? null
            : MoriIconBadge(icon: icon!, danger: danger, enabled: enabled));
    final trailingWidget =
        trailing ??
        (showChevron && (onTap != null || onLongPress != null)
            ? Icon(
                MoriIcons.chevron,
                size: 18,
                color: colors.onSurfaceVariant.withValues(
                  alpha: enabled ? 0.72 : 0.35,
                ),
              )
            : null);

    return ListTile(
      enabled: enabled,
      contentPadding: padding,
      horizontalTitleGap: 12,
      minVerticalPadding: 9,
      leading: leadingWidget,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: enabled ? foreground : foreground.withValues(alpha: 0.38),
          fontWeight: FontWeight.w500,
          fontSize: 15.5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled
                      ? colors.onSurfaceVariant
                      : colors.onSurfaceVariant.withValues(alpha: 0.38),
                  height: 1.35,
                ),
              ),
            ),
      trailing: trailingWidget,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
    );
  }
}

class MoriIconBadge extends StatelessWidget {
  const MoriIconBadge({
    super.key,
    required this.icon,
    this.size = 34,
    this.danger = false,
    this.enabled = true,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final double size;
  final bool danger;
  final bool enabled;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = danger
        ? colors.errorContainer
        : (color ?? colors.primaryContainer);
    final foreground = danger
        ? colors.onErrorContainer
        : (iconColor ?? colors.onPrimaryContainer);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: enabled ? background : background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.53,
        color: enabled ? foreground : foreground.withValues(alpha: 0.45),
      ),
    );
  }
}

class MoriSettingsSwitchTile extends StatelessWidget {
  const MoriSettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: padding,
      secondary: icon == null ? null : MoriIconBadge(icon: icon!),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 15.5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A grouped form section with a title and optional helper copy.
class MoriFormSection extends StatelessWidget {
  const MoriFormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.topPadding = 24,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, topPadding, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (description != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
        MoriSettingsGroup(padding: padding, children: children),
      ],
    );
  }
}

class MoriPageIntro extends StatelessWidget {
  const MoriPageIntro({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.fromLTRB(4, 4, 4, 12),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.55,
        ),
      ),
    );
  }
}

class MoriEmptyState extends StatelessWidget {
  const MoriEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, compact ? 24 : 40, 32, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 60 : 72,
              height: compact ? 60 : 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: compact ? 26 : 30,
                color: colors.onPrimaryContainer,
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MoriTag extends StatelessWidget {
  const MoriTag({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? colors.primaryContainer,
        borderRadius: BorderRadius.circular(MoriRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground ?? colors.onPrimaryContainer,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }
}

class MoriSheetOption extends StatelessWidget {
  const MoriSheetOption({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return MoriSettingsTile(
      icon: icon,
      title: label,
      subtitle: subtitle,
      danger: danger,
      showChevron: false,
      onTap: onTap,
    );
  }
}

/// A softly rounded action button powered by Forui, used for secondary and
/// empty-state actions.
class MoriActionButton extends StatelessWidget {
  const MoriActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = FButtonVariant.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final FButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 7)],
        Text(label),
      ],
    );
    final button = FButton(onPress: onPressed, variant: variant, child: child);
    final sized = expand
        ? SizedBox(width: double.infinity, height: 46, child: button)
        : SizedBox(height: 40, child: button);
    // Standalone widget tests and previews may not have an enclosing FTheme.
    if (context.findAncestorWidgetOfExactType<FTheme>() != null) {
      return sized;
    }
    return FTheme(data: MoriTheme.forui(Theme.of(context)), child: sized);
  }
}

/// Destructive confirmation action with the error colour applied.
class MoriDangerButton extends StatelessWidget {
  const MoriDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.error,
        foregroundColor: colors.onError,
        disabledBackgroundColor: colors.error.withValues(alpha: 0.35),
        disabledForegroundColor: colors.onError.withValues(alpha: 0.6),
      ),
      child: Text(label),
    );
  }
}

/// A simple, low-contrast label used inside chats.
class MoriTimeLabel extends StatelessWidget {
  const MoriTimeLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(MoriRadius.pill),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
