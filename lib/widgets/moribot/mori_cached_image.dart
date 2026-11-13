import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mori_ai/services/moribot/mori_media_cache.dart';

/// Displays a server image from the authenticated local media cache.
class MoriCachedImage extends StatefulWidget {
  const MoriCachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  State<MoriCachedImage> createState() => _MoriCachedImageState();
}

class _MoriCachedImageState extends State<MoriCachedImage> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MoriCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  void _load() {
    _future = widget.url.trim().isEmpty
        ? Future<File?>.value(null)
        : MoriMediaCache.instance.fileFor(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _fallback(context),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading(context);
        }
        return _fallback(context);
      },
    );

    final clipped = widget.borderRadius == null
        ? content
        : ClipRRect(borderRadius: widget.borderRadius!, child: content);
    if (widget.width == null && widget.height == null) {
      return clipped;
    }
    return SizedBox(width: widget.width, height: widget.height, child: clipped);
  }

  Widget _loading(BuildContext context) {
    final placeholder = widget.placeholder;
    if (placeholder != null) {
      return placeholder;
    }
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: colors.primary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final placeholder = widget.placeholder;
    if (placeholder != null) {
      return placeholder;
    }
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: 18,
        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
