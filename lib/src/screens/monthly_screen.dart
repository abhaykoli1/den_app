import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../exporter.dart';
import '../insights.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// Monthly Revenue Sheet — money received by stream (§13, owner-only).
class MonthlyScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const MonthlyScreen({super.key, required this.session, required this.club});

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  String _month = thisMonth();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _locked => widget.session.user?.isStaff ?? false;

  Future<void> _load() async {
    if (_locked) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _d = Map<String, dynamic>.from(
        await widget.session.api.get(
          '/clubs/${widget.club.clubId}/reports/monthly',
          query: {'month': _month},
        ),
      );
    } on ApiException catch (e) {
      _error = e.isForbidden ? null : e.message;
      _d = {};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _sourceTone(AppColors c, String source) {
    switch (source) {
      case 'frames':
        return c.blue;
      case 'items':
        return c.green;
      case 'memberships':
        return c.gold;
      case 'due':
        return c.red;
      case 'tournaments':
        return c.blue;
      default:
        return c.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_locked) return const AdminLockedCard();

    final st = Map<String, dynamic>.from(_d['sourceTotals'] ?? const {});
    final sc = Map<String, dynamic>.from(_d['sourceCounts'] ?? const {});
    final rows = List<dynamic>.from(_d['rows'] ?? const []);

    Widget sourceTile(String label, String key, String unit, Color tone) =>
        Expanded(
          child: StatTile(
            label: label,
            value: fmtMoney(st[key]),
            sub: '${sc[key] ?? 0} $unit',
            tone: tone,
          ),
        );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final m = await pickMonth(context, _month);
              if (m != null) {
                setState(() => _month = m);
                _load();
              }
            },
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 14,
              color: c.textSecondary,
            ),
            label: Text(
              ymLabel(_month),
              style: TextStyle(color: c.text, fontSize: Dimens.font12),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: EightBallLoader(label: 'loading month…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load',
              hint: _error!,
              icon: Icons.cloud_off_outlined,
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _exBtn(c, 'Transactions.xlsx', _exportTransactions),
                _exBtn(c, 'Per-day.xlsx', _exportPerDay),
                _exBtnPdf(c, 'Month PDF', _exportPdf),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                sourceTile('Frame Billing', 'frames', 'payments', c.blue),
                const SizedBox(width: 8),
                sourceTile('Item Billing', 'items', 'payments', c.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                sourceTile('Memberships', 'memberships', 'plans sold', c.gold),
                const SizedBox(width: 8),
                sourceTile('Due Collected', 'due', 'payments', c.red),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                sourceTile('Tournaments', 'tournaments', 'entry fees', c.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Month total',
                    value: fmtMoney(st['total']),
                    sub: _month,
                    tone: c.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InsightsCard(club: widget.club),
            const SizedBox(height: 10),
            SectionCard(
              title: 'Transactions · ${rows.length}',
              child:
                  rows.isEmpty
                      ? const EmptyState(
                        title: 'No earnings this month',
                        hint:
                            'Frame payments, item bills, plan sales and due collections appear here.',
                        icon: Icons.payments_outlined,
                      )
                      : Column(
                        children: [
                          for (final r in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: _sourceTone(c, '${r['source']}'),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['desc']}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: c.text,
                                            fontSize: Dimens.font12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              fmtDate(r['date']),
                                              style: TextStyle(
                                                color: c.textMuted,
                                                fontSize: Dimens.font10,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            ToneBadge(
                                              '${r['source']}',
                                              _sourceTone(c, '${r['source']}'),
                                            ),
                                            if ((r['mode'] ?? '') != '') ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '${r['mode']}'.toUpperCase(),
                                                style: TextStyle(
                                                  color: c.textMuted,
                                                  fontSize: Dimens.font9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    fmtMoney(r['amount']),
                                    style: TextStyle(
                                      color: c.green,
                                      fontSize: Dimens.font12_5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------ exports (§30: Excel + PDF)
  Widget _exBtn(AppColors c, String label, Future<void> Function() onTap) =>
      OutlinedButton.icon(
        onPressed: () => _safeExport(onTap),
        icon: Icon(Icons.table_view_outlined, size: 13, color: c.green),
        label: Text(
          label,
          style: TextStyle(color: c.textSecondary, fontSize: Dimens.font11),
        ),
      );

  Widget _exBtnPdf(AppColors c, String label, Future<void> Function() onTap) =>
      OutlinedButton.icon(
        onPressed: () => _safeExport(onTap),
        icon: Icon(Icons.picture_as_pdf_outlined, size: 13, color: c.red),
        label: Text(
          label,
          style: TextStyle(color: c.textSecondary, fontSize: Dimens.font11),
        ),
      );

  Future<void> _safeExport(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (mounted) toast(context, 'Export failed: $e', error: true);
    }
  }

  double _dbl(dynamic v) => ((v ?? 0) as num).toDouble();

  Future<void> _exportTransactions() {
    final rows = List<dynamic>.from(_d['rows'] ?? const []);
    return shareXlsx('rowdys-den-transactions-$_month.xlsx', {
      'Transactions': [
        ['Date', 'Source', 'Description', 'Mode', 'Amount'],
        for (final r in rows)
          [
            r['date'] ?? '',
            r['source'] ?? '',
            r['desc'] ?? '',
            r['mode'] ?? '',
            _dbl(r['amount']),
          ],
      ],
    });
  }

  Future<void> _exportPerDay() {
    final daily = List<dynamic>.from(_d['daily'] ?? const []);
    final st = Map<String, dynamic>.from(_d['sourceTotals'] ?? const {});
    return shareXlsx('rowdys-den-per-day-$_month.xlsx', {
      'Per-day': [
        [
          'Date',
          'Frames',
          'Items',
          'Memberships',
          'Due',
          'Tournaments',
          'Total',
        ],
        for (final d in daily)
          [
            '${d['date']}',
            _dbl(d['frames']),
            _dbl(d['items']),
            _dbl(d['memberships']),
            _dbl(d['due']),
            _dbl(d['tournaments']),
            _dbl(d['total'] ?? d['income']),
          ],
        [
          'TOTAL',
          _dbl(st['frames']),
          _dbl(st['items']),
          _dbl(st['memberships']),
          _dbl(st['due']),
          _dbl(st['tournaments']),
          _dbl(st['total']),
        ],
      ],
    });
  }

  Future<void> _exportPdf() {
    final st = Map<String, dynamic>.from(_d['sourceTotals'] ?? const {});
    final sc = Map<String, dynamic>.from(_d['sourceCounts'] ?? const {});
    final daily = List<dynamic>.from(_d['daily'] ?? const []);
    final rows = List<dynamic>.from(_d['rows'] ?? const []);
    final totalCount = sc.values.fold<int>(0, (a, v) => a + (v as num).toInt());
    return shareA4Pdf(
      fileName: 'rowdys-den-monthly-$_month.pdf',
      clubName: widget.session.activeClub?.name ?? "Rowdy's Den",
      title: 'Monthly Revenue — $_month', // spec: print title sirf ye
      tables: [
        ReportTable(
          heading: 'Source totals (received)',
          headers: const ['Source', 'Entries', 'Amount'],
          rows: [
            ['Frame Billing', '${sc['frames'] ?? 0}', rs(st['frames'])],
            ['Item Billing', '${sc['items'] ?? 0}', rs(st['items'])],
            ['Memberships', '${sc['memberships'] ?? 0}', rs(st['memberships'])],
            ['Due Collected', '${sc['due'] ?? 0}', rs(st['due'])],
            ['Tournaments', '${sc['tournaments'] ?? 0}', rs(st['tournaments'])],
          ],
          totalRow: ['Month total', '$totalCount', rs(st['total'])],
        ),
        ReportTable(
          heading: 'Per-day',
          headers: const [
            'Date',
            'Frames',
            'Items',
            'Memberships',
            'Due',
            'Tournaments',
            'Total',
          ],
          rows: [
            for (final d in daily)
              [
                fmtDate('${d['date']}'),
                rs(d['frames']),
                rs(d['items']),
                rs(d['memberships']),
                rs(d['due']),
                rs(d['tournaments']),
                rs(d['total'] ?? d['income']),
              ],
          ],
        ),
        ReportTable(
          heading: 'Transactions',
          headers: const ['Date', 'Source', 'Description', 'Mode', 'Amount'],
          rows: [
            for (final r in rows)
              [
                fmtDate('${r['date']}'),
                '${r['source']}',
                '${r['desc']}',
                '${r['mode'] ?? ''}'.toUpperCase(),
                rs(r['amount']),
              ],
          ],
          note:
              'Money received, by stream — wallet-mode consumption is pre-paid and not counted as new income.',
        ),
      ],
    );
  }
}
