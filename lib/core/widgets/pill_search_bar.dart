import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Glass-styled pill-shaped search bar.
///
/// Displays a capsule with a search icon and placeholder text.
/// When focused, optionally expands and shows a cancel button.
///
/// ```dart
/// PillSearchBar(
///   hintText: 'Поиск заказов...',
///   onChanged: (query) => print(query),
/// )
/// ```
class PillSearchBar extends StatefulWidget {
  const PillSearchBar({
    super.key,
    this.hintText = 'Поиск...',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.autofocus = false,
    this.onClear,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final bool autofocus;
  final VoidCallback? onClear;

  @override
  State<PillSearchBar> createState() => _PillSearchBarState();
}

class _PillSearchBarState extends State<PillSearchBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onFocusChanged() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DeskflowRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 44,
          decoration: BoxDecoration(
            color: _hasFocus
                ? DeskflowColors.glassSurfaceElevated
                : DeskflowColors.glassSurface,
            borderRadius: BorderRadius.circular(DeskflowRadius.pill),
            border: Border.all(
              color: _hasFocus
                  ? DeskflowColors.primarySolid.withValues(alpha: 0.4)
                  : DeskflowColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: DeskflowSpacing.md),
              Icon(
                Icons.search_rounded,
                size: 20,
                color: _hasFocus
                    ? DeskflowColors.textSecondary
                    : DeskflowColors.textTertiary,
              ),
              const SizedBox(width: DeskflowSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  style: DeskflowTypography.body,
                  cursorColor: DeskflowColors.primarySolid,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: DeskflowTypography.body.copyWith(
                      color: DeskflowColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: widget.onSubmitted,
                ),
              ),
              if (_hasText)
                IconButton(
                  onPressed: _clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: DeskflowColors.textTertiary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              const SizedBox(width: DeskflowSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
