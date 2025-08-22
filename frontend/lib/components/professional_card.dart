import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// Professional card component with subtle shadows and hover effects
class ProfessionalCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool showHoverEffect;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? customShadow;

  const ProfessionalCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.showHoverEffect = true,
    this.backgroundColor,
    this.borderRadius,
    this.customShadow,
  });

  @override
  State<ProfessionalCard> createState() => _ProfessionalCardState();
}

class _ProfessionalCardState extends State<ProfessionalCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    if (!widget.showHoverEffect) return;
    
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.white,
                  borderRadius: widget.borderRadius ?? 
                      BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(
                    color: DesignTokens.colors['gray200']!,
                    width: 1,
                  ),
                  boxShadow: widget.customShadow ?? 
                      (_isHovered 
                          ? DesignTokens.cardShadowHover 
                          : DesignTokens.cardShadow),
                ),
                child: Padding(
                  padding: widget.padding ?? 
                      const EdgeInsets.all(DesignTokens.spacing16),
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Professional stats card with icon and color coding
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isActive;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.subtitle,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? DesignTokens.primaryOrange;
    final effectiveBackgroundColor = backgroundColor ?? 
        (isActive 
            ? DesignTokens.colors['primary50'] 
            : Colors.white);

    return ProfessionalCard(
      onTap: onTap,
      backgroundColor: effectiveBackgroundColor,
      showHoverEffect: onTap != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: DesignTokens.colors['gray600'],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.colors['black'],
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DesignTokens.spacing4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: DesignTokens.colors['gray500'],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing12),
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: effectiveIconColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton component
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height ?? 16,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? 
                BorderRadius.circular(DesignTokens.radiusSmall),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
              colors: [
                DesignTokens.colors['gray200']!,
                DesignTokens.colors['gray100']!,
                DesignTokens.colors['gray200']!,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Stats card skeleton for loading states
class StatsCardSkeleton extends StatelessWidget {
  const StatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfessionalCard(
      showHoverEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeleton(
                      width: 80,
                      height: 14,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    ),
                    const SizedBox(height: DesignTokens.spacing8),
                    LoadingSkeleton(
                      width: 60,
                      height: 24,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    ),
                  ],
                ),
              ),
              LoadingSkeleton(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
