import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'admin_dashboard_screen.dart';
import 'day_close_screen.dart';
import 'expenses_screen.dart';
import 'finance_screen.dart';
import 'frames_screen.dart';
import 'info_screens.dart';
import 'item_bills_screen.dart';
import 'logs_screen.dart';
import 'master_admin_screen.dart';
import 'monthly_screen.dart';
import 'settings_screen.dart';
import 'team_screen.dart';
import 'tournaments_screen.dart';

/// More — hub mirroring the web sidebar (§22), role-filtered.
class MoreScreen extends StatelessWidget {
  final SessionController session;
  final ClubController club;
  const MoreScreen({super.key, required this.session, required this.club});

  void _open(BuildContext context, String title, String subtitle, Widget body) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SubPage(title: title, subtitle: subtitle, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = session.user;
    final isStaff = user?.isStaff ?? false;
    final isMaster = user?.isMaster ?? false;
    final hasClub = session.activeClub != null;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (hasClub) ...[
          const _Header('Club'),
          _Row(
            icon: Icons.receipt_long_outlined,
            title: 'Item Bills',
            sub: 'Counter item bills · history, receipts & dues',
            onTap:
                () => _open(
                  context,
                  'Item Bills',
                  'Counter item bills · history, receipts & dues',
                  ItemBillsScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.emoji_events_outlined,
            title: 'Tournaments',
            sub: 'Players & entry fees → bracket → match tables → champion',
            onTap:
                () => _open(
                  context,
                  'Tournaments',
                  'Players & entry fees → bracket → match tables → champion',
                  TournamentsScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.history,
            title: 'Frames',
            sub: 'Billed frames · winners, settlements & corrections',
            onTap:
                () => _open(
                  context,
                  'Frames',
                  'Billed frames · winners, settlements & corrections',
                  FramesScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.show_chart,
            title: 'Logs',
            sub: 'Billing, payments, warnings and admin actions',
            onTap:
                () => _open(
                  context,
                  'Activity Logs',
                  'Billing, payments, warnings and admin actions',
                  LogsScreen(session: session, club: club),
                ),
          ),
        ],
        if (!isStaff && hasClub) ...[
          const _Header('Admin'),
          _Row(
            icon: Icons.insights_outlined,
            title: 'Reports & smart insights',
            sub: 'Revenue, expenses, P&L, trends and recommended actions',
            tone: c.gold,
            onTap:
                () => _open(
                  context,
                  'Reports & Admin',
                  'Monthly revenue, expenses, P&L and smart insights',
                  AdminDashboardScreen(
                    session: session,
                    club: club,
                    onOpen:
                        (title, subtitle, body) =>
                            _open(context, title, subtitle, body),
                  ),
                ),
          ),
          _Row(
            icon: Icons.nights_stay_outlined,
            title: 'Day Close',
            sub: 'Close the day and reconcile accounts',
            onTap:
                () => _open(
                  context,
                  'Day Close · daily accounts',
                  'Close the day and reconcile accounts',
                  DayCloseScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.calendar_view_month_outlined,
            title: 'Monthly Revenue',
            sub: 'Money received — frames, item bills, memberships, dues',
            onTap:
                () => _open(
                  context,
                  'Monthly Revenue Sheet',
                  'Money received — frames, item bills, memberships, due collections',
                  MonthlyScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.scale_outlined,
            title: 'Finance',
            sub: 'P&L · balance sheet · stock profit · utilisation',
            onTap:
                () => _open(
                  context,
                  'Finance · P&L & Balance',
                  'How much came in, went out, and stayed — the month-end account',
                  FinanceScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.receipt_outlined,
            title: 'Expenses',
            sub: 'Track and manage club expenses',
            onTap:
                () => _open(
                  context,
                  'Expenses',
                  'Track and manage club expenses',
                  ExpensesScreen(session: session, club: club),
                ),
          ),
          _Row(
            icon: Icons.badge_outlined,
            title: 'Club Staff',
            sub: 'Manage staff roles and permissions',
            onTap:
                () => _open(
                  context,
                  'Club Staff · roles & access',
                  'Manage staff roles and permissions',
                  TeamScreen(session: session, club: club),
                ),
          ),
        ],
        if (isMaster) ...[
          const _Header('Platform'),
          _Row(
            icon: Icons.shield_outlined,
            title: 'Master Admin',
            sub: 'Manage platform-wide administration',
            tone: c.gold,
            onTap:
                () => _open(
                  context,
                  'Master Admin',
                  'Manage platform-wide administration',
                  MasterAdminScreen(session: session, club: club),
                ),
          ),
        ],
        const _Header('General'),
        _Row(
          icon: Icons.settings_outlined,
          title: 'Settings',
          sub: hasClub ? 'Configure your club settings' : 'Profile & account',
          onTap:
              () => _open(
                context,
                'Settings',
                hasClub ? 'Configure your club settings' : 'Profile & account',
                SettingsScreen(session: session, club: club),
              ),
        ),
        _Row(
          icon: Icons.headset_mic_outlined,
          title: 'Human Support',
          sub: 'Contact support for help',
          onTap:
              () => _open(
                context,
                'Human Support',
                'Contact support for help',
                SupportScreen(session: session),
              ),
        ),
        _Row(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy & Policy',
          sub: 'View and manage privacy settings',
          onTap:
              () => _open(
                context,
                'Privacy & Policy',
                'View and manage privacy settings',
                const PrivacyScreen(),
              ),
        ),
        _Row(
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          sub: 'View and manage terms and conditions',
          onTap:
              () => _open(
                context,
                'Terms & Conditions',
                'View and manage terms and conditions',
                const TermsScreen(),
              ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ToneBadge('v3.17.0', c.green)],
        ),
        const SizedBox(height: 4),
        Text(
          'Powered by Rowdy\'s Den',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: Dimens.font9_5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final Color? tone;

  const _Row({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = tone ?? c.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tone != null ? c.gold.withValues(alpha: 0.35) : c.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: t.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: t),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: Dimens.font13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sub,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 17, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushed sub-page shell: app bar with back + title/subtitle (web parity, no page titles on tab root).
class _SubPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  const _SubPage({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: c.text,
                fontSize: Dimens.font15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}
