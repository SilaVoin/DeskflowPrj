import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.suffixIcon,
    this.prefixIcon,
    this.enabled = true,
    this.autofocus = false,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          autofocus: autofocus,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          style: DeskflowTypography.body,
          cursorColor: DeskflowColors.primarySolid,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            labelStyle: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.textSecondary,
            ),
            hintStyle: DeskflowTypography.body.copyWith(
              color: DeskflowColors.textTertiary,
            ),
            errorStyle: DeskflowTypography.caption.copyWith(
              color: DeskflowColors.destructiveSolid,
            ),
            filled: true,
            fillColor: DeskflowColors.glassSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DeskflowSpacing.lg,
              vertical: DeskflowSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              borderSide: const BorderSide(
                color: DeskflowColors.glassBorder,
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              borderSide: const BorderSide(
                color: DeskflowColors.glassBorder,
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              borderSide: BorderSide(
                color: hasError
                    ? DeskflowColors.destructiveSolid
                    : DeskflowColors.primarySolid,
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              borderSide: const BorderSide(
                color: DeskflowColors.destructiveSolid,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              borderSide: const BorderSide(
                color: DeskflowColors.destructiveSolid,
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeskflowRadius.md),
              borderSide: BorderSide(
                color: DeskflowColors.glassBorder.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
