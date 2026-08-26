import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../insights.dart';
import '../models.dart';
import '../session.dart';
import '../dimensions.dart';
import '../theme.dart';
import '../widgets.dart';

class TablesScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const TablesScreen({super.key, required this.session, required this.club});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.club.addListener(_onData);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.club.sessions.any((s) => !s.stopped) && mounted) {
        setState(() {});
      }
    });
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.club.removeListener(_onData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final club = widget.club;
    return RefreshIndicator(
      onRefresh: club.refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total due',
                  value: fmtMoney(club.stats.totalDue),
                  sub:
                      '${club.members.where((m) => m.active && m.hasDue).length} active members',
                  tone: c.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Daily earnings',
                  value: fmtMoney(club.stats.todayEarnings),
                  sub: "Today's Payment",
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Due limit',
                  value: fmtMoney(widget.session.activeClub?.dueLimit ?? 0),
                  sub:
                      (widget.session.activeClub != null &&
                              (widget.session.activeClub!.dueLimit) > 0 &&
                              club.stats.totalDue >=
                                  widget.session.activeClub!.dueLimit)
                          ? 'Limit exceeded'
                          : 'Club setting',
                  tone: c.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InsightsCard(club: club),
          const SizedBox(height: 10),
          if (club.tables.where((t) => t.active).isEmpty)
            const EmptyState(
              title: 'No active games',
              hint: 'Add games from Settings → Game Pricing',
              icon: Icons.table_restaurant_outlined,
            ),
          for (final t in club.tables.where((t) => t.active))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TableCard(
                key: ValueKey(t.id),
                table: t,
                session: club.sessionFor(t.id),
                previousFrame: _previousFrameFor(t),
                screen: this,
              ),
            ),
          const SizedBox(height: 20),
          // Text(
          //   'Final amounts are computed by the server.',
          //   textAlign: TextAlign.center,
          //   style: TextStyle(
          //     color: c.textMuted,
          //     fontSize: Dimens.font10,
          //     fontStyle: FontStyle.italic,
          //   ),
          // ),
        ],
      ),
    );
  }

  /// The frames endpoint is the source of truth after a bill is confirmed.
  /// Keep this lookup defensive because older backends may omit tableId.
  Map<String, dynamic>? _previousFrameFor(ClubTable table) {
    final matches =
        widget.club.frames
            .whereType<Map>()
            .map((frame) => Map<String, dynamic>.from(frame))
            .where(
              (frame) =>
                  '${frame['tableId'] ?? ''}' == table.id ||
                  '${frame['tableName'] ?? ''}' == table.name,
            )
            .toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final aDate = DateTime.tryParse(
        '${a['createdAt'] ?? a['endedAt'] ?? ''}',
      );
      final bDate = DateTime.tryParse(
        '${b['createdAt'] ?? b['endedAt'] ?? ''}',
      );
      return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    return matches.first;
  }

  Future<void> startSession(ClubTable table) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => StartSessionSheet(
            session: widget.session,
            club: widget.club,
            table: table,
          ),
    );
    if (ok == true) await widget.club.refresh();
  }

  Future<void> stopSession(ClubSession s) async {
    try {
      await widget.session.api.post(
        '/clubs/${widget.club.clubId}/sessions/${s.id}/stop',
      );
      await widget.club.refresh();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> confirmBill(ClubSession s) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => FinalBillSheet(
            session: widget.session,
            club: widget.club,
            tableSession: s,
          ),
    );
    if (ok == true) {
      await widget.club.refresh();
      if (mounted) {
        final msg = FinalBillSheet.lastMessage;
        if (msg != null) toast(context, msg);
      }
    }
  }
}

class _TableCard extends StatefulWidget {
  final ClubTable table;
  final ClubSession? session;
  final Map<String, dynamic>? previousFrame;
  final _TablesScreenState screen;

  const _TableCard({
    super.key,
    required this.table,
    required this.session,
    required this.previousFrame,
    required this.screen,
  });

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _busy = false;
  String? _busyAction;

  ClubTable get table => widget.table;
  ClubSession? get session => widget.session;
  Map<String, dynamic>? get previousFrame => widget.previousFrame;
  _TablesScreenState get screen => widget.screen;

