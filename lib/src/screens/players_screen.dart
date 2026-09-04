import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dimensions.dart';

import '../api.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Players — member directory with wallet/due/plans, edit/delete/mail actions.
/// Sab forms bottom-sheet me (chat-box style) — dialogs nahi.
class PlayersScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const PlayersScreen({super.key, required this.session, required this.club});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
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

  Color _badgeTone(AppColors c, String badge) => switch (badge) {
    'due' => c.red,
    'wallet' => c.gold,
    'pass' => c.blue,
    'monthly' => c.green,
    _ => c.textMuted,
  };

  Future<void> _refresh() async {
    await widget.club.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _q.toLowerCase();
    final members =
        widget.club.members
            .where(
              (m) => m.name.toLowerCase().contains(q) || m.phone.contains(q),
            )
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: Dimens.searchH,
                  child: TextField(
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.searchFont,
                    ),
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
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.green,
                  foregroundColor: c.onGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _playerSheet(null),
                icon: const Icon(Icons.person_add_alt, size: 20),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child:
                members.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.all(12),
                      children: const [
                        EmptyState(
                          title: 'No players yet',
                          hint:
                              'Add your regulars to track wallets, passes and dues.',
                          icon: Icons.groups_outlined,
                        ),
                      ],
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: members.length,
                      itemBuilder: (_, i) => _memberCard(context, members[i]),
                    ),
          ),
        ),
      ],
    );
  }

  // ================================================================ card
  Widget _memberCard(BuildContext context, Member m) {
    final c = context.colors;
    final tone = _badgeTone(c, m.badge);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: m.hasDue ? c.red : tone, width: 3),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 9, 6, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: (m.hasDue ? c.red : c.green).withValues(
                      alpha: 0.14,
                    ),
                    child: Text(
                      m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                      style: TextStyle(
                        color: m.hasDue ? c.red : c.green,
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
                                  fontSize: Dimens.font13_5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (!m.active) ToneBadge('disabled', c.red),
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
                  ToneBadge(m.badge, tone),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _mini(c, 'WALLET', fmtMoney(m.walletBalance), c.gold),
                  _mini(
                    c,
                    'DUE',
                    fmtMoney(m.dueAmount),
                    m.hasDue ? c.red : c.textMuted,
                  ),
                  if (m.passFramesLeft > 0) ...[
                    _mini(c, 'FRAMES', '${m.passFramesLeft}', c.blue),
                  ],
                  if (m.planName != null) ...[
                    _mini(
                      c,
                      (m.planType ?? 'plan').toUpperCase(),
                      m.planName!,
                      m.planType == 'wallet'
                          ? c.gold
                          : m.planType == 'pass'
                          ? c.blue
                          : c.green,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _act(
                    c,
                    Icons.payments_outlined,
                    'Collect',
                    c.green,
                    () => _collectSheet(m),
                  ),
                  _act(
                    c,
                    Icons.card_membership,
                    'Plan',
                    c.gold,
                    () => _planSheet(m),
                  ),
                  _act(
                    c,
                    Icons.mail_outline,
                    'Mail',
                    m.email.isEmpty
                        ? c.textMuted.withValues(alpha: 0.35)
                        : c.blue,
                    () => _mail(m),
                  ),
                  _act(
                    c,
                    Icons.edit_outlined,
                    'Edit',
                    c.textSecondary,
                    () => _playerSheet(m),
                  ),
                  _act(
                    c,
                    Icons.delete_outline,
                    'Delete',
                    c.red,
                    () => _confirmDelete(m),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(AppColors c, String label, String value, Color tone) =>
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone,
                  fontSize: Dimens.font11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _act(
    AppColors c,
    IconData icon,
    String tip,
    Color tone,
    VoidCallback onTap,
  ) => IconButton(
    tooltip: tip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 20, color: tone),
  );

  // ================================================================ add / edit sheet
  Future<void> _playerSheet(Member? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final notes = TextEditingController();
    final wallet = TextEditingController();
    final due = TextEditingController();
    final frames =
        TextEditingController(); // opening pass frames (v3.21 backend)
    // edit-mode direct-set (blank = no change) — backend PATCH direct-set
    final setWallet = TextEditingController();
    final setDue = TextEditingController();
    final setFrames = TextEditingController();
    ClubPlan? plan; // add-mode only: sell a plan right away (atomic, v3.20+)
    String mode = 'cash';
    final plans = widget.club.plans.where((p) => p.active).toList();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              bool saving = false;
              final c = ctx.colors;
              Future<void> submit() async {
                if (name.text.trim().isEmpty) {
                  toast(ctx, 'Enter a name', error: true);
                  return;
                }
                if (saving) return;
                set(() => saving = true);

                try {
                  final clubId = widget.club.clubId;
                  if (clubId == null) {
                    throw const ApiException(-1, 'Club not ready');
                  }

                  final normalizedEmail = email.text.trim().toLowerCase();

                  if (existing == null) {
                    await widget.session.api.post('/clubs/$clubId/members', {
                      'name': name.text.trim(),
                      'phone': phone.text.trim(),
                      'email': normalizedEmail,
                      'notes': notes.text.trim(),
                      'walletBalance': double.tryParse(wallet.text.trim()) ?? 0,
                      'dueAmount': double.tryParse(due.text.trim()) ?? 0,
                      'passFramesLeft': int.tryParse(frames.text.trim()) ?? 0,
                      if (plan != null) 'planId': plan!.id,
                      if (plan != null) 'planPaid': true,
                      if (plan != null) 'mode': mode,
                    });
                  } else {
                    await widget.session.api.patch(
                      '/clubs/$clubId/members/${existing.id}',
                      {
                        'name': name.text.trim(),
                        'phone': phone.text.trim(),
                        'email': normalizedEmail,
                        'notes': notes.text.trim(),
                        if (setWallet.text.trim().isNotEmpty)
                          'walletBalance':
                              double.tryParse(setWallet.text.trim()) ?? 0,
                        if (setDue.text.trim().isNotEmpty)
                          'dueAmount': double.tryParse(setDue.text.trim()) ?? 0,
                        if (setFrames.text.trim().isNotEmpty)
                          'passFramesLeft':
                              int.tryParse(setFrames.text.trim()) ?? 0,
                      },
                    );
                  }

                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    set(() => saving = false);
                    toast(ctx, e.message, error: true);
                  }
                } catch (_) {
                  if (ctx.mounted) {
                    set(() => saving = false);
                    toast(ctx, 'Could not save player', error: true);
                  }
                }
              }

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
                          existing == null
                              ? 'Add player'
                              : 'Edit — ${existing.name}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: phone,
                                keyboardType: TextInputType.phone,
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Email (optional)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (existing == null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: wallet,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: AppText.field.copyWith(color: c.text),
                                  decoration: const InputDecoration(
                                    labelText: 'Opening wallet ₹ (optional)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: due,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: AppText.field.copyWith(color: c.text),
                                  decoration: const InputDecoration(
                                    labelText: 'Opening due ₹ (optional)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: frames,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppText.field.copyWith(color: c.text),
                            decoration: const InputDecoration(
                              labelText: 'Opening pass frames (optional)',
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: notes,
                            style: AppText.field.copyWith(color: c.text),
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                            ),
                          ),
                          if (plans.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              style: AppText.dropdown.copyWith(color: c.text),
                              key: ValueKey('newplan-${plan?.id ?? 'none'}'),
                              initialValue: plan?.id ?? '',
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    'No plan right now',
                                    style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: Dimens.font12,
                                    ),
                                  ),
                                ),
                                for (final p in plans)
                                  DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} · ${fmtMoney(p.amount)} (${p.type})',
                                      style: TextStyle(
                                        color: c.text,
                                        fontSize: Dimens.font12,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged:
                                  (v) => set(
                                    () =>
                                        plan =
                                            (v == null || v.isEmpty)
                                                ? null
                                                : plans.firstWhere(
                                                  (p) => p.id == v,
                                                ),
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Membership plan (optional)',
                              ),
                            ),
                            if (plan != null) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'cash',
                                      label: Text('Cash'),
                                    ),
                                    ButtonSegment(
                                      value: 'upi',
                                      label: Text('UPI'),
                                    ),
                                    ButtonSegment(
                                      value: 'card',
                                      label: Text('Card'),
                                    ),
                                  ],
                                  selected: {mode},
                                  onSelectionChanged:
                                      (v) => set(() => mode = v.first),
                                ),
                              ),
                            ],
                          ],
                        ] else ...[
                          const SizedBox(height: 6),
                          TextField(
                            controller: notes,
                            style: AppText.field.copyWith(color: c.text),
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: setWallet,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: AppText.field.copyWith(color: c.text),
                                  decoration: InputDecoration(
                                    labelText: 'Set wallet ₹',
                                    hintText: fmtNum(existing.walletBalance),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: setDue,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: AppText.field.copyWith(color: c.text),
                                  decoration: InputDecoration(
                                    labelText: 'Set due ₹',
                                    hintText: fmtNum(existing.dueAmount),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: setFrames,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: AppText.field.copyWith(color: c.text),
                                  decoration: InputDecoration(
                                    labelText: 'Set frames',
                                    hintText: '${existing.passFramesLeft}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              'blank = no change · values are SET directly (not added)',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: Dimens.font9_5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        actionPair(
                          ctx,
                          primaryLabel:
                              existing == null
                                  ? (plan == null
                                      ? 'Add player'
                                      : 'Add + sell ${plan!.name}')
                                  : 'Save changes',
                          onPrimary: submit,
                          cancelLabel: 'Close',
                          onCancel: () => Navigator.pop(ctx),
                          loading: saving,
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
    await widget.club.refresh();
    if (!mounted) return;
    if (existing == null) {
      toast(
        context,
        plan == null
            ? 'Player added · ${name.text.trim()}'
            : 'Player added · ${plan!.name} sold (${fmtMoney(plan!.amount)} booked)',
      );
    } else {
      toast(context, 'Player updated · ${name.text.trim()}');
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
                        Text(
                          'Due ${fmtMoney(m.dueAmount)} · part or full, old due settles first',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font11,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            labelText: 'Amount ₹',
                          ),
                        ),
                        const SizedBox(height: 8),
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

  // ================================================================ plan sheet
  Future<void> _planSheet(Member m) async {
    final plans = widget.club.plans.where((p) => p.active).toList();
    if (plans.isEmpty) {
      toast(context, 'Create a membership plan in Settings first', error: true);
      return;
    }
    ClubPlan picked = plans.first;
    String mode = 'cash';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              final c = ctx.colors;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sell plan — ${m.name}',
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        style: AppText.dropdown.copyWith(color: c.text),
                        key: ValueKey('plan-${picked.id}'),
                        initialValue: picked.id,
                        isDense: true,
                        items: [
                          for (final p in plans)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name} · ${fmtMoney(p.amount)} (${p.type})',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: Dimens.font12,
                                ),
                              ),
                            ),
                        ],
                        onChanged:
                            (v) => set(
                              () => picked = plans.firstWhere((p) => p.id == v),
                            ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'cash', label: Text('Cash')),
                            ButtonSegment(value: 'upi', label: Text('UPI')),
                            ButtonSegment(value: 'card', label: Text('Card')),
                          ],
                          selected: {mode},
                          onSelectionChanged: (v) => set(() => mode = v.first),
                        ),
                      ),
                      const SizedBox(height: 12),
                      actionPair(
                        ctx,
                        primaryLabel:
                            'Sell ${picked.name} · ${fmtMoney(picked.amount)}',
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
      final res = await widget.session.api.post(
        '/clubs/${widget.club.clubId}/plans/${picked.id}/sell',
        {'memberId': m.id, 'mode': mode},
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Plan sold');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ================================================================ mail / delete
  Future<void> _mail(Member m) async {
    if (m.email.isEmpty) {
      toast(
        context,
        'Add an email address in the player card first (Edit)',
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

  Future<void> _confirmDelete(Member m) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete ${m.name}?',
                  style: TextStyle(
                    color: c.text,
                    fontSize: Dimens.font14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wallet ${fmtMoney(m.walletBalance)} aur due ${fmtMoney(m.dueAmount)} history se hat jayega. Frames/bills record me rehte hain.',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: Dimens.font11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                // ★ Delete + Keep bhi ek hi row me
                actionPair(
                  ctx,
                  primaryLabel: 'Delete player',
                  destructive: true,
                  cancelLabel: 'Keep',
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      final res = await widget.session.api.delete(
        '/clubs/${widget.club.clubId}/members/${m.id}',
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Player deleted');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }
}
