import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
  });

  final Widget child;

  static Widget box({
    double? width,
    double height = 16,
    double borderRadius = DeskflowRadius.md,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: DeskflowColors.glassSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static Widget circle({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: DeskflowColors.glassSurface,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}
