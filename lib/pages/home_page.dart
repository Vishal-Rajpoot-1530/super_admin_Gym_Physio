import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/app_shell.dart';
import '../widgets/common.dart';
import '../main.dart';
import 'api_connection_page.dart';
import 'user_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // null = server se data nahi aaya
  final Map<Module, List<AppUser>?> _data = {};

  bool _loading = true;
  final Map<Module, String> _errors = {};
  final Set<Module> _pending = {};
  int _generation = 0;

  // 'all' | 'clinic' | 'gym'
  String _feedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _pending.addAll(Module.values);
      _errors.clear();
    });
    await Future.wait(
      Module.values.map((module) async {
        List<AppUser>? result;
        String? error;
        try {
          result = await ApiService.fetchUsers(module);
        } catch (e) {
          error = '$e';
        }
        if (!mounted || generation != _generation) return;
        setState(() {
          _data[module] = result;
          if (error != null) _errors[module] = error;
          _pending.remove(module);
          _loading = _pending.isNotEmpty;
        });
      }),
    );
  }

  Future<void> _configureModule(Module module) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ApiConnectionPage(initialModule: module),
      ),
    );
    if (saved == true) await _load();
  }

  bool get _hasData => _data.values.any((list) => list != null);

  List<AppUser> get _allUsers => [
    ...?_data[Module.clinic],
    ...?_data[Module.gym],
  ];

  String _value(int number) {
    if (_loading) return '…';
    if (!_hasData) return '—';
    return formatNumber(number);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final stats = UserStats.from(_allUsers);

    return AppShell(
      module: null,
      onConnectionChanged: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (ApiConfig.storageWarning != null)
                Text(
                  ApiConfig.storageWarning!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              const SizedBox(height: 24),
              AutoGrid(
                children: [
                  StatCard(
                    label: 'Total Users',
                    value: _value(stats.total),
                    icon: Icons.groups_outlined,
                    caption: 'Clinic + Gym combined',
                  ),
                  StatCard(
                    label: 'Online Users',
                    value: _value(stats.online),
                    icon: Icons.wifi_tethering_rounded,
                    caption: 'Subscription accounts',
                  ),
                  StatCard(
                    label: 'Active Users',
                    value: _value(stats.active),
                    icon: Icons.verified_user_outlined,
                    caption: 'Access enabled',
                  ),
                  StatCard(
                    label: 'Expiring Soon',
                    value: _value(stats.expiringSoon),
                    icon: Icons.event_repeat_outlined,
                    caption: 'Next 7 days',
                    captionColor: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AutoGrid(
                minWidth: 420,
                maxColumns: 2,
                children: [
                  _buildModuleCard(
                    module: Module.clinic,
                    icon: Icons.monitor_heart_outlined,
                    subtitle: 'Patients, plans, renewals and credentials.',
                    buttonLabel: 'Open Clinic Portal',
                  ),
                  _buildModuleCard(
                    module: Module.gym,
                    icon: Icons.fitness_center,
                    subtitle: 'Members, passes, renewals and credentials.',
                    buttonLabel: 'Launch Gym Manager',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildBottomRow(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pill(
                label: 'UNIFIED CORE INSTANCE',
                fg: AppColors.primary,
                bg: AppColors.primarySoft,
              ),
              SizedBox(height: 10),
              Text(
                'Super Admin Portal',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage Physio Clinic and Gym Management users '
                'from one place.',
                style: TextStyle(fontSize: 15, color: AppColors.muted),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  // ============================================================
  // MODULE CARDS
  // ============================================================

  Widget _buildModuleCard({
    required Module module,
    required IconData icon,
    required String subtitle,
    required String buttonLabel,
  }) {
    final users = _data[module];
    final stats = users == null ? null : UserStats.from(users);

    String number(int? value) {
      if (_pending.contains(module)) return '…';
      if (value == null) return '—';
      return formatNumber(value);
    }

    final Widget status;
    if (_pending.contains(module)) {
      status = const Pill(
        label: 'Checking',
        fg: AppColors.muted,
        bg: AppColors.neutralSoft,
        dot: true,
      );
    } else if (users == null) {
      status = const Pill(
        label: 'Unreachable',
        fg: AppColors.danger,
        bg: AppColors.dangerSoft,
        dot: true,
      );
    } else {
      status = const Pill(
        label: 'Live',
        fg: AppColors.primary,
        bg: AppColors.primarySoft,
        dot: true,
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          moduleName(module),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        status,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Total Users',
                  value: number(stats?.total),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(label: 'Online', value: number(stats?.online)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(label: 'Active', value: number(stats?.active)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DetailLine(
            label: 'Plans expiring in 7 days',
            value: number(stats?.expiringSoon),
          ),
          const SizedBox(height: 8),
          _DetailLine(
            label: 'Active plan value',
            value: stats == null
                ? number(null)
                : 'Rs ${formatNumber(stats.planValue)}',
          ),
          if (_errors[module] != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errors[module]!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _configureModule(module),
                    icon: const Icon(Icons.settings_ethernet_outlined),
                    label: const Text('Configure API connection'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                navigateTo(context, UsersPage(module: module));
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM ROW  (Recent registrations + Quick switch)
  // ============================================================

  Widget _buildBottomRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final feed = _buildFeedCard();
        final quick = _buildQuickSwitchCard();

        if (constraints.maxWidth < 900) {
          return Column(children: [feed, const SizedBox(height: 20), quick]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: feed),
            const SizedBox(width: 20),
            Expanded(child: quick),
          ],
        );
      },
    );
  }

  Widget _buildFeedCard() {
    var users = _allUsers;

    if (_feedFilter == 'clinic') {
      users = users.where((u) => u.module == Module.clinic).toList();
    } else if (_feedFilter == 'gym') {
      users = users.where((u) => u.module == Module.gym).toList();
    }

    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = users.take(6).toList();

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (recent.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'No recent registrations',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _buildFeedRow(recent[i]),
          ],
        ],
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Registrations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Latest users added across both modules',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabChipButton(
                    label: 'All',
                    selected: _feedFilter == 'all',
                    onTap: () => setState(() => _feedFilter = 'all'),
                  ),
                  TabChipButton(
                    label: 'Physio',
                    selected: _feedFilter == 'clinic',
                    onTap: () => setState(() => _feedFilter = 'clinic'),
                  ),
                  TabChipButton(
                    label: 'Gym',
                    selected: _feedFilter == 'gym',
                    onTap: () => setState(() => _feedFilter = 'gym'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }

  Widget _buildFeedRow(AppUser user) {
    final isClinic = user.module == Module.clinic;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const IconTile(icon: Icons.person_add_alt_1_outlined, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name.isEmpty ? '(no name)' : user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Pill(
                      label: isClinic ? 'PHYSIO' : 'GYM',
                      fg: isClinic ? AppColors.primary : AppColors.accent,
                      bg: isClinic
                          ? AppColors.primarySoft
                          : AppColors.accentSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${user.type.toUpperCase()} user  •  ${user.email}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(timeAgo(user.createdAt), style: monoStyle),
        ],
      ),
    );
  }

  Widget _buildQuickSwitchCard() {
    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Switch',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Jump straight into a module\'s user registry.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          _QuickTile(
            icon: Icons.monitor_heart_outlined,
            title: 'Physio Clinic',
            subtitle: 'Clinic users & plans',
            onTap: () =>
                navigateTo(context, const UsersPage(module: Module.clinic)),
          ),
          const SizedBox(height: 12),
          _QuickTile(
            icon: Icons.fitness_center,
            title: 'Gym Management',
            subtitle: 'Gym members & plans',
            onTap: () =>
                navigateTo(context, const UsersPage(module: Module.gym)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMALL WIDGETS
// ============================================================

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                    ),
                    Text(subtitle, style: monoStyle),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
