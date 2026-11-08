import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';

class CharacterCardEditPage extends StatefulWidget {
  const CharacterCardEditPage({
    super.key,
    required this.cardId,
    this.isNew = false,
    this.initialName = '',
  });

  final String cardId;
  final bool isNew;
  final String initialName;

  @override
  State<CharacterCardEditPage> createState() => _CharacterCardEditPageState();
}

class _CharacterCardEditPageState extends State<CharacterCardEditPage> {
  static const _burstStyleTemplate = '''
你是在用手机打字聊天，不是在写文章。
一次只说一两句话，最多两三句。
想说的多就拆成几条短消息发，用 ||| 分隔。
每条尽量短，一条控制在 15-25 个字左右。
禁止一次输出一大段，超过三行就是错的。''';

  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late final TextEditingController _personaController;
  late final TextEditingController _personalityController;
  late final TextEditingController _speakingStyleController;
  late final TextEditingController _backgroundController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _likesController;
  late final TextEditingController _dislikesController;
  late final TextEditingController _boundariesController;
  late final TextEditingController _scenarioController;
  late final TextEditingController _greetingController;
  late final TextEditingController _exampleDialogueController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _postHistoryController;
  late final TextEditingController _rawDefinitionController;

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _pendingAvatarBytes;
  bool _removeAvatar = false;

  late CharacterCardType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final card = widget.isNew
        ? null
        : CharacterStore.instance.cardById(widget.cardId);
    _type = card?.type ?? CharacterCardType.simple;
    _nameController = TextEditingController(
      text: card?.name ?? widget.initialName,
    );
    _taglineController = TextEditingController(text: card?.tagline ?? '');
    _personaController = TextEditingController(text: card?.persona ?? '');
    _personalityController = TextEditingController(
      text: card?.personality ?? '',
    );
    _speakingStyleController = TextEditingController(
      text: card?.speakingStyle ?? '',
    );
    _backgroundController = TextEditingController(text: card?.background ?? '');
    _relationshipController = TextEditingController(
      text: card?.relationship ?? '',
    );
    _likesController = TextEditingController(text: card?.likes ?? '');
    _dislikesController = TextEditingController(text: card?.dislikes ?? '');
    _boundariesController = TextEditingController(text: card?.boundaries ?? '');
    _scenarioController = TextEditingController(text: card?.scenario ?? '');
    _greetingController = TextEditingController(text: card?.greeting ?? '');
    _exampleDialogueController = TextEditingController(
      text: card?.exampleDialogue ?? '',
    );
    _systemPromptController = TextEditingController(
      text: card?.systemPrompt ?? '',
    );
    _postHistoryController = TextEditingController(
      text: card?.postHistoryInstructions ?? '',
    );
    _rawDefinitionController = TextEditingController(
      text: card?.rawDefinition ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _personaController.dispose();
    _personalityController.dispose();
    _speakingStyleController.dispose();
    _backgroundController.dispose();
    _relationshipController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    _boundariesController.dispose();
    _scenarioController.dispose();
    _greetingController.dispose();
    _exampleDialogueController.dispose();
    _systemPromptController.dispose();
    _postHistoryController.dispose();
    _rawDefinitionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final current = CharacterStore.instance.cardById(widget.cardId);
    final previousAvatar = current?.avatar ?? '';
    var avatar = previousAvatar;
    String? createdAvatar;

    try {
      if (_pendingAvatarBytes != null) {
        createdAvatar = await AvatarStore.instance.saveAvatar(
          widget.cardId,
          _pendingAvatarBytes!,
        );
        avatar = createdAvatar;
      } else if (_removeAvatar) {
        avatar = '';
      }

      final profile = CharacterProfile(
        id: widget.cardId,
        type: _type,
        avatar: avatar,
        name: _nameController.text,
        tagline: _taglineController.text,
        persona: _personaController.text,
        personality: _personalityController.text,
        speakingStyle: _speakingStyleController.text,
        background: _backgroundController.text,
        relationship: _relationshipController.text,
        likes: _likesController.text,
        dislikes: _dislikesController.text,
        boundaries: _boundariesController.text,
        scenario: _scenarioController.text,
        greeting: _greetingController.text,
        exampleDialogue: _exampleDialogueController.text,
        systemPrompt: _systemPromptController.text,
        postHistoryInstructions: _postHistoryController.text,
        rawDefinition: _rawDefinitionController.text,
      );

      if (widget.isNew) {
        await CharacterStore.instance.createCard(profile);
      } else {
        await CharacterStore.instance.save(profile);
      }

      if (previousAvatar.isNotEmpty && previousAvatar != avatar) {
        await AvatarStore.instance.deleteAvatar(previousAvatar);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (createdAvatar != null) {
        await AvatarStore.instance.deleteAvatar(createdAvatar);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('角色卡保存失败，请重试')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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

  void _clearAvatar() {
    setState(() {
      _pendingAvatarBytes = null;
      _removeAvatar = true;
    });
  }

  Future<void> _pasteRawDefinition() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) {
      return;
    }
    if (text.isEmpty) {
      _showSnackBar('剪贴板中没有可粘贴的文本');
      return;
    }

    _rawDefinitionController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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
    final pageTitle = widget.isNew ? '新建角色卡' : '编辑角色卡';
    final storedCard = CharacterStore.instance.cardById(widget.cardId);
    final card =
        storedCard ??
        (widget.isNew
            ? CharacterProfile(
                id: widget.cardId,
                type: _type,
                name: _nameController.text,
              )
            : null);

    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: Text(pageTitle)),
        body: const Center(child: Text('角色卡不存在或已被删除')),
      );
    }

