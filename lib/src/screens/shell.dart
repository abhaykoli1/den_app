import 'package:flutter/material.dart';

import '../api.dart';
import '../dimensions.dart';
import '../rowdy_care.dart';
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
import 'more_screen.dart';
import 'settings_screen.dart';
import 'team_screen.dart';
import 'tournaments_screen.dart';
import 'workspace_hubs.dart';
import 'package:flutter/cupertino.dart';

/// App shell — four intent-based destinations. Detailed workflows remain in
/// compact workspaces and the More hub instead of competing as nav items.
class HomeShell extends StatefulWidget {
  final SessionController session;
  const HomeShell({super.key, required this.session});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ClubController club = ClubController(widget.session);
  // Nullable so an already-mounted state survives hot reload after this field
  // was introduced. A fresh state still creates it in initState.
  PageController? _pageController;
  int _index = 0;
  int _clubTabIndex = 0;
  int _recordsTabIndex = 0;
  String? _loadedClubId;
  bool _dashOpen =
      false; // ★ v3.26 — drawer me Dashboard dropdown (5 report links)

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    widget.session.addListener(_onSession);
    club.addListener(_onData);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshActiveClub());
  }

  void _onSession() {
    if (mounted) setState(() {});
    // Theme, profile and text-size notifications must not reload the complete
    // club payload. Fetch only when the active club actually changes.
    _refreshActiveClub();
  }

  void _refreshActiveClub() {
    final clubId = widget.session.activeClub?.id;
    if (clubId == null || clubId == _loadedClubId) return;
    _loadedClubId = clubId;
    club.refresh();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    club.removeListener(_onData);
    club.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    if (_pageController?.hasClients == true) {
      _pageController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openClubTab(int subTabIndex) {
    setState(() {
      _index = 1;
      _clubTabIndex = subTabIndex.clamp(0, 3);
    });
    if (_pageController?.hasClients == true) {
      _pageController!.animateToPage(
        1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openRecordsTab(int subTabIndex) {
    setState(() {
      _index = 2;
      _recordsTabIndex = subTabIndex.clamp(0, 3);
    });
    if (_pageController?.hasClients == true) {
      _pageController!.animateToPage(
        2,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static const _tabTitles = ['Home', 'Club', 'Records', 'More'];

  // ------------------------------------------------------------- alerts bell
  List<_Alert> _alerts() {
    final out = <_Alert>[];
    if ((widget.session.user?.isMaster ?? false)) {
      return out; // master: no club alerts
    }
    final activeClub = widget.session.activeClub;
    if (activeClub == null) return out;

    // due limit
    final dueMembers =
        club.members.where((m) => m.active && m.dueAmount > 0).toList();
    final totalDue = dueMembers.fold<double>(0, (a, m) => a + m.dueAmount);
    final limit = activeClub.dueLimit;
    if (limit > 0 && totalDue >= limit) {
      out.add(
        _Alert(
          Icons.scale_outlined,
          'red',
          'Due limit crossed',
          '${fmtMoneyText(totalDue)} of ${fmtMoneyText(limit)} is still uncollected',
          'Records',
        ),
      );
    } else if (limit > 0 && totalDue >= 0.7 * limit) {
      out.add(
        _Alert(
          Icons.scale_outlined,
          'gold',
          'Due limit nearing',
          '${fmtMoneyText(totalDue)} collected-dues pending of ${fmtMoneyText(limit)} limit',
          'Records',
        ),
      );
    }

    // stock
    final outStock =
        club.menuItems.where((i) => i.active && i.stockQty <= 0).toList();
    if (outStock.isNotEmpty) {
      out.add(
        _Alert(
          Icons.error_outline,
          'red',
          'Out of stock',
          outStock.map((i) => i.name).take(3).join(', '),
          'Records',
        ),
      );
    }
    final low =
        club.menuItems
            .where(
              (i) => i.active && i.stockQty > 0 && i.stockQty <= i.reorderLevel,
            )
            .toList();
    if (low.isNotEmpty) {
      out.add(
        _Alert(
          Icons.inventory_2_outlined,
          'gold',
          'Low stock',
          low.map((i) => '${i.name} (${i.stockQty})').take(3).join(', '),
          'Records',
        ),
      );
    }

    // memberships expiring within 7 days
    final expiring =
        club.members.where((m) {
          if (!m.active || m.planExpiresAt.isEmpty) return false;
          final d = DateTime.tryParse(m.planExpiresAt);
          if (d == null) return false;
          final days = d.difference(DateTime.now()).inDays;
          return days <= 7;
        }).toList();
    if (expiring.isNotEmpty) {
      out.add(
        _Alert(
          Icons.event_repeat,
          'gold',
          'Memberships expiring',
          '${expiring.map((m) => m.name).take(3).join(', ')} — within 7 days',
          'Club',
        ),
      );
    }
    return out;
  }

  String fmtMoneyText(num v) => fmtMoney(v);

  void _showAlerts(List<_Alert> alerts) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'ALERTS · ${alerts.length}',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (alerts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: c.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "All clear — No Alert's yet.",
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: Dimens.font12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final a in alerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pop(ctx);
                            final i = _tabTitles.indexWhere(
                              (t) => t == a.jumpTab,
                            );
                            if (i >= 0) _selectTab(i);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: c.bgMuted,
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: a.tone == 'red' ? c.red : c.gold,
                                  width: 3,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  a.icon,
                                  size: 15,
                                  color: a.tone == 'red' ? c.red : c.gold,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.title,
                                        style: TextStyle(
                                          color: c.text,
                                          fontSize: Dimens.font12_5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        a.sub,
                                        style: TextStyle(
                                          color: c.textMuted,
                                          fontSize: Dimens.font10_5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: c.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
    );
  }

  void _showQrCode() {
    final qrCode = (widget.session.activeClub?.qrCode ?? '').trim();
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Payment QR code'),
            content:
                qrCode.isEmpty
                    ? Text(
                      'Upload a payment QR code in Club Settings.',
                      style: TextStyle(color: c.textSecondary),
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClubLogo(
                          logo: qrCode,
                          size: 240,
                          borderRadius: 8,
                          fallbackIcon: Icons.qr_code_2_outlined,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.session.activeClub?.name ?? '',
                          style: TextStyle(color: c.textSecondary),
                        ),
                      ],
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // ------------------------------------------------------------- add club
  Future<void> _createClub() async {
    final c = context.colors;
    final name = TextEditingController(
      text: widget.session.clubs.isEmpty ? "Rowdy's Den" : '',
    );
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New club',
                      style: TextStyle(
                        color: c.text,
                        fontSize: Dimens.font14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Within the plan\'s maximum club limit — the server verifies it.',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font10_5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: AppText.field.copyWith(color: c.text),
                      decoration: const InputDecoration(
                        hintText: "Club name — e.g. Rowdy's Den",
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.green,
                          foregroundColor: c.onGreen,
                        ),
                        onPressed: () {
                          if (name.text.trim().isEmpty) {
                            toast(ctx, 'Club name', error: true);
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Create club'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    if (ok != true) return;
    try {
      final res = await widget.session.api.post('/clubs', {
        'name': name.text.trim(),
      });
      await widget.session.loadClubs();
      final rawId =
          (res is Map)
              ? (res['id'] ?? (res['club'] is Map ? res['club']['id'] : null))
              : null;
      final newId = rawId == null ? '' : '$rawId';
      if (newId.isNotEmpty && newId != 'null') {
        await widget.session.selectClub(newId);
      }
      if (mounted) toast(context, 'Club ready — ${name.text.trim()}');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // --------------------------------------------------- pushed sub-page shell
  void _pushSub(String title, String subtitle, Widget body) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pageCtx) {
          final pc = pageCtx.colors;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(CupertinoIcons.back, size: 22),
                onPressed: () => Navigator.pop(pageCtx),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: pc.text,
                      fontSize: Dimens.font15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: pc.textMuted,
                      fontSize: Dimens.font10_5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // actions: [
              //   IconButton(
              //     tooltip: 'Refresh',
              //     onPressed: club.loading ? null : club.refresh,
              //     icon: Icon(Icons.refresh, size: 18, color: pc.textSecondary),
              //   ),
              //   const SizedBox(width: 4),
              // ],
            ),
            body: SafeArea(child: body),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- sidebar drawer (web §22 parity)
  Widget _buildDrawer(AppColors c) {
    final user = widget.session.user;
    final isStaff = user?.isStaff ?? false;
    final isMaster = user?.isMaster ?? false;
    final hasClub = widget.session.activeClub != null;
    const tabTitles = _tabTitles;
    final curTab = tabTitles[_index.clamp(0, tabTitles.length - 1)];

    // web `.nav-section` parity — chhota caps label + hairline rule
    Widget section(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Row(
        children: [
          Text(
            t.toUpperCase(),
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font9_5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: c.border)),
        ],
      ),
    );

    // ★ v3.26 — Dashboard dropdown ke chhote indented links
    Widget sub(IconData icon, String title, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(left: 14),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -3),
        leading: Icon(icon, size: 15, color: c.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: c.text,
            fontSize: Dimens.font12_5,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.pop(context); // close drawer, pehle
          onTap();
        },
      ),
    );

    Widget item(
      IconData icon,
      String title,
      VoidCallback onTap, {
      Color? tone,
      bool selected = false,
    }) => ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      selected: selected,
      selectedTileColor: c.green.withValues(alpha: 0.08),
      leading: Icon(
        icon,
        size: 20,
        color: tone ?? (selected ? c.green : c.textSecondary),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? c.green : c.text,
          fontSize: Dimens.font13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // close drawer, pehle
        onTap();
      },
    );

    void jump(String name) {
      final i = tabTitles.indexWhere((t) => t == name);
      if (i >= 0) _selectTab(i);
    }

    final items = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/rowdys_den_logo_square.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ROWDY'S DEN",
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Club Billing',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font11,
                    ),
                  ),
                ],
              ),
            ),
            ToneBadge('v3.26', c.green),
          ],
        ),
      ),
      if (!isMaster) ...[
        section('Club'),
        // Padding(
        //   padding: Dimens.clubMetaPad,
        //   child: Text(
        //     'ACTIVE CLUB · ${widget.session.clubs.length}/∞',
        //     style: TextStyle(
        //       color: c.textMuted,
        //       fontSize: Dimens.font10,
        //       fontWeight: FontWeight.w800,
        //       letterSpacing: 1.1,
        //     ),
        //   ),
        // ),
        Padding(
          padding: Dimens.clubSelectorPad,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: Dimens.clubSelectorH,
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    borderRadius: BorderRadius.circular(
                      Dimens.clubSelectorRadius,
                    ),
                    border: Border.all(
                      color: c.gold,
                      width: Dimens.clubSelectorBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.gold.withValues(alpha: 0.1),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.session.activeClub?.id,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: c.text,
                        size: 17,
                      ),
                      dropdownColor: c.bgElevated,
                      borderRadius: BorderRadius.circular(
                        Dimens.clubSelectorRadius,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      style: TextStyle(
                        color: c.text,
                        fontSize: Dimens.clubSelectorFont,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (id) {
                        if (id != null) widget.session.selectClub(id);
                      },
                      items: [
                        for (final cl in widget.session.clubs)
                          DropdownMenuItem(
                            value: cl.id,
                            child: Text(
                              cl.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isStaff) ...[
                const SizedBox(width: Dimens.clubSelectorGap),
                SizedBox(
                  height: Dimens.clubAddButtonSize,
                  width: Dimens.clubAddButtonSize,
                  child: OutlinedButton(
                    onPressed: _createClub,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.green,
                      side: BorderSide(
                        color: c.green,
                        width: Dimens.clubSelectorBorder,
                      ),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Dimens.clubSelectorRadius,
                        ),
                      ),
                    ),
                    child: const Icon(Icons.add, size: Dimens.clubSelectorIcon),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      // ★ v3.23 — web sidebar parity: ADMIN block (Dashboard + Club Staff)
      // sirf owner/master; staff ko poora section hi nahi milta.
      if (hasClub && !isStaff) ...[
        section('Admin'),
        item(
          Icons.insights_outlined,
          'Reports & admin',
          () => _pushSub(
            'Reports & Admin',
            'Monthly revenue, expenses, P&L and smart insights',
            AdminDashboardScreen(
              session: widget.session,
              club: club,
              onOpen: _pushSub,
            ),
          ),
          tone: c.gold,
        ),
        // ★ v3.26.1 — Dashboard simple rahe; 5 report links "More ▾" me
        // (owner correction). Tap = open/close (drawer band NAHI hota).
        ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          leading: Icon(
            Icons.read_more_outlined,
            size: 17,
            color: c.textSecondary,
          ),
          title: Text(
            'More',
            style: TextStyle(
              color: c.text,
              fontSize: Dimens.font13,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            _dashOpen ? Icons.expand_less : Icons.expand_more,
            size: 16,
            color: c.textMuted,
          ),
          onTap: () => setState(() => _dashOpen = !_dashOpen),
        ),
        if (_dashOpen) ...[
          sub(
            Icons.nights_stay_outlined,
            'Day Close',
            () => _pushSub(
              'Day Close',
              'Daily collection · drawer close',
              DayCloseScreen(session: widget.session, club: club),
            ),
          ),
          sub(
            Icons.scale_outlined,
            'Finance · P&L',
            () => _pushSub(
              'Finance · P&L',
              'Profit & loss — is month ka',
              FinanceScreen(session: widget.session, club: club),
            ),
          ),
          sub(
            Icons.calendar_view_month_outlined,
            'Monthly Revenue',
            () => _pushSub(
              'Monthly Revenue',
              'Is month ki received income',
              MonthlyScreen(session: widget.session, club: club),
            ),
          ),
          sub(
            Icons.receipt_outlined,
            'Expenses',
            () => _pushSub(
              'Expenses',
              'Club ke saare expenses',
              ExpensesScreen(session: widget.session, club: club),
            ),
          ),
          sub(
            Icons.badge_outlined,
            'Club Staff',
            () => _pushSub(
              'Club Staff · roles & access',
              'Manage staff roles and permissions',
              TeamScreen(session: widget.session, club: club),
            ),
          ),
        ],
      ],
      if (hasClub) ...[
        section('Billing'),
        item(
          Icons.grid_on,
          'Tables & players',
          () => jump('Club'),
          selected: curTab == 'Club',
        ),
        item(
          Icons.money_off_outlined,
          'Dues, counter & stock',
          () => jump('Records'),
          selected: curTab == 'Records',
        ),
        item(
          Icons.receipt_long_outlined,
          'Item Bills',
          () => _pushSub(
            'Item Bills',
            'Counter item bills · history, receipts & dues',
            ItemBillsScreen(session: widget.session, club: club),
          ),
        ),
        item(
          Icons.history,
          'Frames',
          () => _pushSub(
            'Frames',
            'Billed frames · winners, settlements & corrections',
            FramesScreen(session: widget.session, club: club),
          ),
        ),
        item(
          Icons.emoji_events_outlined,
          'Tournaments',
          () => _pushSub(
            'Tournaments',
            'Players & entry fees → bracket → match tables → champion',
            TournamentsScreen(session: widget.session, club: club),
          ),
        ),
        item(
          Icons.show_chart,
          'Activity Logs',
          () => _pushSub(
            'Activity Logs',
            'Billing, payments, warnings and admin actions',
            LogsScreen(session: widget.session, club: club),
          ),
        ),
      ],
      section('General'),
      item(
        Icons.settings_outlined,
        'Settings',
        () => _pushSub(
          'Settings',
          'Configure your club settings',
          SettingsScreen(session: widget.session, club: club),
        ),
      ),
      item(
        Icons.headset_mic_outlined,
        'Human Support',
        () => _pushSub(
          'Human Support',
          'Contact support for help',
          SupportScreen(session: widget.session),
        ),
      ),
      item(
        Icons.privacy_tip_outlined,
        'Privacy & Policy',
        () => _pushSub(
          'Privacy & Policy',
          'View and manage privacy settings',
          const PrivacyScreen(),
        ),
      ),
      item(
        Icons.description_outlined,
        'Terms & Conditions',
        () => _pushSub(
          'Terms & Conditions',
          'View and manage terms and conditions',
          const TermsScreen(),
        ),
      ),
      item(
        Icons.logout,
        'Sign out',
        () => widget.session.signOut(),
        tone: c.red,
      ),
      const SizedBox(height: 14),
    ];

    return Drawer(
      width:
          MediaQuery.sizeOf(
            context,
          ).width.clamp(0, Dimens.clubDrawerMaxWidth).toDouble(),
      child: SafeArea(
        child: ListView(padding: EdgeInsets.zero, children: items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hot reload keeps the existing State object. Ensure a controller also
    // exists for states created before swipe navigation was added.
    _pageController ??= PageController(initialPage: _index);
    final c = context.colors;
    final isMaster = widget.session.user?.isMaster ?? false;
    final hasClub = widget.session.activeClub != null;

    final tabs = <_Tab>[
      _Tab(
        'Home',
        Icons.home_outlined,
        HomeOverview(
          session: widget.session,
          club: club,
          onTab: _selectTab,
          onOpenClubTab: _openClubTab,
          onOpenRecordsTab: _openRecordsTab,
          onOpenSubPage: _pushSub,
        ),
      ),
      _Tab(
        'Club',
        Icons.sports_bar_outlined,
        ClubWorkspace(
          session: widget.session,
          club: club,
          initialTab: _clubTabIndex,
        ),
      ),
      _Tab(
        'Records',
        Icons.receipt_long_outlined,
        RecordsWorkspace(
          session: widget.session,
          club: club,
          initialTab: _recordsTabIndex,
        ),
      ),
      _Tab(
        'More',
        Icons.grid_view_outlined,
        MoreScreen(session: widget.session, club: club),
      ),
    ];
    final index = _index.clamp(0, tabs.length - 1);
    final alerts = _alerts();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tabs[index].title,
              style: TextStyle(
                color: c.text,
                fontSize: Dimens.font16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              hasClub
                  ? widget.session.activeClub!.name
                  : isMaster
                  ? 'Rowdy\'s Den · Master'
                  : "Rowdy's Den",
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (widget.session.clubs.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.swap_horiz, color: c.green, size: 22),
                tooltip: 'Switch club',
                onSelected: widget.session.selectClub,
                itemBuilder:
                    (_) => [
                      for (final cl in widget.session.clubs)
                        PopupMenuItem(
                          value: cl.id,
                          child: Row(
                            children: [
                              if (cl.id == widget.session.activeClub?.id)
                                Icon(Icons.check, size: 14, color: c.green)
                              else
                                const SizedBox(width: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cl.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
              ),
            ),
          if (!isMaster)
            IconButton(
              tooltip: 'Alerts',
              onPressed: () => _showAlerts(alerts),
              icon: Badge.count(
                count: alerts.length,
                isLabelVisible: alerts.isNotEmpty,
                backgroundColor: c.red,
                textStyle: const TextStyle(
                  fontSize: Dimens.font9,
                  fontWeight: FontWeight.w800,
                ),
                child: Icon(
                  Icons.notifications_none,
                  size: 20,
                  color: alerts.isEmpty ? c.textSecondary : c.gold,
                ),
              ),
            ),
          if (hasClub)
            IconButton(
              tooltip: 'Payment QR code',
              onPressed: _showQrCode,
              icon: Icon(
                Icons.qr_code_2_outlined,
                size: 21,
                color: c.textSecondary,
              ),
            ),
          IconButton(
            tooltip: widget.session.darkMode ? 'Light mode' : 'Dark mode',
            onPressed: widget.session.toggleTheme,
            icon: Icon(
              widget.session.darkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
              size: 20,
              color: c.gold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap:
                  () => _pushSub(
                    'Account',
                    widget.session.user?.email ?? '',
                    _AccountPage(
                      session: widget.session,
                      club: club,
                      onOpen: _pushSub,
                    ),
                  ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: c.green.withValues(alpha: 0.15),
                child: Text(
                  (widget.session.user?.name.isNotEmpty == true
                          ? widget.session.user!.name[0]
                          : '?')
                      .toUpperCase(),
                  style: TextStyle(
                    color: c.green,
                    fontSize: Dimens.font12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(c),
      body: SafeArea(
        // ★ v3.25 — Rowdy Care tab as an overlay, NOT a Scaffold FAB. A real
        // FAB makes every floating SnackBar jump to mid-screen to dodge it.
        child: Stack(
          children: [
            (!hasClub
                ? (isMaster
                    ? MoreScreen(session: widget.session, club: club)
                    : _NoClub(
                      canCreate: !(widget.session.user?.isStaff ?? false),
                      onCreateClub: _createClub,
                    ))
                : PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [for (final tab in tabs) tab.body],
                )),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(1, 0.24),
                child: RowdyCareFab(session: widget.session),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          hasClub
              ? NavigationBar(
                selectedIndex: index,
                onDestinationSelected: _selectTab,
                destinations: [
                  for (final t in tabs)
                    NavigationDestination(
                      icon: Icon(t.icon, size: 20),
                      label: t.title,
                    ),
                ],
              )
              : null,
    );
  }
}

class _Tab {
  final String title;
  final IconData icon;
  final Widget body;
  const _Tab(this.title, this.icon, this.body);
}

class _Alert {
  final IconData icon;
  final String tone; // 'red' | 'gold'
  final String title;
  final String sub;

  /// Target tab ka TITLE (index nahi — Dashboard center me aaya hai,
  /// owner/staff ke indexes alag hote hain, isliye name-based lookup).
  final String jumpTab;
  const _Alert(this.icon, this.tone, this.title, this.sub, this.jumpTab);
}

/// Signed-in, non-master account with zero clubs (fresh 402-cleared state).
class _NoClub extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onCreateClub;
  const _NoClub({required this.canCreate, required this.onCreateClub});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, color: c.gold, size: 26),
              const SizedBox(height: 8),
              Text(
                'No club yet',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                canCreate
                    ? 'Create your own club now — "Rowdy\'s Den" or any other name.'
                    : 'Your club will be created automatically once your subscription is activated.\nIf the lock is open but the club is not visible, please contact the Master Admin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: Dimens.font11,
                  height: 1.4,
                ),
              ),
              if (canCreate) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.green,
                      foregroundColor: c.onGreen,
                    ),
                    onPressed: onCreateClub,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create my club'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rendered wherever the staff lockdown (403 Admin area) blocks a staff member.
class AdminLockedCard extends StatelessWidget {
  final ApiException? error;
  const AdminLockedCard({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: c.gold, size: 26),
              const SizedBox(height: 8),
              Text(
                'Admin area — owner access required',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask the club owner to open this report on their device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Account page (header avatar tap) — profile + admin links live here (drawer-free).
class _AccountPage extends StatelessWidget {
  final SessionController session;
  final ClubController club;
  final void Function(String title, String subtitle, Widget body) onOpen;
  const _AccountPage({
    required this.session,
    required this.club,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = session.user;
    final isStaff = user?.isStaff ?? false;
    final isMaster = user?.isMaster ?? false;
    final hasClub = session.activeClub != null;

    Widget link(
      IconData icon,
      String title,
      String sub,
      Widget body, {
      Color? tone,
    }) {
      final t = tone ?? c.green;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onOpen(title, sub, body),
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

    Widget section(String t) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        t.toUpperCase(),
        style: TextStyle(
          color: c.textMuted,
          fontSize: Dimens.font9_5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: c.green.withValues(alpha: 0.15),
                  child: Text(
                    (user?.name.isNotEmpty == true ? user!.name[0] : '?')
                        .toUpperCase(),
                    style: TextStyle(
                      color: c.green,
                      fontSize: Dimens.font18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      ToneBadge(
                        isMaster
                            ? 'master admin'
                            : isStaff
                            ? 'staff'
                            : 'owner',
                        isMaster
                            ? c.gold
                            : isStaff
                            ? c.blue
                            : c.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isStaff && hasClub) ...[
          section('Admin'),
          link(
            Icons.nights_stay_outlined,
            'Day Close · daily accounts',
            'Close the day and reconcile accounts',
            DayCloseScreen(session: session, club: club),
          ),
          link(
            Icons.calendar_view_month_outlined,
            'Monthly Revenue Sheet',
            'Money received — frames, item bills, memberships, due collections',
            MonthlyScreen(session: session, club: club),
          ),
          link(
            Icons.scale_outlined,
            'Finance · P&L & Balance',
            'How much came in, went out, and stayed — the month-end account',
            FinanceScreen(session: session, club: club),
          ),
          link(
            Icons.receipt_outlined,
            'Expenses',
            'Track and manage club expenses',
            ExpensesScreen(session: session, club: club),
          ),
          link(
            Icons.badge_outlined,
            'Club Staff · roles & access',
            'Manage staff roles and permissions',
            TeamScreen(session: session, club: club),
          ),
        ],
        if (isMaster) ...[
          section('Platform'),
          link(
            Icons.shield_outlined,
            'Master Admin',
            'Manage platform-wide administration',
            MasterAdminScreen(session: session, club: club),
            tone: c.gold,
          ),
        ],
        section('General'),
        link(
          Icons.settings_outlined,
          'Settings',
          'Configure your club settings',
          SettingsScreen(session: session, club: club),
        ),
        link(
          Icons.headset_mic_outlined,
          'Human Support',
          'Contact support for help',
          SupportScreen(session: session),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await session.signOut();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.red.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout, size: 15, color: c.red),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: c.red,
                      fontSize: Dimens.font13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
