import 'dart:convert';

import 'package:flutter/material.dart';

import 'dimensions.dart';
import 'theme.dart';

OverlayEntry? _topToast;

/// Displays a club logo saved either as a normal URL or as the data-URL
/// produced by the logo picker.  Keeping this in one place makes the logo
/// look identical in Settings and in the drawer header.
class ClubLogo extends StatelessWidget {
  final String logo;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;

  const ClubLogo({
    super.key,
    required this.logo,
    this.size = 44,
    this.borderRadius = 8,
    this.fallbackIcon = Icons.storefront_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = logo.trim();
    final fallback = Icon(fallbackIcon, size: size * .45, color: c.textMuted);
    Widget child = fallback;

    if (image.isNotEmpty) {
      if (image.startsWith('data:')) {
        try {
          child = Image.memory(
            base64Decode(image.substring(image.indexOf(',') + 1)),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        } catch (_) {
          // Invalid old data-URLs fall back to the standard shop icon.
        }
      } else {
        child = Image.network(
          image,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.bgMuted,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  final c = context.colors;
  // A SnackBar sits at the bottom Scaffold, which is obscured by an open
  // dialog/bottom sheet. Put validation feedback above that modal instead.
  if (ModalRoute.of(context) is PopupRoute) {
    _topToast?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry =
        _topToast = OverlayEntry(
          builder:
              (ctx) => Positioned(
                top: MediaQuery.paddingOf(ctx).top + 10,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: error ? c.red : c.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          error
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 18,
                          color: error ? c.red : c.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (_topToast == entry) {
        entry.remove();
        _topToast = null;
      }
    });
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: error ? c.red : c.border),
        ),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 16,
              color: error ? c.red : c.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(color: c.text, fontSize: Dimens.font13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color tone;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.tone = Colors.green,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: Dimens.statCardTitleFont,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone,
                    fontSize: Dimens.statCardMoneyFont,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!
                        .split(' ')
                        .map(
                          (word) =>
                              word.isEmpty
                                  ? word
                                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
                        )
                        .join(' '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textMuted,
                      fontWeight: FontWeight.w400,
                      fontSize: Dimens.statCardSubtitleFont,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ToneBadge extends StatelessWidget {
  final String text;
  final Color tone;
  const ToneBadge(this.text, this.tone, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: tone,
          fontSize: Dimens.font10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    this.hint = '',
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          // ★ v3.25 — parent Column crossAxis.start me bhi full-width stretch →
          // "No entries yet" hamesha visually centered rahe.
          const SizedBox(width: double.infinity),
          Icon(icon, color: c.textMuted, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: Dimens.font13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 8-ball loader (brand mascot from the web app).
class EightBallLoader extends StatefulWidget {
  final String label;
  const EightBallLoader({super.key, this.label = ''});

  @override
  State<EightBallLoader> createState() => _EightBallLoaderState();
}

class _EightBallLoaderState extends State<EightBallLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctl,
            builder:
                (_, child) => Transform.translate(
                  offset: Offset(0, -10 + 20 * _ctl.value),
                  child: child,
                ),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.35),
                  colors: [
                    Color(0xFF3D4450),
                    Color(0xFF14161C),
                    Color(0xFF05060A),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '8',
                  style: TextStyle(
                    color: Color(0xFF14161C),
                    fontWeight: FontWeight.w800,
                    fontSize: Dimens.font12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.label.isNotEmpty)
            Text(
              widget.label,
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font12),
            ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Small caption used above form fields (9px caps, muted).
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, top: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: Dimens.font9,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String hhmmss(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

// ------------------------------------------------------------------ dates
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "2026-08-11" / ISO → "11 Aug 26"
String fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.day} ${_months[d.month - 1]} ${(d.year % 100).toString().padLeft(2, '0')}';
}

/// ISO → "11 Aug · 4:32 PM" (local)
String fmtDT(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return raw;
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} · $h12:$mm $ampm';
}

/// "2026-08" → "Aug 2026"
String ymLabel(String ym) {
  final p = ym.split('-');
  if (p.length != 2) return ym;
  final m = int.tryParse(p[1]) ?? 1;
  return '${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
}

/// Local today as YYYY-MM-DD.
String todayStr([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
}

/// Current month YYYY-MM.
String thisMonth([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year}-${x.month.toString().padLeft(2, '0')}';
}

// ------------------------------------------------------------ date pickers
Future<String?> pickDate(BuildContext context, String current) async {
  final now = DateTime.now();
  final init = DateTime.tryParse(current) ?? now;
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(2024),
    lastDate: DateTime(now.year + 1, 12, 31),
  );
  return d == null ? null : todayStr(d);
}

Future<String?> pickMonth(BuildContext context, String current) async {
  final now = DateTime.now();
  final init = DateTime.tryParse('$current-01') ?? now;
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(2024),
    lastDate: DateTime(now.year + 1, 12, 31),
    initialDatePickerMode: DatePickerMode.year,
  );
  return d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// Shared confirm bottom-sheet — saare "sure?" pop-ups isi style me
/// (chat-box jaisa, neeche se slide-in). Returns true on confirm.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      final tone = destructive ? c.red : c.green;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      destructive ? Icons.delete_outline : Icons.help_outline,
                      size: 16,
                      color: tone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: Dimens.font14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: Dimens.font11_5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              // ★ v3.23 — confirm + cancel EK HI ROW me (owner's rule).
              actionPair(
                ctx,
                primaryLabel: confirmLabel,
                destructive: destructive,
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok == true;
}

/// ================================================================
/// ★ actionPair (v3.23) — dialog/bottom-sheet ka bottom button row:
/// [ PRIMARY (solid green / destructive red) ]  gap  [ Cancel (outline) ]
/// EK HI ROW me, equal width, theme heights (Dimens.buttonH) — iOS
/// aur Android dono pe same. Green ka text theme-aware `colors.onGreen`
/// (light = white, dark = near-black) — web `.btn-green` parity.
/// ================================================================
Widget actionPair(
  BuildContext ctx, {
  required String primaryLabel,
  IconData? primaryIcon,
  bool destructive = false,
  bool loading = false,
  String cancelLabel = 'Close',
  VoidCallback? onPrimary,
  VoidCallback? onCancel,
}) {
  final c = ctx.colors;
  return Row(
    children: [
      Expanded(
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? c.red : c.green,
            foregroundColor: destructive ? Colors.white : c.onGreen,
          ),
          onPressed:
              loading ? null : (onPrimary ?? () => Navigator.pop(ctx, true)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (primaryIcon != null) ...[
                Icon(primaryIcon, size: 15),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(primaryLabel, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton(
          onPressed:
              loading ? null : (onCancel ?? () => Navigator.pop(ctx, false)),
          child: Text(cancelLabel, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
  );
}
