import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mori_ai/models/sticker.dart';
import 'package:mori_ai/services/sticker_store.dart';

/// 打开表情包选择面板。
///
/// 返回用户选择的表情包；点击添加按钮会调用 [onAdd] 并刷新列表。
Future<Sticker?> showStickerPickerSheet(
  BuildContext context, {
  required Future<Sticker?> Function() onAdd,
}) {
  return showModalBottomSheet<Sticker>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => StickerPickerSheet(onAdd: onAdd),
  );
}

class StickerPickerSheet extends StatelessWidget {
  const StickerPickerSheet({super.key, required this.onAdd});

  final Future<Sticker?> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 380,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Text(
                  '表情包',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '点按发送 · 长按删除',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Sticker>>(
              valueListenable: StickerStore.instance.stickers,
              builder: (context, stickers, _) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: stickers.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AddStickerTile(onTap: onAdd);
                    }
                    final sticker = stickers[index - 1];
                    return _StickerTile(
                      sticker: sticker,
                      onSelect: () => Navigator.of(context).pop(sticker),
                      onDelete: () => _deleteSticker(context, sticker),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSticker(BuildContext context, Sticker sticker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除表情包'),
        content: const Text('确定删除这张表情包吗？删除后无法恢复。'),
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
      ),
    );
    if (confirmed != true) {
      return;
    }
    await StickerStore.instance.deleteSticker(sticker.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('表情包已删除')));
    }
  }
}

class _AddStickerTile extends StatelessWidget {
  const _AddStickerTile({required this.onTap});

  final Future<Sticker?> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(),
      child: CustomPaint(
        painter: _DashedRectPainter(color: colors.outline, radius: 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: colors.primary),
              const SizedBox(height: 2),
              Text(
                '添加',
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.sticker,
    required this.onSelect,
    required this.onDelete,
  });

  final Sticker sticker;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = sticker.bytes;
    return InkWell(
      onTap: onSelect,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: bytes == null
            ? ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.onSurfaceVariant,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + 4;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
