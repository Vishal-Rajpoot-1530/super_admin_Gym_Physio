import 'package:flutter/material.dart';

import '../dialogs/create_user_dialogs.dart';
import '../dialogs/edit_user_dialog.dart';
import '../dialogs/password_dialogs.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/app_shell.dart';
import '../widgets/common.dart';

enum _UserTab { all, quarterly, monthly, annual, inactive }

class UsersPage extends StatefulWidget {
  final Module module;

  const UsersPage({super.key, required this.module});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<AppUser> users = [];

  bool loading = true;
  int _loadGeneration = 0;

  String? error;

  _UserTab _tab = _UserTab.all;

  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();

    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD USERS FROM API
  // ============================================================

  Future<void> _loadUsers() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiService.fetchUsers(widget.module);
      if (mounted && generation == _loadGeneration) {
        setState(() => users = result);
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  // ============================================================
  // COMMON API ACTION
  // ============================================================

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();

      if (mounted) {
        showMessage(context, successMessage);
      }

      await _loadUsers();
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  // ============================================================
  // SELECT SUBSCRIPTION PLAN
  // ============================================================

  Future<Plan?> _choosePlan(String title) {
    return showDialog<Plan>(
      context: context,
      builder: (context) {
        return DialogFrame(
          icon: Icons.workspace_premium_outlined,
          title: title,
          subtitle: 'Select a subscription plan',
          width: 420,
          onClose: () => Navigator.pop(context),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
          child: Column(
            children: Plan.values.map((plan) {
              return PlanOption(
                plan: plan,
                selected: false,
                onTap: () {
                  Navigator.pop(context, plan);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ============================================================
  // USER ACTION MENU (popup)
  // ============================================================

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          IconTile(icon: icon, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.text,
                  ),
                ),
                Text(subtitle, style: monoStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(AppUser user, Offset position) async {
    final screen = MediaQuery.of(context).size;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        screen.width - position.dx,
        screen.height - position.dy,
      ),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      constraints: const BoxConstraints(minWidth: 290, maxWidth: 330),
      items: [
        // Header
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            margin: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Eyebrow('User context'),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Pill(
                  label: user.isActive ? 'ACTIVE' : 'INACTIVE',
                  fg: user.isActive ? AppColors.primary : AppColors.muted,
                  bg: user.isActive
                      ? AppColors.primarySoft
                      : AppColors.neutralSoft,
                ),
              ],
            ),
          ),
        ),

        // EDIT USER
        _menuItem(
          'edit',
          Icons.edit_outlined,
          'Edit User',
          'Profile & contact info',
        ),

        // ACTIVE / INACTIVE USER
        _menuItem(
          'status',
          user.isActive
              ? Icons.pause_circle_outline
              : Icons.play_circle_outline,
          user.isActive ? 'Temporarily Inactive' : 'Activate',
          user.isActive ? 'Pause access' : 'Restore access',
        ),

        // ASSIGN PLAN - ONLY FOR ONLINE USER
        if (user.type == 'online')
          _menuItem(
            'plan',
            Icons.workspace_premium_outlined,
            user.membership == null ? 'Assign Plan' : 'Change / Assign Plan',
            'Set subscription tier',
          ),

        // RENEW PLAN - ONLINE USER + EXISTING PLAN REQUIRED
        if (user.type == 'online' && user.membership != null)
          _menuItem(
            'renew',
            Icons.autorenew,
            'Renew Plan',
            'Extend membership',
          ),

        const PopupMenuDivider(),

        // RESET PASSWORD
        _menuItem(
          'password',
          Icons.vpn_key_outlined,
          'Reset Password',
          'Issue new portal credentials',
        ),
      ],
    );

    if (action == null || !mounted) {
      return;
    }

    await _handleAction(user, action);
  }

  Future<void> _handleAction(AppUser user, String action) async {
    // ==========================================================
    // EDIT USER
    // ==========================================================

    if (action == 'edit') {
      final updated = await showDialog<bool>(
        context: context,
        builder: (_) {
          return EditUserDialog(user: user);
        },
      );

      if (updated == true) {
        await _loadUsers();
      }
    }
    // ==========================================================
    // ACTIVE / INACTIVE
    // ==========================================================
    else if (action == 'status') {
      await _runAction(() {
        return ApiService.updateStatus(widget.module, user.id, !user.isActive);
      }, user.isActive ? 'User inactive' : 'User activated');
    }
    // ==========================================================
    // ASSIGN PLAN / RENEW PLAN
    // ==========================================================
    else if (action == 'plan' || action == 'renew') {
      final selectedPlan = await _choosePlan(
        action == 'renew' ? 'Renew Plan' : 'Assign Plan',
      );

      if (selectedPlan == null) {
        return;
      }

      if (action == 'renew') {
        await _runAction(() {
          return ApiService.renewPlan(widget.module, user.id, selectedPlan);
        }, 'Plan renewed');
      } else {
        await _runAction(() {
          return ApiService.assignPlan(widget.module, user.id, selectedPlan);
        }, 'Plan assigned');
      }
    }
    // ==========================================================
    // RESET PASSWORD
    // ==========================================================
    else if (action == 'password') {
      final newPassword = await showDialog<String>(
        context: context,
        builder: (_) {
          return PasswordDialog(user: user);
        },
      );

      if (newPassword != null) {
        await _runAction(() {
          return ApiService.resetPassword(widget.module, user.id, newPassword);
        }, 'Password reset');
      }
    }
  }

  // ============================================================
  // FILTERING (sirf display ke liye, API same hai)
  // ============================================================

  List<AppUser> get _filtered {
    final q = _query.trim().toLowerCase();

    return users.where((u) {
      switch (_tab) {
        case _UserTab.all:
          break;
        case _UserTab.quarterly:
          if (u.membership?.plan != Plan.quarterly) return false;
          break;
        case _UserTab.monthly:
          if (u.membership?.plan != Plan.monthly) return false;
          break;
        case _UserTab.annual:
          if (u.membership?.plan != Plan.annual) return false;
          break;
        case _UserTab.inactive:
          if (u.isActive) return false;
          break;
      }

      if (q.isEmpty) return true;

      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final stats = UserStats.from(users);
    final ready = !loading && error == null;

    String value(int number) => ready ? formatNumber(number) : '—';

    return AppShell(
      module: widget.module,
      onConnectionChanged: _loadUsers,
      child: RefreshIndicator(
        onRefresh: _loadUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(stats, ready),
              const SizedBox(height: 24),
              AutoGrid(
                children: [
                  StatCard(
                    label: 'Total Users',
                    value: value(stats.total),
                    icon: Icons.groups_outlined,
                    caption: '${value(stats.active)} active',
                  ),
                  StatCard(
                    label: 'Online Users',
                    value: value(stats.online),
                    icon: Icons.wifi_tethering_rounded,
                    caption: 'Subscription accounts',
                  ),
                  StatCard(
                    label: 'Pending Renewal',
                    value: value(stats.expiringSoon),
                    icon: Icons.event_repeat_outlined,
                    caption: 'Next 7 days',
                    captionColor: AppColors.warning,
                  ),
                  StatCard(
                    label: 'Active Plan Value',
                    value: ready ? 'Rs ${formatNumber(stats.planValue)}' : '—',
                    icon: Icons.payments_outlined,
                    caption: 'Running subscriptions',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTableCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(UserStats stats, bool ready) {
    final inactive = stats.total - stats.active;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow(
                'Registry & access controls',
                icon: Icons.verified_user_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '${moduleName(widget.module)} Accounts',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage users, subscription plans, renewal windows, '
                'and security credentials.',
                style: TextStyle(fontSize: 15, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Active: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    ready ? '${stats.active}' : '—',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Inactive: ',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  Text(
                    ready ? '$inactive' : '—',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) {
                    return CreateUserDialog(module: widget.module);
                  },
                );

                if (created == true && mounted) {
                  showMessage(
                    context,
                    'User and subscription saved to the backend.',
                  );
                  _searchController.clear();
                  _query = '';
                  _tab = _UserTab.all;
                  await _loadUsers();
                }
              },
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('Create User'),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // TABLE CARD
  // ============================================================

  String _tabLabel(_UserTab tab) {
    switch (tab) {
      case _UserTab.all:
        return 'All Members';
      case _UserTab.quarterly:
        return 'Quarterly (3 Mo)';
      case _UserTab.monthly:
        return 'Monthly';
      case _UserTab.annual:
        return 'Annual';
      case _UserTab.inactive:
        return 'Inactive';
    }
  }

  Widget _buildTableCard() {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 12,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tab in _UserTab.values)
                      TabChipButton(
                        label: _tabLabel(tab),
                        selected: _tab == tab,
                        onTap: () => setState(() => _tab = tab),
                      ),
                  ],
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search name, email, phone',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildTableBody(),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    // LOADING
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // API ERROR
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 36,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    // NO USERS
    if (users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: Text('No users found')),
      );
    }

    final items = _filtered;

    // NO MATCH (filter / search)
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: Text(
            'No matching users',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 960
                ? 960.0
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    _buildTableHeader(),
                    for (final user in items) _buildRow(user),
                  ],
                ),
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.primaryTint,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Text(_footerText(items.length), style: monoStyle),
        ),
      ],
    );
  }

  String _footerText(int shown) {
    final q = _query.trim();
    final base = 'Showing $shown of ${users.length} records';

    if (q.isEmpty) {
      return base;
    }

    return '$base   •   Filtered by: "$q"';
  }

  // Column flex values (header + rows same rakhne ke liye)
  static const int _flexIdentity = 30;
  static const int _flexPlan = 27;
  static const int _flexFee = 15;
  static const int _flexStatus = 20;
  static const double _actionWidth = 56;

  Widget _buildTableHeader() {
    Widget cell(String text, int flex) {
      return Expanded(flex: flex, child: Eyebrow(text));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.primaryTint,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          cell('User identity', _flexIdentity),
          cell('Assigned plan & schedule', _flexPlan),
          cell('Fee', _flexFee),
          cell('Status', _flexStatus),
          const SizedBox(width: _actionWidth, child: Eyebrow('Action')),
        ],
      ),
    );
  }

  Widget _buildRow(AppUser user) {
    final membership = user.membership;
    final online = user.type == 'online';

    // ---------------- PLAN CELL ----------------
    Widget planCell;
    if (!online) {
      planCell = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offline user',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          Text('Subscription not required', style: monoStyle),
        ],
      );
    } else if (membership == null) {
      planCell = const Align(
        alignment: Alignment.centerLeft,
        child: Pill(
          label: 'No subscription',
          fg: AppColors.warning,
          bg: AppColors.warningSoft,
        ),
      );
    } else {
      planCell = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pill(
            label: membership.plan.label,
            fg: AppColors.primary,
            bg: AppColors.primarySoft,
          ),
          const SizedBox(height: 6),
          Text(
            '${formatDate(membership.start)} → ${formatDate(membership.end)}',
            style: monoStyle,
          ),
        ],
      );
    }

    // ---------------- FEE CELL ----------------
    Widget feeCell;
    if (membership == null) {
      feeCell = const Text('—', style: TextStyle(color: AppColors.muted));
    } else {
      feeCell = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rs ${membership.price}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          Text(
            membership.expired ? 'EXPIRED' : membership.status.toUpperCase(),
            style: monoStyle,
          ),
        ],
      );
    }

    // ---------------- STATUS CELL ----------------
    final statusCell = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Pill(
          label: online ? 'Online' : 'Offline',
          dot: true,
          fg: online ? AppColors.accent : AppColors.muted,
          bg: online ? AppColors.accentSoft : AppColors.neutralSoft,
        ),
        Pill(
          label: user.isActive ? 'Active' : 'Inactive',
          fg: user.isActive ? AppColors.primary : AppColors.muted,
          bg: user.isActive ? AppColors.primarySoft : AppColors.neutralSoft,
        ),
        if (membership != null && membership.expired)
          const Pill(
            label: 'Expired',
            fg: AppColors.danger,
            bg: AppColors.dangerSoft,
          ),
      ],
    );

    return InkWell(
      // Row par click = menu (pehle bottom sheet khulta tha)
      onTap: () {},
      onTapUp: (details) => _openMenu(user, details.globalPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // IDENTITY
            Expanded(
              flex: _flexIdentity,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      initialsOf(user.name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          user.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          '${user.phone}  •  Created ${formatDate(user.createdAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // PLAN
            Expanded(flex: _flexPlan, child: planCell),

            // FEE
            Expanded(flex: _flexFee, child: feeCell),

            // STATUS
            Expanded(flex: _flexStatus, child: statusCell),

            // ACTION (3 dots)
            SizedBox(
              width: _actionWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      _openMenu(user, details.globalPosition);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
