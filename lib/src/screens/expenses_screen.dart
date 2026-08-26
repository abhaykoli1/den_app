import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../insights.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// Expenses — owner-only admin surface (§11).
class ExpensesScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const ExpensesScreen({super.key, required this.session, required this.club});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _month = thisMonth();
  String _category = 'ALL';
  bool _loading = true;
  String? _error;
  List<dynamic> _rows = [];
  double _total = 0;
  Map<String, dynamic> _byCategory = {};

  static const _cats = [
    'rent',
    'salary',
    'electricity',
    'maintenance',
    'stock',
    'tournament',
    'misc',
  ];

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
      final d = await widget.session.api.get(
        '/clubs/${widget.club.clubId}/expenses',
        query: {'month': _month},
      );
      _rows = List<dynamic>.from(d['rows'] ?? const []);
      _total = (d['total'] ?? 0).toDouble();
      _byCategory = Map<String, dynamic>.from(d['byCategory'] ?? const {});
    } on ApiException catch (e) {
      _error = e.isForbidden ? null : e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_locked) return const AdminLockedCard();

    final rows =
        _category == 'ALL'
            ? _rows
            : _rows.where((r) => '${r['category']}' == _category).toList();
    final catEntries =
        _byCategory.entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final topCat = catEntries.isEmpty ? null : catEntries.first;
    final daysElapsed = DateTime.now().day.clamp(1, 31);

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
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.green,
                  foregroundColor: c.onGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: _addExpense,
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add Expense'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EmptyState(
                title: 'Could not load',
                hint: _error!,
                icon: Icons.cloud_off_outlined,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Month expenses',
                  value: fmtMoney(_total),
                  sub: '${_rows.length} entries · $_month',
                  tone: c.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Top category',
                  value: topCat?.key ?? '—',
                  sub: topCat == null ? '' : fmtMoney(topCat.value as num),
                  tone: c.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Per day (avg)',
                  value: fmtMoney(
                    _month == thisMonth() ? _total / daysElapsed : _total / 30,
                  ),
                  sub: 'run rate this month',
                  tone: c.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InsightsCard(club: widget.club),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(c, 'ALL', 'All · ${fmtMoney(_total)}'),
              for (final e in catEntries)
                _chip(c, e.key, '${e.key} · ${fmtMoney(e.value as num)}'),
            ],
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'All expenses · ${rows.length}',
            child:
                _loading
                    ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: EightBallLoader(label: 'loading…'),
                    )
                    : rows.isEmpty
                    ? const EmptyState(
                      title: 'No expenses this month',
                      hint: 'Rent, salaries, stock purchases — log them here.',
                      icon: Icons.receipt_outlined,
                    )
                    : Column(
                      children: [
                        for (final r in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${r['title']}',
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
                                          if (r['auto'] == true) ...[
                                            const SizedBox(width: 4),
                                            ToneBadge('auto-stock', c.green),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ToneBadge('${r['category']}', c.blue),
                                const SizedBox(width: 8),
                                Text(
                                  fmtMoney(r['amount']),
                                  style: TextStyle(
                                    color: c.red,
                                    fontSize: Dimens.font12_5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _editExpense(r),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color: c.blue,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap:
                                      r['auto'] == true
                                          ? null
                                          : () => _delete(r),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 15,
                                      color:
                                          r['auto'] == true ? c.border : c.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Divider(color: c.border),
                        Row(
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                color: c.text,
                                fontSize: Dimens.font12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              fmtMoney(
                                rows.fold<double>(
                                  0,
                                  (a, r) => a + ((r['amount'] ?? 0) as num),
                                ),
                              ),
                              style: TextStyle(
                                color: c.red,
                                fontSize: Dimens.font13,
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
    );
  }

  Widget _chip(AppColors c, String value, String label) {
    final sel = _category == value;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          fontSize: Dimens.font11,
          color: sel ? Colors.black87 : c.textSecondary,
        ),
      ),
      selected: sel,
      selectedColor: c.green,
      backgroundColor: c.bgElevated,
      side: BorderSide(color: sel ? c.green : c.border),
      onSelected: (_) => setState(() => _category = value),
    );
  }

  Future<void> _addExpense() async {
    final c = context.colors;
    final title = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    String cat = 'misc';
    String date = todayStr();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
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
                          'Add Expense',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const FieldLabel('Title'),
                        TextField(
                          controller: title,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            hintText: 'e.g. July electricity bill',
                          ),
                        ),
                        const FieldLabel('Category'),
                        DropdownButtonFormField<String>(
                          style: AppText.dropdown.copyWith(color: c.text),
                          initialValue: cat,
                          items: [
                            for (final k in _cats)
                              DropdownMenuItem(value: k, child: Text(k)),
                          ],
                          onChanged: (v) => set(() => cat = v ?? 'misc'),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel('Amount ₹'),
                                  TextField(
                                    controller: amount,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel('Date'),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final d = await pickDate(ctx, date);
                                      if (d != null) set(() => date = d);
                                    },
                                    icon: Icon(
                                      Icons.calendar_month_outlined,
                                      size: 14,
                                      color: c.textSecondary,
                                    ),
                                    label: Text(
                                      fmtDate(date),
                                      style: TextStyle(
                                        color: c.text,
                                        fontSize: Dimens.font12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const FieldLabel('Note (optional)'),
                        TextField(
                          controller: note,
                          style: AppText.field.copyWith(color: c.text),
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
                            child: const Text('Save expense'),
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
    final amt = double.tryParse(amount.text.trim()) ?? 0;
    if (title.text.trim().isEmpty || amt <= 0) {
      if (mounted) {
        toast(context, 'Title + positive amount required', error: true);
      }
      return;
    }
    try {
      await widget.session.api.post('/clubs/${widget.club.clubId}/expenses', {
        'title': title.text.trim(),
        'category': cat,
        'amount': amt,
        'date': date,
        'note': note.text.trim(),
      });
      await _load();
      await widget.club.refresh();
      if (mounted) toast(context, 'Expense saved');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _delete(dynamic r) async {
    final sure = await confirmSheet(
      context,
      title: 'Delete expense?',
      message:
          '${r['title']} · ${fmtMoney(r['amount'])}\nEntry books se permanently hat jayegi.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await widget.session.api.delete(
        '/clubs/${widget.club.clubId}/expenses/${r['id']}',
      );
      await _load();
      if (mounted) toast(context, 'Expense deleted');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _editExpense(dynamic r) async {
    final c = context.colors;
    final title = TextEditingController(text: '${r['title'] ?? ''}');
    final amount = TextEditingController(text: '${r['amount'] ?? ''}');
    final note = TextEditingController(text: '${r['note'] ?? ''}');
    var category = '${r['category'] ?? 'misc'}';
    var date = '${r['date'] ?? todayStr()}';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, set) => Padding(
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
                            'Edit Expense',
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const FieldLabel('Title'),
                          TextField(
                            controller: title,
                            style: AppText.field.copyWith(color: c.text),
                          ),
                          const FieldLabel('Category'),
                          DropdownButtonFormField<String>(
                            style: AppText.dropdown.copyWith(color: c.text),
                            initialValue:
                                _cats.contains(category) ? category : 'misc',
                            items: [
                              for (final k in _cats)
                                DropdownMenuItem(value: k, child: Text(k)),
                            ],
                            onChanged: (v) => set(() => category = v ?? 'misc'),
                          ),
                          const FieldLabel('Amount ₹'),
                          TextField(
                            controller: amount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppText.field.copyWith(color: c.text),
                          ),
                          const FieldLabel('Date'),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await pickDate(ctx, date);
                              if (picked != null) set(() => date = picked);
                            },
                            icon: Icon(
                              Icons.calendar_month_outlined,
                              size: 14,
                              color: c.textSecondary,
                            ),
                            label: Text(
                              fmtDate(date),
                              style: TextStyle(
                                color: c.text,
                                fontSize: Dimens.font12,
                              ),
                            ),
                          ),
                          const FieldLabel('Note (optional)'),
                          TextField(
                            controller: note,
                            style: AppText.field.copyWith(color: c.text),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Save changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || title.text.trim().isEmpty || value <= 0) {
      if (ok == true && mounted) {
        toast(context, 'Title + positive amount required', error: true);
      }
      return;
    }
    try {
      await widget.session.api
          .patch('/clubs/${widget.club.clubId}/expenses/${r['id']}', {
            'title': title.text.trim(),
            'category': category,
            'amount': value,
            'date': date,
            'note': note.text.trim(),
          });
      await _load();
      await widget.club.refresh();
      if (mounted) toast(context, 'Expense updated');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }
}
