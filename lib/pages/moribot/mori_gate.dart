import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mori_ai/pages/home_page.dart';
import 'package:mori_ai/pages/moribot/pairing_page.dart';
import 'package:mori_ai/services/moribot/mori_chat_repository.dart';
import 'package:mori_ai/services/moribot/mori_realtime_service.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';

class MoriGate extends StatefulWidget {
  const MoriGate({super.key});

  @override
  State<MoriGate> createState() => _MoriGateState();
}

class _MoriGateState extends State<MoriGate> {
  bool _wasReady = false;

  @override
  void initState() {
    super.initState();
    MoriSessionStore.instance.snapshot.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  @override
  void dispose() {
    MoriSessionStore.instance.snapshot.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    final snapshot = MoriSessionStore.instance.snapshot.value;
    final isReady = snapshot.status == MoriSessionStatus.ready;
    if (isReady && !_wasReady) {
      _wasReady = true;
      unawaited(MoriChatRepository.instance.initialize());
      unawaited(MoriRealtimeService.instance.start());
    } else if (!isReady && _wasReady) {
      _wasReady = false;
      unawaited(MoriRealtimeService.instance.stop());
      MoriChatRepository.instance.reset();
    }
  }

  Future<void> _retry() async {
    try {
      await MoriSessionStore.instance.refreshMe();
    } catch (_) {
      // The snapshot already contains the error to render.
    }
  }

  Future<void> _unpair() async {
    await MoriRealtimeService.instance.stop();
    MoriChatRepository.instance.reset();
    await MoriSessionStore.instance.unpair();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MoriSessionSnapshot>(
      valueListenable: MoriSessionStore.instance.snapshot,
      builder: (context, snapshot, _) {
        return switch (snapshot.status) {
          MoriSessionStatus.ready => const HomePage(),
          MoriSessionStatus.unpaired => const MoriPairingPage(),
          MoriSessionStatus.connecting => const _ConnectionLoadingPage(),
          MoriSessionStatus.error => _ConnectionErrorPage(
            snapshot: snapshot,
            onRetry: _retry,
            onUnpair: _unpair,
          ),
        };
      },
    );
  }
}

class _ConnectionLoadingPage extends StatelessWidget {
  const _ConnectionLoadingPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer,
                    colors.primary.withValues(alpha: 0.62),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                MoriIcons.leaf,
                size: 36,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(height: 14),
            Text(
              '正在连接 MoriBot…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionErrorPage extends StatelessWidget {
  const _ConnectionErrorPage({
    required this.snapshot,
    required this.onRetry,
    required this.onUnpair,
  });

  final MoriSessionSnapshot snapshot;
  final Future<void> Function() onRetry;
  final Future<void> Function() onUnpair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接失败')),
      body: MoriEmptyState(
        icon: MoriIcons.wifiOff,
        title: '无法连接 MoriBot',
        message: [
          snapshot.error ?? '请检查服务器地址和网络后重试。',
          if (snapshot.serverUrl != null) '\n服务器：${snapshot.serverUrl}',
        ].join(),
        actions: [
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(MoriIcons.refresh, size: 18),
            label: const Text('重试'),
          ),
          TextButton.icon(
            onPressed: onUnpair,
            icon: const Icon(MoriIcons.logout, size: 17),
            label: const Text('重新配对'),
          ),
        ],
      ),
    );
  }
}
