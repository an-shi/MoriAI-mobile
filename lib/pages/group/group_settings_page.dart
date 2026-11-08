import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/models/group_reply_mode.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/group_avatar.dart';

class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final Set<String> _selectedIds;
  late GroupReplyMode _replyMode;
  Uint8List? _pendingAvatarBytes;
  bool _removeAvatar = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final group = GroupStore.instance.groupById(widget.groupId);
    _nameController = TextEditingController(text: group?.name ?? '');
    _selectedIds = {
      for (final id in group?.memberIds ?? const <String>[])
        if (CharacterStore.instance.cardById(id) != null) id,
    };
    _replyMode = group?.replyMode ?? GroupReplyMode.sequential;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: _AvatarSourceButton(
                  icon: Icons.photo_library_outlined,
                  label: '照片',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _AvatarSourceButton(
                  icon: Icons.photo_camera_outlined,
                  label: '拍摄',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null || !mounted) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      if (bytes.isEmpty) {
        _showSnackBar('头像读取失败，请重新选择。');
        return;
      }
      if (bytes.lengthInBytes > 4 * 1024 * 1024) {
        _showSnackBar('头像不能超过 4 MB，请选择更小的图片。');
        return;
      }
      setState(() {
        _pendingAvatarBytes = bytes;
        _removeAvatar = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('无法选择头像，请检查相册或相机权限。');
    }
  }

  Future<void> _save() async {
    final group = GroupStore.instance.groupById(widget.groupId);
    if (group == null) {
      _showSnackBar('群聊不存在或已被删除');
      return;
    }
    if (_selectedIds.length < 2) {
      _showSnackBar('群聊至少需要两个成员');
      return;
    }

    setState(() => _saving = true);
    var avatar = group.avatar;
    String? createdAvatar;
    try {
      if (_pendingAvatarBytes != null) {
        createdAvatar = await AvatarStore.instance.saveAvatar(
          group.id,
          _pendingAvatarBytes!,
        );
        avatar = createdAvatar;
      } else if (_removeAvatar) {
        avatar = '';
      }

      final name = _nameController.text.trim().isEmpty
          ? '群聊'
          : _nameController.text.trim();
      await GroupStore.instance.updateGroup(
        GroupProfile(
          id: group.id,
          name: name,
          avatar: avatar,
          memberIds: _selectedIds.toList(growable: false),
          createdAt: group.createdAt,
          replyMode: _replyMode,
        ),
      );

      if (group.avatar.isNotEmpty && group.avatar != avatar) {
        await AvatarStore.instance.deleteAvatar(group.avatar);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (createdAvatar != null) {
        await AvatarStore.instance.deleteAvatar(createdAvatar);
      }
      if (!mounted) {
        return;
      }
      _showSnackBar('群聊设置保存失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除聊天记录'),
          content: const Text('确定删除该群聊的全部聊天记录吗？删除后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ChatHistoryStore.instance.deleteConversation(widget.groupId);
      await ChatQueueStore.instance.saveFor(widget.groupId, const []);
      if (mounted) {
        _showSnackBar('聊天记录已删除');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('删除聊天记录失败，请重试');
      }
    }
  }

  String _replyModeLabel(GroupReplyMode mode) {
    return switch (mode) {
      GroupReplyMode.sequential => '固定顺序，全部回复',
      GroupReplyMode.randomOrder => '随机顺序，全部回复',
      GroupReplyMode.singleRandom => '随机选择一名角色回复',
      GroupReplyMode.mentioned => '优先回复被点名的角色',
    };
  }

  String _replyModeDescription(GroupReplyMode mode) {
    return switch (mode) {
      GroupReplyMode.sequential => '群成员按列表顺序依次回复。',
      GroupReplyMode.randomOrder => '每轮打乱成员顺序，但所有成员都会回复。',
      GroupReplyMode.singleRandom => '每轮随机选择一名角色回复，更接近群聊。',
      GroupReplyMode.mentioned => '消息中提到角色名时由该角色回复，否则随机一名。',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final group = GroupStore.instance.groupById(widget.groupId);
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('群聊设置')),
        body: const Center(child: Text('群聊不存在或已被删除')),
      );
    }

    final cards = CharacterStore.instance.cards.value;
    final hasAvatar =
        _pendingAvatarBytes != null ||
        (!_removeAvatar && group.avatar.isNotEmpty);
    final canSave = _selectedIds.length >= 2 && !_saving;

    return Scaffold(
      appBar: AppBar(title: const Text('群聊设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GroupAvatar(
                    group: group,
                    size: 84,
                    previewBytes: _pendingAvatarBytes,
                    forceFallback: _removeAvatar && _pendingAvatarBytes == null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _saving ? null : _pickAvatar,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('更换群头像'),
                        ),
                        if (hasAvatar)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() {
                                      _pendingAvatarBytes = null;
                                      _removeAvatar = true;
                                    });
                                  },
                            child: const Text('移除群头像'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: '群聊名称',
              hintText: '例如：深夜聊天室',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<GroupReplyMode>(
            initialValue: _replyMode,
            decoration: InputDecoration(
              labelText: '发言顺序',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              for (final mode in GroupReplyMode.values)
                DropdownMenuItem<GroupReplyMode>(
                  value: mode,
                  child: Text(_replyModeLabel(mode)),
                ),
            ],
            onChanged: _saving
                ? null
                : (mode) {
                    if (mode != null) {
                      setState(() => _replyMode = mode);
                    }
                  },
          ),
          const SizedBox(height: 8),
          Text(
            _replyModeDescription(_replyMode),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '群成员',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '已选 ${_selectedIds.length} 人',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: colors.outlineVariant,
                    ),
                  CheckboxListTile(
                    value: _selectedIds.contains(cards[index].id),
                    onChanged: _saving
                        ? null
                        : (selected) {
                            setState(() {
                              final id = cards[index].id;
                              if (selected == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                    secondary: CharacterAvatar(
                      character: cards[index],
                      size: 40,
                    ),
                    title: Text(cards[index].displayName),
                    subtitle: Text(cards[index].type.label),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canSave ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_selectedIds.length < 2 ? '至少选择两个成员' : '保存群聊设置'),
          ),
          const SizedBox(height: 16),
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
              leading: Icon(Icons.delete_sweep_outlined, color: colors.error),
              title: Text('删除聊天记录', style: TextStyle(color: colors.error)),
              subtitle: const Text('清空该群聊的全部本地聊天记录'),
              onTap: _saving ? null : _deleteHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSourceButton extends StatelessWidget {
  const _AvatarSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: colors.primary),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
