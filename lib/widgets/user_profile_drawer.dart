import 'package:flutter/material.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/widgets/user_avatar.dart';

class UserProfileDrawer extends StatelessWidget {
  const UserProfileDrawer({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

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
                InkWell(
                  onTap: onOpenProfile,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(profile: profile, size: 68),
                        const SizedBox(height: 14),
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
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
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          '点击编辑个人信息',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('个人信息'),
                  subtitle: const Text('头像、名称、性别与生日'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenProfile,
                ),
                Divider(height: 1, color: colors.outlineVariant),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Mori',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
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
