import 'package:flutter/material.dart';
import 'package:mori_ai/models/moment_interaction_settings.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';

class MomentInteractionSettingsPage extends StatefulWidget {
  const MomentInteractionSettingsPage({super.key});

  @override
  State<MomentInteractionSettingsPage> createState() =>
      _MomentInteractionSettingsPageState();
}

class _MomentInteractionSettingsPageState
    extends State<MomentInteractionSettingsPage> {
  late MomentInteractionSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = MomentInteractionSettingsStore.instance.settings.value;
  }

  void _update(MomentInteractionSettings next) {
    setState(() => _settings = next.normalized());
  }

  Future<void> _save() async {
    try {
      await MomentInteractionSettingsStore.instance.save(_settings);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('保存动态互动设置失败，请重试')));
    }
  }

  Future<void> _reset() async {
    final defaults = MomentInteractionSettings.defaults;
    setState(() => _settings = defaults);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('动态互动')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '以下设置会在下一次动态或评论触发自动互动时生效。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动评论人数',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '每条新动态随机选择 ${_settings.autoCommentCount} 个角色评论；设为 2 以上时，也会有额外角色加入同一条评论的回复。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: _settings.autoCommentCount.toDouble(),
                  min: 0,
                  max: MomentInteractionSettings.maxCommentCount.toDouble(),
                  divisions: MomentInteractionSettings.maxCommentCount,
                  label: '${_settings.autoCommentCount} 人',
                  onChanged: (value) {
                    _update(
                      _settings.copyWith(autoCommentCount: value.round()),
                    );
                  },
                  onChangeEnd: (value) => _save(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 人（关闭）',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${MomentInteractionSettings.maxCommentCount} 人',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动回复层数',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '角色自动回复最多嵌套 ${_settings.autoReplyDepth} 层。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '用户直接回复角色评论时不受此限制，被回复的角色会主动回复一次。',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: _settings.autoReplyDepth.toDouble(),
                  min: 0,
                  max: MomentInteractionSettings.maxReplyDepth.toDouble(),
                  divisions: MomentInteractionSettings.maxReplyDepth,
                  label: '${_settings.autoReplyDepth} 层',
                  onChanged: (value) {
                    _update(_settings.copyWith(autoReplyDepth: value.round()));
                  },
                  onChangeEnd: (value) => _save(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 层（关闭）',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${MomentInteractionSettings.maxReplyDepth} 层',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('恢复默认设置'),
          ),
          const SizedBox(height: 12),
          Text(
            '自动评论和回复会增加模型调用次数，人数和层数越高，消耗越多。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: child,
      ),
    );
  }
}
