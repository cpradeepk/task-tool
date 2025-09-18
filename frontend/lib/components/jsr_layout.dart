import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'horizontal_navbar.dart';
import '../admin_login.dart';
import '../theme/theme_provider.dart';
import '../utils/responsive.dart';
import 'ui/animations.dart';

class JSRLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String title;

  const JSRLayout({
    super.key,
    required this.child,
    this.title = 'Amtariksha',
  });

  @override
  ConsumerState<JSRLayout> createState() => _JSRLayoutState();
}

class _JSRLayoutState extends ConsumerState<JSRLayout> {
  bool _isAdmin = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('is_admin') ?? false;
      _userEmail = prefs.getString('user_email');
    });
  }

  void _showAdminLogin() {
    showDialog(
      context: context,
      builder: (context) => const AdminLoginDialog(),
    ).then((_) => _loadUserInfo());
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      context.go('/');
    }
  }

  void _zoomIn() {
    ref.read(themeProvider.notifier).zoomIn();
  }

  void _zoomOut() {
    ref.read(themeProvider.notifier).zoomOut();
  }

  void _resetZoom() {
    ref.read(themeProvider.notifier).resetZoom();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final zoomLevel = themeState.zoomLevel;
    final currentRoute = GoRouterState.of(context).uri.path;

    return Transform.scale(
      scale: zoomLevel,
      alignment: Alignment.topLeft,
      child: Scaffold(
        backgroundColor: DesignTokens.colors['gray50'],
        body: Column(
          children: [
            // Horizontal Navigation Bar
            HorizontalNavbar(
              currentRoute: currentRoute,
              isAdmin: _isAdmin,
              userEmail: _userEmail,
              onSignOut: _signOut,
            ),

            // Main Content Area
            Expanded(
              child: ResponsiveContainer(
                child: FadeInAnimation(
                  duration: const Duration(milliseconds: 300),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),


      ),
    );
  }
}

// Page wrapper that provides consistent styling for all pages
class JSRPageWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;

  const JSRPageWrapper({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.colors['black'],
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 16,
                          color: DesignTokens.colors['gray600'],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...[
                const SizedBox(width: 16),
                Row(children: actions!),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],

        // Page Content
        Expanded(child: child),
      ],
    );
  }
}

// Card component that matches JSR web app styling
class JSRCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool showHoverEffect;

  const JSRCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.showHoverEffect = false,
  });

  @override
  State<JSRCard> createState() => _JSRCardState();
}

class _JSRCardState extends State<JSRCard>
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
      end: 1.02,
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
    return MouseRegion(
      onEnter: (_) {
        if (widget.showHoverEffect || widget.onTap != null) {
          setState(() => _isHovered = true);
          _animationController.forward();
        }
      },
      onExit: (_) {
        if (widget.showHoverEffect || widget.onTap != null) {
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
              scale: (widget.showHoverEffect || widget.onTap != null) 
                  ? _scaleAnimation.value 
                  : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: widget.padding ?? const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(
                    color: DesignTokens.colors['gray200']!,
                    width: 1,
                  ),
                  boxShadow: _isHovered
                      ? DesignTokens.cardShadowHover
                      : DesignTokens.cardShadow,
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}
