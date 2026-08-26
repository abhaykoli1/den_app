import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dimensions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../insights.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Due Desk — sabhi pending dues ek jagah. Collect / WhatsApp / Mail actions,
/// sab pop-ups bottom-sheet style (chat-box jaisa) — dialogs nahi.
class DueDeskScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const DueDeskScreen({super.key, required this.session, required this.club});

  @override
  State<DueDeskScreen> createState() => _DueDeskScreenState();
}

class _DueDeskScreenState extends State<DueDeskScreen> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    widget.club.addListener(_onData);
  }

  void _onData() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    widget.club.removeListener(_onData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _q.toLowerCase();
    final dues =
        widget.club.members
            .where(
              (m) =>
                  m.dueAmount > 0 &&
                  (m.name.toLowerCase().contains(q) || m.phone.contains(q)),
            )
            .toList()
          ..sort((a, b) => b.dueAmount.compareTo(a.dueAmount));
    final total = dues.fold<double>(0, (s, m) => s + m.dueAmount);
    final walletHeld = widget.club.members.fold<double>(
      0,
      (s, m) => s + m.walletBalance,
    );
    final limit = widget.session.activeClub?.dueLimit ?? 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Pending due',
                value: fmtMoney(total),
                tone: c.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Wallet held',
                value: fmtMoney(walletHeld),
                tone: c.gold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Due limit',
                value: fmtMoney(limit),
                tone: c.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InsightsCard(club: widget.club),
        const SizedBox(height: 8),
        // ★ v3.26 — compact search bar (Dimens.searchH/searchPad/searchFont)
        SizedBox(
          height: Dimens.searchH,
          child: TextField(
            style: TextStyle(color: c.text, fontSize: Dimens.searchFont),
            decoration: const InputDecoration(
              isDense: true,
              // contentPadding: Dimens.searchPad,
              prefixIconConstraints: BoxConstraints(minWidth: 32),
              hintText: 'Search name or phone…',
              prefixIcon: Icon(Icons.search, size: 16),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        const SizedBox(height: 8),
        if (dues.isEmpty)
          const EmptyState(
            title: 'No pending dues',
            hint: 'Everyone is settled. 🎉',
            icon: Icons.verified_outlined,
          ),
        for (final m in dues) _dueCard(context, m),
      ],
    );
  }

  // ================================================================ card
  Widget _dueCard(BuildContext context, Member m) {
    final c = context.colors;
    final limit = widget.session.activeClub?.dueLimit ?? 0;
    final over = limit > 0 && m.dueAmount >= limit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: over ? c.red : c.red.withValues(alpha: 0.7),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: c.red.withValues(alpha: 0.14),
                    child: Text(
                      m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                      style: TextStyle(
                        color: c.red,
                        fontSize: Dimens.font13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: Dimens.font14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (over) ToneBadge('over limit', c.red),
                          ],
                        ),
                        Text(
                          [
                            if (m.phone.isNotEmpty) m.phone,
                            if (m.email.isNotEmpty) m.email,
                            if (m.phone.isEmpty && m.email.isEmpty)
                              'no contact',
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font10_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'DUE',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font8_5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        fmtMoney(m.dueAmount),
                        style: TextStyle(
                          color: c.red,
                          fontSize: Dimens.font14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  _chip(c, 'WALLET', fmtMoney(m.walletBalance), c.gold),
                  if (m.dueAmount > m.walletBalance && m.walletBalance > 0) ...[
                    const SizedBox(width: 6),
                    _chip(
                      c,
                      'NET',
                      fmtMoney(m.dueAmount - m.walletBalance),
                      c.blue,
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous Game',
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => MemberFramesScreen(
                                  member: m,
                                  frames: widget.club.frames,
                                ),
                          ),
                        ),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.sports_esports_outlined,
                      size: 20,
                      color: c.green,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        m.phone.isEmpty
                            ? 'Add a phone number first'
                            : 'WhatsApp reminder',
                    onPressed: m.phone.isEmpty ? null : () => _remind(m),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.chat_outlined,
                      size: 20,
                      color:
                          m.phone.isEmpty
                              ? c.textMuted.withValues(alpha: 0.35)
                              : c.green,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        m.email.isEmpty
                            ? 'Add an email first'
                            : 'Mail account summary',
                    onPressed: m.email.isEmpty ? null : () => _mail(m),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.mail_outline,
                      size: 20,
                      color:
                          m.email.isEmpty
                              ? c.textMuted.withValues(alpha: 0.35)
                              : c.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: c.green,
                      foregroundColor: c.onGreen,
                    ),
                    onPressed: () => _collectSheet(m),
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    label: const Text('Collect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(AppColors c, String label, String value, Color tone) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ',
              style: TextStyle(
                color: c.textMuted,
                fontSize: Dimens.font9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: tone,
                fontSize: Dimens.font10_5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  // ================================================================ whatsapp / mail
  Future<void> _remind(Member m) async {
    final digits = m.phone.replaceAll(RegExp('[^0-9]'), '');
    final number = digits.length == 10 ? '91$digits' : digits;
    final clubName = widget.session.activeClub?.name ?? "Rowdy's Den";
    final msg = Uri.encodeComponent(
      'Hello ${m.name}, a friendly reminder from $clubName — your due of '
      '${fmtMoney(m.dueAmount)} is still pending. Please clear it at the counter '
      'whenever convenient. Thank you! 🎱',
    );
    final uri = Uri.parse('https://wa.me/$number?text=$msg');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        toast(context, 'Could not open WhatsApp on this device', error: true);
      }
    }
  }

  Future<void> _mail(Member m) async {
    if (m.email.isEmpty) {
      toast(
        context,
        'Add an email address in the player card first (Players → Edit)',
        error: true,
      );
      return;
    }
    try {
      final res = await widget.session.api.post(
        '/clubs/${widget.club.clubId}/members/${m.id}/notify',
        {'channel': 'email'},
      );
      if (mounted) toast(context, res['message'] ?? 'Mail sent');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ================================================================ collect sheet
  Future<void> _collectSheet(Member m) async {
    final amount = TextEditingController(text: m.dueAmount.toStringAsFixed(2));
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
                          'Collect — ${m.name}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Due ${fmtMoney(m.dueAmount)} · partial or full — old due settles first',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          onChanged: (_) => set(() {}),
                          autofocus: true,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹ ',
                            hintText: '0',
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
                        actionPair(
                          ctx,
                          primaryLabel:
                              'Collect ${fmtMoney(double.tryParse(amount.text.trim()) ?? 0)}',
                          onPrimary: () {
                            final v = double.tryParse(amount.text.trim()) ?? 0;
                            if (v <= 0) {
                              toast(ctx, 'Enter an amount', error: true);
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
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
    if (!mounted) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Confirm due collection?',
      message:
          'Collect ${fmtMoney(value)} via ${mode.toUpperCase()} from ${m.name}. This payment will be applied to the due.',
      confirmLabel: 'Collect ${fmtMoney(value)}',
    );
    if (!confirmed || !mounted) return;
    try {
      final res = await widget.session.api.post(
        '/clubs/${widget.club.clubId}/members/${m.id}/payments',
        {'amount': value, 'mode': mode},
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Collected');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }
}

class MemberFramesScreen extends StatelessWidget {
  final Member member;
  final List<dynamic> frames;

  const MemberFramesScreen({
    super.key,
    required this.member,
    required this.frames,
  });

  List<dynamic> get _memberFrames {
    final result =
        frames.where((frame) {
          final players = (frame['players'] as List?) ?? const [];
          return players.any(
            (player) =>
                '${player['memberId'] ?? player['pid'] ?? ''}' == member.id,
          );
        }).toList();
    result.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = _memberFrames;
    final won =
        history.where((frame) {
          final players = (frame['players'] as List?) ?? const [];
          return players.any(
            (player) =>
                '${player['memberId'] ?? player['pid'] ?? ''}' == member.id &&
                player['isWinner'] == true,
          );
        }).length;
    final billed = history.fold<double>(
      0,
      (total, frame) => total + ((frame['frameAmount'] ?? 0) as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${member.name} · Previous Games')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Played',
                  value: '${history.length}',
                  tone: c.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(label: 'Won', value: '$won', tone: c.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Lost',
                  value: '${history.length - won}',
                  tone: c.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Total',
                  value: fmtMoney(billed),
                  tone: c.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text(
          //   'Total frame money · ${fmtMoney(billed)}',
          //   style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
          // ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const EmptyState(
              title: 'No previous games',
              hint: 'This member has no billed frame history yet.',
              icon: Icons.sports_esports_outlined,
            ),
          for (var i = 0; i < history.length; i++)
            _frameCard(
              history[i],
              c,
              isFirst: i == 0,
              isLast: i == history.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _frameCard(
    dynamic frame,
    AppColors c, {
    required bool isFirst,
    required bool isLast,
  }) {
    final players = (frame['players'] as List?) ?? const [];
    final me = players.firstWhere(
      (player) => '${player['memberId'] ?? player['pid'] ?? ''}' == member.id,
      orElse: () => const <String, dynamic>{},
    );
    final didWin = me['isWinner'] == true;
    final opponents = players
        .where(
          (player) =>
              '${player['memberId'] ?? player['pid'] ?? ''}' != member.id,
        )
        .map((player) => '${player['label'] ?? player['name'] ?? 'Guest'}')
        .join(' vs ');
    final matchLabel =
        players.length == 3 ? '3 player' : '${frame['matchMode'] ?? 'solo'}';
    String titleCase(String value) => value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
    final displayTable = titleCase('${frame['tableName'] ?? 'Table'}');
    final displayMatch = titleCase(matchLabel);
    final started = fmtDT(frame['startedAt'] ?? frame['createdAt']);
    final ended =
        frame['endedAt'] == null ? 'ongoing' : fmtDT(frame['endedAt']);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(10) : Radius.zero,
          topRight: isFirst ? const Radius.circular(10) : Radius.zero,
          bottomLeft: isLast ? const Radius.circular(10) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(10) : Radius.zero,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: c.border),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                didWin ? Icons.emoji_events_outlined : Icons.close,
                color: didWin ? c.green : c.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '$displayTable · $displayMatch',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: didWin ? c.green : c.red,
                              fontSize: Dimens.font12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'With: ${opponents.isEmpty ? 'No opponent recorded' : opponents}',
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$started → $ended',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font10_5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          fmtMoney(frame['frameAmount'] ?? 0),
                          style: TextStyle(
                            color: didWin ? c.green : c.red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
