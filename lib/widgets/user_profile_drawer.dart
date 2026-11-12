import 'package:flutter/material.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/user_avatar.dart';

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({
    super.key,
    required this.onOpenProfile,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder<UserProfile>(
          valueListenable: UserProfileStore.instance.profile,
          builder: (context, profile, _) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(MoriRadius.large),
                        onTap: onOpenProfile,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: UserAvatar(profile: profile, size: 66),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                profile.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (profile.signature.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  profile.signature,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    MoriIcons.edit,
                                    size: 13,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '点击编辑个人信息',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      MoriSettingsGroup(
                        children: [
                          MoriSettingsTile(
                            icon: MoriIcons.profile,
                            title: '个人信息',
                            subtitle: '头像、名称、性别与生日',
                            onTap: onOpenProfile,
                          ),
                        ],
                      ),
                      const MoriSectionHeader(label: '更多'),
                      MoriSettingsGroup(
                        children: [
                          MoriSettingsTile(
                            icon: MoriIcons.settings,
                            title: '设置',
                            subtitle: '模型、外观与关于',
                            onTap: onOpenSettings,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                  child: Row(
                    children: [
                      Icon(
                        MoriIcons.leaf,
                        size: 14,
                        color: colors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mori',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
