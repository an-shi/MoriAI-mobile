import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/proactive_message_settings.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/number_setting_field.dart';

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
  bool _diagnosing = false;

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

  Future<void> _openDiagnostics() async {
    if (_diagnosing) {
      return;
    }
    setState(() => _diagnosing = true);
    try {
      final diagnostics = await ProactiveMessageService.instance.diagnose();
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _DiagnosticsSheet(initial: diagnostics),
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar('读取自动消息状态失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _diagnosing = false);
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
            child: Column(
              children: [
                SwitchListTile(
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
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: const Text('本地通知'),
                  subtitle: const Text('角色主动发消息时发送系统通知，并在会话列表显示未读红点'),
                  value: _settings.notificationsEnabled,
                  onChanged: _settings.enabled
                      ? (value) => _updateAndSave(
                          _settings.copyWith(notificationsEnabled: value),
                        )
                      : null,
                ),
              ],
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Icon(
                Icons.monitor_heart_outlined,
                color: colors.primary,
              ),
              title: const Text('运行诊断'),
              subtitle: const Text('检查自动消息为什么没有触发'),
              trailing: _diagnosing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _diagnosing ? null : _openDiagnostics,
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
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: NumberSettingField(
                        label: '最短间隔（分钟）',
                        value: _settings.silenceMinMinutes,
                        min: ProactiveMessageSettings.minSilenceMinutes,
                        helperText: '至少 1 分钟，可填写任意更大的值。',
                        onChanged: (value) {
                          _update(_settings.copyWith(silenceMinMinutes: value));
                          unawaited(_save());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NumberSettingField(
                        label: '最长间隔（分钟）',
                        value: _settings.silenceMaxMinutes,
                        min: ProactiveMessageSettings.minSilenceMinutes,
                        helperText: '至少 1 分钟，且不小于最短间隔。',
                        onChanged: (value) {
                          _update(_settings.copyWith(silenceMaxMinutes: value));
                          unawaited(_save());
                        },
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
                NumberSettingField(
                  label: '所有单聊每日总上限',
                  value: _settings.dailyLimit,
                  min: 0,
                  allowUnlimited: true,
                  helperText: _settings.dailyLimit < 0
                      ? '当前无上限；输入 0 或正整数可恢复为具体数值。'
                      : '当前 ${_settings.dailyLimit} 条，可填写任意非负整数；负数表示无上限。',
                  onChanged: (value) {
                    _update(_settings.copyWith(dailyLimit: value));
                    unawaited(_save());
                  },
                ),
                const SizedBox(height: 14),
                NumberSettingField(
                  label: '连续未回复上限',
                  value: _settings.maxUnanswered,
                  min: 0,
                  allowUnlimited: true,
                  helperText: _settings.maxUnanswered < 0
                      ? '当前无上限；输入 0 或正整数可恢复为具体数值。'
                      : '当前 ${_settings.maxUnanswered} 条，可填写任意非负整数；负数表示无上限。',
                  onChanged: (value) {
                    _update(_settings.copyWith(maxUnanswered: value));
                    unawaited(_save());
                  },
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

class _DiagnosticsSheet extends StatefulWidget {
  const _DiagnosticsSheet({required this.initial});

  final ProactiveMessageDiagnostics initial;

  @override
  State<_DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<_DiagnosticsSheet> {
  late ProactiveMessageDiagnostics _diagnostics;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _diagnostics = widget.initial;
  }

  Future<void> _checkNow() async {
    if (_checking) {
      return;
    }
    setState(() => _checking = true);
    try {
      await ProactiveMessageService.instance.checkNow();
      final diagnostics = await ProactiveMessageService.instance.diagnose();
      if (mounted) {
        setState(() => _diagnostics = diagnostics);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('检查失败，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final diagnostics = _diagnostics;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '自动消息诊断',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _checking ? null : _checkNow,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_checking ? '检查中…' : '立即检查一次'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  '自动消息只在应用前台或从后台恢复时运行。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _DiagnosticRow(
                  label: '全局开关',
                  value: diagnostics.globalEnabled ? '已开启' : '已关闭',
                  ok: diagnostics.globalEnabled,
                ),
                _DiagnosticRow(
                  label: '模型配置',
                  value: diagnostics.modelConfigured ? '已配置' : '未配置',
                  ok: diagnostics.modelConfigured,
                ),
                _DiagnosticRow(
                  label: '服务状态',
                  value: diagnostics.serviceRunning ? '运行中' : '未运行',
                  ok: diagnostics.serviceRunning,
                ),
                _DiagnosticRow(
                  label: '免打扰',
                  value: diagnostics.quietNow ? '当前处于免打扰' : '未处于免打扰',
                  ok: !diagnostics.quietNow,
                ),
                _DiagnosticRow(
                  label: '今日总量',
                  value:
                      '${diagnostics.totalToday}/${_limitLabel(diagnostics.globalDailyLimit)}',
                  ok:
                      diagnostics.globalDailyLimit < 0 ||
                      diagnostics.totalToday < diagnostics.globalDailyLimit,
                ),
                _DiagnosticRow(
                  label: '上次检查',
                  value: _formatDateTime(diagnostics.lastCheckAt),
                  ok: diagnostics.lastCheckAt != null,
                ),
                if (diagnostics.lastError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '最近错误（${_formatDateTime(diagnostics.lastErrorAt)}）：'
                      '${diagnostics.lastError}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '角色状态',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (diagnostics.conversations.isEmpty)
                  Text(
                    '还没有角色卡。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                for (final item in diagnostics.conversations)
                  Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.characterName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                item.reason,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: item.reason == '条件已满足，可以触发'
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '今日 ${item.dailyCount}/${_limitLabel(item.dailyLimit)} · '
                            '未回复 ${item.unansweredCount}/${_limitLabel(item.maxUnanswered)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '下次沉默：${_formatDateTime(item.nextSilenceAt)} · '
                            '上次主动：${_formatDateTime(item.lastProactiveAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (item.cooldownRemaining != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '角色冷却剩余：${_formatRemaining(item.cooldownRemaining)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (item.firedSlots.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '今日已触发定时：${item.firedSlots.join('、')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            ok
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: ok ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _limitLabel(int limit) {
  return limit < 0 ? '无上限' : '$limit';
}

String _formatRemaining(Duration? duration) {
  if (duration == null || duration.isNegative || duration == Duration.zero) {
    return '无冷却';
  }
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  if (minutes <= 0) {
    return '$seconds 秒';
  }
  return '$minutes 分 $seconds 秒';
}

String _formatDateTime(DateTime? time) {
  if (time == null) {
    return '暂无';
  }
  return '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
