/// Lightweight typed wrappers over the backend's JSON documents.
library;

class AppUser {
  final String id;
  final String email;
  final String name;
  final String picture;
  final String role; // owner | staff | master
  final bool active;
  final String phone;
  final String location;
  final List<String> clubIds;
  final Map<String, dynamic>? subscription;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.picture = '',
    this.role = 'owner',
    this.active = true,
    this.phone = '',
    this.location = '',
    this.clubIds = const [],
    this.subscription,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] ?? '',
    email: j['email'] ?? '',
    name: j['name'] ?? '',
    picture: j['picture'] ?? '',
    role: j['role'] ?? 'owner',
    active: j['active'] ?? true,
    phone: j['phone'] ?? '',
    location: j['location'] ?? '',
    clubIds: (j['clubIds'] as List?)?.map((e) => '$e').toList() ?? const [],
    subscription: j['subscription'] as Map<String, dynamic>?,
  );

  bool get isStaff => role == 'staff';
  bool get isMaster => role == 'master';
}

class Club {
  final String id;
  final String name;
  final String logo;

  /// Older club documents (and objects surviving a hot reload) may not have
  /// this field yet, so QR must remain nullable at the model boundary.
  final String? qrCode;
  final Map<String, dynamic> settings;

  const Club({
    required this.id,
    required this.name,
    this.logo = '',
    this.qrCode,
    this.settings = const {},
  });

  factory Club.fromJson(Map<String, dynamic> j) => Club(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    logo: j['logo'] ?? '',
    qrCode: j['qrCode']?.toString(),
    settings: Map<String, dynamic>.from(j['settings'] ?? const {}),
  );

  double get winnerBonus => (settings['winnerBonus'] ?? 0).toDouble();
  double get dueLimit => (settings['dueLimit'] ?? 0).toDouble();
  double get defaultAdvance => (settings['defaultAdvance'] ?? 0).toDouble();
  double get monthlyTableDiscount =>
      (settings['monthlyTableDiscount'] ?? 0).toDouble();
}

class ClubTable {
  final String id;
  final String name;
  final bool active;
  final int sortOrder;
  final Map<String, dynamic> rate;

  const ClubTable({
    required this.id,
    required this.name,
    this.active = true,
    this.sortOrder = 0,
    this.rate = const {},
  });

  factory ClubTable.fromJson(Map<String, dynamic> j) => ClubTable(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    active: j['active'] ?? true,
    sortOrder: j['sortOrder'] ?? 0,
    rate: Map<String, dynamic>.from(j['rate'] ?? const {}),
  );

  double get hourlyRate => (rate['hourlyRate'] ?? 0).toDouble();
  double get minCharge => (rate['minCharge'] ?? 0).toDouble();
  double get glovePrice => (rate['glovePrice'] ?? 0).toDouble();
}

class Member {
  final String id;
  final String name;
  final String phone;
  final String email;
  final bool active;
  final double walletBalance;
  final double dueAmount;
  final int passFramesLeft;
  final String? planName;
  final String? planType;
  final String badge;
  final String planExpiresAt; // ISO or '' — backend null-safe
  final double tableDiscountPercent;

  const Member({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.active = true,
    this.walletBalance = 0,
    this.dueAmount = 0,
    this.passFramesLeft = 0,
    this.planName,
    this.planType,
    this.badge = 'regular',
    this.planExpiresAt = '',
    this.tableDiscountPercent = 0,
  });

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    email: j['email'] ?? '',
    active: j['active'] ?? true,
    walletBalance: (j['walletBalance'] ?? 0).toDouble(),
    dueAmount: (j['dueAmount'] ?? 0).toDouble(),
    passFramesLeft: (j['passFramesLeft'] ?? 0).toInt(),
    planName: j['planName'],
    planType: j['planType'],
    badge: j['badge'] ?? 'regular',
    planExpiresAt: j['planExpiresAt'] ?? '',
    tableDiscountPercent: (j['tableDiscountPercent'] ?? 0).toDouble(),
  );

  bool get hasDue => dueAmount > 0;
}

class ClubPlan {
  final String id;
  final String name;
  final String type; // wallet | pass | monthly
  final double amount;
  final double value;
  final int frames;
  final int days;
  final double? tableDiscountPercent;
  final bool active;
  final bool isDefault;

  const ClubPlan({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.value = 0,
    this.frames = 0,
    this.days = 0,
    this.tableDiscountPercent,
    this.active = true,
    this.isDefault = false,
  });

  factory ClubPlan.fromJson(Map<String, dynamic> j) => ClubPlan(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    type: j['type'] ?? 'wallet',
    amount: (j['amount'] ?? 0).toDouble(),
    value: (j['value'] ?? 0).toDouble(),
    frames: (j['frames'] ?? 0).toInt(),
    days: (j['days'] ?? 0).toInt(),
    tableDiscountPercent: (j['tableDiscountPercent'] as num?)?.toDouble(),
    active: j['active'] ?? true,
    isDefault: j['isDefault'] ?? false,
  );
}

class MenuItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final double costPrice;
  final int stockQty;
  final int reorderLevel;
  final bool active;

  const MenuItem({
    required this.id,
    required this.name,
    this.category = 'Cafe',
    required this.price,
    this.costPrice = 0,
    this.stockQty = 0,
    this.reorderLevel = 5,
    this.active = true,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    category: j['category'] ?? 'Cafe',
    price: (j['price'] ?? 0).toDouble(),
    costPrice: (j['costPrice'] ?? 0).toDouble(),
    stockQty: (j['stockQty'] ?? 0).toInt(),
    reorderLevel: (j['reorderLevel'] ?? 5).toInt(),
    active: j['active'] ?? true,
  );

  bool get outOfStock => stockQty <= 0;
  bool get lowStock => stockQty <= reorderLevel;
}

