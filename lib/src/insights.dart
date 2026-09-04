import 'package:flutter/material.dart';

import 'dimensions.dart';

import 'session.dart';
import 'theme.dart';

/// ✨ Smart Insights — pure rule engine over live club data (no API cost).
/// Rules mirror the web spec thresholds: severity ordering red > gold > blue > green.
class Insight {
  final IconData icon;
  final Color tone;
  final String text;
  const Insight(this.icon, this.tone, this.text);
}

class InsightsCard extends StatefulWidget {
  final ClubController club;
  final bool compact;
  final int max;
  const InsightsCard({
    super.key,
    required this.club,
    this.compact = true,
    this.max = 3,
  });

  @override
  State<InsightsCard> createState() => _InsightsCardState();
}

class _InsightsCardState extends State<InsightsCard> {
  bool _expanded = false;

  List<Insight> _build(AppColors c) {
    final out = <Insight>[];
    final now = widget.club.currentServerNow;

    // 1 — live tables estimate (2-dp), items included
    final live = widget.club.sessions.where((s) => !s.stopped).toList();
    if (live.isNotEmpty) {
      var est = 0.0;
      for (final s in live) {
        est += s.estimate(now);
      }
      out.add(
        Insight(
          Icons.bolt,
          c.green,
          'Abhi ${live.length} table live — lagbhag ${fmtMoney(est)} billing accumulate ho chuki hai.',
        ),
      );
    }

    // 2 — out of stock (0) = RED; low (<= reorderLevel) = RED alert w/ names
    final outItems =
        widget.club.menuItems
            .where((i) => i.active && i.stockQty <= 0)
            .toList();
    if (outItems.isNotEmpty) {
      out.add(
        Insight(
          Icons.error_outline,
          c.red,
          'Out of stock: ${outItems.map((i) => i.name).take(3).join(", ")}${outItems.length > 3 ? " +${outItems.length - 3}" : ""} — counter pe band rakhein.',
        ),
      );
    }
    final low =
        widget.club.menuItems
            .where(
              (i) => i.active && i.stockQty > 0 && i.stockQty <= i.reorderLevel,
            )
            .toList();
    if (low.isNotEmpty) {
      out.add(
        Insight(
          Icons.inventory_2_outlined,
          c.gold,
          'Low stock: ${low.map((i) => "${i.name} (${i.stockQty})").take(3).join(", ")} — restock kar do.',
        ),
      );
    }

    // 3 — due pressure (RED when totalDue >= 70% of dueLimit)
    final dueMembers =
        widget.club.members.where((m) => m.active && m.dueAmount > 0).toList();
    final totalDue = dueMembers.fold<double>(0, (a, m) => a + m.dueAmount);
    if (totalDue > 0) {
      final limit = widget.club.session.activeClub?.dueLimit ?? 0;
      final worst = dueMembers.reduce(
        (a, b) => a.dueAmount >= b.dueAmount ? a : b,
      );
      final hot = limit > 0 && totalDue >= 0.7 * limit;
      out.add(
        Insight(
          Icons.warning_amber_rounded,
          hot ? c.red : c.gold,
          '${dueMembers.length} members pe ${fmtMoney(totalDue)} due hai'
          '${limit > 0 ? " (limit ${fmtMoney(limit)} ka ${(100 * totalDue / limit).toStringAsFixed(0)}%)" : ""}'
          ' — sabse zyada ${worst.name} (${fmtMoney(worst.dueAmount)}).',
        ),
      );
    }

    // 4 — wallets liability (BLUE)
    final wallets = widget.club.members.fold<double>(
      0,
      (a, m) => a + (m.walletBalance > 0 ? m.walletBalance : 0),
    );
    if (wallets > 0) {
      out.add(
        Insight(
          Icons.account_balance_wallet_outlined,
          c.blue,
          'Member wallets me ${fmtMoney(wallets)} pada hai — ye liability balance sheet me gina jata hai.',
        ),
      );
    }

    // 5 — expiring monthly plans (<= 7 din) = GOLD renewal
    final expiring =
        widget.club.members.where((m) {
          if (m.planExpiresAt.isEmpty) return false;
          final d = DateTime.tryParse(m.planExpiresAt);
          if (d == null) return false;
          final days = d.difference(now.toLocal()).inDays;
          return days <= 7;
        }).toList();
    if (expiring.isNotEmpty) {
      out.add(
        Insight(
          Icons.event_repeat,
          c.gold,
          'Plans expiring soon: ${expiring.map((m) => m.name).take(3).join(", ")} — renewal pitch karo.',
        ),
      );
    }

    // 6 — running tournament progress (BLUE) / upcoming unpaid (GOLD)
    for (final t in widget.club.tournaments) {
      final m = t as Map;
      if (m['status'] == 'running') {
        final matches = (m['matches'] as List?) ?? const [];
        final done =
            matches
                .where((x) => x['status'] == 'done' || x['status'] == 'bye')
                .length;
        out.add(
          Insight(
            Icons.emoji_events_outlined,
            c.blue,
            "${m['name']}: $done/${matches.length} matches ho gaye — table charges ${fmtMoney(m['tableCharges'])} tak.",
          ),
        );
        break;
      }
    }
    final upcomingUnpaid =
        widget.club.tournaments
            .where(
              (t) =>
                  (t as Map)['status'] == 'upcoming' &&
                  (((t['participants'] as List?) ?? const []).any(
                    (p) => p['paidEntry'] != true,
                  )),
            )
            .toList();
    if (upcomingUnpaid.isNotEmpty) {
      final t = upcomingUnpaid.first as Map;
      final pending = ((t['participants'] as List?) ?? const [])
          .where((p) => p['paidEntry'] != true)
          .fold<double>(
            0,
            (a, p) => a + ((t['entryFee'] ?? 0) as num).toDouble(),
          );
      out.add(
        Insight(
          Icons.payments_outlined,
          c.gold,
          "${t['name']} ki entries pending — ${fmtMoney(pending)} collect karna baaki hai.",
        ),
      );
    }

    out.sort((a, b) => _sev(c, a.tone).compareTo(_sev(c, b.tone)));
    return out.take(widget.max).toList();
  }

  int _sev(AppColors c, Color tone) {
    if (tone == c.red) return 0;
    if (tone == c.gold) return 1;
    if (tone == c.blue) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rules = _build(c);
    if (rules.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Smart Insights',
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: c.green.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulseDot(color: c.green),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: c.green,
                              fontSize: Dimens.font9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child:
                  _expanded
                      ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            for (final r in rules)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: widget.compact ? 5 : 7,
                                ),
                                decoration: BoxDecoration(
                                  color: c.bgMuted,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border(
                                    left: BorderSide(color: r.tone, width: 3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(r.icon, size: 13, color: r.tone),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        r.text,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: widget.compact ? 12 : 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({this.color = Colors.green});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_ctl),
    child: Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
