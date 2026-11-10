import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/chat_burst_settings.dart';
import 'package:mori_ai/models/system_context_settings.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/system_context_settings_store.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  static const _globalOptions = [
    ChatBurstTendency.off,
    ChatBurstTendency.natural,
    ChatBurstTendency.active,
  ];

  Future<void> _saveSystemSettings(
    BuildContext context,
    SystemContextSettings next,
  ) async {
    try {
      await SystemContextSettingsStore.instance.save(next);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('系统感知设置保存失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('聊天设置')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          ChatBurstSettingsStore.instance.settings,
          SystemContextSettingsStore.instance.settings,
        ]),
        builder: (context, _) {
          final settings = ChatBurstSettingsStore.instance.settings.value;
          final systemSettings =
              SystemContextSettingsStore.instance.settings.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '系统感知',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '让角色知道当前日期、时间、星期和时区；这些信息只用于理解对话语境，不需要额外系统权限。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.schedule_outlined,
                    color: colors.primary,
                  ),
                  title: const Text('让角色知道当前时间'),
                  subtitle: const Text('单聊、群聊、主动消息和动态生成会参考当前时间；关闭后不注入日期和时间。'),
                  value: systemSettings.timeAwarenessEnabled,
                  onChanged: (value) {
                    unawaited(
                      _saveSystemSettings(
                        context,
                        systemSettings.copyWith(timeAwarenessEnabled: value),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '连发倾向',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '控制角色是否倾向于把一轮回复拆成多条短消息。单角色可以在角色设置页覆盖这里的选择。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < _globalOptions.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: colors.outlineVariant,
                        ),
                      _TendencyTile(
                        tendency: _globalOptions[index],
                        selected:
                            settings.globalTendency == _globalOptions[index],
                        onTap: () {
                          unawaited(
                            ChatBurstSettingsStore.instance.setGlobalTendency(
                              _globalOptions[index],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '“自然”适合大多数角色；“积极”会让模型默认拆成多条，适合话多、活泼的角色；“关闭”只保留模型自己主动分条的情况。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '条数与字数范围',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '分别控制“自然”和“积极”倾向下，一轮回复拆成几条、每条大约多少字。用户明确要求固定条数时，会在该范围内取最接近的值。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _TendencyRangeCard(
                tendency: ChatBurstTendency.natural,
                range: settings.rangeFor(ChatBurstTendency.natural),
              ),
              const SizedBox(height: 12),
              _TendencyRangeCard(
                tendency: ChatBurstTendency.active,
                range: settings.rangeFor(ChatBurstTendency.active),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TendencyRangeCard extends StatelessWidget {
  const _TendencyRangeCard({required this.tendency, required this.range});

  final ChatBurstTendency tendency;
  final ChatBurstRange range;

  Future<void> _save(ChatBurstRange next) {
    return ChatBurstSettingsStore.instance.setTendencyRange(tendency, next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tendency.label}倾向',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '消息 ${range.minMessages}-${range.maxMessages} 条，每条约 ${range.minChars}-${range.maxChars} 字。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberSettingField(
                    label: '最少条数',
                    value: range.minMessages,
                    min: 1,
                    helperText: '至少 1 条。',
                    onChanged: (value) {
                      unawaited(_save(range.copyWith(minMessages: value)));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberSettingField(
                    label: '最多条数',
                    value: range.maxMessages,
                    min: 1,
                    helperText: '不少于最少条数。',
                    onChanged: (value) {
                      unawaited(_save(range.copyWith(maxMessages: value)));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberSettingField(
                    label: '最少字数',
                    value: range.minChars,
                    min: 1,
                    helperText: '每条至少多少字。',
                    onChanged: (value) {
                      unawaited(_save(range.copyWith(minChars: value)));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberSettingField(
                    label: '最多字数',
                    value: range.maxChars,
                    min: 1,
                    helperText: '不少于最少字数。',
                    onChanged: (value) {
                      unawaited(_save(range.copyWith(maxChars: value)));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TendencyTile extends StatelessWidget {
  const _TendencyTile({
    required this.tendency,
    required this.selected,
    required this.onTap,
  });

  final ChatBurstTendency tendency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      title: Text(
        tendency.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(tendency.description),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.primary)
          : const Icon(Icons.circle_outlined),
    );
  }
}
