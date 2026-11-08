import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/moment.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/character_activity_recorder.dart';
import 'package:mori_ai/services/moment_generator.dart';
import 'package:mori_ai/services/moment_interaction_service.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/widgets/character_avatar.dart';
import 'package:mori_ai/widgets/user_avatar.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({
    super.key,
    this.generator,
    this.interactions,
    this.authorId,
    this.showComposer = true,
    this.showCharacterAction = true,
    this.headerLabel = '最新动态',
  });

  final MomentGenerator? generator;
  final MomentInteractions? interactions;
  final String? authorId;
  final bool showComposer;
  final bool showCharacterAction;
  final String headerLabel;

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  late final MomentGenerator _generator;
  late final MomentInteractions _interactions;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _generator = widget.generator ?? MomentService();
    _interactions = widget.interactions ?? MomentInteractionService.instance;
  }

  @override
  void dispose() {
    _generator.dispose();
    super.dispose();
  }

  Future<void> _composeMoment() async {
    final draft = await showModalBottomSheet<_MomentDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _MomentComposer(),
    );
    if (draft == null ||
        (draft.text.trim().isEmpty && draft.image == null) ||
        !mounted) {
      return;
    }

    final profile = UserProfileStore.instance.profile.value;
    try {
      final moment = await MomentStore.instance.add(
        authorId: 'user',
        authorName: profile.displayName,
        isUser: true,
        content: draft.text,
        image: draft.image,
      );
      unawaited(_interactions.onMomentCreated(moment));
      if (!mounted) {
        return;
      }
      _showSnackBar('动态已发布');
    } catch (_) {
      if (mounted) {
        _showSnackBar('发布动态失败，请重试');
      }
    }
  }

  Future<CharacterProfile?> _pickCharacter({
    required String title,
    required String subtitle,
  }) async {
    final cards = CharacterStore.instance.cards.value;
    if (cards.isEmpty) {
      _showSnackBar('还没有可用的角色卡');
      return null;
    }

    return showModalBottomSheet<CharacterProfile>(
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
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final card in cards)
                  ListTile(
                    key: ValueKey('moment-character-${card.id}'),
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
  }

  Future<void> _openCharacterPicker() async {
    if (_generating) {
      return;
    }

    final selected = await _pickCharacter(
      title: '角色发动态',
      subtitle: '选择一个角色，使用当前模型生成一条动态。',
    );
    if (selected == null || !mounted) {
      return;
    }
    await _generateForCharacter(selected);
  }

  Future<void> _generateForCharacter(CharacterProfile character) async {
    setState(() => _generating = true);
    try {
      final content = await _generator.generateForCharacter(character);
      if (!mounted) {
        return;
      }
      final moment = await MomentStore.instance.add(
        authorId: character.id,
        authorName: character.displayName,
        isUser: false,
        content: content,
      );
      unawaited(
        CharacterActivityRecorder.recordMoment(
          character: character,
          moment: moment,
        ),
      );
      unawaited(_interactions.onMomentCreated(moment));
      if (!mounted) {
        return;
      }
      _showSnackBar('「${character.displayName}」发布了新动态');
    } on MomentGenerationException catch (error) {
      if (mounted) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('生成动态失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  String _commentAuthorName(MomentComment comment) {
    if (comment.isUser) {
      return UserProfileStore.instance.profile.value.displayName;
    }
    final character = CharacterStore.instance.cardById(comment.authorId);
    return character?.displayName ??
        (comment.authorName.isEmpty ? '角色' : comment.authorName);
  }

  Future<void> _commentOnMoment(Moment moment, {MomentComment? replyTo}) async {
    final replyToName = replyTo == null ? null : _commentAuthorName(replyTo);
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CommentComposer(
        moment: moment,
        replyTo: replyTo,
        replyToName: replyToName ?? '',
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) {
      return;
    }

    final profile = UserProfileStore.instance.profile.value;
    try {
      final comment = await MomentStore.instance.addComment(
        moment.id,
        authorId: 'user',
        authorName: profile.displayName,
        isUser: true,
        content: text,
        replyToCommentId: replyTo?.id ?? '',
        replyToAuthorName: replyToName ?? '',
        replyDepth: replyTo == null ? 0 : replyTo.replyDepth + 1,
      );
      unawaited(_interactions.onCommentCreated(moment, comment));
      if (mounted) {
        _showSnackBar(replyTo == null ? '评论已发布' : '回复已发布');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(replyTo == null ? '评论失败，请重试' : '回复失败，请重试');
      }
    }
  }

  Future<void> _deleteMoment(Moment moment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除动态'),
          content: const Text('确定删除这条动态吗？'),
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
      await MomentStore.instance.delete(moment.id);
      if (mounted) {
        _showSnackBar('动态已删除');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('删除动态失败，请重试');
      }
    }
  }

  Future<void> _showCommentActions(Moment moment, MomentComment comment) async {
    final colors = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('delete-comment-action'),
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                ),
                title: Text('删除评论', style: TextStyle(color: colors.error)),
                subtitle: const Text('该评论下的回复也会一起删除'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action != 'delete' || !mounted) {
      return;
    }

    try {
      await MomentStore.instance.deleteComment(moment.id, comment.id);
      if (mounted) {
        _showSnackBar('评论已删除');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('删除评论失败，请重试');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.isNegative || difference.inMinutes < 1) {
      return '刚刚';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} 分钟前';
    }

    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final dayDifference = today.difference(date).inDays;
    if (dayDifference == 0) {
      return '${difference.inHours} 小时前';
    }
    final hourMinute =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (dayDifference == 1) {
      return '昨天 $hourMinute';
    }
    if (time.year == now.year) {
      return '${time.month}月${time.day}日';
    }
    return '${time.year}年${time.month}月${time.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: widget.showComposer
          ? FloatingActionButton.extended(
              key: const Key('moment-compose-fab'),
              onPressed: _composeMoment,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('发动态'),
            )
          : null,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          MomentStore.instance.moments,
          CharacterStore.instance.cards,
          UserProfileStore.instance.profile,
        ]),
        builder: (context, _) {
          final allMoments = MomentStore.instance.moments.value;
          final moments = widget.authorId == null
              ? allMoments
              : [
                  for (final moment in allMoments)
                    if (moment.authorId == widget.authorId) moment,
                ];
          final userProfile = UserProfileStore.instance.profile.value;

          return Column(
            children: [
              if (_generating)
                const LinearProgressIndicator(
                  key: Key('moment-generating'),
                  minHeight: 2,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.headerLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.showCharacterAction)
                      TextButton.icon(
                        key: const Key('moment-character-action'),
                        onPressed: _generating ? null : _openCharacterPicker,
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: Text(_generating ? '生成中…' : '角色发动态'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: moments.isEmpty
                    ? _EmptyMoments(
                        onCompose: widget.showComposer ? _composeMoment : null,
                        onGenerate: widget.showCharacterAction && !_generating
                            ? _openCharacterPicker
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: moments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final moment = moments[index];
                          final character = moment.isUser
                              ? null
                              : CharacterStore.instance.cardById(
                                  moment.authorId,
                                );
                          final authorName = moment.isUser
                              ? userProfile.displayName
                              : (character?.displayName ??
                                    (moment.authorName.isEmpty
                                        ? '角色'
                                        : moment.authorName));
                          final avatar = moment.isUser
                              ? UserAvatar(profile: userProfile, size: 40)
                              : CharacterAvatar(
                                  character:
                                      character ??
                                      CharacterProfile(
                                        id: moment.authorId,
                                        name: moment.authorName,
                                      ),
                                  size: 40,
                                );

                          return _MomentCard(
                            moment: moment,
                            authorName: authorName,
                            userDisplayName: userProfile.displayName,
                            avatar: avatar,
                            timeLabel: _formatTime(moment.createdAt),
                            onComment: () => _commentOnMoment(moment),
                            onReplyComment: (comment) =>
                                _commentOnMoment(moment, replyTo: comment),
                            onDeleteComment: (comment) =>
                                _showCommentActions(moment, comment),
                            onDelete: () => _deleteMoment(moment),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyMoments extends StatelessWidget {
  const _EmptyMoments({required this.onCompose, required this.onGenerate});

  final VoidCallback? onCompose;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dynamic_feed_outlined,
              size: 52,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              '还没有动态',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '发一条动态，或者让角色发一条。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (onCompose != null || onGenerate != null) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (onCompose != null)
                    FilledButton.tonalIcon(
                      onPressed: onCompose,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('发动态'),
                    ),
                  if (onGenerate != null)
                    OutlinedButton.icon(
                      onPressed: onGenerate,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('角色发动态'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.authorName,
    required this.userDisplayName,
    required this.avatar,
    required this.timeLabel,
    required this.onComment,
    required this.onReplyComment,
    required this.onDeleteComment,
    required this.onDelete,
  });

  final Moment moment;
  final String authorName;
  final String userDisplayName;
  final Widget avatar;
  final String timeLabel;
  final VoidCallback onComment;
  final ValueChanged<MomentComment> onReplyComment;
  final ValueChanged<MomentComment> onDeleteComment;
  final VoidCallback onDelete;

  String _commentAuthorName(MomentComment comment) {
    if (comment.isUser) {
      return userDisplayName;
    }
    final character = CharacterStore.instance.cardById(comment.authorId);
    if (character != null) {
      return character.displayName;
    }
    return comment.authorName.isEmpty ? '角色' : comment.authorName;
  }

  String? _replyTargetName(MomentComment comment) {
    if (comment.replyToCommentId.isEmpty) {
      return null;
    }
    for (final target in moment.comments) {
      if (target.id == comment.replyToCommentId) {
        return _commentAuthorName(target);
      }
    }
    return comment.replyToAuthorName.isEmpty ? null : comment.replyToAuthorName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('moment-menu-${moment.id}'),
                  tooltip: '动态菜单',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded),
                          SizedBox(width: 10),
                          Text('删除'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (moment.image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Image.memory(
                    moment.image!.bytes,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    semanticLabel: '动态图片',
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        width: double.infinity,
                        color: colors.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (moment.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                moment.content,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 2,
              children: [
                TextButton.icon(
                  key: ValueKey('moment-comment-${moment.id}'),
                  onPressed: onComment,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(
                    moment.comments.isEmpty
                        ? '评论'
                        : '评论 ${moment.comments.length}',
                  ),
                ),
              ],
            ),
            if (moment.comments.isNotEmpty) ...[
              Divider(height: 16, color: colors.outlineVariant),
              for (final comment in moment.comments)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('moment-comment-row-${comment.id}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onReplyComment(comment),
                    onLongPress: () => onDeleteComment(comment),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${_commentAuthorName(comment)}${_replyTargetName(comment) == null ? '' : ' 回复 ${_replyTargetName(comment)}'}：',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: comment.content),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MomentDraft {
  const _MomentDraft({required this.text, this.image});

  final String text;
  final MomentImage? image;
}

class _MomentComposer extends StatefulWidget {
  const _MomentComposer();

  @override
  State<_MomentComposer> createState() => _MomentComposerState();
}

class _MomentComposerState extends State<_MomentComposer> {
  static const _supportedImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  MomentImage? _image;
  bool _canPublish = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    final canPublish = _controller.text.trim().isNotEmpty || _image != null;
    if (canPublish == _canPublish) {
      return;
    }
    setState(() => _canPublish = canPublish);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('照片'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍摄'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
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
        maxWidth: 1600,
        maxHeight: 1600,
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
        _showSnackBar('图片读取失败，请重新选择。');
        return;
      }
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        _showSnackBar('图片不能超过 8 MB，请选择更小的图片。');
        return;
      }

      final mimeType = _imageMimeType(file);
      if (!_supportedImageMimeTypes.contains(mimeType)) {
        _showSnackBar('仅支持 JPEG、PNG、GIF、WebP 格式的图片。');
        return;
      }

      setState(() {
        _image = MomentImage(bytes: bytes, mimeType: mimeType);
        _canPublish = true;
      });
    } catch (_) {
      if (mounted) {
        _showSnackBar('无法选择图片，请检查相册或相机权限。');
      }
    }
  }

  String _imageMimeType(XFile file) {
    final mimeType = file.mimeType?.trim().toLowerCase();
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }
    if (name.endsWith('.gif')) {
      return 'image/gif';
    }
    if (name.endsWith('.heic')) {
      return 'image/heic';
    }
    if (name.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _publish() {
    Navigator.of(context)
        .pop(_MomentDraft(text: _controller.text.trim(), image: _image));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = UserProfileStore.instance.profile.value;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(profile: profile, size: 36),
                const SizedBox(width: 10),
                Text(
                  profile.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('moment-input'),
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '分享此刻…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_image != null) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _image!.bytes,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 88,
                          height: 88,
                          color: colors.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colors.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Material(
                      color: colors.surfaceContainerHighest,
                      elevation: 1,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          setState(() {
                            _image = null;
                            _canPublish = _controller.text.trim().isNotEmpty;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('图片'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('moment-publish'),
                  onPressed: _canPublish ? _publish : null,
                  child: const Text('发布'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({
    required this.moment,
    this.replyTo,
    this.replyToName = '',
  });

  final Moment moment;
  final MomentComment? replyTo;
  final String replyToName;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _controller = TextEditingController();
  bool _canPublish = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    final canPublish = _controller.text.trim().isNotEmpty;
    if (canPublish == _canPublish) {
      return;
    }
    setState(() => _canPublish = canPublish);
  }

  void _publish() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = UserProfileStore.instance.profile.value;
    final momentSummary = widget.moment.content.isEmpty
        ? '分享了一张图片'
        : widget.moment.content;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.replyTo == null ? '写评论' : '回复 ${widget.replyToName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              momentSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (widget.replyTo != null) ...[
              const SizedBox(height: 6),
              Text(
                '「${widget.replyTo!.content}」',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                UserAvatar(profile: profile, size: 36),
                const SizedBox(width: 10),
                Text(
                  profile.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('comment-input'),
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: widget.replyTo == null
                    ? '写评论…'
                    : '回复 ${widget.replyToName}…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('comment-publish'),
                onPressed: _canPublish ? _publish : null,
                child: const Text('发布'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
