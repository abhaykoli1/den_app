import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../api.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// 402 onboarding — plan cards, recommended highlighted, "waiting for activation".
class SubscriptionScreen extends StatefulWidget {
  final SessionController session;
  const SubscriptionScreen({super.key, required this.session});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SellerPlan> _plans = [];
  bool _loading = true;
  String? _error;
  String? _selecting;
  bool _checkingStatus = false;

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
      final list = await widget.session.api.get('/subscription-plans');
      _plans =
          (list as List)
              .map((p) => SellerPlan.fromJson(Map<String, dynamic>.from(p)))
              .toList();
    } on ApiException catch (e) {
      _error = e.message;
    }
    setState(() => _loading = false);
  }

  Future<void> _select(SellerPlan p) async {
    setState(() => _selecting = p.id);
    try {
      final data = await widget.session.api.post(
        '/account/subscription/select',
        {'planId': p.id},
      );
      final user = AppUser.fromJson(Map<String, dynamic>.from(data['user']));
      widget.session.user = user;
      final approved = widget.session.hasUsableSubscription(user.subscription);
      // Pending plans deliberately do not enter the app. The Master Admin
      // activates them from Users → Subscription.
      if (approved) {
        await _openClubIfApproved();
      }
      widget.session.subscriptionLocked = !approved;
      widget.session.broadcast();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _selecting = null);
  }

  Future<void> _openClubIfApproved() async {
    await widget.session.loadClubs();
    if (widget.session.clubs.isEmpty) {
      await widget.session.api.post('/clubs', {'name': "Rowdy's Den"});
      await widget.session.loadClubs();
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _checkingStatus = true);
    try {
      await widget.session.refreshAccount();
      final approved = widget.session.hasUsableSubscription(
        widget.session.user?.subscription,
      );
      if (approved) {
        await _openClubIfApproved();
        widget.session.subscriptionLocked = false;
        widget.session.broadcast();
      } else if (mounted) {
        toast(context, 'Plan approval is pending with the Master Admin.');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _checkingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sub = widget.session.user?.subscription;
    final pending = sub != null && sub['status'] == 'pending';
    return Scaffold(
      body:
          _loading
              ? const EightBallLoader()
              : _error != null
              ? EmptyState(title: _error!, icon: Icons.cloud_off_outlined)
              : ListView(
                padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
                children: [
                  Text(
                    'Choose your plan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.text,
                      fontSize: Dimens.font23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Signed in as ${widget.session.user?.name ?? ''} (${widget.session.user?.email ?? ''})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: Dimens.font12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (pending)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              color: c.gold,
                              size: 30,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Awaiting activation',
                              style: TextStyle(
                                color: c.text,
                                fontSize: Dimens.font14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Your ${sub['planName']} plan is pending. A Master Admin must activate it before club access opens.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: Dimens.font11,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed:
                                      _checkingStatus ? null : _checkStatus,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: Text(
                                    _checkingStatus
                                        ? 'Checking…'
                                        : 'Check status',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: widget.session.signOut,
                                  icon: const Icon(Icons.logout, size: 15),
                                  label: const Text('Sign out'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Text(
                  //   'One subscription powers the whole club',
                  //   style: TextStyle(
                  //     color: c.textMuted,
                  //     fontSize: Dimens.font11,
                  //   ),
                  // ),
                  const SizedBox(height: 10),
                  for (final p in _plans)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: p.recommended ? c.gold : c.border,
                          width: p.recommended ? 1.4 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: Dimens.font15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (p.recommended)
                                  ToneBadge('Recommended', c.gold),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${fmtMoney(p.price)} / ${p.billingCycle == 'yearly' ? 'year' : 'month'}',
                              style: TextStyle(
                                color: c.green,
                                fontSize: Dimens.font19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (p.trialDays > 0)
                              Text(
                                '${p.trialDays}-day free trial included',
                                style: TextStyle(
                                  color: c.blue,
                                  fontSize: Dimens.font11,
                                ),
                              ),
                            const SizedBox(height: 8),
                            for (final f in p.features)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.check, size: 12, color: c.green),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        f,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: Dimens.font12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              '${p.maxClubs} club${p.maxClubs > 1 ? 's' : ''} included',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: Dimens.font11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      p.recommended ? c.gold : c.green,
                                  foregroundColor:
                                      p.recommended ? c.onGold : c.onGreen,
                                ),
                                onPressed:
                                    _selecting != null
                                        ? null
                                        : () => _select(p),
                                child: Text(
                                  _selecting == p.id
                                      ? 'Starting…'
                                      : p.trialDays > 0
                                      ? 'Start free trial'
                                      : 'Request plan',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => widget.session.signOut(),
                    icon: const Icon(Icons.logout, size: 14),
                    label: const Text(
                      'Sign out',
                      style: TextStyle(fontSize: Dimens.font12),
                    ),
                  ),
                ],
              ),
    );
  }
}
