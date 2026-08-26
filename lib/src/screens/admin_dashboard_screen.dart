import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../insights.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'day_close_screen.dart';
import 'expenses_screen.dart';
import 'finance_screen.dart';
import 'monthly_screen.dart';

/// ================================================================
/// ADMIN DASHBOARD (v3.23 · owner-only money cockpit — APP)
/// Web ke `/admin-dashboard` ka Flutter twin — bottom nav ke CENTER tab
/// me (More tab hat gaya, reports yahan se milte hain).
///
///   • Stat tiles: Today Collected, Today Net, Total Due (+limit)
///   • Daily income graph — last 14 din (green income / red expenses)
///   • Income Mix + Expense Mix bars, P&L card
///   • Report page cards: Day Close / Monthly / Finance / Expenses / Staff
///
/// Wahi canonical report endpoints (day-close / monthly / finance) —
/// koi naya API nahi, koi naya package nahi (graphs pure Containers).
/// Colors 100% theme tokens se — dark/light dono me perfect.
/// ================================================================
class AdminDashboardScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  final void Function(String title, String subtitle, Widget body) onOpen;

  const AdminDashboardScreen({
    super.key,
    required this.session,
    required this.club,
    required this.onOpen,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? dc;
  Map<String, dynamic>? mon;
  Map<String, dynamic>? fin;
  bool loading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static List<Map<String, dynamic>> _maps(dynamic v) =>
      v is List
          ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const <Map<String, dynamic>>[];

  static double _nested(Map<String, dynamic>? src, String a, String b) {
    final x = src?[a];
    return x is Map ? _num(x[b]) : 0;
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final clubId = widget.club.clubId;
    if (clubId == null) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final m = thisMonth();
      final d = await widget.session.api.get(
        '/clubs/$clubId/reports/day-close',
      );
      final mo = await widget.session.api.get(
        '/clubs/$clubId/reports/monthly',
        query: {'month': m},
      );
      final f = await widget.session.api.get(
        '/clubs/$clubId/reports/finance',
        query: {'month': m},
      );
      if (!mounted) return;
      setState(() {
        dc = d is Map ? Map<String, dynamic>.from(d) : null;
        mon = mo is Map ? Map<String, dynamic>.from(mo) : null;
        fin = f is Map ? Map<String, dynamic>.from(f) : null;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final collected = _num(dc?['collected']);
    final expToday = _nested(dc, 'expenses', 'total');
    final netToday = _num(dc?['net']);
    final monthTotal = _num(mon?['totalEarnings']);
    final expMonth = _nested(fin, 'expenses', 'total');
    final netProfit = _nested(fin, 'pnl', 'netProfit');
    final dueTotal = widget.club.members
        .where((m) => m.active && m.dueAmount > 0)
        .fold<double>(0, (a, m) => a + m.dueAmount);
    final dueLimit = widget.session.activeClub?.dueLimit ?? 0;

    if (dc == null && loading) {
      return const Center(child: EightBallLoader(label: 'Loading dashboard…'));
    }
    if (dc == null && error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              title: 'Reports could not be loaded',
              hint: error,
              icon: Icons.cloud_off_outlined,
            ),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: c.green,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- top stat tiles (Today collected / net / total due) ----
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Today collected',
                  value: fmtMoney(collected),
                  sub: 'Payment ledger',
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatTile(
                  label: 'Today net',
                  value: fmtMoney(netToday),
                  sub: 'expenses ${fmtMoney(expToday)}',
                  tone: c.blue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatTile(
                  label: 'Total due',
                  value: fmtMoney(dueTotal),
                  sub: 'limit ${fmtMoney(dueLimit)}',
                  tone: c.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          InsightsCard(club: widget.club),
          const SizedBox(height: 10),

          // ★ v3.25 — owner spec: pages Smart Insights ke theek neeche
          _pagesCard(c, collected, monthTotal, expMonth, netProfit),
          const SizedBox(height: 10),

          _dailyCard(c),
          const SizedBox(height: 10),
          _mixCard(
            c,
            title: 'Income Mix — this month',
            total: monthTotal,
            empty: 'There is no income recorded this month yet.',
            rows: _incomeRows(c),
          ),
          const SizedBox(height: 10),
          _mixCard(
            c,
            title: 'Expense Mix — this month',
            total: expMonth,
            empty: 'No expense has been recorded this month — clean month! 🎉',
            rows: _expenseRows(c),
          ),
          const SizedBox(height: 10),
          _pnlCard(c, monthTotal, expMonth, netProfit),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- daily graph
  Widget _dailyCard(AppColors c) {
    final byDate = <String, Map<String, dynamic>>{
      for (final r in _maps(mon?['daily'])) '${r['date']}': r,
    };
    final now = DateTime.now();
    final rows = <(int, double, double)>[
      for (var i = 13; i >= 0; i--)
        (
          DateTime(now.year, now.month, now.day - i).day,
          _num(
            byDate[_key(DateTime(now.year, now.month, now.day - i))]?['income'],
          ),
          _num(
            byDate[_key(
              DateTime(now.year, now.month, now.day - i),
            )]?['expenses'],
          ),
        ),
    ];
    final maxV = rows.fold<double>(
      1,
      (a, d) => d.$2 > a ? d.$2 : (d.$3 > a ? d.$3 : a),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily income — last 14 days',
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'green income · red expenses',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font10_5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.green,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (day, inc, exp) in rows)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: (4 + (inc / maxV) * 66).clamp(4.0, 70.0),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color:
                                  inc > 0
                                      ? c.green
                                      : c.green.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height:
                                exp > 0
                                    ? (2 + (exp / maxV) * 22).clamp(2.0, 24.0)
                                    : 0,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: c.red.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$day',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font9,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- mix bars
  List<(String, double, Color)> _incomeRows(AppColors c) {
    final Map src =
        mon?['sourceTotals'] is Map ? mon!['sourceTotals'] as Map : const {};
    return [
      ('Frames', _num(src['frames']), c.green),
      ('Item Bills', _num(src['items']), c.blue),
      ('Memberships', _num(src['memberships']), c.gold),
      ('Due Collections', _num(src['due']), const Color(0xFFC084FC)),
      ('Tournaments', _num(src['tournaments']), const Color(0xFF2DD4BF)),
    ];
  }

  List<(String, double, Color)> _expenseRows(AppColors c) {
    final palette = [
      c.red,
      c.gold,
      c.blue,
      const Color(0xFFC084FC),
      const Color(0xFF2DD4BF),
      c.textMuted,
    ];
    return [
      for (final (i, e) in _maps(fin?['expenseCategories']).indexed)
        (
          _cap('${e['category'] ?? 'misc'}'),
          _num(e['amount']),
          palette[i % palette.length],
        ),
    ];
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _mixCard(
    AppColors c, {
    required String title,
    required double total,
    required String empty,
    required List<(String, double, Color)> rows,
  }) {
    final shown =
        rows.where((r) => r.$2 > 0).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: c.text,
                fontSize: Dimens.font13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'total ${fmtMoney(total)}',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10_5),
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  empty,
                  style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
                ),
              )
            else
              for (final (label, value, color) in shown) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: Dimens.font11_5,
                        ),
                      ),
                    ),
                    Text(
                      '${fmtMoney(value)} · ${total <= 0 ? 0 : (value / total * 100).round()}%',
                      style: TextStyle(
                        color: c.text,
                        fontSize: Dimens.font11_5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 7,
                    color: c.textMuted.withValues(alpha: 0.15),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor:
                          total <= 0 ? 0 : (value / total).clamp(0.0, 1.0),
                      child: Container(color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ P&L
  Widget _pnlCard(
    AppColors c,
    double income,
    double expense,
    double netProfit,
  ) {
    Widget row(String label, String value, Color color, {bool big = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: big ? c.text : c.textSecondary,
                    fontSize: big ? 12.5 : 11,
                    fontWeight: big ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: big ? 14 : 11,
                  fontWeight: big ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit & Loss — this month',
              style: TextStyle(
                color: c.text,
                fontSize: Dimens.font13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            row('Income', fmtMoney(income), c.green),
            row('Expenses', '− ${fmtMoney(expense)}', c.red),
            Divider(color: c.border, height: 14),
            row(
              'Net Profit',
              fmtMoney(netProfit),
              netProfit >= 0 ? c.gold : c.red,
              big: true,
            ),
            Text(
              'server-computed · cash-basis',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font9_5),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- page links
  Widget _pagesCard(
    AppColors c,
    double collected,
    double monthTotal,
    double expMonth,
    double netProfit,
  ) {
    // ★ v3.25 rewrite — plain Row/Expanded pairs (GridView + Border(left:)
    // trick hata diya: light mode me card contents invisible ho rahe the).
    Widget card(
      String title,
      String sub,
      IconData icon,
      String metric,
      Color tone,
      Widget page,
    ) => Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onOpen(title, sub, page),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              // web `.master-card-link` parity — left 3px accent strip
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 12, color: tone),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font11_5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metric,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone,
                        fontSize: Dimens.font13_5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      sub,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font9_5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget pair(Widget a, [Widget? b]) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b ?? const SizedBox.shrink()),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports & admin pages',
          style: TextStyle(
            color: c.text,
            fontSize: Dimens.font13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        pair(
          card(
            'Day Close',
            'collected today · drawer',
            Icons.nights_stay_outlined,
            fmtMoney(collected),
            c.green,
            DayCloseScreen(session: widget.session, club: widget.club),
          ),
          card(
            'Monthly Revenue',
            'received this month',
            Icons.calendar_view_month_outlined,
            fmtMoney(monthTotal),
            c.blue,
            MonthlyScreen(session: widget.session, club: widget.club),
          ),
        ),
        pair(
          card(
            'Finance · P&L',
            'net profit this month',
            Icons.scale_outlined,
            fmtMoney(netProfit),
            c.gold,
            FinanceScreen(session: widget.session, club: widget.club),
          ),
          card(
            'Expenses',
            'spent this month',
            Icons.receipt_outlined,
            fmtMoney(expMonth),
            c.red,
            ExpensesScreen(session: widget.session, club: widget.club),
          ),
        ),
      ],
    );
  }
}
