import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// Professional primary button with enhanced styling
class ProfessionalButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final ButtonSize size;
  final ButtonVariant variant;
  final double? width;

  const ProfessionalButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.size = ButtonSize.medium,
    this.variant = ButtonVariant.primary,
    this.width,
  });

  @override
  State<ProfessionalButton> createState() => _ProfessionalButtonState();
}

class _ProfessionalButtonState extends State<ProfessionalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
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

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: isEnabled ? _onTapDown : null,
            onTapUp: isEnabled ? _onTapUp : null,
            onTapCancel: isEnabled ? _onTapCancel : null,
            onTap: isEnabled ? widget.onPressed : null,
            child: Container(
              width: widget.width,
              height: _getButtonHeight(),
              decoration: BoxDecoration(
                color: _getBackgroundColor(isEnabled),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                border: widget.variant == ButtonVariant.outline
                    ? Border.all(
                        color: isEnabled
                            ? DesignTokens.primaryOrange
                            : DesignTokens.colors['gray300']!,
                      )
                    : null,
                boxShadow: widget.variant == ButtonVariant.primary && isEnabled
                    ? [
                        BoxShadow(
                          color: DesignTokens.primaryOrange.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getTextColor(isEnabled),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              size: _getIconSize(),
                              color: _getTextColor(isEnabled),
                            ),
                            const SizedBox(width: DesignTokens.spacing8),
                          ],
                          Text(
                            widget.text,
                            style: TextStyle(
                              fontSize: _getFontSize(),
                              fontWeight: FontWeight.w600,
                              color: _getTextColor(isEnabled),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getButtonHeight() {
    switch (widget.size) {
      case ButtonSize.small:
        return 36;
      case ButtonSize.medium:
        return 44;
      case ButtonSize.large:
        return 52;
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 20;
    }
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (!isEnabled) {
      return DesignTokens.colors['gray200']!;
    }

    switch (widget.variant) {
      case ButtonVariant.primary:
        return DesignTokens.primaryOrange;
      case ButtonVariant.secondary:
        return DesignTokens.colors['gray100']!;
      case ButtonVariant.outline:
        return Colors.transparent;
      case ButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _getTextColor(bool isEnabled) {
    if (!isEnabled) {
      return DesignTokens.colors['gray500']!;
    }

    switch (widget.variant) {
      case ButtonVariant.primary:
        return DesignTokens.colors['black']!;
      case ButtonVariant.secondary:
        return DesignTokens.colors['black']!;
      case ButtonVariant.outline:
        return DesignTokens.primaryOrange;
      case ButtonVariant.ghost:
        return DesignTokens.primaryOrange;
    }
  }
}

enum ButtonSize { small, medium, large }
enum ButtonVariant { primary, secondary, outline, ghost }

/// Quick action button for dashboard
class QuickActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const QuickActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          border: Border.all(color: DesignTokens.colors['gray200']!),
          boxShadow: DesignTokens.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? DesignTokens.primaryOrange,
                  size: 20,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.colors['black'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.colors['gray600'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating action button with professional styling
class ProfessionalFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final bool mini;

  const ProfessionalFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.mini = false,
  });

  @override
  State<ProfessionalFAB> createState() => _ProfessionalFABState();
}

class _ProfessionalFABState extends State<ProfessionalFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onTap: widget.onPressed,
            child: Container(
              width: widget.mini ? 40 : 56,
              height: widget.mini ? 40 : 56,
              decoration: BoxDecoration(
                color: DesignTokens.primaryOrange,
                borderRadius: BorderRadius.circular(widget.mini ? 20 : 28),
                boxShadow: [
                  BoxShadow(
                    color: DesignTokens.primaryOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: DesignTokens.colors['black'],
                size: widget.mini ? 20 : 24,
              ),
            ),
          ),
        );
      },
    );
  }
}
