import 'package:flutter/material.dart';

/// ================================================================
/// ★ Dimens — POORE APP KE SIZES KA EK HI PAGE (owner's rule, v3.24).
///
///  Heights, text sizes, paddings, radius — sab yahan. theme.dart ke
///  control themes (AppText + button/input/segment themes) yahi constants
///  use karte hain — kuch badalna ho to SIRF yahan badlo, poora app
///  update ho jayega. Units = Flutter logical pixels (dp) — iOS aur
///  Android dono pe same physical size.
///
///  INPUT fields aur DROPDOWN fields ke ALAG knobs hain (owner's note):
///  `fieldH/fieldFont` vs `dropdownH/dropdownFont` — same rakhe hain abhi,
///  par alag karna ho to bas value change karo.
///
///  ★ v3.26 — SEARCH fields ke bhi alag knobs (searchH/searchFont/
///  searchPad) — chai/due/logs/master-admin ki search rows inpe hain.
/// ================================================================
class Dimens {
  const Dimens._(); // sirf static constants — instance nahi banta

  // ---- heights --------------------------------------------------------
  /// Har MAIN button (Filled/Elevated/Outlined) — Start-timer reference.
  static const double buttonH = 42;

  /// HERO CTA buttons — Start session / Start timer (screenshot wala
  /// bada table-card button). Baaki buttons se consciously bada.
  static const double ctaH = 40;

  /// Text input fields (`TextField`) — floating-label wale fields inpe
  /// base hote hain (Add-player dialog wala owner-approved look).
  static const double fieldH = 42;

  /// Dropdown/select fields — text size ab AppText.dropdown se chhota
  /// kar diya hai, isliye effective height ≈ fieldH hi aati hai; knob
  /// alag rakha hai taake aage alag control rahe.
  static const double dropdownH = 40;

  /// Yellow/black option buttons (Solo/2v2 · Team A/B · Cash/UPI/Card/…).
  static const double segH = 40;

  /// Chhote ghost/text buttons (dense rows ke inline actions).
  static const double ghostH = 34;

  // ---- workspace tabs -------------------------------------------------
  /// Tables/Players aur Records ke top tabs. Screenshot wala generous,
  /// touch-friendly segmented tab strip — app-wide TabBar theme bhi isi ko
  /// follow karta hai.
  static const double workspaceTabBarH = 40;
  static const double workspaceTabH = 40;
  static const double workspaceTabRadius = 10;
  static const double workspaceTabInset = 4;
  static const double workspaceTabFont = 12;
  static const EdgeInsets workspaceTabOuterPad = EdgeInsets.fromLTRB(
    12,
    8,
    12,
    6,
  );

  // ---- club selector (drawer) ----------------------------------------
  /// Active Club dropdown + adjacent add button, matching the drawer design.
  static const double clubSelectorH = 25;
  static const double clubAddButtonSize = 25;
  static const double clubSelectorRadius = 6;
  static const double clubSelectorBorder = .5;
  static const double clubSelectorFont = 13;
  static const double clubSelectorIcon = 13;
  static const double clubSelectorGap = 8;
  static const double clubDrawerMaxWidth = 300;
  static const EdgeInsets clubSelectorPad = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );
  static const EdgeInsets clubMetaPad = EdgeInsets.fromLTRB(22, 8, 22, 10);

  // ---- metric / money cards ------------------------------------------
  /// Shared by every [StatTile]: dashboard, tables, reports, dues and
  /// finance cards. Change these three values to tune card typography app-wide.
  static const double statCardTitleFont = 10;
  static const double statCardMoneyFont = 13;
  static const double statCardSubtitleFont = 10;

  // ---- complete type scale -------------------------------------------
  /// All remaining app text styles use this scale. Keep a value here instead
  /// of writing a numeric `fontSize` in a screen, so typography is tunable
  /// from this one file.
  static const double font6_5 = 6.5;
  static const double font7_5 = 7.5;
  static const double font8 = 8;
  static const double font8_5 = 8.5;
  static const double font9 = 10;
  static const double font9_5 = 9.5;
  static const double font10 = 10;
  static const double font10_5 = 10.5;
  static const double font11 = 11;
  static const double font11_5 = 12;
  static const double font12 = 12;
  static const double font12_5 = 12.5;
  static const double font13 = 13;
  static const double font13_5 = 13.5;
  static const double font14 = 14;
  static const double font15 = 15;
  static const double font16 = 16;
  static const double font17 = 17;
  static const double font18 = 18;
  static const double font19 = 19;
  static const double font21 = 21;
  static const double font23 = 23;
  static const double font27 = 27;

  // ---- text sizes (AppText in theme.dart inhi se banta hai) -----------
  static const double btnFont = 12.5;
  static const double controlFont = 12;
  static const double fieldFont = 13.5;
  static const double dropdownFont = 13;

  // ---- radii ----------------------------------------------------------
  static const double radius = 6;
  static const double radiusCard = 10;

  // ---- spacing --------------------------------------------------------
  static const double gapSm = 6;
  static const double gap = 8;
  static const double gapLg = 3;

  // ---- paddings -------------------------------------------------------
  /// Primary/elevated/filled button padding.
  static const EdgeInsets btnPad = EdgeInsets.symmetric(horizontal: 5);

  /// Individual padding tokens for the other shared button families.
  static const EdgeInsets outlineBtnPad = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets ghostBtnPad = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );
  static const EdgeInsets segmentedBtnPad = EdgeInsets.symmetric(
    horizontal: 10,
  );

  /// Single-line TextField ≈ [fieldH] (12.5px text + 14px vertical pad).
  static const EdgeInsets fieldPad = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 9,
  );

  // ---- SEARCH fields (ALAG knobs — owner's rule v3.26) ----------------
  /// Search bars (Players / Due Desk / Logs / Item Bills / Master Admin) —
  /// list ke upar dense search row, normal input se thodi patli.
  static const double searchH = 42;

  /// Search field ka typed text (thoda chhota — dense list feel).
  static const double searchFont = 13;

  /// Search field ka content padding (prefix icon ke saath centered rahe).
  static const EdgeInsets searchPad = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
  );
}
