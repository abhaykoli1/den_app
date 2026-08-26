// ignore_for_file: prefer_const_constructors
// (pw.* constructors non-const rakhe hain — purane Dart 3.7 analyzer ka
//  const-eval enum rule trip hota hai; output bilkul same rehta hai)

import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:share_plus/share_plus.dart';

import 'dimensions.dart';
import 'theme.dart';
import 'widgets.dart' show fmtDT;

/// Central export engine (§30 v3.1 PATCH: "Exports = Excel + PDF, no CSV").
///
/// Everything builds ON-DEVICE from the club snapshot / report responses —
/// the backend stays the calculator, files never touch MongoDB. Files land in
/// the native share sheet (WhatsApp, Drive, Files, printer apps). Note: PDF
/// standard fonts are Latin-1 — ₹ is unavailable, so PDFs print "Rs".

/// Money for PDFs (ASCII-safe). App UI keeps ₹ via fmtMoney.
String rs(dynamic v) => 'Rs ${fmtNum(((v ?? 0) as num).toDouble())}';

// ---------------------------------------------------------------- errors

class ExportException implements Exception {
  final String message;
  const ExportException(this.message);
  @override
  String toString() => message;
}

// ---------------------------------------------------------------- temp file

Future<File> _writeTemp(String fileName, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$fileName');
  return f.writeAsBytes(bytes, flush: true);
}

Future<void> _shareFile(File f, String mimeType, String subject) async {
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path, mimeType: mimeType)], subject: subject),
  );
}

// ---------------------------------------------------------------- Excel

CellValue? _cell(dynamic v) {
  if (v == null) return null;
  if (v is bool) return BoolCellValue(v);
  if (v is int) return IntCellValue(v);
  if (v is num) return DoubleCellValue(double.parse(v.toStringAsFixed(2)));
  final s = '$v';
  return TextCellValue(s);
}

String _sheetName(String raw) {
  var s = raw.replaceAll(RegExp(r'[\[\]:\*\?\/\\]'), ' ').trim();
  if (s.length > 31) s = s.substring(0, 31);
  return s.isEmpty ? 'Sheet' : s;
}

/// Build a real .xlsx (multi-sheet) and open the share sheet.
/// [sheets] = sheetName → rows (first row typically headers). Numbers stay
/// numeric so the accountant can sum/sort directly in Excel.
Future<void> shareXlsx(
  String fileName,
  Map<String, List<List<dynamic>>> sheets,
) async {
  if (sheets.isEmpty) throw const ExportException('Nothing to export');
  final book = Excel.createExcel();
  final def = book.getDefaultSheet();
  var consumedDefault = false;
  for (final entry in sheets.entries) {
    final name = _sheetName(entry.key);
    if (!consumedDefault && def != null) {
      book.rename(def, name);
      consumedDefault = true;
    }
    final sheet = book[name];
    final widths = <int, int>{};
    for (final row in entry.value) {
      sheet.appendRow([for (final v in row) _cell(v)]);
      for (var i = 0; i < row.length; i++) {
        final len = '${row[i] ?? ''}'.length;
        if (len > (widths[i] ?? 0)) widths[i] = len;
      }
    }
    widths.forEach(
      (i, w) => sheet.setColumnWidth(i, (w + 2).clamp(9, 46).toDouble()),
    );
  }
  final bytes = book.encode();
  if (bytes == null) throw const ExportException('Excel build failed');
  final f = await _writeTemp(fileName, bytes);
  await _shareFile(
    f,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    fileName,
  );
}

// ---------------------------------------------------------------- JSON backup

Future<void> shareJson(String fileName, Object payload) async {
  final f = await _writeTemp(
    fileName,
    utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
  );
  await _shareFile(f, 'application/json', fileName);
}

// ---------------------------------------------------------------- A4 PDF