  Future<void> _run(String actionName, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyAction = actionName;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyAction = null;
        });
      }
    }
  }

  Future<String?> _chooseMember(BuildContext context, List<Member> members) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered =
                members
                    .where(
                      (m) => m.name.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: const Text('Choose member'),
              content: SizedBox(
                width: 600,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged:
                          (value) => setDialogState(() => query = value.trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search member',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Walk-in customer'),
                            onTap: () => Navigator.pop(dialogContext, ''),
                          ),
                          for (final member in filtered)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                member.hasDue
                                    ? '${member.name}  (Due ${fmtMoney(member.dueAmount)})'
                                    : member.name,
                              ),
                              onTap:
                                  () => Navigator.pop(dialogContext, member.id),
                            ),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 24),
                              child: Center(child: Text('No members found')),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = session;
    if (s == null) {
      // ★ v3.25 — idle card "khali" lag raha tha: left green accent strip +
      // rate pill + tighter rhythm (web idle-table parity).
      return Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: c.green,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              table.name,
                              style: TextStyle(
                                color: c.text,
                                fontSize: Dimens.font15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.soft(c.green),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: c.green.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              '${fmtMoney(table.hourlyRate)}/hr',
                              style: TextStyle(
                                color: c.green,
                                fontSize: Dimens.font11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (table.minCharge > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          'min ${fmtMoney(table.minCharge)}',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font11,
                          ),
                        ),
                      ],
                      if (previousFrame != null) ...[
                        const SizedBox(height: 9),
                        _PreviousFrame(frame: previousFrame!),
                      ],
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        height: Dimens.ctaH, // ★ hero CTA — Dimens.ctaH (v3.24)
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.green,
                            foregroundColor: c.onGreen,
                          ),
                          onPressed: () => screen.startSession(table),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Start game'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stopped = s.stopped;
    final now = screen.widget.club.currentServerNow;
    final elapsed = s.elapsed(now);
    final borderColor = stopped ? c.blue : c.gold;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.6),
      ),
      color: c.bgElevated,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tableName,
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!stopped) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: c.red,
                      fontSize: Dimens.font10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else
                  ToneBadge('Final bill', c.blue),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  hhmmss(elapsed),
                  style: TextStyle(
                    color: c.text,
                    fontSize: Dimens.font27,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [],
                  ),
                ),
                const Spacer(),
                Text(
                  '≈ ${fmtMoney(s.estimate(now))} ab tak',
                  style: TextStyle(
                    color: c.gold,
                    fontSize: Dimens.font13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (s.peak)
              Text(
                'peak rate',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: Dimens.font10,
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in s.players)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          p.team == 'A'
                              ? c.blue.withValues(alpha: 0.12)
                              : p.team == 'B'
                              ? c.gold.withValues(alpha: 0.12)
                              : c.bgMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            p.team == 'A'
                                ? c.blue.withValues(alpha: 0.55)
                                : p.team == 'B'
                                ? c.gold.withValues(alpha: 0.55)
                                : c.border,
                        width: p.team == null ? 1 : 1.2,
                      ),
                    ),
                    child: Text(
                      p.memberId != null && _dueOf(context, p.memberId!) > 0
                          ? '${p.label} (due ${fmtMoney(_dueOf(context, p.memberId!))})'
                          : p.label,
                      style: TextStyle(
                        color:
                            p.memberId != null &&
                                    _dueOf(context, p.memberId!) > 0
                                ? c.red
                                : (p.team == 'A'
                                    ? c.blue
                                    : p.team == 'B'
                                    ? c.gold
                                    : c.text),
                        fontSize: Dimens.font11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (s.items.isNotEmpty) ...[
              const SizedBox(height: 5),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap:
                    stopped || _busy
                        ? null
                        : () => _editAttachedItems(context, s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'items: ${s.items.map((i) => '${i['name']}×${i['qty']}').join(', ')} '
                          '· ${fmtMoney(s.itemsTotal)}',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: Dimens.font11,
                          ),
                        ),
                      ),
                      if (!stopped)
                        Icon(Icons.edit_outlined, size: 15, color: c.textMuted),
                    ],
                  ),
                ),
              ),
            ],
            if (s.advancePaid > 0)
              Text(
                'advance ${fmtMoney(s.advancePaid)}',
                style: TextStyle(color: c.green, fontSize: Dimens.font11),
              ),
            if (s.gloves.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final g in s.gloves)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (g['returned'] == true ? c.green : c.gold)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (g['returned'] == true ? c.green : c.gold)
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            value: g['returned'] == true,
                            onChanged:
                                stopped
                                    ? null
                                    : (_) => _toggleGlove(context, s, g),
                            activeColor: c.green,
                            checkColor: c.onGreen,
                          ),
                          Icon(
                            Icons.back_hand_outlined,
                            size: 11,
                            color: g['returned'] == true ? c.green : c.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${g['label'] ?? 'Glove'} · ${g['returned'] == true ? 'returned' : 'out ${fmtMoney(g['price'])}'}',
                            style: TextStyle(
                              color: g['returned'] == true ? c.green : c.gold,
                              fontSize: Dimens.font10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (s.notes.isNotEmpty)
              Text(
                'note: ${s.notes}',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
            if (previousFrame != null) ...[
              const SizedBox(height: 8),
              _PreviousFrame(frame: previousFrame!),
            ],
            const SizedBox(height: 8),
            if (!stopped) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _addItem(context, s),
                      icon: const Icon(Icons.local_cafe_outlined, size: 13),
                      label: const Text(
                        'Item',
                        style: TextStyle(fontSize: Dimens.font11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _addAdvance(context, s),
                      icon: const Icon(Icons.payments_outlined, size: 13),
                      label: const Text(
                        'Advance',
                        style: TextStyle(fontSize: Dimens.font11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _editNote(context, s),
                      icon: const Icon(Icons.sticky_note_2_outlined, size: 13),
                      label: const Text(
                        'Note',
                        style: TextStyle(fontSize: Dimens.font11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _moveTable(context, s),
                      icon: const Icon(Icons.swap_horiz, size: 13),
                      label: const Text(
                        'Move',
                        style: TextStyle(fontSize: Dimens.font11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _cancel(context, s),
                      icon: Icon(Icons.close, size: 13, color: c.red),
                      label: Text(
                        'Cancel',
                        style: TextStyle(fontSize: Dimens.font11, color: c.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _addPlayer(context, s),
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 13,
                      ),
                      label: const Text(
                        'Player',
                        style: TextStyle(fontSize: Dimens.font11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.gold,
                        foregroundColor: c.onGold,
                      ),
                      onPressed:
                          () => _run('stop', () => screen.stopSession(s)),
                      child:
                          _busy
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('Stop timer'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy
                              ? null
                              : () => _run('resume', () async {
                                try {
                                  await screen.widget.session.api.post(
                                    '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/resume',
                                  );
                                  await screen.widget.club.refresh();
                                } on ApiException catch (e) {
                                  if (context.mounted) {
                                    toast(
                                      context,
                                      e.message,
                                      error: e.status >= 500,
                                    );
                                  }
                                }
                              }),
                      child: const Text(
                        'Resume',
                        style: TextStyle(fontSize: Dimens.font12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          _busy
                              ? null
                              : () =>
                                  _run('confirm', () => screen.confirmBill(s)),
                      child:
                          _busy
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('Confirm bill'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _dueOf(BuildContext context, String memberId) {
    for (final m in screen.widget.club.members) {
      if (m.id == memberId) return m.dueAmount;
    }
    return 0;
  }

  Future<void> _addItem(BuildContext context, ClubSession s) async {
    final c = context.colors;
    MenuItem? picked;
    int qty = 1;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (ctx, set) {
              final items =
                  screen.widget.club.menuItems
                      .where((i) => i.active && !i.outOfStock)
                      .toList();
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Attach item to table',
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final i in items)
                            ChoiceChip(
                              showCheckmark: false,
                              label: Text(
                                '${i.name} (${i.stockQty})',
                                style: TextStyle(
                                  fontSize: Dimens.font11,
                                  color:
                                      picked?.id == i.id
                                          ? Colors.black87
                                          : c.textSecondary,
                                ),
                              ),
                              selected: picked?.id == i.id,
                              selectedColor: c.green,
                              onSelected:
                                  (selected) =>
                                      set(() => picked = selected ? i : null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed:
                                () => set(() => qty = qty > 1 ? qty - 1 : 1),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                            ),
                          ),
                          Text(
                            '$qty',
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: () => set(() => qty++),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.green,
                            foregroundColor: c.onGreen,
                          ),
                          onPressed:
                              picked == null
                                  ? null
                                  : () => Navigator.pop(ctx, true),
                          child: Text(
                            picked == null
                                ? 'Pick an item'
                                : 'Add · ${fmtMoney(picked!.price * qty)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
    if (ok != true || picked == null) return;
    try {
      await screen.widget.session.api.post(
        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/items',
        {'menuItemId': picked!.id, 'qty': qty},
      );
      await screen.widget.club.refresh();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _addPlayer(BuildContext context, ClubSession s) async {
    Member? member;
    final guest = TextEditingController();
    String team = s.matchMode == '2v2' ? 'A' : '';
    bool saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              final c = ctx.colors;
              final used = {
                for (final p in s.players)
                  if (p.memberId != null) p.memberId!,
              };
              final members =
                  screen.widget.club.members
                      .where((m) => m.active && !used.contains(m.id))
                      .toList();
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add player — ${s.tableName}',
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w800,
                            fontSize: Dimens.font14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const FieldLabel('Member (optional)'),
                        InkWell(
                          onTap:
                              saving
                                  ? null
                                  : () async {
                                    final id = await _chooseMember(
                                      ctx,
                                      members,
                                    );
                                    if (id == null) return;
                                    set(
                                      () =>
                                          member =
                                              id.isEmpty
                                                  ? null
                                                  : members.firstWhere(
                                                    (m) => m.id == id,
                                                  ),
                                    );
                                  },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              member?.name ?? 'Choose existing member',
                              style: TextStyle(
                                color: member == null ? c.textMuted : c.text,
                                fontSize: Dimens.font12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: guest,
                          enabled: !saving && member == null,
                          decoration: const InputDecoration(
                            hintText: 'Or enter guest name',
                          ),
                        ),
                        if (s.matchMode == '2v2') ...[
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'A', label: Text('Team A')),
                              ButtonSegment(value: 'B', label: Text('Team B')),
                            ],
                            selected: {team},
                            onSelectionChanged:
                                saving
                                    ? null
                                    : (v) => set(() => team = v.first),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                saving
                                    ? null
                                    : () async {
                                      final label =
                                          member?.name ?? guest.text.trim();
                                      if (label.isEmpty) {
                                        toast(
                                          ctx,
                                          'Choose a member or enter a guest name',
                                          error: true,
                                        );
                                        return;
                                      }
                                      set(() => saving = true);
                                      try {
                                        await screen.widget.session.api.post(
                                          '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/players',
                                          {
                                            'label': label,
                                            'type':
                                                member == null
                                                    ? 'guest'
                                                    : 'member',
                                            if (member != null)
                                              'memberId': member!.id,
                                            if (s.matchMode == '2v2')
                                              'team': team,
                                          },
                                        );
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx, true);
                                        }
                                      } on ApiException catch (e) {
                                        if (ctx.mounted) {
                                          toast(ctx, e.message, error: true);
                                          set(() => saving = false);
                                        }
                                      }
                                    },
                            child:
                                saving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text('Add player'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    if (saved == true) await screen.widget.club.refresh();
  }

  Future<void> _editAttachedItems(BuildContext context, ClubSession s) async {
    final quantities = <String, int>{
      for (final item in s.items)
        '${item['menuItemId'] ?? item['itemId']}':
            (item['qty'] as num? ?? 0).toInt(),
    };
    bool saving = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              final c = ctx.colors;
              final menu =
                  screen.widget.club.menuItems.where((i) => i.active).toList();
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit table items',
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w800,
                          fontSize: Dimens.font14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity 0 se item remove hoga; stock aur final amount automatically update honge.',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in menu)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: Dimens.font12,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  saving || (quantities[item.id] ?? 0) == 0
                                      ? null
                                      : () => set(
                                        () =>
                                            quantities[item.id] =
                                                (quantities[item.id] ?? 0) - 1,
                                      ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            SizedBox(
                              width: 26,
                              child: Text(
                                '${quantities[item.id] ?? 0}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: c.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  saving ||
                                          (quantities[item.id] ?? 0) >=
                                              item.stockQty +
                                                  (s.items.firstWhereOrNull(
                                                                (x) =>
                                                                    '${x['menuItemId'] ?? x['itemId']}' ==
                                                                    item.id,
                                                              )?['qty']
                                                              as num? ??
                                                          0)
                                                      .toInt()
                                      ? null
                                      : () => set(
                                        () =>
                                            quantities[item.id] =
                                                (quantities[item.id] ?? 0) + 1,
                                      ),
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: c.green,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              saving
                                  ? null
                                  : () async {
                                    set(() => saving = true);
                                    try {
                                      await screen.widget.session.api.put(
                                        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/items',
                                        {
                                          'items': [
                                            for (final e in quantities.entries)
                                              {
                                                'menuItemId': e.key,
                                                'qty': e.value,
                                              },
                                          ],
                                        },
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx, true);
                                    } on ApiException catch (e) {
                                      if (ctx.mounted) {
                                        toast(ctx, e.message, error: true);
                                        set(() => saving = false);
                                      }
                                    }
                                  },
                          child:
                              saving
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text('Save items'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
    if (saved == true) await screen.widget.club.refresh();
  }

  Future<void> _addAdvance(BuildContext context, ClubSession s) async {
    final amount = TextEditingController();
    String mode = 'cash';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              final c = ctx.colors;
              return Padding(
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
                          'Collect advance',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autofocus: true,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹ ',
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'cash', label: Text('Cash')),
                              ButtonSegment(value: 'upi', label: Text('UPI')),
                              ButtonSegment(value: 'card', label: Text('Card')),
                            ],
                            selected: {mode},
                            onSelectionChanged:
                                (v) => set(() => mode = v.first),
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
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Save ${fmtMoney(double.tryParse(amount.text.trim()) ?? 0)}',
                            ),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || value <= 0) return;
    try {
      await screen.widget.session.api.post(
        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/advance',
        {'amount': value, 'mode': mode},
      );
      await screen.widget.club.refresh();
      if (context.mounted) {
        toast(context, 'Advance ${fmtMoney(value)} recorded');
      }
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleGlove(
    BuildContext context,
    ClubSession s,
    dynamic g,
  ) async {
    try {
      await screen.widget.session.api.post(
        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/gloves/return',
        {'playerId': g['playerId'], 'returned': g['returned'] != true},
      );
      await screen.widget.club.refresh();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _editNote(BuildContext context, ClubSession s) async {
    final note = TextEditingController(text: s.notes);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.colors;
        return Padding(
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
                    'Table note — ${s.tableName}',
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    autofocus: true,
                    style: AppText.field.copyWith(color: c.text),
                    decoration: const InputDecoration(
                      hintText: 'e.g. regulars · cue 4 needs a new tip',
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
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save note'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await screen.widget.session.api.patch(
        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}',
        {'notes': note.text.trim()},
      );
      await screen.widget.club.refresh();
      if (context.mounted) toast(context, 'Note saved');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _moveTable(BuildContext context, ClubSession s) async {
    final c = context.colors;
    final busyIds = {for (final x in screen.widget.club.sessions) x.tableId};
    final free =
        screen.widget.club.tables
            .where(
              (t) => t.active && !busyIds.contains(t.id) && t.id != s.tableId,
            )
            .toList();
    if (free.isEmpty) {
      toast(context, 'No other table is free right now', error: true);
      return;
    }
    String target = free.first.id;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move ${s.tableName} →',
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w800,
                          fontSize: Dimens.font14,
                        ),
                      ),
                      Text(
                        'Rate re-resolves on the new table (peak included).',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in free)
                            ChoiceChip(
                              showCheckmark: false,
                              label: Text(
                                '${t.name} · ${fmtMoney(t.hourlyRate)}/hr'
                                '${t.hourlyRate != s.hourlyRate ? '' : ''}',
                                style: TextStyle(
                                  fontSize: Dimens.font11,
                                  color:
                                      target == t.id
                                          ? Colors.black87
                                          : c.textSecondary,
                                ),
                              ),
                              selected: target == t.id,
                              selectedColor: c.green,
                              onSelected: (_) => set(() => target = t.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.green,
                            foregroundColor: c.onGreen,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Move table'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
    if (ok != true) return;
    try {
      await screen.widget.session.api.post(
        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}/move',
        {'tableId': target},
      );
      await screen.widget.club.refresh();
      if (context.mounted) {
        toast(context, 'Table moved — new rate applied from now');
      }
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _cancel(BuildContext context, ClubSession s) async {
    final sure = await confirmSheet(
      context,
      title: 'Cancel session?',
      message: 'The timer is deleted; any attached items return to stock.',
      confirmLabel: 'Cancel session',
      destructive: true,
    );
    if (!sure) return;
    try {
      final res = await screen.widget.session.api.delete(
        '/clubs/${screen.widget.club.clubId}/sessions/${s.id}',
      );
      await screen.widget.club.refresh();
      if (context.mounted) {
        toast(context, res['message'] ?? 'Session cancelled');
      }
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }
}

/// Compact history context on every table card. It is deliberately read-only:
/// opening Frames remains the place for settlement and winner corrections.
class _PreviousFrame extends StatelessWidget {
  final Map<String, dynamic> frame;
  const _PreviousFrame({required this.frame});

  String get _time => '${frame['createdAt'] ?? frame['endedAt'] ?? ''}';

  double get _amount {
    final raw = frame['frameAmount'] ?? frame['amount'] ?? 0;
    return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
  }

  /// The previous-frame preview is a billing reminder, so show the payer(s)
  /// (the loser(s)), not the winner(s).
  String get _loserName {
    String label(dynamic player) {
      if (player is Map) {
        return '${player['label'] ?? player['name'] ?? player['playerName'] ?? ''}'
            .trim();
      }
      return '$player'.trim();
    }

    final players = frame['players'];
    if (players is List) {
      final losers =
          players
              .where((player) => player is Map && player['isWinner'] != true)
              .map(label)
              .where((name) => name.isNotEmpty)
              .toList();
      if (losers.isNotEmpty) return losers.join(', ');
    }
    return 'Loser not recorded';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: c.bgMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: c.textMuted, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIOUS GAME · ${fmtDT(_time)}',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: Dimens.font9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loserName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: Dimens.font11_5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtMoney(_amount),
            style: TextStyle(
              color: c.green,
              fontSize: Dimens.font13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// start sheet
class StartSessionSheet extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  final ClubTable table;
  const StartSessionSheet({
    super.key,
    required this.session,
    required this.club,
    required this.table,
  });

  @override
  State<StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<StartSessionSheet> {
  final List<_Seat> _seats = [_Seat(), _Seat()];
  String _mode = 'solo';
  final _advance = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _advance.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final players = <Map<String, dynamic>>[];
    final gloveSeats = <int>[];
    for (var i = 0; i < _seats.length; i++) {
      final seat = _seats[i];
      if (seat.member != null) {
        players.add({
          'label': seat.member!.name,
          'type': 'member',
          'memberId': seat.member!.id,
          if (_mode == '2v2') 'team': seat.team,
        });
      } else {
        final guestLabel = seat.guestName.trim();
        final autoLabel = guestLabel.isEmpty ? 'Guest ${i + 1}' : guestLabel;
        seat.guestName = autoLabel;
        players.add({
          'label': autoLabel,
          'type': 'guest',
          if (_mode == '2v2') 'team': seat.team,
        });
      }
      if (seat.glove) gloveSeats.add(players.length - 1);
    }
    if (players.isEmpty) {
      toast(context, 'Add at least one player', error: true);
      return;
    }
    // ★ v3.26 — server 400 se PEHLE yahin pakdo (owner note: "session
    // start karte waqt kabhi kabhi error"). Teen classic cases:
    final memberIds = [
      for (final p in players)
        if (p['type'] == 'member') '${p['memberId']}',
    ];
    if (memberIds.length != memberIds.toSet().length) {
      toast(
        context,
        'The same member cannot occupy two seats — make one seat a guest',
        error: true,
      );
      return;
    }
    if (_mode == '2v2') {
      final inA = players.where((p) => p['team'] == 'A').length;
      final inB = players.where((p) => p['team'] == 'B').length;
      if (inA == 0 || inB == 0) {
        toast(
          context,
          'For 2v2, Team A and Team B must each have at least 1 player',
          error: true,
        );
        return;
      }
    }
    final confirmed = await confirmSheet(
      context,
      title: 'Start timer?',
      message:
          'The timer will start on ${widget.table.name} for ${players.map((p) => p['label']).join(', ')}. '
          'Rate: ${fmtMoney(widget.table.hourlyRate)}/hr.',
      confirmLabel: 'Start timer',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.api.post('/clubs/${widget.club.clubId}/sessions', {
        'tableId': widget.table.id,
        'players': players,
        'matchMode': _mode,
        'advancePaid': double.tryParse(_advance.text.trim()) ?? 0,
        'notes': _notes.text.trim(),
        if (gloveSeats.isNotEmpty) 'gloveSeatIndexes': gloveSeats,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final members = widget.club.members.where((m) => m.active).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start — ${widget.table.name}',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${fmtMoney(widget.table.hourlyRate)}/hr'
                '${widget.table.minCharge > 0 ? ' · min ${fmtMoney(widget.table.minCharge)}' : ''}',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'solo', label: Text('Solo')),
                    ButtonSegment(value: '2v2', label: Text('2 v 2')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) => setState(() => _mode = v.first),
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < _seats.length; i++)
                _seatRow(context, i, members),
              if (_seats.length < 8)
                TextButton.icon(
                  onPressed: () => setState(() => _seats.add(_Seat())),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text(
                    'Add seat',
                    style: TextStyle(fontSize: Dimens.font12),
                  ),
                ),
              const FieldLabel('Advance ₹ (optional)'),
              TextField(
                controller: _advance,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: AppText.field.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText:
                      widget.club.session.activeClub?.defaultAdvance != null &&
                              widget.club.session.activeClub!.defaultAdvance > 0
                          ? 'default ${fmtNum(widget.club.session.activeClub!.defaultAdvance)}'
                          : '0',
                ),
              ),
              if (widget.table.glovePrice > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'gloves ${fmtMoney(widget.table.glovePrice)}/pair — toggle per seat above',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font10,
                    ),
                  ),
                ),
              const FieldLabel('Note (optional)'),
              TextField(
                controller: _notes,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: 'e.g. league night · cue 4',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: Dimens.ctaH, // ★ hero CTA — Dimens.ctaH (v3.24)
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: c.onGreen,
                  ),
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(_busy ? 'Starting…' : 'Start timer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseSeatMember(_Seat seat, List<Member> options) async {
    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered =
                options
                    .where(
                      (m) => m.name.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: const Text('Choose member'),
              content: SizedBox(
                width: 600,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged:
                          (value) => setDialogState(() => query = value.trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search member',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Walk-in customer'),
                            onTap: () => Navigator.pop(dialogContext, ''),
                          ),
                          for (final member in filtered)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                member.hasDue
                                    ? '${member.name}  (Due ${fmtMoney(member.dueAmount)})'
                                    : member.name,
                              ),
                              onTap:
                                  () => Navigator.pop(dialogContext, member.id),
                            ),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 24),
                              child: Center(child: Text('No members found')),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || selectedId == null) return;
    setState(() {
      seat.member =
          selectedId.isEmpty
              ? null
              : options.firstWhere((member) => member.id == selectedId);
    });
  }

  Widget _seatRow(BuildContext context, int i, List<Member> members) {
    final c = context.colors;
    final seat = _seats[i];
    // ★ v3.26 — doosri seat pe already-picked member is dropdown me hi na
    // dikhe (duplicate-member 400 ka sabse clean ilaaj).
    final takenElsewhere = <String>{
      for (var j = 0; j < _seats.length; j++)
        if (j != i && _seats[j].member != null) _seats[j].member!.id,
    };
    final options =
        members.where((m) => !takenElsewhere.contains(m.id)).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${i + 1}',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: Dimens.font10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _chooseSeatMember(seat, options),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        seat.member?.name ?? 'Member (or type guest below)',
                        style: TextStyle(
                          color: seat.member == null ? c.textMuted : c.text,
                          fontSize: Dimens.font12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (seat.member == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextField(
                  onChanged: (v) => seat.guestName = v,
                  style: TextStyle(color: c.text, fontSize: Dimens.font12),
                  decoration: const InputDecoration(hintText: 'Guest name'),
                ),
              ),
            if (_mode == '2v2')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('Team A')),
                      ButtonSegment(value: 'B', label: Text('Team B')),
                    ],
                    selected: {seat.team},
                    onSelectionChanged:
                        (v) => setState(() => seat.team = v.first),
                  ),
                ),
              ),
            if (widget.table.glovePrice > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => seat.glove = !seat.glove),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        seat.glove
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 15,
                        color: seat.glove ? c.gold : c.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.back_hand_outlined,
                        size: 12,
                        color: seat.glove ? c.gold : c.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Gloves out · ${fmtMoney(widget.table.glovePrice)}',
                        style: TextStyle(
                          color: seat.glove ? c.gold : c.textMuted,
                          fontSize: Dimens.font11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Seat {
  Member? member;
  String guestName = '';
  String team = 'A';
  bool glove = false;
}

// ---------------------------------------------------------------------------
// final bill sheet
class FinalBillSheet extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  final ClubSession tableSession;
  static String? lastMessage;

  const FinalBillSheet({
    super.key,
    required this.session,
    required this.club,
    required this.tableSession,
  });

  @override
  State<FinalBillSheet> createState() => _FinalBillSheetState();
}

class _FinalBillSheetState extends State<FinalBillSheet> {
  final Set<String> _losers = {};
  String? _winningTeam;
  bool _split = true;
  final _discount = TextEditingController();
  final _cash = TextEditingController();
  String _mode = 'due';
  final Set<String> _usePass = {};
  final Set<String> _gloveFlips = {}; // playerIds we toggled from this sheet
  bool _busy = false;

  @override
  void dispose() {
    _discount.dispose();
    _cash.dispose();
    super.dispose();
  }

  /// ★ v3.21 — backend ab bacha hua cash losers ke PURANE dues se harvest karta
  /// hai (pehle wo paisa bas "refund manually" note ban jata tha). Sheet pe
  /// payer(s) ka old due dikhao taaki counter banda ek hi payment me frame +
  /// due dono collect kar sake. Server hi final calculator hai.
  double _losersOldDue() {
    final s = widget.tableSession;
    Iterable<SessionPlayer> losers;
    if (s.matchMode == '2v2') {
      final t = _winningTeam;
      if (t == null) return 0;
      losers = s.players.where((p) => p.team != null && p.team != t);
    } else {
      if (_losers.isEmpty) return 0;
      losers = s.players.where((p) => _losers.contains(p.pid));
    }
    var sum = 0.0;
    for (final p in losers) {
      if (p.memberId == null) continue;
      final m =
          widget.club.members.where((x) => x.id == p.memberId).firstOrNull;
      if (m != null && m.dueAmount > 0) sum += m.dueAmount;
    }
    return sum;
  }

  String _fmtHint(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double _requiredGuestCash() {
    final s = widget.tableSession;
    final est = s.estimate(widget.club.currentServerNow);
    final oldDue = _losersOldDue();
    final total = est + oldDue;
    List<SessionPlayer> losers;
    if (s.matchMode == '2v2') {
      final t = _winningTeam;
      if (t == null) return 0;
      losers = s.players.where((p) => p.team != null && p.team != t).toList();
    } else if (_split || _losers.isEmpty) {
      losers = s.players.toList();
    } else {
      losers = s.players.where((p) => _losers.contains(p.pid)).toList();
    }
    if (losers.isEmpty) return 0;
    final guestLosers = losers.where((p) => p.memberId == null).toList();
    if (guestLosers.isEmpty) return 0;
    final share = total / losers.length;
    return guestLosers.length * share;
  }

  Future<void> _editPlayerLabel(SessionPlayer p) async {
    final c = context.colors;
    final controller = TextEditingController(text: p.label);
    final res = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 14,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 14,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: c.green),
                      const SizedBox(width: 8),
                      Text(
                        'Player name',
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Enter a name'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              () => Navigator.pop(ctx, controller.text.trim()),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
    if (res == null) return; // cancelled
    final newLabel = res.trim();
    if (newLabel.isEmpty || newLabel == p.label) return;
    setState(() => _busy = true);
    try {
      String? memberId = p.memberId;
      if (memberId == null) {
        final member =
            await widget.session.api.post(
                  '/clubs/${widget.club.clubId}/members',
                  {'name': newLabel},
                )
                as Map<String, dynamic>;
        memberId = member['id'] as String?;
        if (memberId == null || memberId.isEmpty) {
          throw const ApiException(-1, 'Member create failed');
        }
      }
      await widget.session.api.patch(
        '/clubs/${widget.club.clubId}/sessions/${widget.tableSession.id}',
        {
          'players': [
            {
              'pid': p.pid,
              'label': newLabel,
              'type': 'member',
              'memberId': memberId,
            },
          ],
        },
      );
      await widget.club.refresh();
      // update local copy for immediate UI feedback
      setState(() {
        final idx = widget.tableSession.players.indexWhere(
          (x) => x.pid == p.pid,
        );
        if (idx != -1) {
          final old = widget.tableSession.players[idx];
          widget.tableSession.players[idx] = SessionPlayer(
            pid: old.pid,
            label: newLabel,
            type: 'member',
            memberId: memberId,
            team: old.team,
            isWinner: old.isWinner,
          );
        }
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final s = widget.tableSession;
    final est = s.estimate(widget.club.currentServerNow);
    final oldDue = _losersOldDue();
    final total = est + oldDue;
    final payerNames =
        s.matchMode == '2v2'
            ? (_winningTeam == null
                ? 'Team not selected'
                : 'Team ${_winningTeam!}')
            : (_split
                ? 'Split across all players'
                : 'Payers: ${s.players.where((p) => _losers.contains(p.pid)).map((p) => p.label).join(', ')}');

    final confirmed = await confirmSheet(
      context,
      title: 'Confirm final bill?',
      message:
          '$payerNames\n\n${s.players.map((p) => p.label).join(', ')}\n\nTotal: ${fmtMoney(total)}${_mode == 'due' ? ' · due' : ' · ${_mode.toUpperCase()}'}',
      confirmLabel: 'Confirm bill',
    );
    if (!confirmed) return;

    if (s.matchMode == '2v2' && _winningTeam == null) {
      // ignore: use_build_context_synchronously
      toast(context, 'Pick the winning team', error: true);
      return;
    }
    final requiredGuestCash = _requiredGuestCash();
    if (requiredGuestCash > 0) {
      final cashNow = double.tryParse(_cash.text.trim()) ?? 0;
      if (_mode == 'due' || cashNow < requiredGuestCash) {
        final fixed = requiredGuestCash;
        setState(() {
          _mode = 'cash';
          _cash.text = fixed
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'\.?0+$'), '');
        });
        toast(
          // ignore: use_build_context_synchronously
          context,
          'Guest players must pay cash now — set cash collected to ${fmtMoney(fixed)}',
          error: true,
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final res = await widget.session.api
          .post('/clubs/${widget.club.clubId}/sessions/${s.id}/confirm', {
            if (s.matchMode == '2v2') 'winningTeam': _winningTeam,
            if (s.matchMode != '2v2')
              'winners':
                  s.players
                      .where((p) => !_losers.contains(p.pid))
                      .map((p) => p.pid)
                      .toList(),
            if (s.matchMode != '2v2') 'split': _split,
            'discount': double.tryParse(_discount.text.trim()) ?? 0,
            'cashPaid': double.tryParse(_cash.text.trim()) ?? 0,
            'mode': _mode == 'due' ? 'cash' : _mode,
            'paymentMode': _mode,
            'usePass': _usePass.toList(),
          });
      FinalBillSheet.lastMessage = res['message'] as String?;
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.tableSession;
    final est = s.estimate(widget.club.currentServerNow);
    final oldDue = _losersOldDue(); // ★ payer(s) ke purane dues (v3.21 harvest)
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Final bill — ${s.tableName}',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '≈ ${fmtMoney(est)} estimate${oldDue > 0 ? ' + ${fmtMoney(oldDue)} old dues' : ''}'
                ' · server computes the final total',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              ),
              const SizedBox(height: 8),
              if (s.matchMode == '2v2') ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('Team A won')),
                      ButtonSegment(value: 'B', label: Text('Team B won')),
                    ],
                    selected: _winningTeam == null ? const {} : {_winningTeam!},
                    onSelectionChanged:
                        (v) => setState(() => _winningTeam = v.first),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _split ? 'Split mode: all players pay' : 'Loser (pays)',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => setState(() {
                            _losers.clear();
                            _split = true;
                          }),
                      child: const Text('Split'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in s.players)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              !_split && _losers.contains(p.pid)
                                  ? c.green
                                  : c.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                !_split && _losers.contains(p.pid)
                                    ? c.green
                                    : c.bgElevated,
                            width: !_split && _losers.contains(p.pid) ? 0 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap:
                                  () => setState(() {
                                    _split = false;
                                    if (_losers.contains(p.pid)) {
                                      _losers.remove(p.pid);
                                    } else {
                                      _losers.add(p.pid);
                                    }
                                  }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Text(
                                  p.label,
                                  style: TextStyle(
                                    fontSize: Dimens.font12,
                                    color:
                                        !_split && _losers.contains(p.pid)
                                            ? c.onGreen
                                            : c.text,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _editPlayerLabel(p),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (_split)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Split mode: all players share the bill equally',
                      style: TextStyle(
                        color: c.green,
                        fontSize: Dimens.font10_5,
                      ),
                    ),
                  )
                else if (_losers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Payers: ${s.players.where((p) => _losers.contains(p.pid)).map((p) => p.label).join(', ')}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: Dimens.font10_5,
                      ),
                    ),
                  ),
              ],
              // ★ v3.21 — old-due harvest strip: extra cash payer ke purane
              // dues se kat-ta hai (Day Close exact, due list apne-aap chhoti)
              if (oldDue > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.blue.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.price_check_outlined, size: 14, color: c.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Payer(s) owe ${fmtMoney(oldDue)} in old dues — any cash above the '
                          'frame bill settles it automatically (server split: frame → dues).',
                          style: TextStyle(
                            color: c.blue,
                            fontSize: Dimens.font10_5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // frame-pass picks for losers with passes
              ..._passChips(context),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Discount ₹'),
                        TextField(
                          controller: _discount,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldLabel(
                          oldDue > 0
                              ? 'Cash now ₹ (frame + old dues)'
                              : 'Cash collected now ₹',
                        ),
                        TextField(
                          controller: _cash,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                          decoration: InputDecoration(
                            hintText: _fmtHint(est + oldDue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cash', label: Text('Cash')),
                    ButtonSegment(value: 'upi', label: Text('UPI')),
                    ButtonSegment(value: 'due', label: Text('Due')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) => setState(() => _mode = v.first),
                ),
              ),
              if (s.advancePaid > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Advance ${fmtMoney(s.advancePaid)} already collected',
                    style: TextStyle(color: c.green, fontSize: Dimens.font11),
                  ),
                ),
              ..._gloveRows(context),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: c.onGreen,
                  ),
                  onPressed: _busy ? null : _confirm,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(
                    _busy ? 'Billing…' : 'Confirm bill (server computes)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _gloveReturnedNow(dynamic g) {
    final base = g['returned'] == true;
    return _gloveFlips.contains(g['playerId']) ? !base : base;
  }

  List<Widget> _gloveRows(BuildContext context) {
    final c = context.colors;
    final s = widget.tableSession;
    if (s.gloves.isEmpty) return [];
    final out = s.gloves.where((g) => !_gloveReturnedNow(g)).toList();
    final due = out.fold<double>(
      0,
      (a, g) => a + ((g['price'] ?? 0) as num).toDouble(),
    );
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(
              Icons.back_hand_outlined,
              size: 12,
              color: out.isEmpty ? c.green : c.gold,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                out.isEmpty
                    ? 'All gloves returned — no charge'
                    : 'Gloves not returned (${out.length}) +${fmtMoney(due)} · tap to mark returned',
                style: TextStyle(
                  color: out.isEmpty ? c.green : c.gold,
                  fontSize: Dimens.font11,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final g in s.gloves)
            FilterChip(
              showCheckmark: false,
              label: Text(
                '${g['label'] ?? 'Glove'} · ${_gloveReturnedNow(g) ? 'returned' : fmtMoney(g['price'])}',
                style: const TextStyle(fontSize: Dimens.font11),
              ),
              selected: _gloveReturnedNow(g),
              selectedColor: c.green,
              onSelected: (_) => _flipGlove(g),
            ),
        ],
      ),
    ];
  }

  Future<void> _flipGlove(dynamic g) async {
    final nowReturned = !_gloveReturnedNow(g);
    final pid = '${g['playerId']}';
    setState(() {
      if (_gloveFlips.contains(pid)) {
        _gloveFlips.remove(pid);
      } else {
        _gloveFlips.add(pid);
      }
    });
    try {
      await widget.session.api.post(
        '/clubs/${widget.club.clubId}/sessions/${widget.tableSession.id}/gloves/return',
        {'playerId': pid, 'returned': nowReturned},
      );
      // shell refreshes when the sheet closes; keep local state meanwhile
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if (_gloveFlips.contains(pid)) {
            _gloveFlips.remove(pid);
          } else {
            _gloveFlips.add(pid);
          }
        });
        toast(context, e.message, error: true);
      }
    }
  }

  List<Widget> _passChips(BuildContext context) {
    final c = context.colors;
    final passMembers = <Member>[];
    for (final p in widget.tableSession.players) {
      if (p.memberId != null) {
        final m =
            widget.club.members.where((x) => x.id == p.memberId).firstOrNull;
        if (m != null && m.passFramesLeft > 0) passMembers.add(m);
      }
    }
    if (passMembers.isEmpty) return [];
    return [
      Text(
        'Frame pass',
        style: TextStyle(color: c.blue, fontSize: Dimens.font10),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in passMembers)
            FilterChip(
              showCheckmark: false,
              label: Text(
                '${m.name} · ${m.passFramesLeft} left',
                style: const TextStyle(fontSize: Dimens.font11),
              ),
              selected: _usePass.contains(m.id),
              selectedColor: c.blue,
              onSelected:
                  (v) => setState(() {
                    if (v) {
                      _usePass.add(m.id);
                    } else {
                      _usePass.remove(m.id);
                    }
                  }),
            ),
        ],
      ),
      const SizedBox(height: 6),
    ];
  }
}
