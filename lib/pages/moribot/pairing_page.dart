import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mori_ai/models/moribot/mori_models.dart';
import 'package:mori_ai/services/moribot/mori_bot_client.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';

class MoriPairingPage extends StatefulWidget {
  const MoriPairingPage({super.key});

  @override
  State<MoriPairingPage> createState() => _MoriPairingPageState();
}

class _MoriPairingPageState extends State<MoriPairingPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _codeController = TextEditingController();
  final _deviceController = TextEditingController();

  bool _pasting = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = MoriSessionStore.instance;
    _serverController.text = session.snapshot.value.serverUrl ?? '';
    _deviceController.text = session.lastDeviceName;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _codeController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  Future<void> _pastePairingLink() async {
    setState(() => _pasting = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        throw const MoriApiException('剪贴板中没有配对链接');
      }
      final link = MoriPairingLink.tryParse(text);
      if (link != null) {
        _serverController.text = link.serverUrl;
        _codeController.text = link.code;
      } else {
        _codeController.text = text;
      }
      if (mounted) {
        setState(() => _error = null);
      }
    } on MoriApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '读取剪贴板失败，请手动填写');
      }
    } finally {
      if (mounted) {
        setState(() => _pasting = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final serverText = _serverController.text.trim();
    final codeText = _codeController.text.trim();
    final link = MoriPairingLink.tryParse(codeText);
    final serverUrl = link?.serverUrl ?? serverText;
    final code = link?.code ?? codeText;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await MoriSessionStore.instance.pair(
        serverUrl: serverUrl,
        code: code,
        deviceName: _deviceController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('设备配对成功')));
      }
    } on MoriApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '配对失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notice = MoriSessionStore.instance.snapshot.value.notice;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
            children: [
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer,
                        colors.primary.withValues(alpha: 0.68),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    MoriIcons.leaf,
                    size: 38,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '连接 MoriBot',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '角色卡、会话和消息都由你的 MoriBot 服务器保存。\n先在后台生成一次性配对码，再在这里完成配对。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
              if (notice != null && notice.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                _NoticeBanner(message: notice),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                _NoticeBanner(message: _error!, isError: true),
              ],
              const MoriSectionHeader(
                label: '配对信息',
                padding: EdgeInsets.fromLTRB(4, 26, 4, 8),
              ),
              MoriSettingsGroup(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                children: [
                  TextFormField(
                    key: const Key('pairing-server-field'),
                    controller: _serverController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://mori.example.com',
                      prefixIcon: Icon(MoriIcons.cpu),
                    ),
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      final link = MoriPairingLink.tryParse(
                        _codeController.text,
                      );
                      if (raw.isEmpty) {
                        return link == null ? '请填写 MoriBot 服务器地址' : null;
                      }
                      try {
                        MoriBotClient.normalizeServerUrl(raw);
                      } on MoriApiException catch (error) {
                        return error.message;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('pairing-code-field'),
                    controller: _codeController,
                    enabled: !_submitting,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    maxLength: 32,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                        );
                      }),
                    ],
                    decoration: InputDecoration(
                      labelText: '配对码',
                      hintText: 'H63M-5LQF',
                      counterText: '',
                      prefixIcon: const Icon(MoriIcons.key),
                      suffixIcon: IconButton(
                        tooltip: '粘贴配对链接',
                        onPressed: _pasting ? null : _pastePairingLink,
                        icon: _pasting
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                ),
                              )
                            : const Icon(MoriIcons.copy, size: 19),
                      ),
                    ),
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      if (raw.isEmpty) {
                        return '请填写配对码';
                      }
                      final link = MoriPairingLink.tryParse(raw);
                      final normalized = (link?.code ?? raw).replaceAll(
                        RegExp(r'[^a-zA-Z0-9]'),
                        '',
                      );
                      if (normalized.length != 8) {
                        return '配对码应为 8 位字母或数字';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('pairing-device-field'),
                    controller: _deviceController,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    maxLength: 64,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '设备名称',
                      hintText: 'Pixel 9',
                      counterText: '',
                      prefixIcon: Icon(MoriIcons.profile),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请填写设备名称';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const Key('pairing-submit-button'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(MoriIcons.check),
                label: Text(_submitting ? '正在配对…' : '连接服务器'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MoriRadius.large),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '配对码 10 分钟内有效且只能使用一次。设备令牌会保存在本机安全存储中，之后打开应用无需再次输入。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = isError
        ? colors.errorContainer.withValues(alpha: 0.7)
        : colors.primaryContainer.withValues(alpha: 0.56);
    final foreground = isError
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MoriRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? MoriIcons.info : MoriIcons.leaf,
            size: 17,
            color: foreground,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