class SessionPlayer {
  final String pid;
  final String label;
  final String type; // member | guest
  final String? memberId;
  final String? team;
  final bool isWinner;

  const SessionPlayer({
    required this.pid,
    required this.label,
    this.type = 'guest',
    this.memberId,
    this.team,
    this.isWinner = false,
  });

  factory SessionPlayer.fromJson(Map<String, dynamic> j) => SessionPlayer(
    pid: j['pid'] ?? '',
    label: j['label'] ?? '',
    type: j['type'] ?? 'guest',
    memberId: j['memberId'],
    team: j['team'],
    isWinner: j['isWinner'] ?? false,
  );
}

class ClubSession {
  final String id;
  final String tableId;
  final String tableName;
  final String startedAt;
  final String? endedAt;
  final List<SessionPlayer> players;
  final double hourlyRate;
  final double minCharge;
  final bool peak;
  final String matchMode;
  final List<dynamic> items;
  final double itemsTotal;
  final double advancePaid;
  final String notes;
  final List<dynamic> gloves;

  const ClubSession({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.startedAt,
    this.endedAt,
    this.players = const [],
    this.hourlyRate = 0,
    this.minCharge = 0,
    this.peak = false,
    this.matchMode = 'solo',
    this.items = const [],
    this.itemsTotal = 0,
    this.advancePaid = 0,
    this.notes = '',
    this.gloves = const [],
  });

  factory ClubSession.fromJson(Map<String, dynamic> j) => ClubSession(
    id: j['id'] ?? '',
    tableId: j['tableId'] ?? '',
    tableName: j['tableName'] ?? '',
    startedAt: j['startedAt'] ?? '',
    endedAt: j['endedAt'],
    players:
        ((j['players'] as List?) ?? const [])
            .map((p) => SessionPlayer.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
    hourlyRate: (j['hourlyRate'] ?? 0).toDouble(),
    minCharge: (j['minCharge'] ?? 0).toDouble(),
    peak: j['peak'] ?? false,
    matchMode: j['matchMode'] ?? 'solo',
    items: (j['items'] as List?) ?? const [],
    itemsTotal: (j['itemsTotal'] ?? 0).toDouble(),
    advancePaid: (j['advancePaid'] ?? 0).toDouble(),
    notes: j['notes'] ?? '',
    gloves: (j['gloves'] as List?) ?? const [],
  );

  bool get stopped => endedAt != null;

  /// Client-side display estimate ONLY — the server is the final calculator.
  Duration elapsed(DateTime serverNow) {
    final start = DateTime.tryParse(startedAt) ?? serverNow;
    final end =
        stopped ? (DateTime.tryParse(endedAt!) ?? serverNow) : serverNow;
    final diff = end.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }

  double estimate(DateTime serverNow) {
    final minutes = (elapsed(serverNow).inSeconds / 60).ceil().clamp(
      1,
      1 << 30,
    );
    double table = (hourlyRate / 60 * minutes * 100).roundToDouble() / 100;
    if (table < minCharge) table = minCharge;
    final glovesDue = gloves
        .where((g) => g['returned'] != true)
        .fold<double>(0, (s, g) => s + ((g['price'] ?? 0) as num).toDouble());
    return table + itemsTotal + glovesDue;
  }
}

class Stats {
  final double todayEarnings;
  final double totalDue;
  final int runningSessions;
  final int liveMatches;
  // ★ v3.21 backend keys (additive — purane backend pe defaults)
  final int activeMembers;
  final int activeSessions; // alias of runningSessions
  final double dueLimit;
  final String currency;
  final String currencySymbol;
  final String today;

  const Stats({
    this.todayEarnings = 0,
    this.totalDue = 0,
    this.runningSessions = 0,
    this.liveMatches = 0,
    this.activeMembers = 0,
    this.activeSessions = 0,
    this.dueLimit = 0,
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.today = '',
  });

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
    todayEarnings: (j['todayEarnings'] ?? 0).toDouble(),
    totalDue: (j['totalDue'] ?? 0).toDouble(),
    runningSessions: (j['runningSessions'] ?? 0).toInt(),
    liveMatches: (j['liveMatches'] ?? 0).toInt(),
    activeMembers: (j['activeMembers'] ?? 0).toInt(),
    activeSessions: (j['activeSessions'] ?? j['runningSessions'] ?? 0).toInt(),
    dueLimit: (j['dueLimit'] ?? 0).toDouble(),
    currency: j['currency'] ?? 'INR',
    currencySymbol: j['currencySymbol'] ?? '₹',
    today: j['today'] ?? '',
  );
}

class SellerPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String billingCycle;
  final int trialDays;
  final int maxClubs;
  final List<String> features;
  final bool recommended;

  const SellerPlan({
    required this.id,
    required this.name,
    this.description = '',
    this.price = 0,
    this.billingCycle = 'monthly',
    this.trialDays = 0,
    this.maxClubs = 1,
    this.features = const [],
    this.recommended = false,
  });

  factory SellerPlan.fromJson(Map<String, dynamic> j) => SellerPlan(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    description: j['description'] ?? '',
    price: (j['price'] ?? 0).toDouble(),
    billingCycle: j['billingCycle'] ?? 'monthly',
    trialDays: (j['trialDays'] ?? 0).toInt(),
    maxClubs: (j['maxClubs'] ?? 1).toInt(),
    features: ((j['features'] as List?) ?? const []).map((e) => '$e').toList(),
    recommended: j['recommended'] ?? false,
  );
}
