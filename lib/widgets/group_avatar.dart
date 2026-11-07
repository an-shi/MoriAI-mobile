import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.group,
    required this.size,
    this.previewBytes,
    this.forceFallback = false,
  });

  final GroupProfile group;
  final double size;
  final Uint8List? previewBytes;
  final bool forceFallback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = forceFallback
        ? null
        : AvatarStore.instance.fileFor(group.avatar);
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    final fallback = Container(
      width: size,
      height: size,
      color: colors.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.groups_rounded,
        size: size * 0.55,
        color: colors.onPrimaryContainer,
      ),
    );

    final Widget image;
    if (previewBytes != null) {
      image = Image.memory(
        previewBytes!,
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
      label: '${group.displayName}的群头像',
      image: true,
      child: ClipOval(
        child: SizedBox(width: size, height: size, child: image),
      ),
    );
  }
}
