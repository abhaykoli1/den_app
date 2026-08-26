import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';

/// App-wide session state: token, user, clubs, active club selection.
class SessionController extends ChangeNotifier {
  final Api api;
  AppUser? user;
  List<Club> clubs = [];
  String? activeClubId;
  bool restoring = true;
  bool busy = false;
  String? lastError;
  bool devMode = false;

  /// Public rebuild trigger for screens that mutate session state directly.
  void broadcast() => notifyListeners();

  bool subscriptionLocked = false;

  /// Dark is the product default; the header sun/moon icon flips it (persisted).
  bool darkMode = true;

  /// Global text scaling. 1.0 preserves the app's original default sizing.
  double textScale = 1.0;

  /// First-run intro — shown once before login.
  bool showOnboarding = false;

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rd_theme', darkMode ? 'dark' : 'light');
  }

  Future<void> setTextScale(double value) async {
    textScale = value.clamp(0.85, 1.25);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('rd_text_scale', textScale);
  }

  Future<void> completeOnboarding() async {
    showOnboarding = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rd_seen_onboarding', true);
  }

  SessionController(this.api);

  Club? get activeClub {
    if (activeClubId == null) return clubs.isEmpty ? null : clubs.first;
    for (final c in clubs) {
      if (c.id == activeClubId) return c;
    }
    return clubs.isEmpty ? null : clubs.first;
  }

  bool get isLoggedIn => api.isLoggedIn && user != null;

  bool hasUsableSubscription(Map<String, dynamic>? sub) {
    final status = (sub?['status'] ?? '').toString().toLowerCase();
    if (status != 'trial' && status != 'active') return false;
    final expiresAt = sub?['expiresAt']?.toString();
    if (expiresAt == null || expiresAt.isEmpty) return true;
    try {
      final expires = DateTime.parse(expiresAt.replaceFirst('Z', '+00:00'));
      return expires.isAfter(DateTime.now().toUtc());
    } catch (_) {
      return false;
    }
  }

  /// Every new club owner must choose a plan before entering the workspace.
  /// Master accounts and staff use their existing club owner's subscription.
  bool get needsSubscriptionSetup {
    if (!isLoggedIn || user!.isMaster || user!.isStaff) return false;
    return !hasUsableSubscription(user!.subscription);
  }

  Future<void> refreshAccount() async {
    user = AppUser.fromJson(
      Map<String, dynamic>.from(await api.get('/auth/me')),
    );
    await loadClubs();
    notifyListeners();
  }

  Future<void> restore() async {
    restoring = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      api.token = prefs.getString('rd_token');
      activeClubId = prefs.getString('rd_active_club');
      darkMode = prefs.getString('rd_theme') != 'light';
      textScale = (prefs.getDouble('rd_text_scale') ?? 1.0).clamp(0.85, 1.25);
      try {
        final dm = await api.get('/auth/dev-mode');
        devMode = dm is Map && dm['devMode'] == true;
      } catch (_) {
        /* backend down — login screen shows the form anyway */
      }
      if (api.isLoggedIn) {
        user = AppUser.fromJson(
          Map<String, dynamic>.from(await api.get('/auth/me')),
        );
        await loadClubs();
      }
    } on ApiException catch (e) {
      if (e.isAuth) await signOut(silent: true);
    } catch (_) {
      /* keep login screen */
    }
    api.onUnauthorized = () => signOut(silent: true);
    restoring = false;
    notifyListeners();
  }

  Future<bool> signInGoogle() async {
    if (AppConfig.googleClientId.isEmpty) {
      lastError = 'Google sign-in not configured (GOOGLE_CLIENT_ID missing)';
      notifyListeners();
      return false;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final gs = GoogleSignIn.instance;
      // serverClientId = WEB client (React wala hi) → token audience backend
      // se match karta hai. clientId SIRF iOS par; Android apna client
      // package-name + SHA-1 se console mein auto-resolve karta hai.
      await gs.initialize(
        serverClientId: AppConfig.googleClientId,
        clientId:
            !kIsWeb && Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty
                ? AppConfig.googleIosClientId
                : null,
      );
      if (!gs.supportsAuthenticate()) {
        throw const ApiException(
          400,
          'Is device par Google sign-in flow supported nahi hai',
        );
      }
      final GoogleSignInAccount account = await gs.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(401, 'Google did not return an id token');
      }
      final data = await api.post('/auth/google', {'idToken': idToken});
      await _acceptLogin(Map<String, dynamic>.from(data));
      return true;
    } on GoogleSignInException catch (e) {
      // HAMESHA console mein log karo (ya cancel ho ya config error) —
      // flutter run ka output paste karke exact reason dekha ja sake.
      debugPrint(
        '[rd] google-signin: code=${e.code} · desc=${e.description} · details=${e.details}',
      );
      // user ne sheet band kar di → UI mein koi error mat dikhao
      if (e.code != GoogleSignInExceptionCode.canceled) {
        lastError = 'Google sign-in failed — ${e.description ?? e.code.name}';
      }
    } on ApiException catch (e) {
      lastError = e.message;
    } catch (e) {
      debugPrint('[rd] google-signin: unexpected: $e');
      lastError = 'Google sign-in failed — $e';
    }
    busy = false;
    notifyListeners();
    return false;
  }

  Future<bool> signInDev(String email, {String name = ''}) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final data = await api.post('/auth/dev', {'email': email, 'name': name});
      await _acceptLogin(Map<String, dynamic>.from(data));
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
    }
    busy = false;
    notifyListeners();
    return false;
  }

  Future<void> _acceptLogin(Map<String, dynamic> data) async {
    api.token = data['token'] as String;
    user = AppUser.fromJson(Map<String, dynamic>.from(data['user']));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rd_token', api.token!);
    await loadClubs();
    busy = false;
    notifyListeners();
  }

  Future<void> loadClubs() async {
    try {
      final list = await api.get('/clubs');
      clubs =
          (list as List)
              .map((c) => Club.fromJson(Map<String, dynamic>.from(c)))
              .toList();
      subscriptionLocked = false;
    } on ApiException catch (e) {
      if (e.isSubscription) subscriptionLocked = true;
    }
    if (clubs.isNotEmpty) {
      final ok = clubs.any((c) => c.id == activeClubId);
      if (!ok) {
        activeClubId = clubs.first.id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('rd_active_club', activeClubId!);
      }
    }
    notifyListeners();
  }

  Future<void> selectClub(String id) async {
    activeClubId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rd_active_club', id);
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? location,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (location != null) body['location'] = location;
      user = AppUser.fromJson(
        Map<String, dynamic>.from(await api.patch('/auth/me', body)),
      );
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveClubSettings(Map<String, dynamic> settings) async {
    final club = activeClub;
    if (club == null) return false;
    try {
      final updated = Club.fromJson(
        Map<String, dynamic>.from(
          await api.patch('/clubs/${club.id}/settings', settings),
        ),
      );
      clubs = [for (final c in clubs) c.id == club.id ? updated : c];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut({bool silent = false}) async {
    api.token = null;
    user = null;
    clubs = [];
    activeClubId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rd_token');
    await prefs.remove('rd_active_club');
    if (!silent) notifyListeners();
  }
}

/// Per-club live data (tables, sessions, members...) refreshed from /data.
class ClubController extends ChangeNotifier {
  final SessionController session;
  List<ClubTable> tables = [];
  List<ClubSession> sessions = [];
  List<Member> members = [];
  List<ClubPlan> plans = [];
  List<MenuItem> menuItems = [];
  List<dynamic> frames = [];
  List<dynamic> itemBills = [];
  List<dynamic> tournaments = [];
  List<dynamic> expenses = [];
  List<dynamic> sales = [];
  List<dynamic> logs = [];
  Stats stats = const Stats();
  DateTime serverNow = DateTime.now().toUtc();
  DateTime _serverNowSampledAt = DateTime.now().toUtc();
  bool loading = false;
  String? error;
  Future<void>? _refreshing;
  String? _refreshingClubId;

  ClubController(this.session);

  String? get clubId => session.activeClub?.id;

  /// Keeps the server clock moving between refreshes. The API clock remains
  /// the reference point, while this local delta lets live table timers tick
  /// every second without repeatedly fetching `/data`.
  DateTime get currentServerNow =>
      serverNow.add(DateTime.now().toUtc().difference(_serverNowSampledAt));

  Future<void> refresh() async {
    final id = clubId;
    if (id == null) return;
    if (_refreshing != null && _refreshingClubId == id) {
      return _refreshing!;
    }
    late final Future<void> request;
    request = _refresh(id).whenComplete(() {
      if (identical(_refreshing, request)) {
        _refreshing = null;
        _refreshingClubId = null;
      }
    });
    _refreshing = request;
    _refreshingClubId = id;
    return request;
  }

  Future<void> _refresh(String id) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final d = Map<String, dynamic>.from(
        await session.api.get('/clubs/$id/data'),
      );
      // A club switch may happen while the previous response is in flight.
      // Ignore that stale payload instead of painting the wrong club briefly.
      if (id != clubId) return;
      tables =
          (d['tables'] as List? ?? const [])
              .map((t) => ClubTable.fromJson(Map<String, dynamic>.from(t)))
              .toList();
      sessions =
          (d['sessions'] as List? ?? const [])
              .map((s) => ClubSession.fromJson(Map<String, dynamic>.from(s)))
              .toList();
      members =
          (d['members'] as List? ?? const [])
              .map((m) => Member.fromJson(Map<String, dynamic>.from(m)))
              .toList();
      plans =
          (d['plans'] as List? ?? const [])
              .map((p) => ClubPlan.fromJson(Map<String, dynamic>.from(p)))
              .toList();
      menuItems =
          (d['menuItems'] as List? ?? const [])
              .map((m) => MenuItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
      frames = List<dynamic>.from(d['frames'] ?? const []);
      itemBills = List<dynamic>.from(d['itemBills'] ?? const []);
      tournaments = List<dynamic>.from(d['tournaments'] ?? const []);
      expenses = List<dynamic>.from(d['expenses'] ?? const []);
      sales = List<dynamic>.from(d['sales'] ?? const []);
      logs = List<dynamic>.from(d['logs'] ?? const []);
      stats = Stats.fromJson(Map<String, dynamic>.from(d['stats'] ?? const {}));
      final sn = DateTime.tryParse(d['serverNow'] ?? '');
      if (sn != null) {
        serverNow = sn.toUtc();
        _serverNowSampledAt = DateTime.now().toUtc();
      }
    } on ApiException catch (e) {
      error = e.message;
      if (e.isSubscription) {
        session.subscriptionLocked = true;
        session.notifyListeners();
      }
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  ClubSession? sessionFor(String tableId) {
    for (final s in sessions) {
      if (s.tableId == tableId) return s;
    }
    return null;
  }
}
