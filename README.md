# Rowdy's Den — Club Billing (Flutter app)

Companion app for the FastAPI billing engine (`../backend`). The **backend is the
only authoritative calculator** — the app shows client-side estimates while a
session runs, but every final number comes from the server (confirm-bill,
item bills, due collections, reports).

Dark theme is the product default, per the design system.

## Requirements

- Flutter **3.29+** (`sdk: >=3.7.0`) — `Color.withValues` + `CardThemeData`/`DialogThemeData`.
  (Build verified against Flutter **3.44.8 / Dart 3.12.2**, August 2026.)
- Deps: `google_sign_in ^7.2.0` (7.x `instance/initialize/authenticate` API),
  `excel ^4.0.6`, `pdf ^3.12.0` + `printing ^5.14.2`, `share_plus ^11.1.0`,
  `path_provider ^2.1.5` — §30 exports: real multi-sheet .xlsx + A4/58mm PDFs
  + native share sheet, all built on-device (backend stays the calculator).
  (`pdf` is pinned <3.13 because 3.13+ needs `xml ^7` while `excel` needs `xml <7`;
  `share_plus` is pinned ^11 because 13.x needs Dart >=3.10 / Flutter >=3.38.)
- A running backend (see `../backend/README.md`).

## Setup

```bash
cd flutter_app
flutter pub get
```

## Run

### Android emulator (backend on your machine)

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api
```

### iOS simulator / desktop / Chrome

```bash
flutter run --dart-define=API_URL=http://localhost:8000/api
```

### Production backend

```bash
flutter run --dart-define=API_URL=https://den-server-omega.vercel.app/api
```

### Google sign-in (React website + app dono ek saath)

Architecture ye hai: **web client ID (React wala) har jagah audience rahega**,
aur app ke native clients sirf Google ke sign-in flow ko allow karte hain.

1. **Usi Google Cloud project** mein jahan React ka web client hai:
   - Existing **Web client** ko touch mat karo — React + backend verification dono usi par chalte hain.
   - Naya **Android OAuth client** banao: package name = `applicationId`
     (`android/app/build.gradle` mein, default `com.example.rowdys_den_app`)
     + SHA-1 fingerprint:
     ```bash
     cd android && ./gradlew signingReport   # debug keystore ka SHA-1 copy karo
     ```
   - iOS ke liye **iOS OAuth client** banao (bundle id = Xcode/Runner wali).
2. **Backend `.env`** (dono jagah — local aur Vercel env):
   ```env
   GOOGLE_CLIENT_ID=<web client — waise ka waisa, React wala>
   GOOGLE_CLIENT_IDS=<android client id>,<ios client id>   # comma-separated, optional
   ```
   Backend ab token ka audience in sab mein se **kisi bhi ek** se match karta hai.
3. **App chalao** — dart-define mein hamesha **web** client ID (ye
   `serverClientId` ban jaata hai, isliye token backend se match karta hai):
   ```bash
   # Android
   flutter run \
     --dart-define=API_URL=http://10.0.2.2:8000/api \
     --dart-define=GOOGLE_CLIENT_ID=<web client id>
   # iOS — apna iOS client id bhi do
   flutter run \
     --dart-define=API_URL=http://localhost:8000/api \
     --dart-define=GOOGLE_CLIENT_ID=<web client id> \
     --dart-define=GOOGLE_IOS_CLIENT_ID=<ios client id>
   ```
4. **iOS extra step**: `ios/Runner/Info.plist` mein `GIDClientID` (iOS client id)
   aur `CFBundleURLTypes` mein **reversed client id**
   (`com.googleusercontent.apps.<...>`) add karna hota hai — google_sign_in
   plugin docs ka standard step.

Without `GOOGLE_CLIENT_ID` the Google button shows an error hint; if the
backend runs with `AUTH_DEV_MODE=true`, a dev email login appears instead
(handy for testing before OAuth is wired up).

#### "Google sign-in failed" / `ApiException: 10` (DEVELOPER_ERROR) checklist

Kaam karte hue order mein check karo:

1. **`serverClientId` = WEB client id hi hona chahiye** (React wala
   `375395125425-st5ba...`). Android/iOS client id yahan daalne se yahi
   error aata hai. Web id `config.dart` mein default bana di gayi hai.
2. **Android OAuth client (console) ka SHA-1 match kare**: Google Cloud →
   APIs & Services → Credentials → Android client → package name =
   `android/app/build.gradle` ka `applicationId` + SHA-1:
   ```bash
   cd android && ./gradlew signingReport   # Variant: debug → SHA-1 copy karo
   ```
   Release ke liye release keystore ka SHA-1 bhi alag se add karna hoga.
3. **OAuth consent screen**: agar "Testing" mode mein hai to tumhara Gmail
   Test users mein add ho.
4. **Backend restart** after `.env` edits (config process start par padhta hai).
5. Emulator par backend reach karne ke liye: `--dart-define=API_URL=http://10.0.2.2:8000/api`
   ya phir `adb reverse tcp:8000 tcp:8000` (tab localhost chalega).
