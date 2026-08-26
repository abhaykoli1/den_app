import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Activity Logs — billing, payments, warnings and admin actions (§15).
class LogsScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const LogsScreen({super.key, required this.session, required this.club});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _tag = 'ALL';
  String _q = '';

  static const _tags = ['ALL', 'BILLING', 'PAYMENT', 'WARNING', 'ADMIN'];

  String _modeLabel(String m) {
    switch (m.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      default:
        return m;
    }
  }

  Color _tone(AppColors c, String tag) {
    switch (tag) {
      case 'BILLING':
        return c.blue;
      case 'PAYMENT':
        return c.green;
      case 'WARNING':
        return c.red;
      default:
        return c.gold;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.club.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.club.removeListener(_onData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var logs = List<dynamic>.from(widget.club.logs);
    logs.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    if (_tag != 'ALL') {
      logs = logs.where((l) => '${l['tag'] ?? 'ADMIN'}' == _tag).toList();
    }
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      logs =
          logs
              .where(
                (l) =>
                    '${l['message']} ${l['actor']}'.toLowerCase().contains(q),
              )
              .toList();
    }
    return RefreshIndicator(
      onRefresh: widget.club.refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final t in _tags)
                  ButtonSegment(
                    value: t,
                    label: Text(
                      t == 'ALL' ? 'All' : t[0] + t.substring(1).toLowerCase(),
                      style: const TextStyle(fontSize: Dimens.font11),
                    ),
                  ),
              ],
              selected: {_tag},
              onSelectionChanged: (v) => setState(() => _tag = v.first),
            ),
          ),
          const SizedBox(height: 8),
          // ★ v3.26 — compact search bar
          SizedBox(
            height: Dimens.searchH,
            child: TextField(
              style: TextStyle(color: c.text, fontSize: Dimens.searchFont),
              decoration: const InputDecoration(
                isDense: true,
                // contentPadding: Dimens.searchPad,
                prefixIconConstraints: BoxConstraints(minWidth: 32),
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: 'Search logs',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const EmptyState(
              title: 'No logs yet',
              hint: 'Billing, payments and admin actions are recorded here.',
              icon: Icons.history,
            ),
          for (final l in logs)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: _tone(c, '${l['tag'] ?? 'ADMIN'}'),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Container(width: 1, color: c.border)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ToneBadge(
                                  '${l['tag'] ?? 'ADMIN'}',
                                  _tone(c, '${l['tag'] ?? 'ADMIN'}'),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    [
                                      fmtDT(l['createdAt']),
                                      if ((l['mode'] ?? '') != '')
                                        _modeLabel('${l['mode']}'),
                                      if ((l['amount'] ?? 0) != 0)
                                        fmtMoney(l['amount']),
                                    ].where((s) => s.isNotEmpty).join('  ·  '),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: Dimens.font10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${l['message'] ?? ''}',
                              style: TextStyle(
                                color: c.text,
                                fontSize: Dimens.font12_5,
                                height: 1.3,
                              ),
                            ),
                            if ((l['actor'] ?? '') != '')
                              Text(
                                'by ${l['actor']}',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: Dimens.font10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
