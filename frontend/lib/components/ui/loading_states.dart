import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

class LoadingSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const LoadingSpinner({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * 3.14159,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (widget.color ?? DesignTokens.colors['primary']!)
                      .withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border(
                    top: BorderSide(
                      color: widget.color ?? DesignTokens.colors['primary']!,
                      width: 2,
                    ),
                    right: BorderSide.none,
                    bottom: BorderSide.none,
                    left: BorderSide.none,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                DesignTokens.colors['gray100']!,
                DesignTokens.colors['gray200']!,
                DesignTokens.colors['gray100']!,
              ],
              stops: [
                0.0,
                0.5,
                1.0,
              ],
              transform: GradientRotation(_animation.value * 3.14159),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double? height;
  final double? width;

  const SkeletonCard({
    super.key,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: height ?? 120,
        width: width,
        decoration: BoxDecoration(
          color: DesignTokens.colors['gray100'],
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        ),
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonText({
    super.key,
    this.width,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: DesignTokens.colors['gray100'],
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        ),
      ),
    );
  }
}

class DashboardCardSkeleton extends StatelessWidget {
  const DashboardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.colors['gray200']!),
        boxShadow: DesignTokens.cardShadow,
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 80, height: 14),
                SizedBox(height: DesignTokens.spacing8),
                SkeletonText(width: 60, height: 32),
                SizedBox(height: DesignTokens.spacing4),
                SkeletonText(width: 100, height: 12),
              ],
            ),
          ),
          SizedBox(width: DesignTokens.spacing12),
          SkeletonCard(height: 48, width: 48),
        ],
      ),
    );
  }
}

class TaskCardSkeleton extends StatelessWidget {
  const TaskCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.colors['gray200']!),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SkeletonText(height: 16)),
              SizedBox(width: DesignTokens.spacing8),
              SkeletonText(width: 60, height: 20),
            ],
          ),
          SizedBox(height: DesignTokens.spacing8),
          SkeletonText(width: double.infinity, height: 14),
          SizedBox(height: DesignTokens.spacing4),
          SkeletonText(width: 200, height: 14),
          SizedBox(height: DesignTokens.spacing12),
          Row(
            children: [
              SkeletonText(width: 80, height: 12),
              SizedBox(width: DesignTokens.spacing16),
              SkeletonText(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}