/// One titled, bordered table inside an A4 report.
class ReportTable {
  final String? heading;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String>? totalRow;
  final String? note;
  const ReportTable({
    this.heading,
    required this.headers,
    required this.rows,
    this.totalRow,
    this.note,
  });
}

bool _rightCol(String h) {
  const keys = [
    'AMOUNT',
    'TOTAL',
    'INCOME',
    'EXPENSE',
    'NET',
    'BALANCE',
    'REVENUE',
    'PROFIT',
    'COST',
    'QTY',
    'SOLD',
    'CASH',
    'UPI',
    'CARD',
    'WALLET',
    'DUE',
    'PAID',
    'COLLECTED',
    'FRAMES',
    'ITEMS',
    'MEMBERSHIP',
    'TOURNAMENT',
    'MINUTE',
    'PCS',
    'RATE',
    'PRICE',
    'COUNT',
    'ENTRIES',
    'WALLET',
  ];
  final u = h.toUpperCase();
  return keys.any(u.contains);
}

/// Branded A4 sheet (PrintSheetModal equivalent) → native share/print sheet.
Future<void> shareA4Pdf({
  required String fileName,
  required String clubName,
  required String title,
  String subtitle = '',
  required List<ReportTable> tables,
  List<String> footnotes = const [],
}) async {
  final headerStyle = pw.TextStyle(
    fontSize: Dimens.font8,
    fontWeight: pw.FontWeight.bold,
  );
  final cellStyle = pw.TextStyle(fontSize: Dimens.font8);
  final boldStyle = pw.TextStyle(
    fontSize: Dimens.font8_5,
    fontWeight: pw.FontWeight.bold,
  );

  pw.Widget cell(
    String text, {
    bool bold = false,
    bool right = false,
    bool head = false,
  }) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: head ? headerStyle : (bold ? boldStyle : cellStyle),
    ),
  );

  pw.Widget buildTable(ReportTable t) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (var i = 0; i < t.headers.length; i++)
              cell(
                t.headers[i],
                head: true,
                right: i > 0 && _rightCol(t.headers[i]),
              ),
          ],
        ),
        for (final r in t.rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < r.length; i++)
                cell(r[i], right: i > 0 && _rightCol(t.headers[i])),
            ],
          ),
        if (t.totalRow != null)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(
                top: pw.BorderSide(width: 0.8, color: PdfColors.grey700),
              ),
            ),
            children: [
              for (var i = 0; i < t.totalRow!.length; i++)
                cell(
                  t.totalRow![i],
                  bold: true,
                  right: i > 0 && _rightCol(t.headers[i]),
                ),
            ],
          ),
      ],
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(28),
      build:
          (ctx) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  clubName.isEmpty ? "Rowdy's Den" : clubName,
                  style: pw.TextStyle(
                    fontSize: Dimens.font15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  "powered by Rowdy's Den — Club Billing",
                  style: pw.TextStyle(
                    fontSize: Dimens.font8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Container(height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: Dimens.font13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      fontSize: Dimens.font9,
                      color: PdfColors.grey700,
                    ),
                  ),
                pw.SizedBox(height: 8),
              ],
            ),
            for (final t in tables) ...[
              if (t.heading != null)
                pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 2, top: 6),
                  child: pw.Text(
                    t.heading!.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: Dimens.font8_5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              buildTable(t),
              if (t.note != null)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    t.note!,
                    style: pw.TextStyle(
                      fontSize: Dimens.font7_5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
            ],
            for (final n in footnotes)
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  n,
                  style: pw.TextStyle(
                    fontSize: Dimens.font8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated ${DateTime.now()} · server-computed numbers',
              style: pw.TextStyle(
                fontSize: Dimens.font7_5,
                color: PdfColors.grey500,
              ),
            ),
          ],
    ),
  );
  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

// ---------------------------------------------------------------- 58mm receipt

const int receiptWidth = 30;

String receiptRule() => '-' * receiptWidth;

