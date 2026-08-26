import 'package:flutter/material.dart';

import 'dimensions.dart';

/// Material 3 tokens mapped 1:1 to the web app's global.css (owner-final).
/// Dark theme is the default; light available via toggle.
///
/// ★ v4.0 — PALETTE swap (owner's design): warm gold (#D4A017) accent on
///   near-black charcoal (#0C0C0D/#141416/#1C1C1F), cream text (#F2EFE8).
///   Structure/logic unchanged — only AppColors.dark/.light values updated,
///   everything else (buttons, inputs, cards…) reads from these same tokens.
///
/// ★ v3.22 — BUTTON + FIELD polish pass (owner's review):
///   • Har button ab web-global.css jaisa OUTLINED look rakhta hai —
///     · ElevatedButton  = `.btn`           (muted fill + 1px border-strong)
///     · OutlinedButton  = Upload-Logo look (transparent + 1px border-strong)
///     · TextButton      = ghost-outline    (Remove-Logo jaisi jagahon pe
///                                          ab halka border aata hai)
///     · FilledButton    = ekloota solid    (sirf primary CTAs — green)
///   • Button text pehle se halka (w600) — "light bold", w700/w800 sirf
///     values/titles ke liye.
///   • Input / select fields compact web-scale (dense, 6px radius,
///     border → green focus ring), dropdown/dialog/bottom-sheet sab
///     theme tokens follow karte hain — light aur dark dono me sahi.
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color bgElevated;
  final Color bgMuted;
  final Color bgHover;
  final Color bgInput;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color green;
  final Color red;
  final Color gold;
  final Color blue;

  /// Brand-green button ke upar ka TEXT — web `.btn-green` parity (owner's
  /// rule v3.23): dark theme me near-black text, light theme me white.
  final Color onGreen;

  /// Gold button ke upar ka TEXT — same owner rule: dark theme me near-black
  /// brown (#1A1305 — web parity), light theme me white.
  final Color onGold;

  const AppColors({
    required this.bg,
    required this.bgElevated,
    required this.bgMuted,
    required this.bgHover,
    required this.bgInput,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.green,
    required this.red,
    required this.gold,
    required this.blue,
    required this.onGreen,
    required this.onGold,
  });

  // == Owner palette v4 — warm gold/charcoal "Rowdy's Den" look =============
  static const dark = AppColors(
    bg: Color(0xFF0C0C0D),
    bgElevated: Color(0xFF141416),
    bgMuted: Color(0xFF1C1C1F),
    bgHover: Color(0xFF242428),
    bgInput: Color(0xFF121214),
    border: Color(0xFF2A2A2E),
    borderStrong: Color(0xFF3A3A3E),
    text: Color(0xFFF2EFE8),
    textSecondary: Color(0xFFC7C2B8),
    textMuted: Color(0xFF8B8680),
    green: Color(0xFF3DBA6E),
    red: Color(0xFFE05A4F),
    gold: Color(0xFFD4A017),
    blue: Color(0xFF5B8DEF),
    onGreen: Color(0xFF0D1208),
    onGold: Color(0xFF0C0C0D),
  );

  // == Owner palette v4 — light companion (same brand, warm-cream base) =====
  static const light = AppColors(
    bg: Color(0xFFF7F5F0),
    bgElevated: Color(0xFFFFFFFF),
    bgMuted: Color(0xFFEFEBE2),
    bgHover: Color(0xFFE8E2D5),
    bgInput: Color(0xFFFFFFFF),
    border: Color(0xFFE0DAC8),
    borderStrong: Color(0xFFC9C0A8),
    text: Color(0xFF1A1815),
    textSecondary: Color(0xFF5C574C),
    textMuted: Color(0xFF7A756B),
    green: Color(0xFF2F9E5B),
    red: Color(0xFFC94A3F),
    gold: Color(0xFFB8860B),
    blue: Color(0xFF3B6FD9),
    onGreen: Color(0xFFFFFFFF),
    onGold: Color(0xFFFFFFFF),
  );

  Color soft(Color tone) => tone.withValues(alpha: 0.14);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppThemeX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

