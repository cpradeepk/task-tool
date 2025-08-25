import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BreadcrumbItem {
  final String label;
  final String? route;
  final IconData? icon;

  BreadcrumbItem({
    required this.label,
    this.route,
    this.icon,
  });
}

class Breadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Color? textColor;
  final Color? activeColor;
  final double fontSize;

  const Breadcrumb({
    super.key,
    required this.items,
    this.textColor,
    this.activeColor,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextColor = textColor ?? Colors.grey.shade600;
    final defaultActiveColor = activeColor ?? const Color(0xFFFFA301);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Home icon
          InkWell(
            onTap: () => context.go('/dashboard'),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                Icons.home,
                size: 16,
                color: defaultTextColor,
              ),
            ),
          ),
          
          // Breadcrumb items
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;
            
            return Row(
              children: [
                // Separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                
                // Breadcrumb item
                if (item.route != null && !isLast)
                  InkWell(
                    onTap: () => context.go(item.route!),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.icon != null) ...[
                            Icon(
                              item.icon,
                              size: 14,
                              color: defaultTextColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: defaultTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Current page (not clickable)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: 14,
                            color: defaultActiveColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: defaultActiveColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

// Helper function to generate admin breadcrumbs
List<BreadcrumbItem> getAdminBreadcrumbs(String currentPage, {String? subPage}) {
  List<BreadcrumbItem> breadcrumbs = [
    BreadcrumbItem(
      label: 'Admin',
      route: '/admin',
      icon: Icons.admin_panel_settings,
    ),
  ];

  switch (currentPage) {
    case 'users':
      breadcrumbs.add(BreadcrumbItem(
        label: 'User Management',
        route: subPage != null ? '/admin/users/manage' : null,
        icon: Icons.people,
      ));
      if (subPage != null) {
        breadcrumbs.add(BreadcrumbItem(label: subPage));
      }
      break;
    case 'projects':
      breadcrumbs.add(BreadcrumbItem(
        label: 'Project Management',
        route: subPage != null ? '/admin/projects/settings' : null,
        icon: Icons.folder_special,
      ));
      if (subPage != null) {
        breadcrumbs.add(BreadcrumbItem(label: subPage));
      }
      break;
    case 'modules':
      breadcrumbs.add(BreadcrumbItem(
        label: 'Module Management',
        icon: Icons.view_module,
      ));
      break;
    case 'roles':
      breadcrumbs.add(BreadcrumbItem(
        label: 'Role Management',
        route: subPage != null ? '/admin/roles/manage' : null,
        icon: Icons.security,
      ));
      if (subPage != null) {
        breadcrumbs.add(BreadcrumbItem(label: subPage));
      }
      break;
    case 'master-data':
      breadcrumbs.add(BreadcrumbItem(
        label: 'Master Data',
        icon: Icons.edit_note,
      ));
      break;
    case 'reports':
      breadcrumbs.add(BreadcrumbItem(
        label: 'Reports',
        route: subPage != null ? '/admin/reporting' : null,
        icon: Icons.bar_chart,
      ));
      if (subPage != null) {
        breadcrumbs.add(BreadcrumbItem(label: subPage));
      }
      break;
    default:
      breadcrumbs.add(BreadcrumbItem(label: currentPage));
  }

  return breadcrumbs;
}
