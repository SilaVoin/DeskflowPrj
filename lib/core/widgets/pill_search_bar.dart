import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class PillSearchBar extends StatefulWidget {
  const PillSearchBar({
    super.key,
    this.hintText = 'Поиск...',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.autofocus = false,
    this.onClear,
    this.height = 44,
    this.horizontalPadding = DeskflowSpacing.md,
    this.gapAfterIcon = DeskflowSpacing.sm,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final bool autofocus;
  final VoidCallback? onClear;
  final double height;
  final double horizontalPadding;
  final double gapAfterIcon;

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
          height: widget.height,
          decoration: BoxDecoration(
            color: _hasFocus
                ? DeskflowColors.shellGlassSurfaceFocused
                : DeskflowColors.shellGlassSurface,
            borderRadius: BorderRadius.circular(DeskflowRadius.pill),
            border: Border.all(
              color: _hasFocus
                  ? DeskflowColors.primarySolid.withValues(alpha: 0.4)
                  : DeskflowColors.glassBorderStrong.withValues(alpha: 0.72),
              width: 0.75,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: widget.horizontalPadding),
              Icon(
                Icons.search_rounded,
                size: 20,
                color: _hasFocus
                    ? DeskflowColors.textSecondary
                    : DeskflowColors.textTertiary,
              ),
              SizedBox(width: widget.gapAfterIcon),
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
              SizedBox(width: widget.horizontalPadding * 0.5),
            ],
          ),
        ),
      ),
    );
  }
}
