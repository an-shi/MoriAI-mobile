import 'package:flutter/material.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/pages/chat_page.dart';
import 'package:mori_ai/pages/group/group_settings_page.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/widgets/group_avatar.dart';

class GroupChatDetailPage extends StatelessWidget {
  const GroupChatDetailPage({super.key, required this.group});

  final GroupProfile group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<GroupProfile>>(
      valueListenable: GroupStore.instance.groups,
      builder: (context, groups, _) {
        GroupProfile current = group;
        for (final item in groups) {
          if (item.id == group.id) {
            current = item;
            break;
          }
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                GroupAvatar(group: current, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${current.memberIds.length} 位成员',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupSettingsPage(groupId: current.id),
                    ),
                  );
                },
                tooltip: '群聊设置',
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          body: ChatPage(group: current),
        );
      },
    );
  }
}