/// Left/right aligned mono receipt row (truncates a too-long left side).
String receiptRow(String left, String right) {
  final maxLeft = receiptWidth - right.length - 1;
  var l = left;
  if (l.length > maxLeft) l = l.substring(0, maxLeft < 0 ? 0 : maxLeft);
  final pad = receiptWidth - l.length - right.length;
  return l + ' ' * (pad < 1 ? 1 : pad) + right;
}

/// Build a 58mm thermal-style mono PDF and share/print it.
/// Lines starting with '**' render bold (markers are stripped).
Future<void> shareReceiptPdf({
  required String fileName,
  required String clubName,
  required List<String> lines,
}) async {
  final courier = pw.Font.courier();
  final courierBold = pw.Font.courierBold();
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        58 * PdfPageFormat.mm,
        297 * PdfPageFormat.mm,
        marginAll: 4 * PdfPageFormat.mm,
      ),
      build:
          (ctx) => [
            pw.Text(
              (clubName.isEmpty ? "ROWDY'S DEN" : clubName.toUpperCase()),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: courierBold, fontSize: Dimens.font12),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "powered by Rowdy's Den - Club Billing",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: courier, fontSize: Dimens.font6_5),
            ),
            pw.SizedBox(height: 4),
            for (final raw in lines)
              raw.isEmpty
                  ? pw.SizedBox(height: 4)
                  : pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      raw.startsWith('**') ? raw.substring(2) : raw,
                      style: pw.TextStyle(
                        font: raw.startsWith('**') ? courierBold : courier,
                        fontSize: Dimens.font8,
                      ),
                    ),
                  ),
          ],
    ),
  );
  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

// ---------------------------------------------------------------- receipts data

/// Item bill → 58mm mono lines (English only per spec).
List<String> itemBillReceiptLines(dynamic b) {
  final items = ((b['items'] as List?) ?? const []);
  final total = ((b['amount'] ?? 0) as num).toDouble();
  final discount = ((b['discount'] ?? 0) as num).toDouble();
  final paid = b['paid'] == true;
  // v3.21 partial mark-paid — purane bills ke liye legacy fallback
  final paidAmt = ((b['paidAmount'] ?? (paid ? total : 0)) as num).toDouble();
  final dueAmt = ((b['dueAmount'] ?? (paid ? 0 : total)) as num).toDouble();
  final partial = !paid && paidAmt > 0;
  final lines = <String>[
    receiptRule(),
    '**${receiptRow('ITEM BILL', '#${(b['id'] ?? '').toString().toUpperCase()}')}',
    (() {
      final dt = fmtDT(b['createdAt']);
      return dt.length > receiptWidth ? dt.substring(0, receiptWidth) : dt;
    })(),
    receiptRow(
      '${b['customerName'] ?? 'Walk-in'}',
      '${b['mode'] ?? ''}'.toUpperCase(),
    ),
    receiptRule(),
    for (final i in items)
      receiptRow('${i['name']} x${i['qty']}', rs(i['amount'])),
    receiptRule(),
    receiptRow('Subtotal', rs(total + discount)),
    if (discount > 0) receiptRow('Discount', '-${rs(discount)}'),
    '**${receiptRow('TOTAL', rs(total))}',
    receiptRow(
      paid
          ? 'Paid (${b['settledMode'] ?? b['mode'] ?? 'cash'})'
          : partial
          ? 'Part-paid (${b['settledMode'] ?? 'cash'})'
          : 'UNPAID - due',
      rs(paid ? total : paidAmt),
    ),
    if (partial) receiptRow('Due left', rs(dueAmt)),
    receiptRule(),
    paid
        ? 'Payment complete - thank you!'
        : partial
        ? 'Balance at counter - thank you!'
        : 'Pay at counter - thank you!',
    'Visit again · play fair',
  ];
  return lines;
}