class AppTheme {
  static ThemeData _base(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.green,
      // web .btn-green: dark theme me near-black text, light me white
      onPrimary: c.onGreen,
      secondary: c.gold,
      onSecondary: const Color(0xFF1A1305),
      surface: c.bgElevated,
      onSurface: c.text,
      error: c.red,
      onError: Colors.white,
      surfaceContainerHighest: c.bgMuted,
      outline: c.border,
      outlineVariant: c.border,
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      // popups ke liye (Dropdown menu, Drawer) elevated surface — Material ka
      // default purple-ish tint dono themes me galat lagta tha.
      canvasColor: c.bgElevated,
      extensions: [c],
      dividerColor: c.border,
      fontFamily: 'Inter',
      // ★ v3.24 — DropdownButton/FormField ka text default yahi se aata hai
      // (titleLarge) — pehle 16px ka bada text + badi height aati thi. Ab
      // dropdown aur input dono ek hi compact size pe.
      textTheme: (brightness == Brightness.dark
              ? ThemeData.dark()
              : ThemeData.light())
          .textTheme
          .copyWith(
            titleLarge: AppText.dropdown.copyWith(color: c.text),
            bodyLarge: AppText.field.copyWith(color: c.text),
            // Dropdown popup menu items DefaultTextStyle = bodyMedium use
            // karte hain — warna overlay me bada default text aata hai.
            bodyMedium: AppText.dropdown.copyWith(color: c.text),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgElevated,
        foregroundColor: c.text,
        elevation: 0,
        centerTitle: false,
        // ★ v3.26 — back-button aur title ke beech ka gap kam (owner's note;
        // default 16 bahut khulla lagta tha).
        titleSpacing: 8,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: Dimens.font17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ================================================================ //
      // ★ BUTTONS — sab web-global.css scale pe (bordered, w600 text)    //
      // ================================================================ //

      // `.btn` — web ka default action button: muted fill + border-strong.
      // (Pehle elevatedButtonTheme define hi nahi tha → Material ka default
      // khoobsurat-sa purple tonal button ghus jata tha. Fixed.)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(c.bgMuted),
          foregroundColor: WidgetStatePropertyAll(c.text),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimens.radius),
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
          padding: const WidgetStatePropertyAll(Dimens.btnPad),
          textStyle: const WidgetStatePropertyAll(AppText.button),
          minimumSize: const WidgetStatePropertyAll(Size(0, Dimens.buttonH)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),

      // `.btn-outline` / Upload-Logo look — transparent + border-strong.
      // (Pehle `side` set hi nahi tha → Material ka apna grey-purple border.)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.text),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimens.radius),
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
          padding: const WidgetStatePropertyAll(Dimens.outlineBtnPad),
          textStyle: const WidgetStatePropertyAll(AppText.control),
          minimumSize: const WidgetStatePropertyAll(Size(0, Dimens.buttonH)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),

      // ★ Owner's rule: "Remove Logo jaisi plain buttons bhi WITH OUTLINE".
      // TextButton bhi ab ghost-outline hai (transparent + border-strong) —
      // foreground intentionally secondary rakha hai taaki jo screens
      // red/danger foreground dete hain (Remove Logo, Delete…) wo red text +
      // border ke saath outlined danger-button jaisa dikhe.
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.textSecondary),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
          padding: const WidgetStatePropertyAll(Dimens.ghostBtnPad),
          textStyle: const WidgetStatePropertyAll(AppText.control),
          minimumSize: const WidgetStatePropertyAll(Size(0, Dimens.ghostH)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),

