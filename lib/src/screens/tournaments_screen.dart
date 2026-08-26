import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../dimensions.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Tournaments — players & entry fees → bracket/fixtures → match tables → champion (§14).
class TournamentsScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const TournamentsScreen({
    super.key,
    required this.session,
    required this.club,
  });

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  List<dynamic> _tours = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.session.api.get(
        '/clubs/${widget.club.clubId}/tournaments',
      );
      if (mounted) {
        setState(() {
          _tours = List<dynamic>.from(list as List? ?? const []);
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), widget.club.refresh()]);
  }

  Color _statusTone(AppColors c, String s) {
    switch (s) {
      case 'running':
        return c.green;
      case 'upcoming':
        return c.gold;
      case 'completed':
        return c.blue;
      default:
        return c.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final running = _tours.where((t) => t['status'] == 'running').length;
    final upcoming = _tours.where((t) => t['status'] == 'upcoming').length;
    final completed = _tours.where((t) => t['status'] == 'completed').length;
    final collected = _tours.fold<double>(
      0,
      (a, t) => a + ((t['collected'] ?? 0) as num).toDouble(),
    );

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.green,
                foregroundColor: c.onGreen,
              ),
              onPressed: () => _editTour(null),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('New Tournament'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Running',
                  value: '$running',
                  sub: 'live right now',
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Upcoming',
                  value: '$upcoming',
                  sub: 'entries open',
                  tone: c.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Completed',
                  value: '$completed',
                  sub: 'records saved',
                  tone: c.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Entries collected',
                  value: fmtMoney(collected),
                  sub: 'across all events',
                  tone: c.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: EightBallLoader(label: 'loading…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load',
              hint: _error!,
              icon: Icons.cloud_off_outlined,
            )
          else if (_tours.isEmpty)
            const EmptyState(
              title: 'No tournaments yet',
              hint:
                  'Friday Snooker Open? Create it — entries, bracket and prizes auto-track.',
              icon: Icons.emoji_events_outlined,
            )
          else
            for (final t in _tours)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => TournamentDetailScreen(
                              session: widget.session,
                              club: widget.club,
                              tour: t,
                              onChanged: _refreshAll,
                            ),
                      ),
                    );
                    _refreshAll();
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t['name']}',
                                  style: TextStyle(
                                    color: c.text,
                                    fontSize: Dimens.font14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              ToneBadge(
                                '${t['status']}',
                                _statusTone(c, '${t['status']}'),
                              ),
                              // ★ v3.25 — list card se hi delete (owner spec)
                              const SizedBox(width: 2),
                              InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: () => _deleteTour(t),
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: c.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              Text(
                                '${t['game']}',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: Dimens.font11,
                                ),
                              ),
                              Text(
                                fmtDate(t['date']),
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: Dimens.font11,
                                ),
                              ),
                              Text(
                                '${t['playerCount'] ?? ((t['participants'] as List?) ?? const []).length}/${t['maxPlayers']} players',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: Dimens.font11,
                                ),
                              ),
                              Text(
                                (t['entryFee'] ?? 0) > 0
                                    ? 'entry ${fmtMoney(t['entryFee'])}'
                                    : 'entry free',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: Dimens.font11,
                                ),
                              ),
                              if (t['format'] == 'league')
                                Text(
                                  'league',
                                  style: TextStyle(
                                    color: c.blue,
                                    fontSize: Dimens.font11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                'collected ${fmtMoney(t['collected'] ?? _collectedOf(t))}',
                                style: TextStyle(
                                  color: c.green,
                                  fontSize: Dimens.font11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  double _collectedOf(dynamic t) {
    final parts = (t['participants'] as List?) ?? const [];
    return parts.fold<double>(
      0,
      (a, p) =>
          a +
          (p['paidEntry'] == true
              ? ((t['entryFee'] ?? 0) as num).toDouble()
              : 0),
    );
  }

  Future<void> _deleteTour(dynamic t) async {
    final sure = await confirmSheet(
      context,
      title: 'Delete ${t['name']}?',
      message:
          'The entire record will be deleted — bracket, matches, everything. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await widget.session.api.delete(
        '/clubs/${widget.club.clubId}/tournaments/${t['id']}',
      );
      _refreshAll();
      if (mounted) toast(context, 'Tournament deleted');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _editTour(dynamic existing) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => TournamentFormSheet(
            session: widget.session,
            club: widget.club,
            existing: existing,
          ),
    );
    if (changed == true) _refreshAll();
  }
}

// ---------------------------------------------------------------------------
// create / edit form (format locked after start)
class TournamentFormSheet extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  final dynamic existing;
  const TournamentFormSheet({
    super.key,
    required this.session,
    required this.club,
    this.existing,
  });

  @override
  State<TournamentFormSheet> createState() => _TournamentFormSheetState();
}

