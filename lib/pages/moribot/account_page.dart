import 'package:flutter/material.dart';
import 'package:mori_ai/pages/settings/about_settings_page.dart';
import 'package:mori_ai/pages/settings/appearance_settings_page.dart';
import 'package:mori_ai/services/moribot/mori_chat_repository.dart';
import 'package:mori_ai/services/moribot/mori_realtime_service.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

class MoriAccountPage extends StatefulWidget {
  const MoriAccountPage({super.key});

  @override
  State<MoriAccountPage> createState() => _MoriAccountPageState();
}

class _MoriAccountPageState extends State<MoriAccountPage> {
  bool _refreshing = false;

  Future<void> _refreshConnection() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      await MoriSessionStore.instance.refreshMe();
      await MoriChatRepository.instance.refreshAll();
      await MoriRealtimeService.instance.restart();
      if (mounted) {
        _showMessage('已重新连接 MoriBot');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('$error');
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清除本地缓存'),
          content: const Text(
            '会删除手机上的会话、消息和媒体缓存。MoriBot 服务器上的数据不会受影响，重新打开后会再次同步。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('清除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await MoriSessionStore.instance.clearLocalCache();
      final repository = MoriChatRepository.instance;
      repository.reset();
      await repository.initialize(force: true);
      if (mounted) {
        _showMessage('本地缓存已清除');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('$error');
      }
    }
  }

  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('解除配对'),
          content: const Text(
            '解除后这台设备需要重新输入配对码才能访问 MoriBot。服务器上的角色、会话和消息不会被删除。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('解除配对'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await MoriRealtimeService.instance.stop();
    MoriChatRepository.instance.reset();
    await MoriSessionStore.instance.unpair();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _roleLabel(String role) {
    return switch (role) {
      'admin' => '管理员',
      'user' => '普通用户',
      _ => role.isEmpty ? '账户' : role,
    };
  }

  String _realtimeLabel(MoriRealtimeStatus status) {
    return switch (status) {
      MoriRealtimeStatus.connected => '实时通道已连接',
      MoriRealtimeStatus.connecting => '正在连接实时通道…',
      MoriRealtimeStatus.disconnected => '实时通道已断开，正在重连',
      MoriRealtimeStatus.stopped => '实时通道未连接',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ValueListenableBuilder<MoriSessionSnapshot>(
      valueListenable: MoriSessionStore.instance.snapshot,
      builder: (context, snapshot, _) {
        final user = snapshot.user;
        final device = snapshot.device;
        return ValueListenableBuilder<MoriRealtimeStatus>(
          valueListenable: MoriRealtimeService.instance.status,
          builder: (context, realtime, _) {
            return ListView(
              padding: MoriTheme.pagePadding,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer.withValues(alpha: 0.85),
                        colors.primary.withValues(alpha: 0.42),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(MoriRadius.xlarge),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initial(user?.effectiveDisplayName ?? 'Mori'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.effectiveDisplayName ?? 'MoriBot 账户',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (user != null) '@${user.username}',
                                if (user != null) _roleLabel(user.role),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Icon(
                                  realtime == MoriRealtimeStatus.connected
                                      ? MoriIcons.wifi
                                      : MoriIcons.wifiOff,
                                  size: 13,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _realtimeLabel(realtime),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const MoriSectionHeader(label: '服务器'),
                MoriSettingsGroup(
                  children: [
                    MoriSettingsTile(
                      icon: MoriIcons.server,
                      title: 'MoriBot 地址',
                      subtitle: snapshot.serverUrl ?? '未连接',
                      showChevron: false,
                    ),
                    MoriSettingsTile(
                      icon: MoriIcons.cpu,
                      title: '服务端版本',
                      subtitle: snapshot.serverVersion?.isNotEmpty ?? false
                          ? '${snapshot.serverVersion} · 协议 ${snapshot.protocol ?? '-'}'
                          : '尚未获取',
                      showChevron: false,
                    ),
                    MoriSettingsTile(
                      icon: MoriIcons.profile,
                      title: '当前设备',
                      subtitle: device == null
                          ? '未登记'
                          : '${device.name} · ${device.id}',
                      showChevron: false,
                    ),
                    MoriSettingsTile(
                      icon: MoriIcons.refresh,
                      title: _refreshing ? '正在重新连接…' : '重新连接',
                      subtitle: '校验设备令牌并刷新角色卡与会话',
                      enabled: !_refreshing,
                      trailing: _refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _refreshConnection,
                    ),
                  ],
                ),
                const MoriSectionHeader(label: '本地数据'),
                MoriSettingsGroup(
                  children: [
                    MoriSettingsTile(
                      icon: MoriIcons.database,
                      title: '清除本地缓存',
                      subtitle: '服务器数据不受影响，可随时重新同步',
                      onTap: _clearCache,
                    ),
                  ],
                ),
                const MoriSectionHeader(label: '偏好设置'),
                MoriSettingsGroup(
                  children: [
                    MoriSettingsTile(
                      icon: MoriIcons.palette,
                      title: '外观',
                      subtitle: '浅色、深色或跟随系统',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AppearanceSettingsPage(),
                          ),
                        );
                      },
                    ),
                    MoriSettingsTile(
                      icon: MoriIcons.info,
                      title: '关于 Mori',
                      subtitle: '版本 1.0.0',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const MoriSectionHeader(label: '配对'),
                MoriSettingsGroup(
                  children: [
                    MoriSettingsTile(
                      icon: MoriIcons.logout,
                      title: '解除配对',
                      subtitle: '清除本机设备令牌并返回配对页面',
                      danger: true,
                      showChevron: false,
                      onTap: _unpair,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                  child: Text(
                    '角色、会话和消息均保存在 MoriBot 服务器。手机只保留可随时丢弃的本地缓存。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'M';
    }
    return String.fromCharCode(trimmed.runes.first);
  }
}
