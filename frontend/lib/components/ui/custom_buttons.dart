import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

enum ButtonVariant { primary, secondary, outline, ghost }
enum ButtonSize { small, medium, large }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
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
    final buttonStyle = _getButtonStyle();
    final textStyle = _getTextStyle();
    final padding = _getPadding();

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _isPressed = true);
          _animationController.forward();
        }
      },
      onTapUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
          _animationController.reverse();
        }
      },
      onTapCancel: () {
        if (_isPressed) {
          setState(() => _isPressed = false);
          _animationController.reverse();
        }
      },
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.isFullWidth ? double.infinity : null,
              padding: padding,
              decoration: BoxDecoration(
                color: buttonStyle['backgroundColor'],
                border: buttonStyle['border'],
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                boxShadow: widget.onPressed != null && !widget.isLoading
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: _getIconSize(),
                      height: _getIconSize(),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          textStyle.color!,
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                  ] else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: _getIconSize(),
                      color: textStyle.color,
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                  ],
                  Text(
                    widget.text,
                    style: textStyle,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _getButtonStyle() {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    switch (widget.variant) {
      case ButtonVariant.primary:
        return {
          'backgroundColor': isDisabled
              ? DesignTokens.colors['gray300']
              : DesignTokens.colors['primary'],
          'border': null,
        };
      case ButtonVariant.secondary:
        return {
          'backgroundColor': isDisabled
              ? DesignTokens.colors['gray100']
              : Colors.white,
          'border': Border.all(
            color: isDisabled
                ? DesignTokens.colors['gray300']!
                : DesignTokens.colors['gray300']!,
          ),
        };
      case ButtonVariant.outline:
        return {
          'backgroundColor': Colors.transparent,
          'border': Border.all(
            color: isDisabled
                ? DesignTokens.colors['gray300']!
                : DesignTokens.colors['primary']!,
          ),
        };
      case ButtonVariant.ghost:
        return {
          'backgroundColor': Colors.transparent,
          'border': null,
        };
    }
  }

  TextStyle _getTextStyle() {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final fontSize = _getFontSize();

    Color textColor;
    switch (widget.variant) {
      case ButtonVariant.primary:
        textColor = isDisabled
            ? DesignTokens.colors['gray500']!
            : DesignTokens.colors['black']!;
        break;
      case ButtonVariant.secondary:
        textColor = isDisabled
            ? DesignTokens.colors['gray500']!
            : DesignTokens.colors['black']!;
        break;
      case ButtonVariant.outline:
        textColor = isDisabled
            ? DesignTokens.colors['gray500']!
            : DesignTokens.colors['primary']!;
        break;
      case ButtonVariant.ghost:
        textColor = isDisabled
            ? DesignTokens.colors['gray500']!
            : DesignTokens.colors['primary']!;
        break;
    }

    return TextStyle(
      color: textColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing12,
          vertical: DesignTokens.spacing8,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing12,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing20,
          vertical: DesignTokens.spacing16,
        );
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
    }
  }
}

class LoadingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: isLoading ? null : onPressed,
      variant: variant,
      size: size,
      icon: icon,
      isLoading: isLoading,
    );
  }
}
