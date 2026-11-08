import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 数字设置输入框。
///
/// [allowUnlimited] 为 true 时，输入负数会归一化为 -1，表示无上限。
class NumberSettingField extends StatefulWidget {
  const NumberSettingField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.allowUnlimited = false,
    this.min = 0,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? helperText;
  final bool allowUnlimited;
  final int min;

  @override
  State<NumberSettingField> createState() => _NumberSettingFieldState();
}

class _NumberSettingFieldState extends State<NumberSettingField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant NumberSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = widget.value.toString();
      return;
    }

    var normalized = parsed;
    if (widget.allowUnlimited && normalized < 0) {
      normalized = -1;
    } else if (normalized < widget.min) {
      normalized = widget.min;
    }

    _controller.text = normalized.toString();
    if (normalized != widget.value) {
      widget.onChanged(normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) {
        _focusNode.unfocus();
      },
    );
  }
}