      // Ekloota SOLID button — sirf primary CTA (Start / Confirm / Save).
      // ★ v3.23: green CTA ka text theme-aware onGreen (light = white,
      // dark = near-black) — web `.btn-green` parity. Weight w600 (light bold).
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(c.green),
          foregroundColor: WidgetStatePropertyAll(c.onGreen),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimens.radius),
            ),
          ),
          padding: const WidgetStatePropertyAll(Dimens.btnPad),
          textStyle: const WidgetStatePropertyAll(AppText.button),
          minimumSize: const WidgetStatePropertyAll(Size(0, Dimens.buttonH)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),

      // ★ Yellow/black option buttons (Solo/2v2 · Team A/B · Cash/UPI/Card) —
      // height CTA jitni (Dimens.segH), selected = GOLD fill + dark text
      // (owner's screenshots wala look), unselected = transparent + border.
      segmentedButtonTheme: SegmentedButtonThemeData(
        selectedIcon: const SizedBox.shrink(), // ★ v3.24 — tick icon hata diya
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.gold : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected)
                    ? const Color(0xFF1A1305)
                    : c.textSecondary,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.selected) ? c.gold : c.borderStrong,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimens.radius),
            ),
          ),

          padding: const WidgetStatePropertyAll(Dimens.segmentedBtnPad),
          textStyle: const WidgetStatePropertyAll(AppText.control),
          minimumSize: const WidgetStatePropertyAll(Size(0, Dimens.segH)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),

      // Workspace tabs (Tables / Players etc.) share one scale. Individual
      // tab surfaces can provide their own indicator color, but dimensions
      // always come from Dimens.
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: c.text,
        unselectedLabelColor: c.textMuted,
        labelStyle: const TextStyle(
          fontSize: Dimens.workspaceTabFont,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: Dimens.workspaceTabFont,
          fontWeight: FontWeight.w500,
        ),
      ),

      // IconButtons ko chhota muted tile jaisa (web .btn-icon) — lekin
      // border NAHI (dense toolbars me clutter ho jata), sirf hover bg.
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.textSecondary),
          iconSize: const WidgetStatePropertyAll(18),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),

      // ================================================================ //
      // ★ INPUTS / SELECTS — web `.input` scale (compact, green focus)   //
      // ================================================================ //
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: c.bgInput,
        contentPadding: Dimens.fieldPad,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.green, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.red, width: 1.4),
        ),
        hintStyle: AppText.hint(c),
        labelStyle: AppText.inputLabel(c),
        floatingLabelStyle: TextStyle(
          color: c.textMuted,
          fontSize: Dimens.font11,
        ),
        helperStyle: TextStyle(color: c.textMuted, fontSize: Dimens.font10_5),
        errorStyle: TextStyle(color: c.red, fontSize: Dimens.font10_5),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
      ),
      // Dropdown (select) fields inputDecorationTheme follow karte hain;
      // unka popup canvasColor (upar) se elevated-surface pe aata hai.
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          color: c.text,
          fontSize: Dimens.font11,
          fontWeight: FontWeight.w500,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.bgElevated),
          elevation: const WidgetStatePropertyAll(2),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: c.border),
            ),
          ),
        ),
      ),

      // ================================================================ //
      // Baaki shells — sab tokens se, dono themes me consistent          //
      // ================================================================ //
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bgElevated,
        height: 56,
        indicatorColor: c.green.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 19,
            color: s.contains(WidgetState.selected) ? c.green : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: Dimens.font10_5,
            fontWeight:
                s.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.green : c.textMuted,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(
          color: c.text,
          fontSize: Dimens.font12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgElevated,
        contentTextStyle: TextStyle(
          color: c.text,
          fontSize: Dimens.font13,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        // web modal-title = 12px bold — Material default 20px title bahut bada tha
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: Dimens.font14,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: c.textSecondary,
          fontSize: Dimens.font12,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }

  static ThemeData dark() => _base(AppColors.dark, Brightness.dark);
  static ThemeData light() => _base(AppColors.light, Brightness.light);
}

/// ================================================================
/// ★ AppText (v3.24) — poore app ke TEXT STYLES ek hi jagah.
/// Sizes Dimens se linked; "light bold" (w600) weight rule follow.
/// Color-dependence ho to function versions use karo.
/// ================================================================
class AppText {
  const AppText._();

  /// Solid/CTA buttons (Start session, Save, Confirm…)
  static const TextStyle button = TextStyle(
    fontSize: Dimens.btnFont,
    fontWeight: FontWeight.w600,
  );

  /// Chhote controls — ghost text buttons, outlined buttons, option segments.
  static const TextStyle control = TextStyle(
    fontSize: Dimens.controlFont,
    fontWeight: FontWeight.w600,
  );

  /// Input fields ka typed text.
  static const TextStyle field = TextStyle(
    fontSize: Dimens.fieldFont,
    fontWeight: FontWeight.w500,
  );

  /// Dropdown/select fields ka text (fields se ALAG knob — owner's note;
  /// pehle default 16px titleLarge aata tha, isliye bahut bada lagta tha).
  static const TextStyle dropdown = TextStyle(
    fontSize: Dimens.dropdownFont,
    fontWeight: FontWeight.w500,
  );

  /// Placeholder / hint text.
  static TextStyle hint(AppColors c) => TextStyle(
    color: c.textMuted,
    fontSize: Dimens.font12_5,
    fontWeight: FontWeight.w300,
  );

  /// Field labels (floating LabelText).
  static TextStyle inputLabel(AppColors c) => TextStyle(
    color: c.textMuted,
    fontSize: Dimens.font11,
    fontWeight: FontWeight.w500,
  );
}

/// ₹ formatting consistent with the backend (2dp, no noise) + Indian grouping.
String fmtMoney(num? v) {
  final d = (v ?? 0).toDouble();
  final r = (d * 100).roundToDouble() / 100;
  return '₹${_inGroup(r == r.truncateToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2))}';
}

String fmtNum(num? v) {
  final d = (v ?? 0).toDouble();
  final r = (d * 100).roundToDouble() / 100;
  return _inGroup(
    r == r.truncateToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2),
  );
}

/// en-IN digit grouping without the intl package: 2000 → 2,000 · 123456.5 → 1,23,456.50
String _inGroup(String raw) {
  final neg = raw.startsWith('-');
  final s = neg ? raw.substring(1) : raw;
  final dot = s.indexOf('.');
  final whole = dot == -1 ? s : s.substring(0, dot);
  final frac = dot == -1 ? '' : s.substring(dot);
  if (whole.length <= 3) return '${neg ? '-' : ''}$whole$frac';
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${neg ? '-' : ''}${parts.join(',')},$last3$frac';
}