    final hasAvatar =
        _pendingAvatarBytes != null ||
        (!_removeAvatar && card.avatar.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '为「${card.displayName}」设置头像、填写类型与人物设定。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _CharacterSectionCard(
            icon: Icons.account_circle_outlined,
            title: '角色头像',
            description: '会显示在角色卡列表和对话页面的助理头像上。',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CharacterAvatar(
                  character: card,
                  size: 88,
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
                        label: const Text('选择头像'),
                      ),
                      if (hasAvatar)
                        TextButton(
                          onPressed: _saving ? null : _clearAvatar,
                          child: const Text('移除头像'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CharacterSectionCard(
            icon: Icons.tune_rounded,
            title: '角色卡类型',
            description: '选择适合的填写模板。切换类型会保留已填写内容，但只有当前类型包含的字段会用于对话。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<CharacterCardType>(
                  key: const ValueKey('character-card-type'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '填写类型',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    for (final type in CharacterCardType.values)
                      DropdownMenuItem<CharacterCardType>(
                        value: type,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: (type) {
                    if (type == null) {
                      return;
                    }
                    setState(() => _type = type);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _type.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CharacterSectionCard(
            icon: Icons.badge_outlined,
            title: '基础信息',
            description: _type.usesRawDefinition
                ? '名称仅用于角色卡列表和对话称呼，粘贴的设定原文不会被改写。'
                : '角色名称会用于对话称呼，简介会显示在角色卡列表中。',
            child: Column(
              children: [
                _buildField(
                  controller: _nameController,
                  label: '名称',
                  hint: '例如：小森',
                  maxLength: 24,
                  textInputAction: TextInputAction.next,
                ),
                if (!_type.usesRawDefinition) ...[
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _taglineController,
                    label: '一句话简介',
                    hint: '例如：温柔、耐心，喜欢倾听的伙伴',
                    maxLength: 80,
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ],
            ),
          ),
          if (_type.usesRawDefinition) ...[
            const SizedBox(height: 16),
            _CharacterSectionCard(
              icon: Icons.content_paste_rounded,
              title: '粘贴角色卡设定',
              description: '把从其他地方复制来的完整设定粘贴到这里。原文会直接作为系统提示词，不做拆分或改写。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _pasteRawDefinition,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('从剪贴板粘贴'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildField(
                    controller: _rawDefinitionController,
                    label: '角色卡设定',
                    hint: '在此粘贴完整设定，例如角色名称、背景、性格、说话方式、开场白和示例对话。',
                    maxLength: 20000,
                    minLines: 12,
                    maxLines: 30,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  _burstTemplateButton(_rawDefinitionController),
                ],
              ),
            ),
          ],
          if (!_type.usesRawDefinition) ...[
            const SizedBox(height: 16),
            _CharacterSectionCard(
              icon: Icons.psychology_outlined,
              title: '人格描述',
              description: '一段自由填写的人格说明，适合简单陪伴类型。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    controller: _personaController,
                    label: '人格描述',
                    hint: '例如：温柔、真诚，带一点幽默感，善于倾听。',
                    maxLength: 1200,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  _burstTemplateButton(_personaController),
                ],
              ),
            ),
          ],
          if (_type.usesStructuredSettings) ...[
            const SizedBox(height: 16),
            _CharacterSectionCard(
              icon: Icons.account_tree_outlined,
              title: '结构化设定',
              description: '这些字段只在结构化设定及以上类型中生效，建议保持简洁具体。',
              child: Column(
                children: [
                  _buildField(
                    controller: _personalityController,
                    label: '性格特点',
                    hint: '例如：温柔、真诚、耐心，偶尔有一点幽默感。',
                    maxLength: 800,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _speakingStyleController,
                    label: '说话方式',
                    hint: '例如：短句口语；一次一两句，想说的多就拆成几条发，用 ||| 分隔。',
                    maxLength: 800,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  _burstTemplateButton(_speakingStyleController),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _backgroundController,
                    label: '背景故事',
                    hint: '角色的身份、经历和世界观。',
                    maxLength: 1200,
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _relationshipController,
                    label: '与用户的关系',
                    hint: '例如：逐渐熟悉、值得信任的朋友。',
                    maxLength: 300,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _likesController,
                    label: '喜欢',
                    hint: '例如：安静的音乐、植物、深夜的闲聊。',
                    maxLength: 400,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _dislikesController,
                    label: '不喜欢',
                    hint: '例如：被强迫做决定、过度客套。',
                    maxLength: 400,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _boundariesController,
                    label: '行为边界',
                    hint: '例如：不假装人类，不提供医疗或法律方面的确定性建议。',
                    maxLength: 800,
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ],
          if (_type.usesDialogueSettings) ...[
            const SizedBox(height: 16),
            _CharacterSectionCard(
              icon: Icons.chat_bubble_outline,
              title: '对话表现',
              description: '场景和示例对话会加入提示词；开场白会显示在对话欢迎页。',
              child: Column(
                children: [
                  _buildField(
                    controller: _scenarioController,
                    label: '场景',
                    hint: '例如：一个安静的夜晚，用户刚结束忙碌的一天。',
                    maxLength: 800,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _greetingController,
                    label: '开场白',
                    hint: '角色在新对话中说的第一句话。',
                    maxLength: 800,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _exampleDialogueController,
                    label: '示例对话',
                    hint: '<START>\n{{user}}: 今天有点累。\n{{char}}: 那就先别急着振作，想聊聊吗？',
                    maxLength: 3000,
                    minLines: 5,
                    maxLines: 10,
                  ),
                ],
              ),
            ),
          ],
          if (_type.usesAdvancedSettings) ...[
            const SizedBox(height: 16),
            _CharacterSectionCard(
              icon: Icons.settings_suggest_outlined,
              title: '高级指令',
              description: '追加到系统提示词中，适合需要精细控制模型行为的角色。',
              child: Column(
                children: [
                  _buildField(
                    controller: _systemPromptController,
                    label: '附加系统指令',
                    hint: '例如：始终保持简洁，不要主动结束对话。',
                    maxLength: 2000,
                    minLines: 4,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _postHistoryController,
                    label: '附加行为要求',
                    hint: '例如：每次回复都先回应情绪，再提出一个具体建议。',
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 6,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('保存角色卡'),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _appendBurstTemplate(TextEditingController controller) {
    final existing = controller.text.trimRight();
    if (existing.contains('用 ||| 分隔')) {
      return;
    }
    final next = existing.isEmpty
        ? _burstStyleTemplate
        : '$existing\n\n$_burstStyleTemplate';
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    setState(() {});
  }

  Widget _burstTemplateButton(TextEditingController controller) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _saving ? null : () => _appendBurstTemplate(controller),
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Text('填入连发模板'),
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

class _CharacterSectionCard extends StatelessWidget {
  const _CharacterSectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
