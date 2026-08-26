import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

/// Club Staff — roles & access (§18, owner-only; masters never listed).
class TeamScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const TeamScreen({super.key, required this.session, required this.club});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _clubs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _locked => widget.session.user?.isStaff ?? false;

  Future<void> _load() async {
    if (_locked) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.session.api.get('/team');
      _clubs = List<dynamic>.from(d['clubs'] ?? const []);
    } on ApiException catch (e) {
      _error = e.isForbidden ? null : e.message;
      _clubs = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_locked) return const AdminLockedCard();

    final handlers = _clubs.fold<int>(
      0,
      (a, cl) => a + ((cl['handlers'] as List?) ?? const []).length,
    );
    final disabled = _clubs.fold<int>(
      0,
      (a, cl) =>
          a +
          (((cl['handlers'] as List?) ?? const [])
              .where((h) => h['active'] != true)
              .length),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Clubs',
                  value: '${_clubs.length}',
                  sub: 'under you',
                  tone: c.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Handlers',
                  value: '$handlers',
                  sub: 'owners + staff',
                  tone: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Disabled',
                  value: '$disabled',
                  sub: 'blocked by Master',
                  tone: c.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: EightBallLoader(label: 'loading team…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load',
              hint: _error!,
              icon: Icons.cloud_off_outlined,
            )
          else
            for (final cl in _clubs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  title: '${(cl['club'] as Map?)?['name'] ?? 'Club'}',
                  trailing: ToneBadge(
                    '${((cl['handlers'] as List?) ?? const []).length} handlers',
                    c.blue,
                  ),
                  child:
                      (cl['handlers'] as List? ?? const []).isEmpty
                          ? Text(
                            'Only you (owner) — no staff members yet.',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: Dimens.font11,
                            ),
                          )
                          : Column(
                            children: [
                              for (final h in (cl['handlers'] as List))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor: (h['isOwner'] == true
                                                ? c.gold
                                                : c.blue)
                                            .withValues(alpha: 0.16),
                                        child: Text(
                                          '${h['name'] ?? '?'}'.isEmpty
                                              ? '?'
                                              : '${h['name']}'
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                          style: TextStyle(
                                            color:
                                                h['isOwner'] == true
                                                    ? c.gold
                                                    : c.blue,
                                            fontSize: Dimens.font12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${h['name']}',
                                              style: TextStyle(
                                                color: c.text,
                                                fontSize: Dimens.font12_5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${h['email']}',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: c.textMuted,
                                                fontSize: Dimens.font10,
                                              ),
                                            ),
                                            Text(
                                              h['lastLoginAt'] == null
                                                  ? 'never signed in'
                                                  : 'last login ${fmtDT(h['lastLoginAt'])}',
                                              style: TextStyle(
                                                color: c.textMuted,
                                                fontSize: Dimens.font9_5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ToneBadge(
                                        h['isOwner'] == true
                                            ? 'Owner'
                                            : 'Staff',
                                        h['isOwner'] == true ? c.gold : c.blue,
                                      ),
                                      if (h['active'] != true) ...[
                                        const SizedBox(width: 4),
                                        ToneBadge('disabled', c.red),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                ),
              ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'For staff access, the account must first sign in to the app with Google. Then you or the Master Admin can add it as club staff from the Master panel.',
              style: TextStyle(
                color: c.textMuted,
                fontSize: Dimens.font10,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
