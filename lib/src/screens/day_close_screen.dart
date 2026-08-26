import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../exporter.dart';
import '../insights.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// Day Close — daily accounts reconcile (§12-ish / Admin ▸ Day Close).
class DayCloseScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const DayCloseScreen({super.key, required this.session, required this.club});

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  String _date = todayStr();
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
          '/clubs/${widget.club.clubId}/reports/day-close',
          query: {'date': _date},
        ),
      );
    } on ApiException catch (e) {
      _error = e.isForbidden ? null : e.message;
      _d = {};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_locked) return const AdminLockedCard();

    final byMode = Map<String, dynamic>.from(_d['byMode'] ?? const {});
    final bySource = Map<String, dynamic>.from(_d['bySource'] ?? const {});
    final sourceCounts = Map<String, dynamic>.from(
      _d['sourceCounts'] ?? const {},
    );
    final expenses = Map<String, dynamic>.from(_d['expenses'] ?? const {});
    final expCats = Map<String, dynamic>.from(
      expenses['byCategory'] ?? const {},
    );
    final expRows = List<dynamic>.from(expenses['rows'] ?? const []);
    final ops = Map<String, dynamic>.from(_d['ops'] ?? const {});
    final top = List<dynamic>.from(_d['topItems'] ?? const []);
    final closing = Map<String, dynamic>.from(_d['closing'] ?? const {});
    final collected = (_d['collected'] ?? 0).toDouble();
    final expTotal =
        (_d['expenses'] is Map ? (_d['expenses']['total'] ?? 0) : 0).toDouble();
    final net = collected - expTotal;
    final pendingDue = (_d['pendingDue'] ?? 0).toDouble();
    final drawer = (closing['drawerCash'] ?? 0).toDouble();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await pickDate(context, _date);
                    if (d != null) {
                      setState(() => _date = d);
                      _load();
                    }
                  },
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: c.textSecondary,
                  ),
                  label: Text(
                    fmtDate(_date),
                    style: TextStyle(color: c.text, fontSize: Dimens.font12),
                  ),
                ),
              ),
              if (_date != todayStr()) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _date = todayStr());
                    _load();
                  },
                  child: Text(
                    'Back to Today',
                    style: TextStyle(color: c.blue, fontSize: Dimens.font12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          InsightsCard(club: widget.club),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: EightBallLoader(label: 'closing the day…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load',
              hint: _error!,
              icon: Icons.cloud_off_outlined,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Total collected',
                    value: fmtMoney(collected),
                    sub:
                        '${sourceCounts.values.fold<int>(0, (a, v) => a + (v as num).toInt())} payment entries',
                    tone: c.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Expenses',
                    value: fmtMoney(expTotal),
                    sub: '${expRows.length} entries this day',
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
                    label: net < 0 ? 'Net (loss)' : 'Net',
                    value: fmtMoney(net),
                    sub: 'collected − expenses · drawer me hona chahiye',
                    tone: net < 0 ? c.red : c.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Pending due (all members)',
                    value: fmtMoney(pendingDue),
                    sub: 'all members · right now',
                    tone: c.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SectionCard(
              title: 'Mode-wise Collection · $_date',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (collected == 0)
                    Text(
                      'No collections recorded for this day.',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font12,
                      ),
                    ),
                  for (final m in ['cash', 'upi', 'card'])
                    if (((byMode[m] ?? 0) as num) != 0)
                      _line(
                        c,
                        m == 'cash'
                            ? 'Cash'
                            : m == 'upi'
                            ? 'UPI'
                            : 'Card',
                        fmtMoney(byMode[m]),
                        tone: c.green,
                      ),
                  if (collected > 0) Divider(color: c.border, height: 14),
                  Text(
                    'SOURCE-WISE (WHICH STREAM EARNED)',
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
                    'Table Billing (frames)  ×${sourceCounts['frames'] ?? 0}',
                    fmtMoney(bySource['frames']),
                  ),
                  _line(
                    c,
                    'Item Sales  ×${sourceCounts['items'] ?? 0}',
                    fmtMoney(bySource['items']),
                  ),
                  _line(
                    c,
                    'Memberships  ×${sourceCounts['memberships'] ?? 0}',
                    fmtMoney(bySource['memberships']),
                  ),
                  _line(
                    c,
                    'Due Collections  ×${sourceCounts['due'] ?? 0}',
                    fmtMoney(bySource['due']),
                  ),
                  _line(
                    c,
                    'Tournament Entries  ×${sourceCounts['tournaments'] ?? 0}',
                    fmtMoney(bySource['tournaments']),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SectionCard(
              title: "Day's Expenses",
              child:
                  expRows.isEmpty
                      ? Text(
                        'No expenses logged.',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font12,
                        ),
                      )
                      : Column(
                        children: [
                          for (final e in expCats.entries)
                            _line(
                              c,
                              e.key,
                              '-${fmtMoney(e.value)}',
                              tone: c.red,
                            ),
                          Divider(color: c.border, height: 12),
                          _line(
                            c,
                            'Total expenses',
                            '-${fmtMoney(expTotal)}',
                            tone: c.red,
                            bold: true,
                          ),
                        ],
                      ),
            ),
            const SizedBox(height: 10),
            SectionCard(
              title: 'Ops snapshot',
              child: Column(
                children: [
                  _line(
                    c,
                    'Frames billed',
                    '${ops['framesBilled'] ?? 0} · ${fmtMoney(ops['tableRevenue'])}',
                  ),
                  _line(c, 'Table amount', fmtMoney(ops['tableRevenue'])),
                  _line(
                    c,
                    'Items on frames',
                    fmtMoney(ops['itemsRevenue']),
                    sub: '${ops['itemBills'] ?? 0} counter bills',
                  ),
                  _line(
                    c,
                    'Tables live right now',
                    '${ops['liveTables'] ?? 0}',
                    tone: c.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SectionCard(
              title: 'Top 5 Counter Items · day',
              child:
                  top.isEmpty
                      ? Text(
                        'Nothing sold at the counter this day.',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font12,
                        ),
                      )
                      : Column(
                        children: [
                          for (final t in top)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${t['name']}',
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: Dimens.font12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${t['qty']} pcs',
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: Dimens.font11,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  fmtMoney(t['revenue']),
                                  style: TextStyle(
                                    color: c.green,
                                    fontSize: Dimens.font11_5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: drawer < 0 ? c.red : c.border),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        drawer < 0
                            ? Icons.trending_down
                            : Icons.inventory_2_outlined,
                        size: 14,
                        color: drawer < 0 ? c.red : c.gold,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Closing · ${_date == todayStr() ? 'today so far' : fmtDate(_date)} — drawer should hold ${fmtMoney(drawer)}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font12_5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Count the cash in the drawer: ${fmtMoney(closing['drawerCash'])} '
                    '(cash collected ${fmtMoney(closing['cashCollected'])} − expenses ${fmtMoney(closing['expenses'])}). '
                    'UPI/card ${fmtMoney((closing['upi'] ?? 0) + (closing['card'] ?? 0))} should match your statements.',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: Dimens.font11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ToneBadge(
                    drawer < 0 ? 'drawer short' : 'drawer healthy',
                    drawer < 0 ? c.red : c.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // --------------------------------------------- closing slip (§30)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                ),
                onPressed: _exportSlip,
                icon: const Icon(Icons.print_outlined, size: 15),
                label: const Text('Closing Slip (PDF / Print)'),
              ),
            ),
            Text(
              'Save or share the slip with the drawer count — both the accountant and owner keep a record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportSlip() async {
    final byMode = Map<String, dynamic>.from(_d['byMode'] ?? const {});
    final bySource = Map<String, dynamic>.from(_d['bySource'] ?? const {});
    final sourceCounts = Map<String, dynamic>.from(
      _d['sourceCounts'] ?? const {},
    );
    final expenses = Map<String, dynamic>.from(_d['expenses'] ?? const {});
    final expCats = Map<String, dynamic>.from(
      expenses['byCategory'] ?? const {},
    );
    final ops = Map<String, dynamic>.from(_d['ops'] ?? const {});
    final top = List<dynamic>.from(_d['topItems'] ?? const []);
    final closing = Map<String, dynamic>.from(_d['closing'] ?? const {});
    const week = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    var sub = fmtDate(_date);
    try {
      final dt = DateTime.parse(_date);
      sub = '${fmtDate(_date)} · ${week[dt.weekday - 1]}';
    } catch (_) {
      /* keep plain date */
    }
    try {
      await shareA4Pdf(
        fileName: 'rowdys-den-day-close-$_date.pdf',
        clubName: widget.session.activeClub?.name ?? "Rowdy's Den",
        title: 'Day Close — $_date',
        subtitle: sub,
        tables: [
          ReportTable(
            heading: 'Mode-wise collection',
            headers: const ['Mode', 'Amount'],
            rows: [
              for (final m in ['cash', 'upi', 'card'])
                if (((byMode[m] ?? 0) as num) != 0)
                  [m.toUpperCase(), rs(byMode[m])],
            ],
            totalRow: ['Collected', rs(_d['collected'])],
          ),
          ReportTable(
            heading: 'Source-wise (which stream earned)',
            headers: const ['Source', 'Entries', 'Amount'],
            rows: [
              [
                'Table Billing',
                '${sourceCounts['frames'] ?? 0}',
                rs(bySource['frames']),
              ],
              [
                'Item Sales',
                '${sourceCounts['items'] ?? 0}',
                rs(bySource['items']),
              ],
              [
                'Memberships',
                '${sourceCounts['memberships'] ?? 0}',
                rs(bySource['memberships']),
              ],
              [
                'Due Collections',
                '${sourceCounts['due'] ?? 0}',
                rs(bySource['due']),
              ],
              [
                'Tournament Entries',
                '${sourceCounts['tournaments'] ?? 0}',
                rs(bySource['tournaments']),
              ],
            ],
          ),
          if (expCats.isNotEmpty)
            ReportTable(
              heading: "Day's expenses",
              headers: const ['Category', 'Amount'],
              rows: [
                for (final e in expCats.entries) [e.key, rs(e.value)],
              ],
              totalRow: ['Total expenses', rs(expenses['total'])],
            ),
          if (top.isNotEmpty)
            ReportTable(
              heading: 'Top counter items',
              headers: const ['Item', 'Qty', 'Revenue'],
              rows: [
                for (final t in top)
                  ['${t['name']}', '${t['qty'] ?? 0}', rs(t['revenue'])],
              ],
            ),
          ReportTable(
            heading: 'Closing drawer',
            headers: const ['Head', 'Amount'],
            rows: [
              ['Cash collected', rs(closing['cashCollected'])],
              ['Expenses paid', rs(closing['expenses'])],
              ['Drawer cash should hold', rs(closing['drawerCash'])],
              ['UPI', rs(closing['upi'])],
              ['Card', rs(closing['card'])],
              ['Pending due (all members)', rs(_d['pendingDue'])],
            ],
            note:
                'Count the drawer and match with the slip; UPI/card should match your statements.',
          ),
          ReportTable(
            heading: 'Ops snapshot',
            headers: const ['Metric', 'Value'],
            rows: [
              ['Frames billed', '${ops['framesBilled'] ?? 0}'],
              ['Table revenue', rs(ops['tableRevenue'])],
              ['Items on frames', rs(ops['itemsRevenue'])],
              ['Counter bills', '${ops['itemBills'] ?? 0}'],
              ['Tables live right now', '${ops['liveTables'] ?? 0}'],
            ],
          ),
        ],
      );
    } catch (e) {
      if (mounted) toast(context, 'Export failed: $e', error: true);
    }
  }

  Widget _line(
    AppColors c,
    String label,
    String value, {
    Color? tone,
    bool bold = false,
    String? sub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
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
                if (sub != null)
                  Text(
                    '  ($sub)',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font10,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: tone ?? c.text,
              fontSize: Dimens.font12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
