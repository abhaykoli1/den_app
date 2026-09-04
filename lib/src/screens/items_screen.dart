import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../insights.dart';
import 'item_bills_screen.dart';
import '../models.dart';
import '../offline_queue.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class CounterSelection extends ChangeNotifier {
  final Map<String, int> quantities = {};

  void setQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      quantities.remove(itemId);
    } else {
      quantities[itemId] = quantity;
    }
    notifyListeners();
  }

  void clear() {
    quantities.clear();
    notifyListeners();
  }
}

class ItemsScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  final CounterSelection selection;
  const ItemsScreen({
    super.key,
    required this.session,
    required this.club,
    required this.selection,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final OfflineQueue _queue = OfflineQueue();
  Member? _member;
  final _customer = TextEditingController();
  final _discount = TextEditingController();
  String _mode = 'cash';
  int _guestNumber = 1;
  String? _selectedCategory;

  String _defaultGuestName() {
    final guestName = 'Guest $_guestNumber';
    _guestNumber += 1;
    return guestName;
  }

  @override
  void initState() {
    super.initState();
    widget.club.addListener(_onData);
    widget.selection.addListener(_onData);
  }

  void _onData() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    widget.club.removeListener(_onData);
    widget.selection.removeListener(_onData);
    _customer.dispose();
    _discount.dispose();
    _queue.dispose();
    super.dispose();
  }

  double get _subtotal {
    var sum = 0.0;
    for (final entry in widget.selection.quantities.entries) {
      final item =
          widget.club.menuItems.where((i) => i.id == entry.key).firstOrNull;
      if (item != null) sum += item.price * entry.value;
    }
    return sum;
  }

  double get _estProfit {
    var sum = 0.0;
    for (final entry in widget.selection.quantities.entries) {
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
    final picked =
        widget.selection.quantities.entries.where((e) => e.value > 0).toList();
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
          widget.selection.clear();
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
    final items = widget.club.menuItems.where((i) => i.active).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        InsightsCard(club: widget.club),
        const SizedBox(height: 8),
        _counter(context, items),
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
    final price = TextEditingController();
    final cost = TextEditingController();
    final stock = TextEditingController();
    final reorder = TextEditingController(text: '5');
    final categories =
        <String>{
            'Cafe',
            ...widget.club.menuItems
                .map((item) => item.category.trim())
                .where((item) => item.isNotEmpty),
          }.toList()
          ..sort();
    var selectedCategory =
        categories.contains('Cafe') ? 'Cafe' : categories.first;

    Future<void> addCategory(
      BuildContext dialogContext,
      void Function(void Function()) set,
    ) async {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: dialogContext,
        builder:
            (context) => AlertDialog(
              title: const Text('Add category'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'Meals, Drinks, Snacks',
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Add category'),
                ),
              ],
            ),
      );
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty && !categories.contains(normalized)) {
        set(() {
          categories.add(normalized);
          categories.sort();
          selectedCategory = normalized;
        });
      }
    }

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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final categoryField =
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCategory,
                                  style: AppText.dropdown.copyWith(
                                    color: c.text,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    contentPadding: Dimens.fieldPad,
                                  ),
                                  items:
                                      categories
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (value) => set(
                                        () =>
                                            selectedCategory =
                                                value ?? selectedCategory,
                                      ),
                                );
                            final addCategoryButton = OutlinedButton.icon(
                              onPressed: () => addCategory(ctx, set),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add category'),
                            );
                            final priceField = TextField(
                              controller: price,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: AppText.field.copyWith(color: c.text),
                              decoration: const InputDecoration(
                                labelText: 'Sell price ₹ *',
                              ),
                            );
                            if (constraints.maxWidth < 560) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  categoryField,
                                  const SizedBox(height: 6),
                                  addCategoryButton,
                                  const SizedBox(height: 6),
                                  priceField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: categoryField),
                                const SizedBox(width: 8),
                                SizedBox(width: 130, child: addCategoryButton),
                                const SizedBox(width: 8),
                                Expanded(child: priceField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fields = [
                              TextField(
                                controller: cost,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Cost ₹ (profit calc)',
                                ),
                              ),
                              TextField(
                                controller: stock,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Stock qty',
                                ),
                              ),
                              TextField(
                                controller: reorder,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppText.field.copyWith(color: c.text),
                                decoration: const InputDecoration(
                                  labelText: 'Low alert at',
                                ),
                              ),
                            ];
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  for (final field in fields) ...[
                                    field,
                                    const SizedBox(height: 6),
                                  ],
                                ],
                              );
                            }
                            return Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < fields.length;
                                  index++
                                ) ...[
                                  if (index > 0) const SizedBox(width: 8),
                                  Expanded(child: fields[index]),
                                ],
                              ],
                            );
                          },
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
        'category': selectedCategory,
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
    final selected =
        items
            .where((item) => widget.selection.quantities[item.id] != null)
            .toList();
    final seenItemIds = <String>{};
    final categoryItems = <String, List<MenuItem>>{};
    for (final item in items) {
      if (!seenItemIds.add(item.id)) continue;
      categoryItems.putIfAbsent(item.category, () => []).add(item);
    }
    final categories = categoryItems.keys.toList()..sort();
    final category =
        categories.contains(_selectedCategory)
            ? _selectedCategory!
            : (categories.isEmpty ? null : categories.first);
    final visibleItems =
        category == null ? const <MenuItem>[] : categoryItems[category]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: category,
                  style: AppText.dropdown.copyWith(color: c.text),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    contentPadding: Dimens.fieldPad,
                  ),
                  items:
                      categories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (category != null) ...[
                  Text(
                    'Category: $category',
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final quantity =
                          widget.selection.quantities[item.id] ?? 0;
                      return _CounterItemCard(
                        item: item,
                        quantity: quantity,
                        onTap:
                            item.outOfStock
                                ? null
                                : () => setState(() {
                                  widget.selection.setQuantity(
                                    item.id,
                                    quantity == 0 ? 1 : quantity,
                                  );
                                }),
                      );
                    },
                  ),
                ],
              ],
            );
          },
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
          for (var index = 0; index < selected.length; index++)
            _SelectedItemRow(
              item: selected[index],
              qty: widget.selection.quantities[selected[index].id] ?? 0,
              isFirst: index == 0,
              isLast: index == selected.length - 1,
              onQtyChanged:
                  (qty) => widget.selection.setQuantity(
                    selected[index].id,
                    qty.clamp(0, selected[index].stockQty),
                  ),
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
                fontSize: Dimens.dropdownFont,
                fontWeight: FontWeight.w500,
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

class _CounterItemCard extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final VoidCallback? onTap;

  const _CounterItemCard({
    required this.item,
    required this.quantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unavailable = item.outOfStock;
    return Card(
      margin: EdgeInsets.zero,
      color: quantity > 0 ? c.green.withValues(alpha: 0.12) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unavailable ? c.textMuted : c.text,
                        fontSize: Dimens.font12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                unavailable ? 'Out of stock' : fmtMoney(item.price),
                style: TextStyle(
                  color: unavailable ? c.red : c.green,
                  fontSize: Dimens.font11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedItemRow extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<int> onQtyChanged;

  const _SelectedItemRow({
    required this.item,
    required this.qty,
    this.isFirst = true,
    this.isLast = true,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isFirst ? 12 : 0),
          topRight: Radius.circular(isFirst ? 12 : 0),
          bottomLeft: Radius.circular(isLast ? 12 : 0),
          bottomRight: Radius.circular(isLast ? 12 : 0),
        ),
      ),
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
  final CounterSelection selection;
  const StockScreen({
    super.key,
    required this.session,
    required this.club,
    required this.selection,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  void initState() {
    super.initState();
    widget.club.addListener(_onData);
    widget.selection.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.club.removeListener(_onData);
    widget.selection.removeListener(_onData);
    super.dispose();
  }

  void _openBills() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ItemBillsScreen(session: widget.session, club: widget.club),
      ),
    );
  }

  Future<void> _addItem() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Cafe');
    final price = TextEditingController();
    final stock = TextEditingController(text: '0');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Sell price ₹',
                    ),
                  ),
                  TextField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock qty'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (name.text.trim().isEmpty ||
                            (double.tryParse(price.text) ?? 0) <= 0) {
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Add item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (saved != true || !mounted) return;
    try {
      await widget.session.api.post('/clubs/${widget.club.clubId}/menu-items', {
        'name': name.text.trim(),
        'category':
            category.text.trim().isEmpty ? 'Cafe' : category.text.trim(),
        'price': double.tryParse(price.text) ?? 0,
        'costPrice': 0,
        'stockQty': int.tryParse(stock.text) ?? 0,
        'reorderLevel': 5,
      });
      await widget.club.refresh();
      if (mounted) toast(context, 'Item added');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stock',
                  style: TextStyle(
                    color: c.text,
                    fontSize: Dimens.font14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bills history',
                onPressed: _openBills,
                icon: Icon(Icons.history, color: c.textSecondary),
              ),
              FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
