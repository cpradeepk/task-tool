import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

enum StatsCardColor { blue, green, yellow, red, purple, gray }

class StatsCard extends StatefulWidget {
  final String title;
  final dynamic value;
  final IconData icon;
  final StatsCardColor color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isActive;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = StatsCardColor.blue,
    this.subtitle,
    this.onTap,
    this.isActive = false,
  });

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _getColorScheme(widget.color);
    final iconColorScheme = _getIconColorScheme(widget.color);

    return MouseRegion(
      onEnter: (_) {
        if (widget.onTap != null) {
          setState(() => _isHovered = true);
          _animationController.forward();
        }
      },
      onExit: (_) {
        if (widget.onTap != null) {
          setState(() => _isHovered = false);
          _animationController.reverse();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.onTap != null ? _scaleAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(
                    color: widget.isActive 
                        ? DesignTokens.colors['primary']!
                        : DesignTokens.colors['gray200']!,
                    width: widget.isActive ? 2 : 1,
                  ),
                  boxShadow: _isHovered || widget.isActive
                      ? DesignTokens.cardShadowHover
                      : DesignTokens.cardShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: DesignTokens.colors['gray600'],
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing4),
                          Text(
                            widget.value.toString(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.colors['black'],
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: DesignTokens.spacing4),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: DesignTokens.colors['gray500'],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing12),
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spacing12),
                      decoration: BoxDecoration(
                        color: colorScheme['background'],
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                        border: Border.all(color: colorScheme['border']!),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 24,
                        color: iconColorScheme['icon'],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, Color> _getColorScheme(StatsCardColor color) {
    switch (color) {
      case StatsCardColor.blue:
        return {
          'background': DesignTokens.colors['primary50']!,
          'border': DesignTokens.colors['primary200']!,
        };
      case StatsCardColor.green:
        return {
          'background': DesignTokens.colors['primary']!,
          'border': DesignTokens.colors['primary600']!,
        };
      case StatsCardColor.yellow:
        return {
          'background': DesignTokens.colors['primary200']!,
          'border': DesignTokens.colors['primary400']!,
        };
      case StatsCardColor.red:
        return {
          'background': DesignTokens.colors['gray200']!,
          'border': DesignTokens.colors['gray400']!,
        };
      case StatsCardColor.purple:
        return {
          'background': DesignTokens.colors['primary100']!,
          'border': DesignTokens.colors['primary300']!,
        };
      case StatsCardColor.gray:
        return {
          'background': DesignTokens.colors['gray100']!,
          'border': DesignTokens.colors['gray300']!,
        };
    }
  }

  Map<String, Color> _getIconColorScheme(StatsCardColor color) {
    switch (color) {
      case StatsCardColor.blue:
        return {'icon': DesignTokens.colors['primary']!};
      case StatsCardColor.green:
      case StatsCardColor.yellow:
      case StatsCardColor.red:
      case StatsCardColor.purple:
      case StatsCardColor.gray:
        return {'icon': DesignTokens.colors['black']!};
    }
  }
}
