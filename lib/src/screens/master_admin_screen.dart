import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Master Admin — platform-wide gold panel (§4 / sidebar Master Admin, master-only).
class MasterAdminScreen extends StatefulWidget {
  final SessionController session;
  final ClubController? club; // may be null — master without clubs
  const MasterAdminScreen({super.key, required this.session, this.club});

  @override
  State<MasterAdminScreen> createState() => _MasterAdminScreenState();
}

class _MasterAdminScreenState extends State<MasterAdminScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _overview = {};
  List<dynamic> _users = [];
  List<dynamic> _clubs = [];
  List<dynamic> _plans = [];
  List<dynamic> _mailouts = [];
  Map<String, dynamic> _support = {};
  String _q = '';

  Api get _api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _api.get('/master/overview'),
        _api.get('/master/users', query: _q.isEmpty ? null : {'q': _q}),
        _api.get('/master/mailouts'),
        _api.get('/subscription-plans'),
        _api.get('/team'),
        _api.get('/platform/support'),
      ]);
      _overview = Map<String, dynamic>.from(res[0] as Map);
      _users = List<dynamic>.from(res[1] as List? ?? const []);
      _mailouts = List<dynamic>.from(res[2] as List? ?? const []);
      _plans = List<dynamic>.from(res[3] as List? ?? const []);
      _clubs = [
        for (final entry in (res[4] as Map)['clubs'] as List? ?? const [])
          (entry as Map)['club'],
      ];
      _support = Map<String, dynamic>.from(res[5] as Map? ?? const {});
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RefreshIndicator(
      onRefresh: _load,
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
                hintText: 'Name, email, user/club ID',
              ),
              onSubmitted: (v) {
                _q = v;
                _load();
              },
              onChanged: (v) => _q = v,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: EightBallLoader(label: 'master panel…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Master area',
              hint: _error!,
              icon: Icons.shield_outlined,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Accounts',
                    value: '${_overview['accounts'] ?? 0}',
                    sub: 'login accounts',
                    tone: c.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Total clubs',
                    value: '${_overview['totalClubs'] ?? 0}',
                    sub: 'branches',
                    tone: c.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Active subscriptions',
                    value: '${_overview['activeSubs'] ?? 0}',
                    sub: 'trial + active',
                    tone: c.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Platform MRR',
                    value: fmtMoney(_overview['mrr']),
                    sub: 'monthly recurring',
                    tone: c.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Seller plans',
                    value: '${_overview['sellerPlans'] ?? 0}',
                    sub: 'active catalog',
                    tone: c.blue,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 10),
            _accountsCard(c),
            const SizedBox(height: 10),
            _plansCard(c),
            const SizedBox(height: 10),
            _clubsCard(c),
            const SizedBox(height: 10),
            _supportCard(c),
            const SizedBox(height: 10),
            _mailoutsCard(c),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- accounts
  Widget _accountsCard(AppColors c) {
    return SectionCard(
      title: 'Login Accounts & Subscriptions',
      child:
          _users.isEmpty
              ? Text(
                'No users found.',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font12),
              )
              : Column(
                children: [
                  for (final u in _users)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _manageUser(u),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  u['role'] == 'master'
                                      ? c.gold.withValues(alpha: 0.18)
                                      : c.blue.withValues(alpha: 0.15),
                              child: Text(
                                '${u['name'] ?? '?'}'.isNotEmpty
                                    ? '${u['name']}'
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color:
                                      u['role'] == 'master' ? c.gold : c.blue,
                                  fontSize: Dimens.font12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${u['name']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: Dimens.font12_5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${u['email']} · ${u['id']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: Dimens.font9_5,
                                    ),
                                  ),
                                  if ((u['clubNames'] as List? ?? const [])
                                      .isNotEmpty)
                                    Text(
                                      (u['clubNames'] as List).join(', '),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: c.textMuted,
                                        fontSize: Dimens.font9_5,
                                      ),
                                    ),
                                  if (u['subscription'] != null)
                                    Row(
                                      children: [
                                        ToneBadge(
                                          '${(u['subscription'] as Map)['status']}',
                                          _subTone(
                                            c,
                                            '${(u['subscription'] as Map)['status']}',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(u['subscription'] as Map)['planName'] ?? ''} · ${fmtMoney((u['subscription'] as Map)['price'])}',
                                          style: TextStyle(
                                            color: c.textMuted,
                                            fontSize: Dimens.font9_5,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ToneBadge(
                                  u['role'] == 'master'
                                      ? 'Master'
                                      : u['role'] == 'staff'
                                      ? 'Staff'
                                      : 'Owner',
                                  u['role'] == 'master'
                                      ? c.gold
                                      : u['role'] == 'staff'
                                      ? c.blue
                                      : c.textSecondary,
                                ),
                                const SizedBox(height: 3),
                                ToneBadge(
                                  u['active'] == false ? 'Blocked' : 'Active',
                                  u['active'] == false ? c.red : c.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  Color _subTone(AppColors c, String s) {
    switch (s) {
      case 'active':
        return c.green;
      case 'trial':
        return c.blue;
      case 'pending':
      case 'past_due':
        return c.gold;
      default:
        return c.red;
    }
  }

  // ------------------------------------------------------------- manage user
  Future<void> _manageUser(dynamic u) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _UserManageSheet(
            api: _api,
            user: Map<String, dynamic>.from(u as Map),
            clubs: _clubs,
            plans: _plans,
          ),
    );
    if (changed == true) _load();
  }

  // ------------------------------------------------------------- plans
  Widget _plansCard(AppColors c) {
    return SectionCard(
      title: 'Seller Subscription Plans',
      trailing: TextButton.icon(
        onPressed: () => _editPlan(null),
        icon: Icon(Icons.add, size: 14, color: c.green),
        label: Text(
          'Add Plan',
          style: TextStyle(color: c.green, fontSize: Dimens.font12),
        ),
      ),
      child:
          _plans.isEmpty
              ? Text(
                'No plans yet — create plans owners pick at signup.',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              )
              : Column(
                children: [
                  for (final p in _plans)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${p['name']}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: c.text,
                                          fontSize: Dimens.font12_5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (p['recommended'] == true) ...[
                                      const SizedBox(width: 4),
                                      ToneBadge('recommended', c.gold),
                                    ],
                                    if (p['active'] == false) ...[
                                      const SizedBox(width: 4),
                                      ToneBadge('off', c.red),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${fmtMoney(p['price'])} / ${p['billingCycle']} · ${p['durationDays'] ?? 30}d · '
                                  '${p['maxClubs'] ?? 1} club(s) · trial ${p['trialDays'] ?? 0}d',
                                  style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: Dimens.font9_5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Toggle active',
                            onPressed: () async {
                              try {
                                await _api.post(
                                  '/master/subscription-plans/${p['id']}/toggle-active',
                                );
                                _load();
                              } on ApiException catch (e) {
                                if (mounted) {
                                  toast(context, e.message, error: true);
                                }
                              }
                            },
                            icon: Icon(
                              Icons.power_settings_new,
                              size: 15,
                              color:
                                  p['active'] == false ? c.textMuted : c.green,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _editPlan(p),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: c.textSecondary,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deletePlan(p),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: c.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Future<void> _editPlan(dynamic existing) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanFormSheet(api: _api, existing: existing),
    );
    if (changed == true) _load();
  }

  Future<void> _deletePlan(dynamic p) async {
    final sure = await confirmSheet(
      context,
      title: 'Delete plan?',
      message: '${p['name']} · ${fmtMoney(p['price'])}',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await _api.delete('/master/subscription-plans/${p['id']}');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ------------------------------------------------------------- clubs
  Widget _clubsCard(AppColors c) {
    return SectionCard(
      title: 'All Clubs / Branch IDs',
      child:
          _clubs.isEmpty
              ? Text(
                'No clubs yet.',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font12),
              )
              : Column(
                children: [
                  for (final cl in _clubs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: c.green.withValues(alpha: 0.15),
                            child: Text(
                              '${(cl['name'] ?? '?')}'
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: c.green,
                                fontSize: Dimens.font11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${cl['name']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.text,
                                    fontSize: Dimens.font12_5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${cl['id']}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: Dimens.font9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _clubSub(cl),
                            child: Text(
                              'Subscription',
                              style: TextStyle(
                                color: c.gold,
                                fontSize: Dimens.font11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Future<void> _clubSub(dynamic cl) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _ClubSubSheet(
            api: _api,
            club: Map<String, dynamic>.from(cl as Map),
            plans: _plans,
          ),
    );
    if (changed == true) _load();
  }

  // ------------------------------------------------------------- support
  Widget _supportCard(AppColors c) {
    return SectionCard(
      title: 'Human Support Contact',
      trailing: TextButton.icon(
        onPressed: _editSupport,
        icon: Icon(Icons.save_outlined, size: 13, color: c.green),
        label: Text(
          'Save Contact',
          style: TextStyle(color: c.green, fontSize: Dimens.font11_5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rowdy Care\'s "Human se baat" reply and the Human Support page both show this email/number — direct help for owners and staff.',
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font10_5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.mail_outline, size: 13, color: c.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (_support['email'] ?? '').isEmpty
                      ? '— not set —'
                      : '${_support['email']}',
                  style: TextStyle(color: c.text, fontSize: Dimens.font12_5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 13, color: c.green),
              const SizedBox(width: 6),
              Text(
                (_support['phone'] ?? '').isEmpty
                    ? '+91 98XXXXXXXX'
                    : '${_support['phone']}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: Dimens.font12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editSupport() async {
    final email = TextEditingController(text: '${_support['email'] ?? ''}');
    final phone = TextEditingController(text: '${_support['phone'] ?? ''}');
    final c = context.colors;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Padding(
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
                      'Human Support Contact',
                      style: TextStyle(
                        color: c.text,
                        fontSize: Dimens.font14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: email,
                      style: AppText.field.copyWith(color: c.text),
                      decoration: const InputDecoration(
                        labelText: 'Support email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      style: AppText.field.copyWith(color: c.text),
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Support phone / WhatsApp',
                        hintText: '+91 98XXXXXXXX',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.green,
                              foregroundColor: c.onGreen,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    if (ok != true) return;
    try {
      await _api.patch('/platform/support', {
        'email': email.text.trim(),
        'phone': phone.text.trim(),
      });
      if (mounted) toast(context, 'Support contact saved');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ------------------------------------------------------------- mailouts
  Widget _mailoutsCard(AppColors c) {
    return SectionCard(
      title: 'Emails Sent / Recorded',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every mail the system produced — subscription welcomes, member plan sales, balance notifies, expiry warnings. sent = delivered via SMTP; recorded = SMTP not configured yet.',
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font10,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          if (_mailouts.isEmpty)
            Text(
              'No mail yet.',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font12),
            ),
          for (final m in _mailouts.take(20))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      fmtDT(m['createdAt']),
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font9_5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m['to']}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font11_5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((m['subject'] ?? '') != '')
                          Text(
                            '${m['subject']}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font9_5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ToneBadge('${m['kind'] ?? 'mail'}', c.blue),
                  const SizedBox(width: 4),
                  ToneBadge(
                    (m['status'] ?? (m['sent'] == true ? 'sent' : 'recorded'))
                        .toString(),
                    ('${m['status']}' == 'sent' || m['sent'] == true)
                        ? c.green
                        : c.gold,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// user manage sheet — role, active, clubs, phone/location + subscription
class _UserManageSheet extends StatefulWidget {
  final Api api;
  final Map<String, dynamic> user;
  final List<dynamic> clubs;
  final List<dynamic> plans;
  const _UserManageSheet({
    required this.api,
    required this.user,
    required this.clubs,
    required this.plans,
  });

  @override
  State<_UserManageSheet> createState() => _UserManageSheetState();
}

class _UserManageSheetState extends State<_UserManageSheet> {
  late String _role = '${widget.user['role'] ?? 'owner'}';
  late bool _active = widget.user['active'] != false;
  late final Set<String> _clubIds = {
    for (final c in (widget.user['clubIds'] as List? ?? const [])) '$c',
  };
  late final _phone = TextEditingController(
    text: '${widget.user['phone'] ?? ''}',
  );
  late final _location = TextEditingController(
    text: '${widget.user['location'] ?? ''}',
  );
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.patch('/master/users/${widget.user['id']}', {
        'role': _role,
        'active': _active,
        'clubIds': _clubIds.toList(),
        'phone': _phone.text.trim(),
        'location': _location.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      setState(() => _busy = false);
    }
  }

  Future<void> _subscription() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _SubSheet(
            api: widget.api,
            path: '/master/users/${widget.user['id']}/subscription',
            subscription: widget.user['subscription'] as Map<String, dynamic>?,
            plans: widget.plans,
          ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sub = widget.user['subscription'] as Map<String, dynamic>?;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage — ${widget.user['name']}',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${widget.user['email']} · ${widget.user['id']}',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Role'),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: 'owner',
                                label: Text('Owner'),
                              ),
                              ButtonSegment(
                                value: 'staff',
                                label: Text('Staff'),
                              ),
                              ButtonSegment(
                                value: 'master',
                                label: Text('Master'),
                              ),
                            ],
                            selected: {_role},
                            onSelectionChanged:
                                (v) => setState(() => _role = v.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Account'),
                      FilterChip(
                        showCheckmark: false,
                        label: Text(
                          _active ? 'Active' : 'Blocked',
                          style: TextStyle(
                            fontSize: Dimens.font11,
                            color: _active ? c.green : c.red,
                          ),
                        ),
                        selected: _active,
                        selectedColor: c.green.withValues(alpha: 0.2),
                        onSelected: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ],
              ),
              const FieldLabel('Clubs (access)'),
              if (widget.clubs.isEmpty)
                Text(
                  'No clubs exist yet.',
                  style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cl in widget.clubs)
                      FilterChip(
                        showCheckmark: false,
                        label: Text(
                          '${cl['name']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: Dimens.font11,
                          ),
                        ),
                        selected: _clubIds.contains('${cl['id']}'),
                        selectedColor: c.blue.withValues(alpha: 0.25),
                        onSelected:
                            (v) => setState(() {
                              if (v) {
                                _clubIds.add('${cl['id']}');
                              } else {
                                _clubIds.remove('${cl['id']}');
                              }
                            }),
                      ),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Phone'),
                        TextField(
                          controller: _phone,
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('City / location'),
                        TextField(
                          controller: _location,
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.bgMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUBSCRIPTION',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            sub == null
                                ? 'No subscription yet'
                                : '${sub['planName'] ?? 'Custom'} · ${sub['status']} · ${fmtMoney(sub['price'])}'
                                    '${(sub['expiresAt'] ?? '') != '' ? ' · till ${fmtDate('${sub['expiresAt']}')}' : ''}',
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _subscription,
                      icon: Icon(
                        Icons.workspace_premium_outlined,
                        size: 15,
                        color: Colors.black,
                      ),
                      label: Text(
                        sub == null ? 'Assign plan' : 'Edit / Remove',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: Dimens.font11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.onGold,
                  ),
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// subscription assign/edit (works for user paths AND club paths)
class _SubSheet extends StatefulWidget {
  final Api api;
  final String path;
  final Map<String, dynamic>? subscription;
  final List<dynamic> plans;
  const _SubSheet({
    required this.api,
    required this.path,
    this.subscription,
    required this.plans,
  });

  @override
  State<_SubSheet> createState() => _SubSheetState();
}

class _SubSheetState extends State<_SubSheet> {
  String? _planId;
  String _status = 'active';
  late final _price = TextEditingController(
    text: '${widget.subscription?['price'] ?? ''}',
  );
  late final _duration = TextEditingController(
    text: '${widget.subscription?['durationDays'] ?? 30}',
  );
  late final _maxClubs = TextEditingController(
    text: '${widget.subscription?['maxClubs'] ?? 1}',
  );
  late final _expires = TextEditingController(
    text: _onlyDate('${widget.subscription?['expiresAt'] ?? ''}'),
  );
  late final _notes = TextEditingController(
    text: '${widget.subscription?['notes'] ?? ''}',
  );
  bool _busy = false;

  static String _onlyDate(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : '';

  @override
  void initState() {
    super.initState();
    _status = '${widget.subscription?['status'] ?? 'active'}';
    final pid = '${widget.subscription?['planId'] ?? ''}';
    if (pid.isNotEmpty && widget.plans.any((p) => '${p['id']}' == pid)) {
      _planId = pid;
    }
    if (_price.text.isEmpty && _planId != null) {
      final p = widget.plans.firstWhere((x) => '${x['id']}' == _planId);
      _price.text = '${p['price']}';
      _duration.text = '${p['durationDays'] ?? 30}';
      _maxClubs.text = '${p['maxClubs'] ?? 1}';
    }
  }

  @override
  void dispose() {
    _price.dispose();
    _duration.dispose();
    _maxClubs.dispose();
    _expires.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final plan =
          _planId == null
              ? null
              : widget.plans.firstWhere((p) => '${p['id']}' == _planId);
      await widget.api.patch(widget.path, {
        'planId': _planId,
        'planName': plan != null ? '${plan['name']}' : null,
        'status': _status,
        'price': double.tryParse(_price.text.trim()) ?? 0,
        'durationDays': int.tryParse(_duration.text.trim()) ?? 30,
        'maxClubs': int.tryParse(_maxClubs.text.trim()) ?? 1,
        if (_expires.text.trim().isNotEmpty)
          'expiresAt': '${_expires.text.trim()}T23:59:59+05:30',
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await widget.api.delete(widget.path);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        toast(context, e.message, error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.subscription == null
                    ? 'Assign Subscription'
                    : 'Edit Subscription',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const FieldLabel('Seller plan (prefills price / days / clubs)'),
              DropdownButtonFormField<String>(
                style: AppText.dropdown.copyWith(color: c.text),
                initialValue: _planId ?? '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Custom / manual'),
                  ),
                  for (final p in widget.plans)
                    DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(
                        '${p['name']} · ${fmtMoney(p['price'])}',
                        style: const TextStyle(fontSize: Dimens.font12),
                      ),
                    ),
                ],
                onChanged:
                    (v) => setState(() {
                      _planId = (v == null || v.isEmpty) ? null : v;
                      if (_planId != null) {
                        final p = widget.plans.firstWhere(
                          (x) => '${x['id']}' == _planId,
                        );
                        _price.text = '${p['price']}';
                        _duration.text = '${p['durationDays'] ?? 30}';
                        _maxClubs.text = '${p['maxClubs'] ?? 1}';
                      }
                    }),
              ),
              const FieldLabel('Status'),
              Wrap(
                spacing: 6,
                // runSpacing: 5,
                children: [
                  for (final s in const [
                    'pending',
                    'trial',
                    'active',
                    'past_due',
                    'paused',
                    'expired',
                    'cancelled',
                  ])
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        s
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map(
                              (word) =>
                                  word.isEmpty
                                      ? word
                                      : '${word[0].toUpperCase()}${word.substring(1)}',
                            )
                            .join(' '),
                        style: TextStyle(
                          fontSize: Dimens.font10,
                          color: _status == s ? Colors.black : c.text,
                        ),
                      ),
                      selected: _status == s,
                      selectedColor:
                          s == 'active'
                              ? c.green
                              : s == 'trial'
                              ? c.blue
                              : s == 'pending' || s == 'past_due'
                              ? c.gold
                              : c.red,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Price ₹'),
                        TextField(
                          controller: _price,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Duration days'),
                        TextField(
                          controller: _duration,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Max clubs'),
                        TextField(
                          controller: _maxClubs,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const FieldLabel(
                'Expires on (leave blank = duration from today)',
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await pickDate(
                          context,
                          _expires.text.trim().isEmpty
                              ? todayStr()
                              : _expires.text.trim(),
                        );
                        if (d != null) setState(() => _expires.text = d);
                      },
                      icon: Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: c.textSecondary,
                      ),
                      label: Text(
                        _expires.text.trim().isEmpty
                            ? 'Pick expiry date'
                            : fmtDate(_expires.text.trim()),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font12,
                        ),
                      ),
                    ),
                  ),
                  if (_expires.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => setState(() => _expires.clear()),
                      child: const Text(
                        'Clear Date',
                        style: TextStyle(fontSize: Dimens.font11),
                      ),
                    ),
                  ],
                ],
              ),

              const FieldLabel('Notes'),
              TextField(
                controller: _notes,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: 'payment ref, deal terms…',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.subscription != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.red,
                          side: BorderSide(color: c.red.withValues(alpha: 0.5)),
                        ),
                        onPressed: _busy ? null : _remove,
                        child: const Text('Remove'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.gold,
                        foregroundColor: c.onGold,
                      ),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Saving…' : 'Save subscription'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// club-level subscription patch (All Clubs card)
class _ClubSubSheet extends StatelessWidget {
  final Api api;
  final Map<String, dynamic> club;
  final List<dynamic> plans;
  const _ClubSubSheet({
    required this.api,
    required this.club,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    return _SubSheet(
      api: api,
      path: '/master/clubs/${club['id']}/subscription',
      subscription: club['subscription'] as Map<String, dynamic>?,
      plans: plans,
    );
  }
}

// ---------------------------------------------------------------------------
// seller plan create/edit
class _PlanFormSheet extends StatefulWidget {
  final Api api;
  final dynamic existing;
  const _PlanFormSheet({required this.api, this.existing});

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  late final _name = TextEditingController(
    text: '${widget.existing?['name'] ?? ''}',
  );
  late final _desc = TextEditingController(
    text: '${widget.existing?['description'] ?? ''}',
  );
  late final _price = TextEditingController(
    text: '${widget.existing?['price'] ?? ''}',
  );
  late final _duration = TextEditingController(
    text: '${widget.existing?['durationDays'] ?? 30}',
  );
  late final _trial = TextEditingController(
    text: '${widget.existing?['trialDays'] ?? 0}',
  );
  late final _maxClubs = TextEditingController(
    text: '${widget.existing?['maxClubs'] ?? 1}',
  );
  late final _features = TextEditingController(
    text: ((widget.existing?['features'] as List?) ?? const []).join(', '),
  );
  late final _sort = TextEditingController(
    text: '${widget.existing?['sortOrder'] ?? 0}',
  );
  String _cycle = 'monthly';
  bool _recommended = false;
  bool _active = true;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _cycle = '${widget.existing['billingCycle'] ?? 'monthly'}';
      _recommended = widget.existing['recommended'] == true;
      _active = widget.existing['active'] != false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _duration.dispose();
    _trial.dispose();
    _maxClubs.dispose();
    _features.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'Plan name required', error: true);
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'price': double.tryParse(_price.text.trim()) ?? 0,
      'billingCycle': _cycle,
      'durationDays': int.tryParse(_duration.text.trim()) ?? 30,
      'trialDays': int.tryParse(_trial.text.trim()) ?? 0,
      'maxClubs': int.tryParse(_maxClubs.text.trim()) ?? 1,
      'features':
          _features.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
      'recommended': _recommended,
      'active': _active,
      'sortOrder': int.tryParse(_sort.text.trim()) ?? 0,
    };
    try {
      if (_isEdit) {
        await widget.api.patch(
          '/master/subscription-plans/${widget.existing['id']}',
          body,
        );
      } else {
        await widget.api.post('/master/subscription-plans', body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit Seller Plan' : 'New Seller Plan',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const FieldLabel('Plan name *'),
              TextField(
                controller: _name,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(hintText: 'Pro · Multi-club'),
              ),
              const FieldLabel('Description'),
              TextField(
                controller: _desc,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: 'one-liner for the pricing card',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Price ₹'),
                        TextField(
                          controller: _price,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Billing cycle'),
                        DropdownButtonFormField<String>(
                          style: AppText.dropdown.copyWith(color: c.text),
                          initialValue: _cycle,
                          items: const [
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('yearly'),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() => _cycle = v ?? 'monthly'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Duration days'),
                        TextField(
                          controller: _duration,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Trial days'),
                        TextField(
                          controller: _trial,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Max clubs'),
                        TextField(
                          controller: _maxClubs,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const FieldLabel('Features (comma separated)'),
              TextField(
                controller: _features,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: '1 club, Unlimited tables, Excel exports…',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilterChip(
                    showCheckmark: false,
                    label: const Text(
                      'Recommended',
                      style: TextStyle(fontSize: Dimens.font11),
                    ),
                    selected: _recommended,
                    selectedColor: c.gold.withValues(alpha: 0.3),
                    onSelected: (v) => setState(() => _recommended = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    showCheckmark: false,
                    label: const Text(
                      'Active (visible)',
                      style: TextStyle(fontSize: Dimens.font11),
                    ),
                    selected: _active,
                    selectedColor: c.green.withValues(alpha: 0.3),
                    onSelected: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sort,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: c.text, fontSize: Dimens.font12),
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.onGold,
                  ),
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _busy
                        ? 'Saving…'
                        : _isEdit
                        ? 'Save changes'
                        : 'Create plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
