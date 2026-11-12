import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/widgets/avatar_fallback.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    required this.size,
    this.previewBytes,
    this.forceFallback = false,
  });

  final UserProfile profile;
  final double size;
  final Uint8List? previewBytes;
  final bool forceFallback;

  @override
  Widget build(BuildContext context) {
    final file = forceFallback
        ? null
        : AvatarStore.instance.fileFor(profile.avatar);
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    final fallback = AvatarFallback(
      label: profile.displayName,
      seed: profile.name,
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
      label: '${profile.displayName}的头像',
      image: true,
      child: ClipOval(
        child: SizedBox(width: size, height: size, child: image),
      ),
    );
  }
}
