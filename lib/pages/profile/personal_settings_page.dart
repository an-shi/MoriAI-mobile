import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/ui/mori_components.dart';
import 'package:mori_ai/ui/mori_icons.dart';
import 'package:mori_ai/ui/mori_theme.dart';
import 'package:mori_ai/widgets/user_avatar.dart';

class PersonalSettingsPage extends StatefulWidget {
  const PersonalSettingsPage({super.key});

  @override
  State<PersonalSettingsPage> createState() => _PersonalSettingsPageState();
}

class _PersonalSettingsPageState extends State<PersonalSettingsPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _signatureController;
  late UserGender _gender;
  DateTime? _birthday;
  Uint8List? _pendingAvatarBytes;
  bool _removeAvatar = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = UserProfileStore.instance.profile.value;
    _nameController = TextEditingController(text: profile.name);
    _signatureController = TextEditingController(text: profile.signature);
    _gender = profile.gender;
    _birthday = profile.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
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
                  icon: MoriIcons.photos,
                  label: '照片',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _AvatarSourceButton(
                  icon: MoriIcons.camera,
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

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthday = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final current = UserProfileStore.instance.profile.value;
    final previousAvatar = current.avatar;
    var avatar = previousAvatar;
    String? createdAvatar;

    try {
      if (_pendingAvatarBytes != null) {
        createdAvatar = await AvatarStore.instance.saveAvatar(
          'user',
          _pendingAvatarBytes!,
        );
        avatar = createdAvatar;
      } else if (_removeAvatar) {
        avatar = '';
      }

      await UserProfileStore.instance.save(
        UserProfile(
          name: _nameController.text,
          avatar: avatar,
          gender: _gender,
          birthday: _birthday,
          signature: _signatureController.text,
        ),
      );

      if (previousAvatar.isNotEmpty && previousAvatar != avatar) {
        await AvatarStore.instance.deleteAvatar(previousAvatar);
      }

      if (!mounted) {
        return;
      }
      final saved = UserProfileStore.instance.profile.value;
      _nameController.text = saved.name;
      _signatureController.text = saved.signature;
      setState(() {
        _pendingAvatarBytes = null;
        _removeAvatar = false;
      });
      _showSnackBar('个人信息已保存');
    } catch (_) {
      if (createdAvatar != null) {
        await AvatarStore.instance.deleteAvatar(createdAvatar);
      }
      if (!mounted) {
        return;
      }
      _showSnackBar('个人信息保存失败，请重试');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = UserProfileStore.instance.profile.value;
    final hasAvatar =
        _pendingAvatarBytes != null ||
        (!_removeAvatar && profile.avatar.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: ListView(
        padding: MoriTheme.pagePadding,
        children: [
          const MoriPageIntro(text: '这些信息只用于你在 Mori 里的显示名称和角色对你的称呼。'),
          MoriSettingsGroup(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  UserAvatar(
                    profile: profile,
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
                          icon: const Icon(MoriIcons.imagePlus, size: 17),
                          label: const Text('更换头像'),
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
                            child: const Text('移除头像'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const MoriSectionHeader(label: '基本资料'),
          MoriSettingsGroup(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            children: [
              TextField(
                controller: _nameController,
                maxLength: 24,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：小森',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<UserGender>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: '性别'),
                items: [
                  for (final gender in UserGender.values)
                    DropdownMenuItem<UserGender>(
                      value: gender,
                      child: Text(gender.label),
                    ),
                ],
                onChanged: (gender) {
                  if (gender != null) {
                    setState(() => _gender = gender);
                  }
                },
              ),
              const SizedBox(height: 14),
              Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(MoriRadius.medium),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 1,
                  ),
                  leading: Icon(
                    MoriIcons.cake,
                    size: 20,
                    color: colors.primary,
                  ),
                  title: Text(
                    '生日',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 15.5,
                    ),
                  ),
                  subtitle: Text(
                    _birthday == null ? '未设置' : _formatDate(_birthday!),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_birthday != null)
                        IconButton(
                          onPressed: () => setState(() => _birthday = null),
                          tooltip: '清除生日',
                          icon: const Icon(MoriIcons.close, size: 18),
                        ),
                      Icon(
                        MoriIcons.chevron,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: _pickBirthday,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _signatureController,
                maxLength: 100,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '个性签名',
                  hintText: '写一句介绍自己的话',
                  counterText: '',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(MoriIcons.save, size: 17),
            label: const Text('保存个人信息'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}年${value.month}月${value.day}日';
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
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(MoriRadius.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 23, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