class _TournamentFormSheetState extends State<TournamentFormSheet> {
  late final _name = TextEditingController(
    text: '${widget.existing?['name'] ?? ''}',
  );
  String _game = 'Snooker';
  String _format = 'knockout';
  late String _date = widget.existing?['date'] ?? todayStr();
  late final _entryFee = TextEditingController(
    text: '${widget.existing?['entryFee'] ?? 0}',
  );
  late final _prize1 = TextEditingController(
    text: '${widget.existing?['prize1'] ?? 0}',
  );
  late final _prize2 = TextEditingController(
    text: '${widget.existing?['prize2'] ?? 0}',
  );
  late final _maxPlayers = TextEditingController(
    text: '${widget.existing?['maxPlayers'] ?? 16}',
  );
  late final _tableRate = TextEditingController(
    text: '${widget.existing?['tableRate'] ?? 0}',
  );
  late final _notes = TextEditingController(
    text: '${widget.existing?['notes'] ?? ''}',
  );
  bool _busy = false;

  bool get _isEdit => widget.existing != null;
  bool get _formatLocked =>
      _isEdit && '${widget.existing['status']}' != 'upcoming';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _game = '${widget.existing['game'] ?? 'Snooker'}';
      _format = '${widget.existing['format'] ?? 'knockout'}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _entryFee.dispose();
    _prize1.dispose();
    _prize2.dispose();
    _maxPlayers.dispose();
    _tableRate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      toast(context, 'Name the tournament', error: true);
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'game': _game,
      'date': _date,
      'entryFee': double.tryParse(_entryFee.text.trim()) ?? 0,
      'prize1': double.tryParse(_prize1.text.trim()) ?? 0,
      'prize2': double.tryParse(_prize2.text.trim()) ?? 0,
      'maxPlayers': int.tryParse(_maxPlayers.text.trim()) ?? 16,
      'tableRate': double.tryParse(_tableRate.text.trim()) ?? 0,
      'notes': _notes.text.trim(),
      if (!_isEdit) 'format': _format,
    };
    try {
      final api = widget.session.api;
      final cid = widget.club.clubId;
      if (_isEdit) {
        await api.patch(
          '/clubs/$cid/tournaments/${widget.existing['id']}',
          body,
        );
      } else {
        await api.post('/clubs/$cid/tournaments', body);
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
                _isEdit ? 'Edit Tournament' : 'New Tournament',
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const FieldLabel('Tournament name *'),
              TextField(
                controller: _name,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: 'Friday Snooker Open',
                ),
              ),
              const FieldLabel('Game'),
              DropdownButtonFormField<String>(
                style: AppText.dropdown.copyWith(color: c.text),
                initialValue: _game,
                items: const [
                  DropdownMenuItem(value: 'Snooker', child: Text('Snooker')),
                  DropdownMenuItem(value: 'Pool', child: Text('Pool')),
                  DropdownMenuItem(
                    value: 'Billiards',
                    child: Text('Billiards'),
                  ),
                  DropdownMenuItem(value: '8-Ball', child: Text('8-Ball')),
                  DropdownMenuItem(value: '9-Ball', child: Text('9-Ball')),
                ],
                onChanged: (v) => setState(() => _game = v ?? 'Snooker'),
              ),
              const FieldLabel('Format'),
              DropdownButtonFormField<String>(
                style: AppText.dropdown.copyWith(color: c.text),
                initialValue: _format,
                items: const [
                  DropdownMenuItem(
                    value: 'knockout',
                    child: Text('Knockout — single elimination'),
                  ),
                  DropdownMenuItem(
                    value: 'league',
                    child: Text('League — round robin'),
                  ),
                ],
                onChanged:
                    _formatLocked
                        ? null
                        : (v) => setState(() => _format = v ?? 'knockout'),
                decoration: InputDecoration(
                  helperText:
                      _formatLocked
                          ? 'format locked — tournament already started'
                          : 'knockout = bracket · league = fixtures + points table',
                  helperStyle: TextStyle(
                    color: c.textMuted,
                    fontSize: Dimens.font10,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Date'),
                        // ★ v3.25 — date chooser ab full input-field jaisa box
                        // (pehle chhota ghost button lagta tha — owner note).
                        InkWell(
                          borderRadius: BorderRadius.circular(Dimens.radius),
                          onTap: () async {
                            final d = await pickDate(context, _date);
                            if (d != null) setState(() => _date = d);
                          },
                          child: Container(
                            height: Dimens.fieldH,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: c.bgInput,
                              borderRadius: BorderRadius.circular(
                                Dimens.radius,
                              ),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  size: 15,
                                  color: c.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  fmtDate(_date),
                                  style: AppText.dropdown.copyWith(
                                    color: c.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Entry fee ₹'),
                        TextField(
                          controller: _entryFee,
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Winner prize ₹'),
                        TextField(
                          controller: _prize1,
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
                        const FieldLabel('Runner-up prize ₹'),
                        TextField(
                          controller: _prize2,
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Max players'),
                        TextField(
                          controller: _maxPlayers,
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
                        const FieldLabel('Match table rate ₹/hr'),
                        TextField(
                          controller: _tableRate,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            hintText: '0 = club rate',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const FieldLabel('Notes (optional)'),
              TextField(
                controller: _notes,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: 'best-of-3 frames, house rules…',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entry fees count as income. Loser pays each match ka table charge (rate × minutes); prize money auto-recorded as expense at the final.',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: Dimens.font10,
                  height: 1.3,
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
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _busy
                        ? 'Saving…'
                        : _isEdit
                        ? 'Save changes'
                        : 'Create Tournament',
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

// ---------------------------------------------------------------------------
// detail — participants, bracket/fixtures, matches, standings, champion
class TournamentDetailScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  final dynamic tour;
  final VoidCallback onChanged;
  const TournamentDetailScreen({
    super.key,
    required this.session,
    required this.club,
    required this.tour,
    required this.onChanged,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  late Map<String, dynamic> _t = Map<String, dynamic>.from(widget.tour as Map);
  Timer? _ticker;
  bool _busy = false;

  String get _status => '${_t['status']}';
  List<dynamic> get _players =>
      List<dynamic>.from(_t['participants'] ?? const []);
  List<dynamic> get _matches => List<dynamic>.from(_t['matches'] ?? const []);
  bool get _isLeague => '${_t['format']}' == 'league';

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _matches.any((m) => m['status'] == 'table_live')) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _base => '/clubs/${widget.club.clubId}/tournaments/${_t['id']}';

  Future<void> _mutate(
    Future<dynamic> Function() call, {
    bool hardRefresh = true,
  }) async {
    setState(() => _busy = true);
    try {
      final res = await call();
      if (res is Map && res['id'] == _t['id']) {
        setState(() => _t = Map<String, dynamic>.from(res));
      }
      widget.onChanged();
      if (hardRefresh) await widget.club.refresh();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  double get _collected => _players.fold<double>(
    0,
    (a, p) =>
        a +
        (p['paidEntry'] == true
            ? ((_t['entryFee'] ?? 0) as num).toDouble()
            : 0),
  );

  Set<String> get _busyTables {
    final ids = <String>{};
    for (final s in widget.club.sessions) {
      ids.add(s.tableId);
    }
    for (final m in _matches) {
      if (m['status'] == 'table_live' && m['tableId'] != null) {
        ids.add('${m['tableId']}');
      }
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final liveCount = _matches.where((m) => m['status'] == 'table_live').length;
    final prizePool =
        ((_t['prize1'] ?? 0) as num) + ((_t['prize2'] ?? 0) as num);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_t['name']}',
              style: TextStyle(
                color: c.text,
                fontSize: Dimens.font15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_t['game']} · ${fmtDate(_t['date'])} · '
              '${(_t['entryFee'] ?? 0) > 0 ? 'entry ${fmtMoney(_t['entryFee'])}' : 'entry free'} · '
              '${_players.length}/${_t['maxPlayers']} players · match table = '
              '${(_t['tableRate'] ?? 0) > 0 ? '${fmtMoney(_t['tableRate'])}/hr' : 'club rate'}'
              '${liveCount > 0 ? ' · $liveCount live' : ''}',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ★ v3.25 — owner spec: Row1 status chip akela, Row2 Edit+Start
            // halves, Row3 Cancel+Delete.
            Row(children: [ToneBadge(_status, _statusTone(c, _status))]),
            if (_status != 'upcoming' &&
                _status != 'completed' &&
                _status != 'cancelled') ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: c.textSecondary,
                  ),
                  label: Text(
                    'Edit',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: Dimens.font12,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_status == 'upcoming') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _edit,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: c.textSecondary,
                      ),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.green,
                        foregroundColor: c.onGreen,
                      ),
                      onPressed:
                          _busy || _players.length < 2
                              ? null
                              : () => _mutate(
                                () => widget.session.api.post('$_base/start'),
                                hardRefresh: true,
                              ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text(
                        _players.length < 2
                            ? 'Need 2 players'
                            : _isLeague
                            ? 'Start · Fixtures'
                            : 'Start · Bracket',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _cancel,
                      icon: Icon(Icons.block, size: 13, color: c.textMuted),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_status == 'completed') _championBanner(c),
            if (_status == 'completed' || _status == 'running') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final p in _players)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    '${p['pid']}' == '${_t['winnerPid']}'
                                        ? c.green.withValues(alpha: 0.14)
                                        : c.bgMuted,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      '${p['pid']}' == '${_t['winnerPid']}'
                                          ? c.green.withValues(alpha: 0.5)
                                          : c.border,
                                ),
                              ),
                              child: Text(
                                '${'${p['pid']}' == '${_t['winnerPid']}' ? '👑 ' : ''}${p['name']}',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: Dimens.font11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'collected ${fmtMoney(_collected)}',
                          style: TextStyle(
                            color: c.green,
                            fontSize: Dimens.font10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'prize pool ${fmtMoney(prizePool)}',
                          style: TextStyle(
                            color: c.gold,
                            fontSize: Dimens.font10,
                          ),
                        ),
                        if (((_t['tableCharges'] ?? 0) as num) > 0)
                          Text(
                            'table ${fmtMoney(_t['tableCharges'])}',
                            style: TextStyle(
                              color: c.blue,
                              fontSize: Dimens.font10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_status == 'upcoming') _playersCard(c),
            if (_isLeague && _status != 'upcoming') _standingsCard(c),
            if (_status == 'running' || _status == 'completed') _bracket(c),
            if (_status == 'running') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _cancel,
                      icon: Icon(Icons.block, size: 13, color: c.red),
                      label: Text(
                        'Cancel tournament',
                        style: TextStyle(color: c.red, fontSize: Dimens.font12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusTone(AppColors c, String s) {
    switch (s) {
      case 'running':
        return c.green;
      case 'upcoming':
        return c.gold;
      case 'completed':
        return c.blue;
      default:
        return c.red;
    }
  }

  Widget _championBanner(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👑 Champion: ${_t['winnerName'] ?? '—'}',
            style: TextStyle(
              color: c.gold,
              fontSize: Dimens.font15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((_t['runnerUpName'] ?? '') != '')
            Text(
              'runner-up ${_t['runnerUpName']}',
              style: TextStyle(color: c.textSecondary, fontSize: Dimens.font11),
            ),
          Text(
            'entries ${fmtMoney(_collected)}',
            style: TextStyle(color: c.textSecondary, fontSize: Dimens.font11),
          ),
        ],
      ),
    );
  }

  Widget _playersCard(AppColors c) {
    return SectionCard(
      title: 'Players · ${_players.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AddEntryForm(
            members: widget.club.members.where((m) => m.active).toList(),
            onAdd: _addPlayer,
          ),
          const SizedBox(height: 8),
          if (_players.isEmpty)
            const EmptyState(
              title: 'No entries yet',
              hint:
                  'Add members or guests — entry fees land in the revenue sheet.',
              icon: Icons.person_add_outlined,
            )
          else
            for (var i = 0; i < _players.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: Dimens.font11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_players[i]['name']}',
                            style: TextStyle(
                              color: c.text,
                              fontSize: Dimens.font12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            (_players[i]['phone'] ?? '').isEmpty
                                ? '—'
                                : '${_players[i]['phone']}',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _busy ? null : () => _togglePaid(_players[i]),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          _players[i]['paidEntry'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color:
                              _players[i]['paidEntry'] == true
                                  ? c.green
                                  : c.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      _players[i]['paidEntry'] == true ? 'paid' : 'unpaid',
                      style: TextStyle(
                        color:
                            _players[i]['paidEntry'] == true ? c.green : c.gold,
                        fontSize: Dimens.font10,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _busy ? null : () => _removePlayer(_players[i]),
                      icon: Icon(Icons.close, size: 14, color: c.red),
                    ),
                  ],
                ),
              ),
          Divider(color: c.border, height: 12),
          Row(
            children: [
              Text(
                'Collected',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              ),
              const Spacer(),
              Text(
                fmtMoney(_collected),
                style: TextStyle(
                  color: c.green,
                  fontSize: Dimens.font12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addPlayer(
    String name,
    String phone,
    String? memberId,
    bool paid,
  ) async {
    await _mutate(() async {
      final res = await widget.session.api.post('$_base/participants', {
        'name': name,
        'phone': phone,
        'memberId': memberId,
      });
      if (paid && ((_t['entryFee'] ?? 0) as num) > 0) {
        final parts = ((res as Map)['participants'] as List?) ?? const [];
        final added = parts.isEmpty ? null : parts.last;
        if (added != null) {
          return widget.session.api.patch(
            '$_base/participants/${added['pid']}',
            {'paidEntry': true},
          );
        }
      }
      return res;
    });
  }

  Future<void> _togglePaid(dynamic p) => _mutate(
    () => widget.session.api.patch('$_base/participants/${p['pid']}', {
      'paidEntry': p['paidEntry'] != true,
    }),
  );

  Future<void> _removePlayer(dynamic p) => _mutate(
    () => widget.session.api.delete('$_base/participants/${p['pid']}'),
  );

  Future<void> _edit() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => TournamentFormSheet(
            session: widget.session,
            club: widget.club,
            existing: _t,
          ),
    );
    if (changed == true) {
      final list = await widget.session.api.get(
        '/clubs/${widget.club.clubId}/tournaments',
      );
      final ours = (list as List).firstWhere(
        (x) => x['id'] == _t['id'],
        orElse: () => _t,
      );
      setState(() => _t = Map<String, dynamic>.from(ours as Map));
      widget.onChanged();
    }
  }

  Future<void> _cancel() async {
    final sure = await confirmSheet(
      context,
      title: 'Cancel tournament?',
      message:
          'Matches and the bracket will be cleared. Collected entries are not refunded automatically (product rule).',
      confirmLabel: 'Cancel it',
      destructive: true,
    );
    if (!sure) return;
    await _mutate(() => widget.session.api.post('$_base/cancel'));
  }

  Future<void> _delete() async {
    final sure = await confirmSheet(
      context,
      title: 'Delete tournament?',
      message:
          'Poora record hat jayega. Entry/prize payment entries ledger me rehti hain.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await widget.session.api.delete(_base);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ------------------------------------------------------------------ league
  Widget _standingsCard(AppColors c) {
    final table = List<dynamic>.from(_t['_standings'] ?? const []);
    if (table.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        title: 'League Standings',
        child: Column(
          children: [
            Row(
              children: [
                _th(c, '#', w: 22),
                _thx(c, 'PLAYER'),
                _th(c, 'P', w: 24, right: true),
                _th(c, 'W', w: 24, right: true),
                _th(c, 'L', w: 24, right: true),
                _th(c, 'DIFF', w: 36, right: true),
                _th(c, 'PTS', w: 30, right: true),
              ],
            ),
            Divider(color: c.border, height: 8),
            for (var i = 0; i < table.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: BoxDecoration(
                  color:
                      i == 0
                          ? c.green.withValues(alpha: 0.10)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    _td(c, '${i + 1}', w: 22, muted: true),
                    _tdx(
                      c,
                      '${i == 0 ? '👑 ' : ''}${table[i]['name']}',
                      tone: i == 0 ? c.green : null,
                      bold: i == 0,
                    ),
                    _td(c, '${table[i]['played']}', w: 24, right: true),
                    _td(c, '${table[i]['won']}', w: 24, right: true),
                    _td(c, '${table[i]['lost']}', w: 24, right: true),
                    _td(c, '${table[i]['scoreDiff']}', w: 36, right: true),
                    _td(
                      c,
                      '${table[i]['points']}',
                      w: 30,
                      right: true,
                      bold: true,
                      tone: i == 0 ? c.green : null,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'win = 3 pts · tiebreak: score diff, then wins',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
            ),
          ],
        ),
      ),
    );
  }

  // tiny table-cell helpers (fixed-width + flexible variants)
  Widget _th(AppColors c, String t, {double w = 40, bool right = false}) =>
      SizedBox(
        width: w,
        child: Text(
          t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: c.textMuted,
            fontSize: Dimens.font9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _thx(AppColors c, String t) => Expanded(
    child: Text(
      t,
      style: TextStyle(
        color: c.textMuted,
        fontSize: Dimens.font9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _td(
    AppColors c,
    String t, {
    double w = 40,
    bool right = false,
    bool muted = false,
    bool bold = false,
    Color? tone,
  }) => SizedBox(
    width: w,
    child: Text(
      t,
      textAlign: right ? TextAlign.right : TextAlign.left,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tone ?? (muted ? c.textMuted : c.text),
        fontSize: Dimens.font11,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );

  Widget _tdx(AppColors c, String t, {Color? tone, bool bold = false}) =>
      Expanded(
        child: Text(
          t,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tone ?? c.text,
            fontSize: Dimens.font11,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      );

  // ------------------------------------------------------------------ bracket
  Widget _bracket(AppColors c) {
    final rounds = <int>[];
    for (final m in _matches) {
      final r = (m['round'] ?? 0) as int;
      if (!rounds.contains(r)) rounds.add(r);
    }
    rounds.sort();
    final totalRounds = rounds.isEmpty ? 0 : rounds.last + 1;
    return SectionCard(
      title:
          _isLeague
              ? 'Fixtures · round robin'
              : 'Bracket · ${_players.length}-player draw',
      child:
          _matches.isEmpty
              ? Text(
                'No matches yet.',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font12),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in rounds) ...[
                    Text(
                      _isLeague
                          ? 'ROUND ${r + 1}'.toUpperCase()
                          : _roundName(r, totalRounds).toUpperCase(),
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final m in _matches.where((x) => x['round'] == r))
                      _MatchCard(m, screen: this),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
    );
  }

  String _roundName(int r, int total) {
    const names = {
      1: 'Final',
      2: 'Semi Final',
      3: 'Quarter Final',
      4: 'Round of 16',
      5: 'Round of 32',
    };
    final remaining = total - r;
    return names[remaining] ?? 'Round of ${1 << remaining}';
  }
}

// ---------------------------------------------------------------------------
class _AddEntryForm extends StatefulWidget {
  final List<Member> members;
  final Future<void> Function(
    String name,
    String phone,
    String? memberId,
    bool paid,
  )
  onAdd;
  const _AddEntryForm({required this.members, required this.onAdd});

  @override
  State<_AddEntryForm> createState() => _AddEntryFormState();
}

class _AddEntryFormState extends State<_AddEntryForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Member? _member;
  bool _paid = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final members = widget.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Member'),
        DropdownButtonFormField<String>(
          style: AppText.dropdown.copyWith(color: c.text),
          initialValue: _member?.id ?? '',
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Guest / type name →'),
            ),
            for (final m in members)
              DropdownMenuItem(
                value: m.id,
                child: Text(
                  m.name,
                  style: const TextStyle(fontSize: Dimens.font12),
                ),
              ),
          ],
          onChanged:
              (v) => setState(() {
                _member =
                    (v == null || v.isEmpty)
                        ? null
                        : members.firstWhere((m) => m.id == v);
                if (_member != null) {
                  _name.text = _member!.name;
                  _phone.text = _member!.phone;
                }
              }),
        ),
        if (_member == null) ...[
          const FieldLabel('Guest name'),
          TextField(
            controller: _name,
            style: AppText.field.copyWith(color: c.text),
            decoration: const InputDecoration(hintText: 'walk-in player'),
          ),
        ],
        const FieldLabel('Phone'),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          style: AppText.field.copyWith(color: c.text),
          decoration: const InputDecoration(hintText: '98xxxxxx01'),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _paid = !_paid),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _paid ? Icons.check_box : Icons.check_box_outline_blank,
                size: 15,
                color: _paid ? c.green : c.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                'Entry paid now (fee goes to revenue sheet)',
                style: TextStyle(
                  color: _paid ? c.green : c.textSecondary,
                  fontSize: Dimens.font11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: c.green,
              foregroundColor: c.onGreen,
            ),
            onPressed:
                _busy
                    ? null
                    : () async {
                      final name = _member?.name ?? _name.text.trim();
                      if (name.isEmpty) {
                        toast(context, 'Name required', error: true);
                        return;
                      }
                      setState(() => _busy = true);
                      await widget.onAdd(
                        name,
                        _phone.text.trim(),
                        _member?.id,
                        _paid,
                      );
                      if (mounted) {
                        setState(() {
                          _busy = false;
                          _member = null;
                          _name.clear();
                          _phone.clear();
                          _paid = true;
                        });
                      }
                    },
            icon: const Icon(Icons.person_add_outlined, size: 15),
            label: const Text('Add Entry'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class _MatchCard extends StatefulWidget {
  final dynamic m;
  final _TournamentDetailScreenState screen;
  const _MatchCard(this.m, {required this.screen});

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  final _s1 = TextEditingController();
  final _s2 = TextEditingController();
  String? _winner;
  String? _tableId;
  String _mode = 'cash';

  dynamic get m => widget.m;

  @override
  void dispose() {
    _s1.dispose();
    _s2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = '${m['status']}';
    final p1 = m['p1'] as Map?;
    final p2 = m['p2'] as Map?;
    final border =
        status == 'table_live'
            ? c.red.withValues(alpha: 0.55)
            : status == 'ready'
            ? c.green.withValues(alpha: 0.4)
            : status == 'done'
            ? c.blue.withValues(alpha: 0.4)
            : c.border;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${m['label']}',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: Dimens.font10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _badge(c, status),
              ],
            ),
            const SizedBox(height: 5),
            _playerRow(c, 'P1', p1, m['score1'], m['winnerPid']),
            const SizedBox(height: 3),
            _playerRow(c, 'P2', p2, m['score2'], m['winnerPid']),
            if (status == 'table_live') _liveBlock(c),
            if (status == 'ready') _readyBlock(c, p1, p2),
            if (status == 'table_live') _scoreSave(c, p1, p2),
            if (status == 'done') ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    fmtDT(m['playedAt']),
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font9_5,
                    ),
                  ),
                  const Spacer(),
                  if ((m['minutes'] ?? 0) != null &&
                      (m['minutes'] as int?) != 0 &&
                      m['minutes'] != null)
                    Text(
                      '${m['minutes']}m',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font9_5,
                      ),
                    ),
                  if (((m['tableAmount'] ?? 0) as num) > 0)
                    Text(
                      '  · table ${fmtMoney(m['tableAmount'])} → loser',
                      style: TextStyle(color: c.gold, fontSize: Dimens.font9_5),
                    ),
                  if ((m['tableName'] ?? '') != '')
                    Text(
                      '  · ${m['tableName']}',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: Dimens.font9_5,
                      ),
                    ),
                ],
              ),
            ],
            if (status == 'bye')
              Text(
                'bye — auto-advanced',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
            if (status == 'waiting')
              Text(
                'waiting for earlier matches',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(AppColors c, String status) {
    switch (status) {
      case 'ready':
        return ToneBadge('ready', c.gold);
      case 'table_live':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                color: c.red,
                fontSize: Dimens.font10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      case 'done':
        return ToneBadge('done', c.blue);
      case 'bye':
        return ToneBadge('bye', c.textMuted);
      default:
        return ToneBadge('waiting', c.textMuted);
    }
  }

  Widget _playerRow(
    AppColors c,
    String tag,
    Map? p,
    dynamic score,
    dynamic winnerPid,
  ) {
    final isWinner =
        p != null &&
        winnerPid != null &&
        '${p['pid']}' == '$winnerPid' &&
        m['status'] == 'done';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isWinner ? c.green.withValues(alpha: 0.12) : c.bgMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isWinner ? c.green.withValues(alpha: 0.45) : c.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            tag,
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              p == null ? '—' : '${isWinner ? '👑 ' : ''}${p['name']}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isWinner ? c.green : (p == null ? c.textMuted : c.text),
                fontSize: Dimens.font12,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (score != null)
            Text(
              '$score',
              style: TextStyle(
                color: isWinner ? c.green : c.text,
                fontSize: Dimens.font13,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _liveBlock(AppColors c) {
    final started = DateTime.tryParse('${m['startedAt'] ?? ''}')?.toLocal();
    // Duration.clamp nahi hai purane Dart me — manual clamp (0 se 2 din).
    final raw =
        started == null ? Duration.zero : DateTime.now().difference(started);
    final elapsed =
        raw < Duration.zero
            ? Duration.zero
            : (raw > const Duration(days: 2) ? const Duration(days: 2) : raw);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            hhmmss(elapsed),
            style: TextStyle(
              color: c.text,
              fontSize: Dimens.font21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '${m['tableName'] ?? ''} · ${fmtMoney(m['hourlyRate'])}/hr',
            style: TextStyle(color: c.textSecondary, fontSize: Dimens.font10),
          ),
        ],
      ),
    );
  }

  Widget _readyBlock(AppColors c, Map? p1, Map? p2) {
    final busy = widget.screen._busyTables;
    final free =
        widget.screen.widget.club.tables
            .where((t) => t.active && !busy.contains(t.id))
            .toList();
    _tableId ??= free.isEmpty ? null : free.first.id;
    if (_tableId != null && free.every((t) => t.id != _tableId)) {
      _tableId = free.isEmpty ? null : free.first.id;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            style: AppText.dropdown.copyWith(color: c.text),
            initialValue: _tableId ?? '',
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Table tracker: off (score only)'),
              ),
              for (final t in free)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    '${t.name} · ${fmtMoney(t.hourlyRate)}/hr',
                    style: const TextStyle(fontSize: Dimens.font12),
                  ),
                ),
            ],
            onChanged:
                (v) => setState(
                  () => _tableId = (v == null || v.isEmpty) ? null : v,
                ),
          ),
          const SizedBox(height: 6),
          // ★ v3.25 — owner spec: On Table aur score-only EK row me, equal halves.
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: c.onGreen,
                  ),
                  onPressed:
                      widget.screen._busy
                          ? null
                          : () {
                            if (_tableId == null) {
                              toast(
                                context,
                                'Choose a table or save with score only',
                                error: true,
                              );
                              return;
                            }
                            widget.screen._mutate(
                              () => widget.screen.widget.session.api.post(
                                '${widget.screen._base}/matches/${m['id']}/play',
                                {'tableId': _tableId},
                              ),
                            );
                          },
                  icon: const Icon(Icons.timer_outlined, size: 15),
                  label: const Text('On Table'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      widget.screen._busy
                          ? null
                          : () => setState(() => _showScore = true),
                  child: const Text('Score only'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _showScore = false;

  Widget _scoreSave(AppColors c, Map? p1, Map? p2) {
    final status = '${m['status']}';
    if (status == 'ready' && !_showScore) return const SizedBox.shrink();
    _winner ??= '${(p1 ?? const {})['pid'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _s1,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.text,
                    fontSize: Dimens.font15,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '${p1?['name'] ?? 'P1'}',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(color: c.textMuted, fontSize: Dimens.font15),
                ),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _s2,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.text,
                    fontSize: Dimens.font15,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '${p2?['name'] ?? 'P2'}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  style: AppText.dropdown.copyWith(color: c.text),
                  initialValue: _winner,
                  items: [
                    for (final p in [p1, p2])
                      if (p != null)
                        DropdownMenuItem(
                          value: '${p['pid']}',
                          child: Text(
                            '${p['name']} wins',
                            style: const TextStyle(fontSize: Dimens.font12),
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() => _winner = v),
                ),
              ),
              if (status == 'table_live') ...[
                const SizedBox(width: 6),
                // ★ v3.25 FIX — DropdownButtonFormField ko Row me bina width ke
                // chhoda tha → unbounded constraints → live card toota hua aata
                // tha (debug me red dashed box, doosre widgets ke upar overlap).
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    style: AppText.dropdown.copyWith(color: c.text),
                    isDense: true,
                    initialValue: _mode,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                    ],
                    onChanged: (v) => setState(() => _mode = v ?? 'cash'),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.green,
                  foregroundColor: c.onGreen,
                ),
                onPressed:
                    widget.screen._busy
                        ? null
                        : () {
                          final pids = {
                            '${(p1 ?? const {})['pid']}',
                            '${(p2 ?? const {})['pid']}',
                          };
                          if (_winner == null || !pids.contains(_winner)) {
                            toast(context, 'Choose a winner', error: true);
                            return;
                          }
                          widget.screen._mutate(
                            () => widget.screen.widget.session.api.post(
                              '${widget.screen._base}/matches/${m['id']}/result',
                              {
                                'score1': int.tryParse(_s1.text.trim()) ?? 0,
                                'score2': int.tryParse(_s2.text.trim()) ?? 0,
                                'winnerPid': _winner,
                                'mode': _mode,
                              },
                            ),
                          );
                        },
                child: const Text('Save'),
              ),
            ],
          ),
          if (status == 'table_live')
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'the table timer stops when you save — table charge goes to the loser',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font9_5),
              ),
            ),
        ],
      ),
    );
  }
}
