import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../exporter.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Frames — billed session history + winner correction (§15).
class FramesScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const FramesScreen({super.key, required this.session, required this.club});

  @override
  State<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends State<FramesScreen> {
  String _month = thisMonth();

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

  List<dynamic> get _frames {
    final list = List<dynamic>.from(widget.club.frames);
    list.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return list.where((f) => '${f['createdAt']}'.startsWith(_month)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final frames = _frames;
    final count = frames.length;
    final billed = frames.fold<double>(
      0,
      (a, f) => a + ((f['frameAmount'] ?? 0) as num).toDouble(),
    );
    final collected = frames.fold<double>(
      0,
      (a, f) => a + ((f['cashCollected'] ?? 0) as num).toDouble(),
    );
    final dueLeft = frames.fold<double>(0, (a, f) {
      final settlements = (f['settlements'] as List?) ?? const [];
      return a +
          settlements.fold<double>(
            0,
            (x, s) => x + (((s['duePart'] ?? 0) as num).toDouble()),
          );
    });

    return RefreshIndicator(
      onRefresh: widget.club.refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final m = await pickMonth(context, _month);
                    if (m != null) setState(() => _month = m);
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(label: 'Frames', value: '$count', tone: c.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Billed',
                  value: fmtMoney(billed),
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Collected',
                  value: fmtMoney(collected),
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Due left',
                  value: fmtMoney(dueLeft),
                  tone: c.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (frames.isEmpty)
            const EmptyState(
              title: 'No frames this month',
              hint:
                  'Confirmed table bills appear here with winner & settlement detail.',
              icon: Icons.grid_on,
            ),
          for (final f in frames)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FrameCard(f, screen: this),
            ),
          if (frames.isNotEmpty)
            Text(
              'Selected the wrong winner? Tap "Fix Winner" — the server will handle the complete reversal and re-billing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textMuted,
                fontSize: Dimens.font10,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> fixWinner(dynamic f) async {
    final players = (f['players'] as List?) ?? const [];
    final matchMode = '${f['matchMode'] ?? 'solo'}';
    final selected = <String>{
      for (final p in (f['winnersPids'] as List?) ?? const []) '$p',
    };
    String? team =
        (f['winningTeam'] as String?) ??
        (matchMode == '2v2'
            ? ((players.firstWhere(
                  (p) => p['isWinner'] == true,
                  orElse: () => const {},
                )['team'])
                as String?)
            : null);
    final note = TextEditingController();
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fix winner — ${f['tableName'] ?? ''}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Full reversal + re-billing — the server will correctly update wallets, dues, passes, and everything else.',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font10_5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (matchMode == '2v2')
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'A',
                                  label: Text('Team A won'),
                                ),
                                ButtonSegment(
                                  value: 'B',
                                  label: Text('Team B won'),
                                ),
                              ],
                              selected: team == null ? const {} : {team!},
                              onSelectionChanged:
                                  (v) => set(() => team = v.first),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in players)
                                ChoiceChip(
                                  showCheckmark: false,
                                  label: Text(
                                    '${p['label']}',
                                    style: const TextStyle(
                                      fontSize: Dimens.font11,
                                    ),
                                  ),
                                  selected: selected.contains('${p['pid']}'),
                                  selectedColor: c.green,
                                  onSelected:
                                      (v) => set(() {
                                        if (v) {
                                          selected.add('${p['pid']}');
                                        } else {
                                          selected.remove('${p['pid']}');
                                        }
                                      }),
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: note,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            hintText: 'Note (optional) — e.g. wrong tap',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.gold,
                              foregroundColor: c.onGold,
                            ),
                            onPressed: () {
                              if (matchMode == '2v2' && team == null) {
                                toast(
                                  ctx,
                                  'Pick the winning team',
                                  error: true,
                                );
                                return;
                              }
                              if (matchMode != '2v2' && selected.isEmpty) {
                                toast(
                                  ctx,
                                  'Pick at least one winner',
                                  error: true,
                                );
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                            icon: const Icon(Icons.gavel, size: 15),
                            label: const Text('Correct & re-bill'),
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
    if (ok != true) return;
    try {
      final body = <String, dynamic>{
        if (matchMode == '2v2') 'winningTeam': team,
        if (matchMode != '2v2') 'winners': selected.toList(),
        'note': note.text.trim(),
      };
      final res = await widget.session.api.patch(
        '/clubs/${widget.club.clubId}/frames/${f['id']}/winners',
        body,
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Winner corrected');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  /// 58mm thermal-style receipt of the billed frame (print/share).
  Future<void> shareFrameReceipt(dynamic f) async {
    try {
      await shareReceiptPdf(
        fileName:
            'rowdys-den-frame-${(f['id'] ?? 'bill').toString().toUpperCase()}.pdf',
        clubName: widget.session.activeClub?.name ?? "Rowdy's Den",
        lines: frameReceiptLines(f),
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not build receipt: $e', error: true);
    }
  }
}

class _FrameCard extends StatelessWidget {
  final dynamic f;
  final _FramesScreenState screen;
  const _FrameCard(this.f, {required this.screen});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final players = (f['players'] as List?) ?? const [];
    final corrected = f['correctedAt'] != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${f['tableName'] ?? 'Table'}',
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font13_5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 6),
                    ToneBadge('${f['matchMode'] ?? 'solo'}', c.blue),
                    if (f['peak'] == true) ...[
                      const SizedBox(width: 4),
                      ToneBadge('peak', c.gold),
                    ],
                    if (corrected) ...[
                      const SizedBox(width: 4),
                      ToneBadge('corrected', c.gold),
                    ],
                    if (f['status'] != null) ...[
                      const SizedBox(width: 4),
                      ToneBadge(
                        '${f['status']}',
                        f['status'] == 'paid'
                            ? c.green
                            : f['status'] == 'partial'
                            ? c.gold
                            : c.red,
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              '${fmtDT(f['startedAt'] ?? f['createdAt'])} → ${f['endedAt'] == null ? 'ongoing' : fmtDT(f['endedAt'])}',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10_5),
            ),
            Divider(color: c.border, height: 10),

            _money(c, 'Frame total', f['frameAmount'], bold: true),
            _money(c, 'Collected now', f['cashCollected'], tone: c.green),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final p in players)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          p['isWinner'] == true
                              ? c.green.withValues(alpha: 0.12)
                              : c.bgMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            p['isWinner'] == true
                                ? c.green.withValues(alpha: 0.5)
                                : c.border,
                      ),
                    ),
                    child: Text(
                      p['isWinner'] == true
                          ? '👑 ${p['label']}'
                          : '${p['label']}',
                      style: TextStyle(
                        color: p['isWinner'] == true ? c.green : c.text,
                        fontSize: Dimens.font11_5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            // Divider(color: c.border, height: 10),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => screen.shareFrameReceipt(f),
                    icon: Icon(
                      Icons.print_outlined,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    label: Text(
                      'Receipt',
                      style: TextStyle(color: c.text, fontSize: Dimens.font12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => screen.fixWinner(f),
                    icon: Icon(Icons.gavel, size: 13, color: c.gold),
                    label: Text(
                      'Fix winner',
                      style: TextStyle(color: c.gold, fontSize: Dimens.font12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _money(
    AppColors c,
    String label,
    dynamic v, {
    Color? tone,
    bool bold = false,
  }) {
    final value = ((v ?? 0) as num).toDouble();
    final normalizedLabel = label.toLowerCase();
    final amountColor =
        tone ??
        (normalizedLabel.contains('due')
            ? c.red
            : normalizedLabel.contains('collected') ||
                normalizedLabel.contains('paid')
            ? c.green
            : (value == 0 ? c.textMuted : c.text));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bold ? c.text : c.textSecondary,
                fontSize: Dimens.font11_5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            fmtMoney(value),
            style: TextStyle(
              color: amountColor,
              fontSize: Dimens.font13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
