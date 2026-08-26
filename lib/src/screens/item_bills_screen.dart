import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../exporter.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Item Bills — counter bill history, receipts and dues (§10 / sidebar Item Bills).
class ItemBillsScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const ItemBillsScreen({super.key, required this.session, required this.club});

  @override
  State<ItemBillsScreen> createState() => _ItemBillsScreenState();
}

class _ItemBillsScreenState extends State<ItemBillsScreen> {
  String _q = '';

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

  List<dynamic> get _bills {
    final list = List<dynamic>.from(widget.club.itemBills);
    list.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    if (_q.isEmpty) return list;
    final q = _q.toLowerCase();
    return list.where((b) {
      final items = ((b['items'] as List?) ?? const [])
          .map((i) => '${i['name']}')
          .join(' ');
      return '${b['customerName']} ${b['mode']} ${b['status']} $items'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bills = _bills;
    return RefreshIndicator(
      onRefresh: widget.club.refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                hintText: 'Customer, item or mode',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 10),
          if (bills.isEmpty)
            const EmptyState(
              title: 'No item bills yet',
              hint: 'Counter bills from the Items tab will appear here.',
              icon: Icons.receipt_long_outlined,
            ),
          for (final b in bills)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BillCard(b, screen: this),
            ),
        ],
      ),
    );
  }

  Future<void> markPaid(dynamic b) async {
    // ★ v3.21 — PARTIAL mark-paid: backend ab {amount, mode} accept karta hai.
    // Outstanding = dueAmount (naye bills) ya legacy fallout (unpaid = full).
    final outstanding =
        ((b['dueAmount'] ?? b['amount'] ?? 0) as num).toDouble();
    final amount = TextEditingController(
      text:
          outstanding == outstanding.truncateToDouble()
              ? outstanding.toStringAsFixed(0)
              : outstanding.toStringAsFixed(2),
    );
    String mode = 'cash';
    final c = context.colors;
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
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark paid — ${b['customerName'] ?? 'Walk-in'}',
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w800,
                            fontSize: Dimens.font14,
                          ),
                        ),
                        Text(
                          'Outstanding ${fmtMoney(outstanding)} · partial or full — the ledger records only the received amount',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font11,
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
                            labelText: 'Amount ₹',
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
                            onPressed: () {
                              final v =
                                  double.tryParse(amount.text.trim()) ?? 0;
                              if (v <= 0) {
                                toast(ctx, 'Enter an amount', error: true);
                                return;
                              }
                              if (v > outstanding) {
                                toast(
                                  ctx,
                                  'Amount cannot exceed outstanding ${fmtMoney(outstanding)}',
                                  error: true,
                                );
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                            child: Text(
                              'Collect ${fmtMoney(double.tryParse(amount.text.trim()) ?? 0)}',
                            ),
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
    if (!mounted) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Confirm money collection?',
      message:
          'Collect ${fmtMoney(value)} via ${mode.toUpperCase()} from ${b['customerName'] ?? 'Customer'}.',
      confirmLabel: 'Collect ${fmtMoney(value)}',
    );
    if (!confirmed || !mounted) return;
    try {
      final res = await widget.session.api.post(
        '/clubs/${widget.club.clubId}/item-bills/${b['id']}/mark-paid',
        {'amount': value, 'mode': mode},
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Bill paid');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> deleteBill(dynamic b) async {
    final sure = await confirmSheet(
      context,
      title: 'Delete this bill?',
      message:
          'Stock returns to inventory and any member due for it is reversed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      final res = await widget.session.api.delete(
        '/clubs/${widget.club.clubId}/item-bills/${b['id']}',
      );
      await widget.club.refresh();
      if (mounted) toast(context, res['message'] ?? 'Bill deleted');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  void showReceipt(dynamic b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReceiptSheet(bill: b, club: widget.session.activeClub),
    );
  }
}

class _BillCard extends StatelessWidget {
  final dynamic b;
  final _ItemBillsScreenState screen;
  const _BillCard(this.b, {required this.screen});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final paid = b['paid'] == true;
    final status = '${b['status'] ?? (paid ? 'paid' : 'unpaid')}';
    final items = ((b['items'] as List?) ?? const []);
    final dueAmount =
        ((b['dueAmount'] ?? (paid ? 0.0 : (b['amount'] ?? 0))) as num)
            .toDouble();
    final paidAmount =
        ((b['paidAmount'] ?? (paid ? (b['amount'] ?? 0) : 0)) as num)
            .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${b['customerName'] ?? 'Walk-in'}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font13_5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (b['memberId'] != null) ...[
                        const SizedBox(width: 5),
                        ToneBadge('member', c.gold),
                      ],
                    ],
                  ),
                ),
                ToneBadge(
                  status == 'paid'
                      ? 'Paid'
                      : status == 'partial'
                      ? 'Partial'
                      : 'Due',
                  status == 'paid'
                      ? c.green
                      : status == 'partial'
                      ? c.gold
                      : c.red,
                ),
                const SizedBox(width: 6),
                Text(
                  '${b['mode'] ?? ''}'.toUpperCase(),
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: Dimens.font10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              fmtDT(b['createdAt']),
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
            ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  items.map((i) => '${i['name']} x${i['qty']}').join('  ·  '),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: Dimens.font11_5,
                  ),
                ),
              ),
            Divider(color: c.border, height: 12),
            _moneyRow(c, 'Total', (b['amount'] ?? 0) + (b['discount'] ?? 0)),
            _moneyRow(
              c,
              'Discount',
              -(b['discount'] ?? 0),
              hide: (b['discount'] ?? 0) == 0,
            ),
            _moneyRow(
              c,
              paid ? 'Paid' : 'Paid so far',
              paidAmount,
              tone: paidAmount > 0 ? c.green : null,
            ),
            _moneyRow(c, 'Due', dueAmount, tone: dueAmount > 0 ? c.red : null),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!paid)
                  TextButton.icon(
                    onPressed: () => screen.markPaid(b),
                    icon: Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: c.green,
                    ),
                    label: Text(
                      'Mark paid',
                      style: TextStyle(color: c.green, fontSize: Dimens.font12),
                    ),
                  ),
                IconButton(
                  tooltip: 'Receipt',
                  onPressed: () => screen.showReceipt(b),
                  icon: Icon(
                    Icons.print_outlined,
                    size: 16,
                    color: c.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => screen.deleteBill(b),
                  icon: Icon(Icons.delete_outline, size: 14, color: c.red),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: c.red, fontSize: Dimens.font12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(
    AppColors c,
    String label,
    num v, {
    Color? tone,
    bool hide = false,
  }) {
    if (hide) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
          ),
          const Spacer(),
          Text(
            fmtMoney(v),
            style: TextStyle(
              color: tone ?? c.text,
              fontSize: Dimens.font11_5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 58mm-style monochrome receipt preview (same look as the web Print Receipt).
class _ReceiptSheet extends StatelessWidget {
  final dynamic bill;
  final Club? club;
  const _ReceiptSheet({required this.bill, this.club});

  @override
  Widget build(BuildContext context) {
    final items = ((bill['items'] as List?) ?? const []);
    const mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: Dimens.font12,
      color: Colors.black87,
    );
    final b = bill;
    final total = ((b['amount'] ?? 0) as num).toDouble();
    final discount = ((b['discount'] ?? 0) as num).toDouble();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Print Receipt',
                    style: TextStyle(
                      color: context.colors.text,
                      fontSize: Dimens.font15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: context.colors.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDF8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DefaultTextStyle(
                style: mono,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      club?.name ?? "Rowdy's Den",
                      style: mono.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: Dimens.font14,
                      ),
                    ),
                    const Text(
                      "powered by Rowdy's Den — Club Billing",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: Dimens.font9,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '----------------------------------------------',
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: mono,
                    ),
                    Row(
                      children: [
                        const Text('ITEM BILL', style: mono),
                        const Spacer(),
                        Text(
                          '#${(b['id'] ?? '').toString().toUpperCase()}',
                          style: mono,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(fmtDT(b['createdAt']), style: mono),
                        const Spacer(),
                        Text('${b['customerName'] ?? 'Walk-in'}', style: mono),
                      ],
                    ),
                    const Text(
                      '----------------------------------------------',
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: mono,
                    ),
                    for (final i in items)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i['name']} x${i['qty']}',
                              style: mono,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(fmtMoney(i['amount']), style: mono),
                        ],
                      ),
                    const Text(
                      '----------------------------------------------',
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: mono,
                    ),
                    Row(
                      children: [
                        const Text('Subtotal', style: mono),
                        const Spacer(),
                        Text(fmtMoney(total + discount), style: mono),
                      ],
                    ),
                    if (discount > 0)
                      Row(
                        children: [
                          const Text('Discount', style: mono),
                          const Spacer(),
                          Text('-${fmtMoney(discount)}', style: mono),
                        ],
                      ),
                    Row(
                      children: [
                        Text(
                          'TOTAL',
                          style: mono.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: Dimens.font14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          fmtMoney(total),
                          style: mono.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: Dimens.font14,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          b['paid'] == true
                              ? 'Paid (${b['settledMode'] ?? b['mode'] ?? 'cash'})'
                              : (((b['paidAmount'] ?? 0) as num) > 0
                                  ? 'PART-PAID (${b['settledMode'] ?? 'cash'})'
                                  : 'UNPAID — due'),
                          style: mono,
                        ),
                        const Spacer(),
                        Text(
                          fmtMoney(
                            b['paid'] == true
                                ? total
                                : ((b['paidAmount'] ?? 0) as num).toDouble(),
                          ),
                          style: mono,
                        ),
                      ],
                    ),
                    if (b['paid'] != true &&
                        (((b['dueAmount'] ?? 0) as num) > 0))
                      Row(
                        children: [
                          const Text('Due left', style: mono),
                          const Spacer(),
                          Text(fmtMoney(b['dueAmount']), style: mono),
                        ],
                      ),
                    const Text(
                      '----------------------------------------------',
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: mono,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b['paid'] == true
                          ? 'Payment complete — thank you!'
                          : 'Pay at counter — thank you!',
                      style: mono,
                    ),
                    const Text('Visit again · play fair', style: mono),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Receipts are sized for 58mm thermal printers.',
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: Dimens.font10,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.green,
                  foregroundColor: context.colors.onGreen,
                ),
                onPressed: () async {
                  try {
                    await shareReceiptPdf(
                      fileName:
                          'rowdys-den-bill-${(bill['id'] ?? 'receipt').toString().toUpperCase()}.pdf',
                      clubName: club?.name ?? "Rowdy's Den",
                      lines: itemBillReceiptLines(bill),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      toast(context, 'Could not build PDF: $e', error: true);
                    }
                  }
                },
                icon: const Icon(Icons.print_outlined, size: 15),
                label: const Text('Share / Print Receipt (58mm PDF)'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
