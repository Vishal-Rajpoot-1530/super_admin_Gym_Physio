import 'package:flutter/material.dart';

import '../main.dart';
import '../pages/home_page.dart';
import '../pages/api_connection_page.dart';
import '../pages/user_page.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Branding + profile text yahin se badlo.
class AppBrand {
  static const name = 'RTS Pannel';
  static const tagline = 'ADMIN CORE';
  static const enterprise = 'RTS Enterprises';
  static const section = 'Control Center';
}

class AdminProfile {
  static const name = 'RTS Official';
  static const role = 'Super Administrator';
  static const initials = 'RO';
}

/// Sidebar se page badalne ke liye (back stack clean rehta hai).
void navigateTo(BuildContext context, Widget page) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
    (route) => false,
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.module,
    this.onConnectionChanged,
  });

  /// null  = Dashboard
  /// clinic / gym = us module ka Users page
  final Module? module;
  final Widget child;
  final Future<void> Function()? onConnectionChanged;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: wide
          ? null
          : Drawer(
              width: 290,
              backgroundColor: Colors.white,
              child: SafeArea(child: _Sidebar(module: module)),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) SizedBox(width: 280, child: _Sidebar(module: module)),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    showMenu: !wide,
                    module: module,
                    onConnectionChanged: onConnectionChanged,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIDEBAR
// ============================================================

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.module});

  final Module? module;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppBrand.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      AppBrand.tagline,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Module switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Module>(
                  value: module,
                  isExpanded: true,
                  hint: const Text('Select module'),
                  icon: const Icon(
                    Icons.unfold_more,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    fontSize: 15,
                  ),
                  items: Module.values.map((m) {
                    return DropdownMenuItem<Module>(
                      value: m,
                      child: Text(moduleName(m)),
                    );
                  }).toList(),
                  onChanged: (m) {
                    if (m == null || m == module) return;
                    navigateTo(context, UsersPage(module: m));
                  },
                ),
              ),
            ),
          ),

          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                const _SectionLabel('Main Operations'),
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  selected: module == null,
                  onTap: () {
                    if (module != null) navigateTo(context, const HomePage());
                  },
                ),
                const _SectionLabel('Physio Clinic'),
                _NavItem(
                  icon: Icons.groups_outlined,
                  label: 'Users',
                  selected: module == Module.clinic,
                  onTap: () {
                    if (module != Module.clinic) {
                      navigateTo(context, UsersPage(module: Module.clinic));
                    }
                  },
                ),
                const _SectionLabel('Fitness & Facilities'),
                _NavItem(
                  icon: Icons.fitness_center,
                  label: 'Gym Management',
                  selected: module == Module.gym,
                  onTap: () {
                    if (module != Module.gym) {
                      navigateTo(context, UsersPage(module: Module.gym));
                    }
                  },
                ),
              ],
            ),
          ),

          // Footer
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Super Admin Panel',
                    style: monoStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 8),
      child: Eyebrow(text),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TOP BAR
// ============================================================

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showMenu,
    this.module,
    this.onConnectionChanged,
  });

  final bool showMenu;
  final Module? module;
  final Future<void> Function()? onConnectionChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth >= 960 ? screenWidth - 280 : screenWidth;
    final narrow = contentWidth < 1100;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
            ),
          if (!narrow) ...[
            const Text(
              AppBrand.enterprise,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.muted,
              ),
            ),
            const Text(
              AppBrand.section,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: const _SearchBox(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'API Connection',
            icon: const Icon(Icons.dns_outlined),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      ApiConnectionPage(initialModule: module ?? Module.gym),
                ),
              );
              if (changed == true && context.mounted) {
                await onConnectionChanged?.call();
              }
            },
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          if (!narrow)
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.help_outline_rounded),
            ),
          if (!narrow) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 32, color: AppColors.border),
            const SizedBox(width: 16),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AdminProfile.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  AdminProfile.role,
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          const CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              AdminProfile.initials,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, size: 20, color: AppColors.muted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search records, staff, patient ID...',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
