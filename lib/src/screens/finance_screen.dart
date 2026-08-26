import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../exporter.dart';
import '../insights.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// Finance — P&L, balance sheet, stock profit, utilisation (§12, owner-only).
class FinanceScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const FinanceScreen({super.key, required this.session, required this.club});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _month = thisMonth();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = {};
  Map<String, dynamic> _u = {};

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
      final res = await Future.wait([
        widget.session.api.get(
          '/clubs/${widget.club.clubId}/reports/finance',
          query: {'month': _month},
        ),
        widget.session.api.get(
          '/clubs/${widget.club.clubId}/reports/utilisation',
          query: {'month': _month},
        ),
      ]);
      _d = Map<String, dynamic>.from(res[0]);
      _u = Map<String, dynamic>.from(res[1]);
    } on ApiException catch (e) {
      _error = e.isForbidden ? null : e.message;
      _d = {};
      _u = {};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hour12(int h) {
    final ampm = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_locked) return const AdminLockedCard();

    final income = Map<String, dynamic>.from(_d['income'] ?? const {});
    final expenses = Map<String, dynamic>.from(_d['expenses'] ?? const {});
    final expCats = Map<String, dynamic>.from(
      expenses['byCategory'] ?? const {},
    );
    final expRowsList = List<dynamic>.from(expenses['rows'] ?? const []);
    int expCount(String cat) =>
        expRowsList.where((r) => '${(r as Map)['category']}' == cat).length;
    final pnl = Map<String, dynamic>.from(_d['pnl'] ?? const {});
    final stockProfit = Map<String, dynamic>.from(
      _d['stockProfit'] ?? const {},
    );
    final stockRows = List<dynamic>.from(stockProfit['rows'] ?? const []);
    final stockTotals = Map<String, dynamic>.from(
      stockProfit['totals'] ?? const {},
    );
    final balance = Map<String, dynamic>.from(_d['balance'] ?? const {});
    final daily = List<dynamic>.from(_d['daily'] ?? const []);
    final net = (pnl['netProfit'] ?? 0).toDouble();

    final tables = List<dynamic>.from(_u['tables'] ?? const []);
    final peakHour = _u['peakHour'];
    final hours = List<dynamic>.from(_u['hours'] ?? const []);

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
              child: EightBallLoader(label: 'crunching…'),
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
                _exBtn(c, 'P&L.xlsx', _exportPnl),
                _exBtn(c, 'Daily.xlsx', _exportDaily),
                _exBtn(c, 'Stock.xlsx', _exportStock),
                _exBtnPdf(c, 'P&L PDF', _exportPnlPdf),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Total income',
                    value: fmtMoney(pnl['incomeTotal']),
                    sub: 'cash received this month',
                    tone: c.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Total expenses',
                    value: fmtMoney(pnl['expenseTotal']),
                    sub:
                        '${(expenses['rows'] as List? ?? const []).length} entries',
                    tone: c.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: net < 0 ? 'Net loss' : 'Net profit',
                    value: fmtMoney(net),
                    sub:
                        net < 0
                            ? 'expenses exceeded income'
                            : 'income − expenses',
                    tone: net < 0 ? c.red : c.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Stock profit',
                    value: fmtMoney(stockTotals['profit']),
                    sub: 'sold ${stockTotals['qtySold'] ?? 0} pcs',
                    tone:
                        ((stockTotals['profit'] ?? 0) as num) < 0
                            ? c.gold
                            : c.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InsightsCard(club: widget.club),
            const SizedBox(height: 10),
            // ------------------------------------------------ P&L
            SectionCard(
              title: 'Profit & Loss Sheet · $_month',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '↗ INCOME (RECEIVED)',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _line(c, 'Table Billing', income['frames'], c.green),
                  _line(c, 'Item Sales', income['items'], c.green),
                  _line(c, 'Memberships', income['memberships'], c.green),
                  _line(c, 'Due Collections', income['due'], c.green),
                  _line(
                    c,
                    'Tournament Entries',
                    income['tournaments'],
                    c.green,
                  ),
                  Divider(color: c.border, height: 12),
                  _line(
                    c,
                    'Total Income',
                    income['total'],
                    c.green,
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '↘ EXPENSES (SPENT)',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final e in expCats.entries)
                    _line(
                      c,
                      '${e.key} ×${expCount(e.key)}',
                      e.value,
                      c.red,
                      negative: true,
                    ),
                  if (expCats.isEmpty)
                    Text(
                      'No expenses logged.',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font11,
                      ),
                    ),
                  Divider(color: c.border, height: 12),
                  _line(
                    c,
                    'Total Expenses',
                    expenses['total'],
                    c.red,
                    bold: true,
                    negative: true,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (net < 0 ? c.red : c.green).withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (net < 0 ? c.red : c.green).withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          net < 0 ? 'NET LOSS' : 'NET PROFIT',
                          style: TextStyle(
                            color: net < 0 ? c.red : c.green,
                            fontSize: Dimens.font12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          fmtMoney(net),
                          style: TextStyle(
                            color: net < 0 ? c.red : c.green,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Income is cash-basis (payment ledger) — same source as the monthly revenue sheet. Expenses go by their entry date.',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ------------------------------------------------ balance sheet
            SectionCard(
              title: 'Balance Sheet · current position',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ASSETS (CLUB'S MONEY/GOODS)",
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _line(
                    c,
                    'Receivables · member dues',
                    balance['receivables'],
                    c.green,
                  ),
                  _line(
                    c,
                    'Inventory value · stock in hand',
                    balance['inventory'],
                    c.green,
                  ),
                  _line(c, 'Fixed assets tracked', balance['assets'], c.green),
                  Divider(color: c.border, height: 12),
                  Text(
                    'LIABILITIES (CLUB OWES)',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _line(
                    c,
                    'Member wallet balances',
                    balance['wallets'],
                    c.red,
                    negative: true,
                  ),
                  if (((balance['liabilities'] ?? 0) as num) != 0)
                    _line(
                      c,
                      'Other liabilities',
                      balance['liabilities'],
                      c.red,
                      negative: true,
                    ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: c.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'NET POSITION',
                          style: TextStyle(
                            color: c.green,
                            fontSize: Dimens.font12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          fmtMoney(balance['netPosition']),
                          style: TextStyle(
                            color: c.green,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Net position = dues + stock value + assets − wallet money.',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ------------------------------------------------ utilisation
            SectionCard(
              title: 'Table Utilisation & Peak Hours · $_month',
              child:
                  tables.isEmpty
                      ? const EmptyState(
                        title: 'No frames this month',
                        hint:
                            'Once frames are billed, per-table utilisation and peak hours show here.',
                        icon: Icons.show_chart,
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final t in tables)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t['name']}',
                                          style: TextStyle(
                                            color: c.text,
                                            fontSize: Dimens.font12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${t['frames']} frames · ${((t['minutes'] ?? 0) / 60).toStringAsFixed(1)} hrs',
                                          style: TextStyle(
                                            color: c.textMuted,
                                            fontSize: Dimens.font10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${fmtMoney(t['effRate'])}/hr eff.',
                                    style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: Dimens.font10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fmtMoney(t['revenue']),
                                    style: TextStyle(
                                      color: c.green,
                                      fontSize: Dimens.font12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Divider(color: c.border, height: 14),
                          Text(
                            'PEAK HOURS (FRAMES STARTED)',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (var h = 0; h < hours.length; h++)
                                if (((hours[h]['frames'] ?? 0) as num) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          peakHour == h
                                              ? c.gold.withValues(alpha: 0.18)
                                              : c.bgMuted,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color:
                                            peakHour == h ? c.gold : c.border,
                                      ),
                                    ),
                                    child: Text(
                                      '${_hour12(h)} · ${hours[h]['frames']}',
                                      style: TextStyle(
                                        color:
                                            peakHour == h
                                                ? c.gold
                                                : c.textSecondary,
                                        fontSize: Dimens.font10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          if (peakHour != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                'Peak: ${_hour12(peakHour as int)} — most frames start during this hour.',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: Dimens.font10,
                                ),
                              ),
                            ),
                        ],
                      ),
            ),
            const SizedBox(height: 10),
            // ------------------------------------------------ stock profit
            SectionCard(
              title: 'Stock Sales & Profit · $_month',
              child:
                  stockRows.isEmpty
                      ? Text(
                        'No counter sales this month.',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font12,
                        ),
                      )
                      : Column(
                        children: [
                          Row(
                            children: [
                              _th(c, 'ITEM', flex: 3),
                              _th(c, 'CATEGORY', flex: 2),
                              _th(c, 'QTY', flex: 1, right: true),
                              _th(c, 'REVENUE', flex: 2, right: true),
                              _th(c, 'PROFIT', flex: 2, right: true),
                            ],
                          ),
                          Divider(color: c.border, height: 8),
                          for (final r in stockRows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  _td(c, '${r['name']}', flex: 3),
                                  _td(
                                    c,
                                    '${r['category']}',
                                    flex: 2,
                                    muted: true,
                                  ),
                                  _td(
                                    c,
                                    '${r['qtySold']}',
                                    flex: 1,
                                    right: true,
                                  ),
                                  _td(
                                    c,
                                    fmtMoney(r['revenue']),
                                    flex: 2,
                                    right: true,
                                  ),
                                  _td(
                                    c,
                                    fmtMoney(r['profit']),
                                    flex: 2,
                                    right: true,
                                    tone:
                                        ((r['profit'] ?? 0) as num) < 0
                                            ? c.red
                                            : c.green,
                                  ),
                                ],
                              ),
                            ),
                          Divider(color: c.border, height: 10),
                          Row(
                            children: [
                              _td(c, 'Total', flex: 3, bold: true),
                              _td(c, '', flex: 2),
                              _td(
                                c,
                                '${stockTotals['qtySold'] ?? 0}',
                                flex: 1,
                                right: true,
                                bold: true,
                              ),
                              _td(
                                c,
                                fmtMoney(stockTotals['revenue']),
                                flex: 2,
                                right: true,
                                bold: true,
                              ),
                              _td(
                                c,
                                fmtMoney(stockTotals['profit']),
                                flex: 2,
                                right: true,
                                bold: true,
                                tone:
                                    ((stockTotals['profit'] ?? 0) as num) < 0
                                        ? c.red
                                        : c.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Accrual basis — bills created this month (paid + unpaid both). Deleted bills are excluded.',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font10,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
            ),
            const SizedBox(height: 10),
            // ------------------------------------------------ daily sheet
            SectionCard(
              title: 'Daily Sheet · cash flow',
              child:
                  daily.isEmpty
                      ? Text(
                        'No activity this month.',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font12,
                        ),
                      )
                      : Column(
                        children: [
                          Row(
                            children: [
                              _th(c, 'DATE', flex: 3),
                              _th(c, 'INCOME', flex: 2, right: true),
                              _th(c, 'EXPENSES', flex: 2, right: true),
                              _th(c, 'NET', flex: 2, right: true),
                            ],
                          ),
                          Divider(color: c.border, height: 8),
                          for (final d in daily.take(31))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  _td(c, fmtDate(d['date']), flex: 3),
                                  _td(
                                    c,
                                    fmtMoney(d['income']),
                                    flex: 2,
                                    right: true,
                                    tone: c.green,
                                  ),
                                  _td(
                                    c,
                                    fmtMoney(d['expenses']),
                                    flex: 2,
                                    right: true,
                                    tone: c.red,
                                  ),
                                  _td(
                                    c,
                                    fmtMoney(
                                      (d['income'] ?? 0) - (d['expenses'] ?? 0),
                                    ),
                                    flex: 2,
                                    right: true,
                                    tone:
                                        (((d['income'] ?? 0) -
                                                        (d['expenses'] ?? 0))
                                                    as num) <
                                                0
                                            ? c.red
                                            : c.green,
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

  Future<void> _exportPnl() {
    final income = Map<String, dynamic>.from(_d['income'] ?? const {});
    final expenses = Map<String, dynamic>.from(_d['expenses'] ?? const {});
    final expCats = Map<String, dynamic>.from(
      expenses['byCategory'] ?? const {},
    );
    final pnl = Map<String, dynamic>.from(_d['pnl'] ?? const {});
    final rows = <List<dynamic>>[
      ['P&L $_month — cash-basis (payment ledger)'],
      [],
      ['INCOME (RECEIVED)', ''],
      ['Table Billing', _dbl(income['frames'])],
      ['Item Sales', _dbl(income['items'])],
      ['Memberships', _dbl(income['memberships'])],
      ['Due Collections', _dbl(income['due'])],
      ['Tournament Entries', _dbl(income['tournaments'])],
      ['Total Income', _dbl(income['total'])],
      [],
      ['EXPENSES (SPENT)', ''],
      for (final e in expCats.entries) [e.key, _dbl(e.value)],
      ['Total Expenses', _dbl(expenses['total'])],
      [],
      [
        _dbl(pnl['netProfit']) < 0 ? 'NET LOSS' : 'NET PROFIT',
        _dbl(pnl['netProfit']),
      ],
    ];
    return shareXlsx('rowdys-den-pnl-$_month.xlsx', {'P&L': rows});
  }

  Future<void> _exportDaily() {
    final daily = List<dynamic>.from(_d['daily'] ?? const []);
    return shareXlsx('rowdys-den-daily-$_month.xlsx', {
      'Daily': [
        ['Date', 'Income', 'Expenses', 'Net', 'Running Balance'],
        for (final d in daily)
          [
            '${d['date']}',
            _dbl(d['income']),
            _dbl(d['expenses']),
            _dbl(d['net'] ?? ((d['income'] ?? 0) - (d['expenses'] ?? 0))),
            _dbl(d['running']),
          ],
      ],
    });
  }

  Future<void> _exportStock() {
    final sp = Map<String, dynamic>.from(_d['stockProfit'] ?? const {});
    final rows = List<dynamic>.from(sp['rows'] ?? const []);
    final t = Map<String, dynamic>.from(sp['totals'] ?? const {});
    return shareXlsx('rowdys-den-stock-profit-$_month.xlsx', {
      'Stock Profit': [
        ['Item', 'Category', 'Qty Sold', 'Revenue', 'Cost', 'Profit'],
        for (final r in rows)
          [
            r['name'] ?? '',
            r['category'] ?? '',
            r['qtySold'] ?? 0,
            _dbl(r['revenue']),
            _dbl(r['cost']),
            _dbl(r['profit']),
          ],
        [
          'TOTAL',
          '',
          t['qtySold'] ?? 0,
          _dbl(t['revenue']),
          _dbl(t['cost']),
          _dbl(t['profit']),
        ],
      ],
    });
  }

  Future<void> _exportPnlPdf() {
    final income = Map<String, dynamic>.from(_d['income'] ?? const {});
    final expenses = Map<String, dynamic>.from(_d['expenses'] ?? const {});
    final expCats = Map<String, dynamic>.from(
      expenses['byCategory'] ?? const {},
    );
    final expRows = List<dynamic>.from(expenses['rows'] ?? const []);
    int expCount(String cat) =>
        expRows.where((r) => '${(r as Map)['category']}' == cat).length;
    final pnl = Map<String, dynamic>.from(_d['pnl'] ?? const {});
    final net = (pnl['netProfit'] ?? 0).toDouble();
    return shareA4Pdf(
      fileName: 'rowdys-den-pnl-$_month.pdf',
      clubName: widget.session.activeClub?.name ?? "Rowdy's Den",
      title: 'Profit & Loss — $_month',
      subtitle:
          '${ymLabel(_month)} · cash-basis income (payment ledger), expenses by entry date',
      tables: [
        ReportTable(
          heading: 'Income (received)',
          headers: const ['Stream', 'Amount'],
          rows: [
            ['Table Billing', rs(income['frames'])],
            ['Item Sales', rs(income['items'])],
            ['Memberships', rs(income['memberships'])],
            ['Due Collections', rs(income['due'])],
            ['Tournament Entries', rs(income['tournaments'])],
          ],
          totalRow: ['Total Income', rs(income['total'])],
        ),
        ReportTable(
          heading: 'Expenses (spent)',
          headers: const ['Category', 'Entries', 'Amount'],
          rows: [
            for (final e in expCats.entries)
              [e.key, '${expCount(e.key)}', rs(e.value)],
          ],
          totalRow: [
            'Total Expenses',
            '${expRows.length}',
            rs(expenses['total']),
          ],
        ),
        ReportTable(
          headers: const ['Result', 'Amount'],
          rows: [
            [net < 0 ? 'Net loss' : 'Net profit', rs(net)],
          ],
          note:
              'Income is cash-basis (payment ledger); wallet-mode consumption is not double counted. Expenses go by entry date.',
        ),
      ],
    );
  }

  Widget _line(
    AppColors c,
    String label,
    dynamic value,
    Color tone, {
    bool bold = false,
    bool negative = false,
  }) {
    final v = ((value ?? 0) as num).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bold ? c.text : c.textSecondary,
                fontSize: Dimens.font12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${negative ? '-' : ''}${fmtMoney(v)}',
            style: TextStyle(
              color: v == 0 ? c.textMuted : tone,
              fontSize: Dimens.font12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(AppColors c, String t, {int flex = 1, bool right = false}) =>
      Expanded(
        flex: flex,
        child: Text(
          t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: c.textMuted,
            fontSize: Dimens.font9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _td(
    AppColors c,
    String t, {
    int flex = 1,
    bool right = false,
    bool muted = false,
    bool bold = false,
    Color? tone,
  }) => Expanded(
    flex: flex,
    child: Text(
      t,
      textAlign: right ? TextAlign.right : TextAlign.left,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tone ?? (muted ? c.textMuted : c.text),
        fontSize: Dimens.font11,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );
}
