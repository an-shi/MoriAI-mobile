import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/widgets/avatar_fallback.dart';

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.character,
    required this.size,
    this.previewBytes,
    this.forceFallback = false,
  });

  final CharacterProfile character;
  final double size;

  /// 编辑页中尚未保存的头像预览。
  final Uint8List? previewBytes;

  /// 强制显示占位头像，例如用户刚移除了头像。
  final bool forceFallback;

  @override
  Widget build(BuildContext context) {
    final avatar = forceFallback ? '' : character.avatar.trim();
    final isAsset = avatar.startsWith('assets/');
    final file = isAsset ? null : AvatarStore.instance.fileFor(avatar);
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    final fallback = AvatarFallback(
      label: character.displayName,
      seed: character.id,
      size: size,
    );

    final Widget image;
    if (previewBytes != null) {
      image = Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (isAsset) {
      image = Image.asset(
        avatar,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (file == null) {
      image = fallback;
    } else {
      image = Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Semantics(
      label: '${character.displayName}的头像',
      image: true,
      child: ClipOval(
        child: SizedBox(width: size, height: size, child: image),
      ),
    );
  }
}
