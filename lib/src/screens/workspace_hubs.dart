import 'package:flutter/material.dart';

import '../dimensions.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'due_desk_screen.dart';
import 'frames_screen.dart';
import 'items_screen.dart';
import 'logs_screen.dart';
import 'players_screen.dart';
import 'settings_screen.dart';
import 'tables_screen.dart';
import 'tournaments_screen.dart';

/// Intent-based workspaces.  The detailed screens are deliberately retained:
/// this only removes the need to make each one a permanent navigation item.
class ClubWorkspace extends StatelessWidget {
  final SessionController session;
  final ClubController club;
  final int initialTab;
  const ClubWorkspace({
    super.key,
    required this.session,
    required this.club,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    initialIndex: initialTab,
    length: 4,
    child: Column(
      children: [
        const _WorkspaceTabs(
          tabs: [
            Tab(text: 'Games'),
            Tab(text: 'Players'),
            Tab(text: 'Dues'),
            Tab(text: 'Frames'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              TablesScreen(session: session, club: club),
              PlayersScreen(session: session, club: club),
              DueDeskScreen(session: session, club: club),
              FramesScreen(session: session, club: club),
            ],
          ),
        ),
      ],
    ),
  );
}

class RecordsWorkspace extends StatelessWidget {
  final SessionController session;
  final ClubController club;
  final int initialTab;
  const RecordsWorkspace({
    super.key,
    required this.session,
    required this.club,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    initialIndex: initialTab,
    length: 4,
    child: Column(
      children: [
        const _WorkspaceTabs(
          tabs: [
            Tab(text: 'Counter'),
            Tab(text: 'Stock'),
            Tab(text: 'Tournaments'),
            Tab(text: 'Logs'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ItemsScreen(session: session, club: club),
              StockScreen(session: session, club: club),
              TournamentsScreen(session: session, club: club),
              LogsScreen(session: session, club: club),
            ],
          ),
        ),
      ],
    ),
  );
}

class HomeOverview extends StatelessWidget {
  final SessionController session;
  final ClubController club;
  final ValueChanged<int> onTab;
  final void Function(int clubTabIndex)? onOpenClubTab;
  final void Function(int recordsTabIndex)? onOpenRecordsTab;
  final void Function(String title, String subtitle, Widget body)?
  onOpenSubPage;
  const HomeOverview({
    super.key,
    required this.session,
    required this.club,
    required this.onTab,
    this.onOpenClubTab,
    this.onOpenRecordsTab,
    this.onOpenSubPage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = session.user;
    final name = user?.name.trim().split(RegExp(r'\s+')).first;
    final running = club.sessions.where((s) => !s.stopped).length;
    final dues = club.members.where((m) => m.active && m.dueAmount > 0).length;
    return RefreshIndicator(
      color: c.green,
      onRefresh: club.refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Good ${_timeGreeting()}, ${name?.isNotEmpty == true ? name : 'there'}',
            style: TextStyle(
              color: c.text,
              fontSize: Dimens.font19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Here is what needs attention at ${session.activeClub?.name ?? "your club"}.',
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Live tables',
                  value: '$running',
                  sub: 'sessions running',
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Pending dues',
                  value: '$dues',
                  sub: fmtMoney(club.stats.totalDue),
                  tone: c.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quick actions',
            style: TextStyle(
              color: c.text,
              fontSize: Dimens.font15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _Action(
                icon: Icons.grid_on_rounded,
                label: 'Manage tables',
                tone: c.green,
                onTap: () => onOpenClubTab?.call(0),
              ),
              _Action(
                icon: Icons.group_add_outlined,
                label: 'Manage players',
                tone: c.blue,
                onTap: () => onOpenClubTab?.call(1),
              ),
              _Action(
                icon: Icons.payments_outlined,
                label: 'Collect due',
                tone: c.red,
                onTap: () => onOpenClubTab?.call(2),
              ),
              _Action(
                icon: Icons.point_of_sale_outlined,
                label: 'Counter sale',
                tone: c.gold,
                onTap: () => onOpenRecordsTab?.call(0),
              ),
              _Action(
                icon: Icons.sports_esports_outlined,
                label: 'Frames',
                tone: c.gold,
                onTap: () => onOpenRecordsTab?.call(2),
              ),
              _Action(
                icon: Icons.history_outlined,
                label: 'Activity Logs',
                tone: c.gold,
                onTap: () => onOpenRecordsTab?.call(3),
              ),
              _Action(
                icon: Icons.emoji_events_outlined,
                label: 'Tournament',
                tone: c.gold,
                onTap:
                    () => onOpenSubPage?.call(
                      'Tournaments',
                      'Players & entry fees → bracket → match tables → champion',
                      TournamentsScreen(session: session, club: club),
                    ),
              ),
              _Action(
                icon: Icons.settings_outlined,
                label: 'Settings',
                tone: c.gold,
                onTap:
                    () => onOpenSubPage?.call(
                      'Settings',
                      'Configure your club settings',
                      SettingsScreen(session: session, club: club),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Today at a glance',
            child: Column(
              children: [
                SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.grid_on_outlined,
                  label: 'Tables available',
                  value:
                      '${club.tables.length - running} of ${club.tables.length}',
                ),
                Divider(height: 20, color: c.border),
                _SummaryRow(
                  icon: Icons.people_outline,
                  label: 'Active players',
                  value: '${club.members.where((m) => m.active).length}',
                ),
                Divider(height: 20, color: c.border),
                _SummaryRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Low stock items',
                  value:
                      '${club.menuItems.where((i) => i.active && i.stockQty <= i.reorderLevel).length}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'morning'
        : h < 17
        ? 'afternoon'
        : 'evening';
  }
}

class _WorkspaceTabs extends StatelessWidget {
  final List<Tab> tabs;
  const _WorkspaceTabs({required this.tabs});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      padding: Dimens.workspaceTabOuterPad,
      child: Container(
        height: Dimens.workspaceTabBarH,
        decoration: BoxDecoration(
          color: c.bgMuted,
          borderRadius: BorderRadius.circular(Dimens.workspaceTabRadius),
        ),
        child: TabBar(
          tabs: [
            for (final tab in tabs)
              Tab(height: Dimens.workspaceTabH, text: tab.text),
          ],
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(Dimens.workspaceTabRadius - 2),
            border: Border.all(color: c.border),
          ),
          labelColor: c.text,
          unselectedLabelColor: c.textMuted,
          labelStyle: const TextStyle(
            fontSize: Dimens.workspaceTabFont,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.all(Dimens.workspaceTabInset),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconBg = tone.withValues(alpha: 0.12);
    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tone, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c.text,
                    fontSize: Dimens.font12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, color: c.textSecondary, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: c.textSecondary, fontSize: Dimens.font13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: c.text,
            fontSize: Dimens.font13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