6. App ab error ke saath underlying detail bhi dikhata hai — `ApiException: 10`
   dikhe to step 1-2 galat hain.

## Structure

```
lib/
  main.dart                 entrypoint + auth/subscription routing, dark theme
  src/
    config.dart             --dart-define API_URL / GOOGLE_CLIENT_ID
    theme.dart              §2.1 dark / §2.2 light tokens (Material 3)
    api.dart                Api client + readable ApiException (401/402/403/-1)
    models.dart             plain-Dart models mirroring the API payloads
    session.dart            SessionController (token/user/clubs) + ClubController (/data)
    offline_queue.dart      counter item-sales queue (SharedPreferences) + auto-sync
    widgets.dart            StatTile, ToneBadge, EmptyState, EightBallLoader, …
    insights.dart           ✨ Smart Insights rule engine (live estimate, stock,
                            due-pressure, wallets, expiring plans, tournaments)
    rowdy_care.dart         ✨ Rowdy Care chat sheet — ONLINE badge, quick-topic
                            chips, typing dots, Hinglish rule replies, human
                            handoff (live contact from /platform/support)
    screens/
      login_screen.dart           Google + dev login
      subscription_screen.dart    402 wall: onboarding / renewal
      shell.dart                  5 tabs (Tables/Players/Due/Items/More), alerts
                                  bell, club switcher, Rowdy Care FAB
      tables_screen.dart          start/stop/cancel sessions, live 1s timer,
                                  estimates, items, advance, note, move,
                                  gloves (start chips + return toggles),
                                  winner chips, discounts, frame-pass chips,
                                  final bill sheet + gloves row
      players_screen.dart         members, wallet collect, plan sales
      due_desk_screen.dart        dues sorted high→low, wa.me reminders, insights
      items_screen.dart           counter sales, member/unpaid flow, offline queue
      item_bills_screen.dart      bill history, receipt preview (58mm style),
                                  mark-paid (mode), delete w/ reversal
      frames_screen.dart          month filter, totals, settlements, gloves,
                                  winner-correction sheet (full server re-bill)
      logs_screen.dart            tag filter (All/Billing/Payment/Warning/Admin),
                                  search, timeline
      tournaments_screen.dart     list + create/edit (format locked), entries,
                                  bracket/fixtures, On Table timer, score-only,
                                  results, league standings, champion banner
      more_screen.dart            hub — mirrors the web sidebar, role-filtered
      day_close_screen.dart       collected/expenses/net/pending-due, mode+source
                                  rows, ops snapshot, top items, closing drawer
      monthly_screen.dart         source totals (incl tournaments), transactions
      finance_screen.dart         P&L, balance sheet, stock profit, daily sheet,
                                  utilisation + peak hours
      expenses_screen.dart        month, category chips, add/delete, auto-stock
      team_screen.dart            club staff (owner-only, masters never listed)
      master_admin_screen.dart    gold panel — overview, users + subscriptions,
                                  seller plans CRUD, club subs, support contact,
                                  mailouts
      info_screens.dart           Human Support (live contact, FAQ), Privacy, Terms
      settings_screen.dart        profile, club settings, Table Pricing CRUD,
                                  Membership Plans CRUD, data export (all-in-one
                                  .xlsx, per-entity .xlsx, Full Backup JSON),
                                  help links, about, sign out
      exporter.dart (src)         §30 engine — shareXlsx / shareJson /
                                  shareA4Pdf (branded bordered tables) /
                                  shareReceiptPdf (58mm Courier) via
                                  excel + pdf + printing + share_plus.
                                  Wired into Settings, Finance (P&L/Daily/
                                  Stock .xlsx + P&L PDF), Monthly
                                  (Transactions/Per-day .xlsx + Month PDF),
                                  Day Close (closing slip PDF), Item Bills &
                                  Frames (58mm receipt PDF/print).
assets/icon.png             app icon (also used by login/about screens)
```

## Behaviour notes

- **Role-aware UI**: staff accounts get operations-only tabs; admin money
  surfaces render an "Admin area — owner access required" card (mirrors the
  backend 403).
- **Subscription lock (402)**: any 402 from the backend flips the app into the
  subscription screen; billing actions are server-enforced regardless.
- **Estimates only**: the live table card mirrors the server's pricing formula
  per minute, but the bill you confirm is always computed server-side.
- **Offline counter sales**: item sales made without connectivity are queued
  locally and replayed with a `(N pending)` badge when the API is reachable.
