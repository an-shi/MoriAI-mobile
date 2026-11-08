import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class ProactiveMessageSettingsPage extends StatefulWidget {
  const ProactiveMessageSettingsPage({super.key});

  @override
  State<ProactiveMessageSettingsPage> createState() =>
      _ProactiveMessageSettingsPageState();
}

class _ProactiveMessageSettingsPageState
    extends State<ProactiveMessageSettingsPage> {
  late ProactiveMessageSettings _settings;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _settings = ProactiveMessageStore.instance.settings.value;
  }

  void _update(ProactiveMessageSettings next) {
    setState(() => _settings = next.normalized());
  }

  Future<void> _save() async {
    try {
      await ProactiveMessageStore.instance.saveSettings(_settings);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('保存自动消息设置失败，请重试');
    }
  }

  Future<void> _updateAndSave(ProactiveMessageSettings next) async {
    _update(next);
    await _save();
  }

  Future<void> _reset() async {
    final defaults = ProactiveMessageSettings.defaults.normalized();
    _update(defaults);
    await _save();
  }

  Future<int?> _pickMinuteOfDay(int initial, String helpText) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      helpText: helpText,
    );
    if (picked == null) {
      return null;
    }
    return picked.hour * 60 + picked.minute;
  }

  Future<void> _addScheduledTime() async {
    final minute = await _pickMinuteOfDay(8 * 60, '选择问候时间');
    if (minute == null || !mounted) {
      return;
    }
    final values = {..._settings.scheduledMinuteValues, minute}.toList()
      ..sort();
    await _updateAndSave(
      _settings.copyWith(
        scheduledTimes: [
          for (final value in values)
            ProactiveMessageSettings.formatTimeOfDay(value),
        ],
      ),
    );
  }

  Future<void> _removeScheduledTime(int minute) async {
    final values = _settings.scheduledMinuteValues
        .where((value) => value != minute)
        .toList();
    await _updateAndSave(
      _settings.copyWith(
        scheduledTimes: [
          for (final value in values)
            ProactiveMessageSettings.formatTimeOfDay(value),
        ],
      ),
    );
  }

  Future<void> _pickQuietTime({required bool start}) async {
    final initial = start
        ? _settings.quietStartMinutes
        : _settings.quietEndMinutes;
    final minute = await _pickMinuteOfDay(initial, start ? '免打扰开始' : '免打扰结束');
    if (minute == null || !mounted) {
      return;
    }
    await _updateAndSave(
      start
          ? _settings.copyWith(quietStartMinutes: minute)
          : _settings.copyWith(quietEndMinutes: minute),
    );
  }

  Future<void> _sendTest() async {
    if (_testing) {
      return;
    }
    final cards = CharacterStore.instance.cards.value;
    if (cards.isEmpty) {
      _showSnackBar('还没有可用的角色卡');
      return;
    }

    final selected = await showModalBottomSheet<CharacterProfile>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  '让角色主动发一条',
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '立即触发一次，不消耗每日额度。',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final card in cards)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CharacterAvatar(character: card, size: 40),
                    title: Text(card.displayName),
                    subtitle: Text(card.type.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(card),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }

    setState(() => _testing = true);
    try {
      final sent = await ProactiveMessageService.instance.triggerNow(
        selected.id,
      );
      if (mounted) {
        _showSnackBar(
          sent
              ? '已让「${selected.displayName}」主动发了一条消息'
              : '「${selected.displayName}」这轮选择沉默，没有发送消息',
        );
      }
    } on ProactiveMessageException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('发送主动消息失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quietRange =
        '${ProactiveMessageSettings.formatTimeOfDay(_settings.quietStartMinutes)}'
        ' - '
        '${ProactiveMessageSettings.formatTimeOfDay(_settings.quietEndMinutes)}';

    return Scaffold(
      appBar: AppBar(title: const Text('自动消息')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '让角色在你沉默一段时间后主动找你，也可以在每天的固定时间发来问候。',
            style: theme.textTheme.bodyMedium?.copyWith(
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
              title: const Text('启用自动消息'),
              subtitle: const Text('开启后，所有单聊角色都可能主动发消息'),
              value: _settings.enabled,
              onChanged: (value) =>
                  _updateAndSave(_settings.copyWith(enabled: value)),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SectionTitle(
                        title: '沉默主动',
                        subtitle: '双方一段时间没有新消息后，随机间隔触发一次。',
                      ),
                    ),
                    Switch(
                      value: _settings.silenceEnabled,
                      onChanged: (value) => _updateAndSave(
                        _settings.copyWith(silenceEnabled: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '沉默 ${_settings.silenceMinMinutes} - '
                  '${_settings.silenceMaxMinutes} 分钟后，随机选一个时间点。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                RangeSlider(
                  values: RangeValues(
                    _settings.silenceMinMinutes.toDouble(),
                    _settings.silenceMaxMinutes.toDouble(),
                  ),
                  min: ProactiveMessageSettings.minSilenceMinutes.toDouble(),
                  max: ProactiveMessageSettings.maxSilenceMinutes.toDouble(),
                  divisions:
                      (ProactiveMessageSettings.maxSilenceMinutes -
                          ProactiveMessageSettings.minSilenceMinutes) ~/
                      ProactiveMessageSettings.minSilenceMinutes,
                  labels: RangeLabels(
                    '${_settings.silenceMinMinutes} 分钟',
                    '${_settings.silenceMaxMinutes} 分钟',
                  ),
                  onChanged: _settings.silenceEnabled
                      ? (value) {
                          final minimum = value.start.round().clamp(
                            ProactiveMessageSettings.minSilenceMinutes,
                            ProactiveMessageSettings.maxSilenceMinutes -
                                ProactiveMessageSettings.minSilenceMinutes,
                          );
                          final maximum = value.end.round().clamp(
                            minimum +
                                ProactiveMessageSettings.minSilenceMinutes,
                            ProactiveMessageSettings.maxSilenceMinutes,
                          );
                          _update(
                            _settings.copyWith(
                              silenceMinMinutes: minimum,
                              silenceMaxMinutes: maximum,
                            ),
                          );
                        }
                      : null,
                  onChangeEnd: (value) => _save(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${ProactiveMessageSettings.minSilenceMinutes} 分钟',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${ProactiveMessageSettings.maxSilenceMinutes ~/ 60} 小时',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Divider(color: colors.outlineVariant),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('追问未回复的问题'),
                  subtitle: const Text('她发出问句后，15-40 分钟没回复时偶尔轻轻追一句'),
                  value: _settings.nudgeEnabled,
                  onChanged: (value) =>
                      _updateAndSave(_settings.copyWith(nudgeEnabled: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SectionTitle(
                        title: '定时问候',
                        subtitle: '每天在固定时间点主动发一条消息。',
                      ),
                    ),
                    Switch(
                      value: _settings.scheduledEnabled,
                      onChanged: (value) => _updateAndSave(
                        _settings.copyWith(scheduledEnabled: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final minute in _settings.scheduledMinuteValues)
                      InputChip(
                        label: Text(
                          ProactiveMessageSettings.formatTimeOfDay(minute),
                        ),
                        onDeleted: _settings.scheduledEnabled
                            ? () => _removeScheduledTime(minute)
                            : null,
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('添加时间'),
                      onPressed: _settings.scheduledEnabled
                          ? _addScheduledTime
                          : null,
                    ),
                  ],
                ),
                if (_settings.scheduledEnabled &&
                    _settings.scheduledMinuteValues.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '还没有定时问候，添加一个时间点即可。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SectionTitle(
                        title: '免打扰',
                        subtitle: '这个时间段内不会主动发消息：$quietRange',
                      ),
                    ),
                    Switch(
                      value: _settings.quietHoursEnabled,
                      onChanged: (value) => _updateAndSave(
                        _settings.copyWith(quietHoursEnabled: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _settings.quietHoursEnabled
                            ? () => _pickQuietTime(start: true)
                            : null,
                        icon: const Icon(Icons.bedtime_outlined, size: 18),
                        label: Text(
                          '开始 '
                          '${ProactiveMessageSettings.formatTimeOfDay(_settings.quietStartMinutes)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _settings.quietHoursEnabled
                            ? () => _pickQuietTime(start: false)
                            : null,
                        icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                        label: Text(
                          '结束 '
                          '${ProactiveMessageSettings.formatTimeOfDay(_settings.quietEndMinutes)}',
                        ),
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
                _SectionTitle(
                  title: '频率保护',
                  subtitle: '避免连续主动消息过多，用户回复后会重新计数。',
                ),
                const SizedBox(height: 14),
                Text(
                  '所有单聊每天最多主动 ${_settings.dailyLimit} 条',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _settings.dailyLimit.toDouble(),
                  min: 1,
                  max: ProactiveMessageSettings.maxDailyLimit.toDouble(),
                  divisions: ProactiveMessageSettings.maxDailyLimit - 1,
                  label: '${_settings.dailyLimit} 条',
                  onChanged: (value) =>
                      _update(_settings.copyWith(dailyLimit: value.round())),
                  onChangeEnd: (value) => _save(),
                ),
                const SizedBox(height: 6),
                Text(
                  '连续 ${_settings.maxUnanswered} 条没有回复后暂停',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _settings.maxUnanswered.toDouble(),
                  min: 1,
                  max: ProactiveMessageSettings.maxUnansweredLimit.toDouble(),
                  divisions: ProactiveMessageSettings.maxUnansweredLimit - 1,
                  label: '${_settings.maxUnanswered} 条',
                  onChanged: (value) =>
                      _update(_settings.copyWith(maxUnanswered: value.round())),
                  onChangeEnd: (value) => _save(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: _testing ? null : _sendTest,
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_testing ? '正在发送…' : '立即让角色发一条'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('恢复默认设置'),
          ),
          const SizedBox(height: 12),
          Text(
            '自动消息只会在应用打开或从后台恢复时触发；应用被系统关闭后无法保证定时发送。每次主动消息都会调用一次模型。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
