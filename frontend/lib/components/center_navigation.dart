import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';

class CenterNavigation extends ConsumerStatefulWidget {
  final bool isAdmin;
  final String currentRoute;
  
  const CenterNavigation({
    super.key,
    required this.isAdmin,
    required this.currentRoute,
  });

  @override
  ConsumerState<CenterNavigation> createState() => _CenterNavigationState();
}

class _CenterNavigationState extends ConsumerState<CenterNavigation> {

  List<DropdownNavItem> _getProjectDropdownItems() {
    // TODO: Fetch actual projects and modules from API
    return [
      DropdownNavItem('All Projects', '/projects', Icons.folder),
      DropdownNavItem('Karyasiddhi', '/projects/1', Icons.folder),
      DropdownNavItem('  └ Frontend Module', '/projects/1/modules/1', Icons.view_module),
      DropdownNavItem('  └ Backend Module', '/projects/1/modules/2', Icons.view_module),
      DropdownNavItem('Anukul', '/projects/2', Icons.folder),
      DropdownNavItem('  └ Core Module', '/projects/2/modules/1', Icons.view_module),
      DropdownNavItem('TIMJ', '/projects/3', Icons.folder),
      DropdownNavItem('  └ Main Module', '/projects/3/modules/1', Icons.view_module),
      DropdownNavItem('Swarg', '/projects/4', Icons.folder),
      DropdownNavItem('  └ Development', '/projects/4/modules/1', Icons.view_module),
    ];
  }

  List<NavigationTab> _getNavigationTabs() {
    List<NavigationTab> tabs = [
      NavigationTab(
        icon: Icons.dashboard,
        label: 'Dashboard',
        route: '/dashboard',
      ),
      NavigationTab(
        icon: Icons.folder,
        label: 'Projects',
        route: '/projects',
        hasDropdown: true,
        dropdownItems: _getProjectDropdownItems(),
      ),
      NavigationTab(
        icon: Icons.timeline,
        label: 'PERT',
        route: '/pert',
      ),
      NavigationTab(
        icon: Icons.calendar_today,
        label: 'Calendar',
        route: '/calendar',
      ),
      NavigationTab(
        icon: Icons.chat,
        label: 'Chat',
        route: '/chat',
      ),
      NavigationTab(
        icon: Icons.notifications,
        label: 'Alerts',
        route: '/alerts',
      ),
    ];

    // Add admin tabs if user is admin
    if (widget.isAdmin) {
      tabs.addAll([
        NavigationTab(
          icon: Icons.admin_panel_settings,
          label: 'Admin',
          route: '/admin',
          hasDropdown: true,
          dropdownItems: [
            DropdownNavItem('User Management', '/admin/users/manage', Icons.people),
            DropdownNavItem('Project Management', '/admin/projects/settings', Icons.folder_special),
            DropdownNavItem('Module Management', '/admin/modules/manage', Icons.view_module),
            DropdownNavItem('Role Management', '/admin/roles/manage', Icons.security),
            DropdownNavItem('Role Assignment', '/admin/roles/assign', Icons.assignment_ind),
            DropdownNavItem('Master Data', '/admin/master-data', Icons.edit_note),
            DropdownNavItem('JSR Reports', '/admin/reporting/jsr', Icons.bar_chart),
            DropdownNavItem('Daily Summary', '/admin/reporting/daily-summary', Icons.today),
            DropdownNavItem('Create Project', '/admin/projects/create', Icons.add_box),
          ],
        ),
      ]);
    }

    // Add personal section
    tabs.add(
      NavigationTab(
        icon: Icons.person,
        label: 'Personal',
        route: '/personal',
        hasDropdown: true,
        dropdownItems: [
          DropdownNavItem('Notes', '/personal/notes', Icons.note),
          DropdownNavItem('Profile', '/profile', Icons.edit),
          DropdownNavItem('Availability', '/availability', Icons.schedule),
        ],
      ),
    );

    return tabs;
  }

  bool _isRouteActive(String route) {
    return widget.currentRoute.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _getNavigationTabs();
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Center the navigation tabs
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: tabs.map((tab) => _buildNavigationTab(tab)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTab(NavigationTab tab) {
    final isActive = _isRouteActive(tab.route);
    const primaryOrange = Color(0xFFFFA301);
    
    if (tab.hasDropdown) {
      return PopupMenuButton<String>(
        offset: const Offset(0, 50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? primaryOrange.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: primaryOrange, width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                size: 20,
                color: isActive ? primaryOrange : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                tab.label,
                style: TextStyle(
                  color: isActive ? primaryOrange : Colors.grey.shade700,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: isActive ? primaryOrange : Colors.grey.shade600,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => tab.dropdownItems!.map((item) {
          return PopupMenuItem<String>(
            value: item.route,
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(item.label),
              ],
            ),
          );
        }).toList(),
        onSelected: (route) {
          context.go(route);
        },
      );
    }

    return InkWell(
      onTap: () => context.go(tab.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? primaryOrange.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: primaryOrange, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 20,
              color: isActive ? primaryOrange : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              tab.label,
              style: TextStyle(
                color: isActive ? primaryOrange : Colors.grey.shade700,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationTab {
  final IconData icon;
  final String label;
  final String route;
  final bool hasDropdown;
  final List<DropdownNavItem>? dropdownItems;

  NavigationTab({
    required this.icon,
    required this.label,
    required this.route,
    this.hasDropdown = false,
    this.dropdownItems,
  });
}

class DropdownNavItem {
  final String label;
  final String route;
  final IconData icon;

  DropdownNavItem(this.label, this.route, this.icon);
}
