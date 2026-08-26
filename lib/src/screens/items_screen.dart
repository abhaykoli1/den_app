import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../insights.dart';
import '../models.dart';
import '../offline_queue.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class ItemsScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const ItemsScreen({super.key, required this.session, required this.club});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final OfflineQueue _queue = OfflineQueue();
  final Map<String, int> _qty = {};
  Member? _member;
  final _customer = TextEditingController();
  final _discount = TextEditingController();
  String _mode = 'cash';
  bool _showHistory = false;
  int _guestNumber = 1;

  String _defaultGuestName() {
    final guestName = 'Guest $_guestNumber';
    _guestNumber += 1;
    return guestName;
  }

  @override
  void initState() {
    super.initState();
    widget.club.addListener(_onData);
  }

  void _onData() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    widget.club.removeListener(_onData);
    _customer.dispose();
    _discount.dispose();
    _queue.dispose();
    super.dispose();
  }

  double get _subtotal {
    var sum = 0.0;
    for (final entry in _qty.entries) {
      final item =
          widget.club.menuItems.where((i) => i.id == entry.key).firstOrNull;
      if (item != null) sum += item.price * entry.value;
    }
    return sum;
  }

  double get _estProfit {
    var sum = 0.0;
    for (final entry in _qty.entries) {
      final item =
          widget.club.menuItems.where((i) => i.id == entry.key).firstOrNull;
      if (item != null) sum += (item.price - item.costPrice) * entry.value;
    }
    return sum;
  }

  Future<void> _chooseMember() async {
    final members = widget.club.members.where((m) => m.active).toList();
    final selectedId = await showDialog<String>(
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 10),
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
      _member =
          selectedId.isEmpty
              ? null
              : members.firstWhere((member) => member.id == selectedId);
    });
  }

  Future<void> _save() async {
    final picked = _qty.entries.where((e) => e.value > 0).toList();
    if (picked.isEmpty) {
      toast(context, 'Tap items to add them', error: true);
      return;
    }
    final customer =
        _customer.text.trim().isEmpty
            ? (_member?.name ?? _defaultGuestName())
            : _customer.text.trim();
    final payload = <String, dynamic>{
      'items': [
        for (final e in picked) {'menuItemId': e.key, 'qty': e.value},
      ],
      'customerName': customer,
      if (_member != null) 'memberId': _member!.id,
      'mode': _mode,
      'discount': double.tryParse(_discount.text.trim()) ?? 0,
    };
    final clubId = widget.club.clubId;
    if (clubId == null) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Confirm counter sale?',
      message:
          'A bill for ${picked.length} item type(s) will be saved for $customer. Payment mode: ${_mode.toUpperCase()}.',
      confirmLabel: 'Save bill',
    );
    if (!confirmed) return;
    try {
      final res = await widget.session.api.post(
        '/clubs/$clubId/item-bills',
        payload,
      );
      await widget.club.refresh();
      if (mounted) {
        toast(context, res['message'] ?? 'Bill saved');
        setState(() {
          _qty.clear();
          _discount.clear();
          _customer.clear();
          _member = null;
        });
      }
    } on ApiException catch (e) {
      if (e.isNetwork) {
        await _queue.enqueue(clubId, payload);
        if (mounted) {
          toast(context, 'Offline — bill queued, sync later', error: true);
        }
      } else if (mounted) {
        toast(context, e.message, error: true);
      }
    }
  }

  Future<void> _sync() async {
    final (sent, failed) = await _queue.sync(widget.session.api);
    if (!mounted) return;
    if (sent > 0) {
      toast(context, 'Synced $sent queued bill(s)');
      await widget.club.refresh();
      if (!mounted) return;
    }
    for (final f in failed) {
      toast(context, f, error: true);
    }
    if (sent == 0 && failed.isEmpty) {
      toast(context, 'Still offline — queue kept', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = widget.club.menuItems.where((i) => i.active).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _showHistory ? 'Item bills (history)' : 'Counter sale',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_queue.length > 0)
              TextButton.icon(
                onPressed: _sync,
                icon: Icon(Icons.sync, size: 14, color: c.gold),
                label: Text(
                  'Sync ${_queue.length}',
                  style: TextStyle(color: c.gold, fontSize: Dimens.font11),
                ),
              ),
            IconButton(
              tooltip: _showHistory ? 'New bill' : 'Bill history',
              onPressed: () => setState(() => _showHistory = !_showHistory),
              icon: Icon(
                _showHistory ? Icons.add_shopping_cart : Icons.history,
                size: 20,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: c.green,
                foregroundColor: c.onGreen,
              ),
              onPressed: _addItemSheet,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InsightsCard(club: widget.club),
        const SizedBox(height: 8),
        if (_showHistory) _history(context) else _counter(context, items),
      ],
    );
  }

  Widget _history(BuildContext context) {
    final c = context.colors;
    final bills = widget.club.itemBills;
    if (bills.isEmpty) {
      return const EmptyState(
        title: 'No bills yet',
        hint: 'Counter sales show up here.',
        icon: Icons.receipt_long_outlined,
      );
    }
    return Column(
      children: [
        for (final b in bills)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${b['customerName']}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          (b['items'] as List? ?? const [])
                              .map((i) => '${i['name']}×${i['qty']}')
                              .join(', '),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ToneBadge(
                    b['paid'] == true ? 'paid · ${b['mode']}' : 'unpaid · due',
                    b['paid'] == true ? c.green : c.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    fmtMoney(b['amount']),
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (b['paid'] != true) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Mark paid',
                      icon: Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: c.green,
                      ),
                      onPressed: () => _markPaid(b),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _markPaid(dynamic b) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Confirm money collection?',
      message:
          'Collect the ${fmtMoney(b['amount'] ?? 0)} cash payment from ${b['customerName'] ?? 'Customer'}.',
      confirmLabel: 'Mark paid',
    );
    if (!confirmed) return;
    try {
      final res = await widget.session.api.post(
        '/clubs/${widget.club.clubId}/item-bills/${b['id']}/mark-paid',
        {'mode': 'cash'},
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Bill paid');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ================================================================ add item sheet
  Future<void> _addItemSheet() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Cafe');
    final price = TextEditingController();
    final cost = TextEditingController();
    final stock = TextEditingController();
    final reorder = TextEditingController(text: '5');
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
                          'Add counter item',
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
                          autofocus: true,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            labelText: 'Item name *',
                            hintText: 'Cold drink, chai, sandwich…',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: category,
                                textCapitalization: TextCapitalization.words,
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  hintText: 'Cafe',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: price,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Sell price ₹ *',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: cost,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Cost ₹ (profit calc)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: stock,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Stock qty',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: reorder,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Low alert at',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        actionPair(
                          ctx,
                          primaryLabel: 'Add item',
                          primaryIcon: Icons.add,
                          onPrimary: () {
                            if (name.text.trim().isEmpty) {
                              toast(ctx, 'Enter the item name', error: true);
                              return;
                            }
                            if ((double.tryParse(price.text.trim()) ?? 0) <=
                                0) {
                              toast(
                                ctx,
                                'Enter a selling price greater than 0',
                                error: true,
                              );
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
    if (ok != true) return;
    final clubId = widget.club.clubId;
    if (clubId == null) return;
    try {
      await widget.session.api.post('/clubs/$clubId/menu-items', {
        'name': name.text.trim(),
        'category':
            category.text.trim().isEmpty ? 'Cafe' : category.text.trim(),
        'price': double.tryParse(price.text.trim()) ?? 0,
        'costPrice': double.tryParse(cost.text.trim()) ?? 0,
        'stockQty': int.tryParse(stock.text.trim()) ?? 0,
        'reorderLevel': int.tryParse(reorder.text.trim()) ?? 5,
      });
      await widget.club.refresh();
      if (mounted) toast(context, 'Item added · ${name.text.trim()}');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Widget _counter(BuildContext context, List<MenuItem> items) {
    final c = context.colors;
    final selected = items.where((i) => (_qty[i.id] ?? 0) > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tap is intentionally a toggle: tap once to add, tap again to remove.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in items)
              InkWell(
                onTap:
                    i.outOfStock
                        ? null
                        : () => setState(() {
                          _qty[i.id] = (_qty[i.id] ?? 0) > 0 ? 0 : 1;
                        }),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        i.outOfStock
                            ? c.bgMuted.withValues(alpha: 0.45)
                            : c.bgMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (_qty[i.id] ?? 0) > 0
                              ? c.green
                              : (i.lowStock ? c.gold : c.border),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 132),
                        child: Text(
                          i.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        fmtMoney(i.price),
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font10_5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (_qty[i.id] ?? 0) > 0
                                  ? c.soft(c.green)
                                  : c.bgElevated,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color:
                                (_qty[i.id] ?? 0) > 0
                                    ? c.green
                                    : c.borderStrong,
                          ),
                        ),
                        child: Text(
                          '×${_qty[i.id] ?? 0}',
                          style: TextStyle(
                            color:
                                (_qty[i.id] ?? 0) > 0 ? c.green : c.textMuted,
                            fontSize: Dimens.font10_5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Selected items',
            style: TextStyle(
              color: c.text,
              fontSize: Dimens.font13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in selected)
            _SelectedItemRow(
              item: item,
              qty: _qty[item.id] ?? 0,
              onQtyChanged:
                  (qty) => setState(() {
                    // Quantity 0 means this item is no longer selected.
                    _qty[item.id] = qty.clamp(0, item.stockQty);
                  }),
            ),
        ],
        const SizedBox(height: 12),
        const FieldLabel('Member (optional)'),
        InkWell(
          onTap: _chooseMember,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _member?.name ?? 'Walk-in customer',
              style: TextStyle(
                color: _member == null ? c.textMuted : c.text,
                fontSize: Dimens.font12,
              ),
            ),
          ),
        ),
        if (_member == null) ...[
          const FieldLabel('Customer name (optional)'),
          TextField(
            controller: _customer,
            style: AppText.field.copyWith(color: c.text),
            decoration: const InputDecoration(
              hintText: 'Guest 1, Guest 2, or type name',
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Cash')),
              ButtonSegment(value: 'upi', label: Text('UPI')),
              ButtonSegment(value: 'card', label: Text('Card')),
              ButtonSegment(value: 'wallet', label: Text('Wallet')),
              ButtonSegment(value: 'due', label: Text('Due')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
        ),
        const SizedBox(height: 8),
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
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Est. profit'),
                  Text(
                    fmtMoney(
                      _estProfit -
                          (double.tryParse(_discount.text.trim()) ?? 0),
                    ),
                    style: TextStyle(
                      color: c.blue,
                      fontSize: Dimens.font14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: c.green,
              foregroundColor: c.onGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(
              'Save bill · ${fmtMoney(_subtotal - (double.tryParse(_discount.text.trim()) ?? 0))}',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'offline? bills queue locally and sync from here',
            style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
          ),
        ),
      ],
    );
  }
}

class _SelectedItemRow extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final ValueChanged<int> onQtyChanged;
  const _SelectedItemRow({
    required this.item,
    required this.qty,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${fmtMoney(item.price)} each · ${item.stockQty} in stock',
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font10_5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Reduce quantity',
              onPressed: () => onQtyChanged(qty - 1),
              icon: Icon(Icons.remove_circle_outline, color: c.textSecondary),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Increase quantity',
              onPressed:
                  qty >= item.stockQty ? null : () => onQtyChanged(qty + 1),
              icon: Icon(Icons.add_circle_outline, color: c.green),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inventory workspace.  Editing is kept here so counter billing stays fast.
class StockScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const StockScreen({super.key, required this.session, required this.club});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
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

  Future<void> _edit(MenuItem item) async {
    final name = TextEditingController(text: item.name);
    final category = TextEditingController(text: item.category);
    final price = TextEditingController(text: item.price.toStringAsFixed(0));
    final cost = TextEditingController(text: item.costPrice.toStringAsFixed(0));
    final stock = TextEditingController(text: '${item.stockQty}');
    final reorder = TextEditingController(text: '${item.reorderLevel}');
    var active = item.active;
    final saved = await showModalBottomSheet<bool>(
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
                            'Edit item',
                            style: TextStyle(
                              color: ctx.colors.text,
                              fontSize: Dimens.font14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Item name',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: price,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Sell price ₹',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: cost,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Cost ₹',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: stock,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Stock qty',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: reorder,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Low alert at',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Available for billing'),
                            value: active,
                            onChanged: (v) => set(() => active = v),
                          ),
                          actionPair(
                            ctx,
                            primaryLabel: 'Save changes',
                            primaryIcon: Icons.save_outlined,
                            onPrimary: () {
                              if (name.text.trim().isEmpty ||
                                  (double.tryParse(price.text) ?? 0) <= 0) {
                                toast(
                                  ctx,
                                  'Enter an item name and a valid selling price',
                                  error: true,
                                );
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
    if (saved != true || !mounted) return;
    try {
      await widget.session.api
          .patch('/clubs/${widget.club.clubId}/menu-items/${item.id}', {
            'name': name.text.trim(),
            'category': category.text.trim(),
            'price': double.tryParse(price.text) ?? 0,
            'costPrice': double.tryParse(cost.text) ?? 0,
            'stockQty': int.tryParse(stock.text) ?? 0,
            'reorderLevel': int.tryParse(reorder.text) ?? 0,
            'active': active,
          });
      await widget.club.refresh();
      if (mounted) toast(context, 'Item updated');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = [...widget.club.menuItems]
      ..sort((a, b) => a.name.compareTo(b.name));
    return RefreshIndicator(
      onRefresh: widget.club.refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'All items · tap to edit',
            style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const EmptyState(
              title: 'No stock items',
              hint: 'Add an item from Counter.',
              icon: Icons.inventory_2_outlined,
            ),
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => _edit(item),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(
                        item.outOfStock
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.inventory_2_outlined,
                        color:
                            item.outOfStock
                                ? c.red
                                : (item.lowStock ? c.gold : c.green),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${item.category} · ${fmtMoney(item.price)} · ${item.stockQty} in stock${item.active ? '' : ' · hidden'}',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: Dimens.font11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.edit_outlined,
                        color: c.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