/// Frame (table bill) → 58mm mono lines (English only per spec).
List<String> frameReceiptLines(dynamic f) {
  final players = ((f['players'] as List?) ?? const []);
  final settlements = ((f['settlements'] as List?) ?? const []);
  final items = ((f['items'] as List?) ?? const []);
  final gloves = ((f['gloves'] as List?) ?? const []);
  final winners = ((f['winners'] as List?) ?? const []);
  num itemsTotal = 0;
  for (final i in items) {
    itemsTotal += ((i['amount'] ?? 0) as num);
  }
  final minutes = ((f['durationMinutes'] ?? f['minutes'] ?? 0) as num).toInt();
  final lines = <String>[
    receiptRule(),
    '**${receiptRow('TABLE BILL', '#${(f['id'] ?? '').toString().toUpperCase()}')}',
    (() {
      final dt = fmtDT(f['createdAt']);
      return dt.length > receiptWidth ? dt.substring(0, receiptWidth) : dt;
    })(),
    receiptRow('${f['tableName'] ?? 'Table'}', '${f['matchMode'] ?? 'solo'}'),
    if (f['peak'] == true) 'Peak hours applied',
    receiptRule(),
    for (final p in players)
      receiptRow(
        '${p['label']}${p['isWinner'] == true ? ' (W)' : ''}',
        p['isWinner'] == true ? 'winner' : '',
      ),
    if (winners.isNotEmpty) ...[
      'Winner${winners.length > 1 ? 's' : ''}: ${winners.join(', ')}',
      'Winner never pays!',
    ],
    if (items.isNotEmpty) ...[
      receiptRule(),
      for (final i in items)
        receiptRow('${i['name']} x${i['qty']}', rs(i['amount'])),
    ],
    receiptRule(),
    receiptRow(
      'Table time${minutes > 0 ? ' ${minutes}m' : ''}',
      rs(f['tableAmount']),
    ),
    if (((f['membershipDiscount'] ?? 0) as num) != 0)
      receiptRow('Membership discount', '-${rs(f['membershipDiscount'])}'),
    if (((f['winnerBonus'] ?? 0) as num) != 0)
      receiptRow('Winner bonus', '+${rs(f['winnerBonus'])}'),
    if (itemsTotal != 0) receiptRow('Items on frame', rs(itemsTotal)),
    if (((f['gloveCharges'] ?? 0) as num) != 0)
      receiptRow('Gloves (${gloves.length} rented)', rs(f['gloveCharges'])),
    if (((f['advanceUsed'] ?? 0) as num) != 0)
      receiptRow('Advance used', '-${rs(f['advanceUsed'])}'),
    '**${receiptRow('TOTAL', rs(f['frameAmount']))}',
    if (((f['oldDueAmount'] ?? 0) as num) != 0)
      receiptRow('Old dues settled', rs(f['oldDueAmount'])),
    receiptRow('Paid now', rs(f['cashCollected'])),
    if (settlements.isNotEmpty) ...[
      receiptRule(),
      'Settlements:',
      for (final s in settlements)
        (() {
          final parts = <String>[
            if (((s['walletPart'] ?? 0) as num) != 0)
              'wallet ${rs(s['walletPart'])}',
            if (((s['passPart'] ?? 0) as num) != 0) 'pass ${rs(s['passPart'])}',
            if (((s['cashPart'] ?? 0) as num) != 0) 'cash ${rs(s['cashPart'])}',
            if (((s['oldDuePart'] ?? 0) as num) != 0)
              'old-due paid ${rs(s['oldDuePart'])}',
            if (((s['duePart'] ?? 0) as num) != 0) 'due ${rs(s['duePart'])}',
          ].join(' + ');
          final text = '${s['memberName'] ?? s['label']}: $parts';
          return text.length > receiptWidth
              ? text.substring(0, receiptWidth)
              : text;
        })(),
    ],
    receiptRule(),
    'Thank you - see you next frame!',
    'Play fair · winner never pays',
  ];
  return lines;
}
