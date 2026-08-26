import 'package:flutter/material.dart';

import '../dimensions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../rowdy_care.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Human Support — contact + FAQ (§37). Fetches live contact from /platform/support.
class SupportScreen extends StatefulWidget {
  final SessionController session;
  const SupportScreen({super.key, required this.session});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.session.api.get('/platform/support');
      if (mounted) {
        setState(() {
          _email = '${s['email'] ?? ''}';
          _phone = '${s['phone'] ?? ''}';
        });
      }
    } catch (_) {
      /* defaults remain */
    }
  }

  String get _digits => _phone.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Could not open — long-press to copy instead',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Talk to the Master Admin',
          trailing: Icon(Icons.headset_mic_outlined, color: c.green, size: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan upgrades & activation, club limits, account enable/disable — handled directly by the platform admin. Pick any channel; your registered email helps them find your account faster.',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: Dimens.font11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              _channel(
                c,
                Icons.mail_outline,
                'Email',
                _email.isEmpty ? 'loading…' : _email,
                _email.isEmpty ? null : () => _open('mailto:$_email'),
              ),
              if (_phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                _channel(
                  c,
                  Icons.call_outlined,
                  'Call',
                  _phone,
                  () => _open('tel:+$_digits'),
                ),
                const SizedBox(height: 6),
                _channel(
                  c,
                  Icons.chat_outlined,
                  'WhatsApp',
                  _phone,
                  () => _open('https://wa.me/$_digits'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Fastest answers — Rowdy Care',
          trailing: Icon(Icons.auto_awesome, color: c.green, size: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Billing splits, dues, Day Close, wallets, tournaments, exports — the green chat bubble answers instantly, 24×7, on every screen.',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: Dimens.font11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.green,
                  foregroundColor: c.onGreen,
                ),
                onPressed:
                    () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RowdyCareSheet(session: widget.session),
                    ),
                icon: const Icon(Icons.chat_bubble_outline, size: 15),
                label: const Text('Open Rowdy Care chat'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SectionCard(
          title: 'Common questions',
          child: Column(
            children: [
              _Faq(
                'Billing is locked (subscription)?',
                'Plans turn active the moment the Master Admin confirms your payment — any billing lock clears right then. Send your registered account email through any contact option above.',
              ),
              _Faq(
                '"Session expired" keeps showing?',
                'Sessions expire for safety — just sign in again with Google. All club data stays exactly as you left it.',
              ),
              _Faq(
                'Club limit reached, need one more club?',
                'Your plan fixes the club count (shown in the club switcher). Ask the Master Admin to upgrade the plan — the new club can be created right after.',
              ),
              _Faq(
                "Staff can't open Finance / Expenses?",
                'By design: staff handle billing, players, dues, items and tournaments; money-admin pages stay owner-only.',
              ),
              _Faq(
                'Want your club data deleted?',
                'Email the Master Admin from your registered owner account with the club name — also see the Privacy & Policy page.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _channel(
    AppColors c,
    IconData icon,
    String label,
    String value,
    VoidCallback? onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: c.bgMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: c.green),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.green,
                    fontSize: Dimens.font11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String q;
  final String a;
  const _Faq(this.q, this.a);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      iconColor: c.textMuted,
      collapsedIconColor: c.textMuted,
      title: Text(
        q,
        style: TextStyle(
          color: c.text,
          fontSize: Dimens.font12_5,
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [
        Text(
          a,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: Dimens.font11_5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Privacy & Policy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last updated: 8 August 2026',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
              const SizedBox(height: 6),
              Text(
                "Rowdy's Den — Club Billing (\"the app\") is billing software for billiards / pool / snooker clubs: live table timers, member billing, dues, counter sales, expenses, reports and tournaments. This page explains, in plain words, what data the app stores and how it is used.",
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: Dimens.font11_5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _PpSection('1. What we store', [
          'Your account — name, email and profile picture from your Google sign-in, plus your role (owner / staff / master admin). We never see or store your Google password.',
          'Club data you enter — clubs and branches, tables, players & members (including phone numbers and emails), table sessions and frame bills, counter item bills, payments and dues, expenses, tournaments, and activity logs.',
          'Platform data — your subscription plan & status, the seller\'s support contact, and a record of transactional emails the system produces.',
        ]),
        const _PpSection('2. How it is used', [
          'Only to run the app for you — billing, reports, dues & alerts, reminders and membership tracking.',
          'Transactional email to the address on record: trial/subscription status, membership sold, balance summary and expiry reminders.',
          'WhatsApp is opened only when YOU tap a reminder or message button — nothing is sent automatically.',
          'We do not sell your data, show ads, or use your club/member data for marketing. Ever.',
        ]),
        const _PpSection('3. Local storage on your device', [
          'No tracking cookies. The app keeps only what it needs to work: your session token and the active club selection.',
        ]),
        const _PpSection('4. Services we rely on', [
          'Google — sign-in (we receive your basic profile: name, email, picture).',
          'MongoDB Atlas — cloud database where your club data lives.',
          'Vercel — hosting that serves the app and its API.',
        ]),
        const _PpSection('5. Your choices', [
          'Export everything anytime from Settings → Data Export (Excel/JSON).',
          'Ask for your account or club data to be deleted — email the Master Admin from your registered owner account.',
          'Staff accounts are controlled by the club owner and the Master Admin.',
        ]),
        const _PpSection('6. Retention & security', [
          'Data is kept while your account is active. Passwords never touch our servers (Google sign-in only). API calls are authenticated with per-session tokens and served over HTTPS.',
        ]),
      ],
    );
  }
}

class _PpSection extends StatelessWidget {
  final String title;
  final List<String> bullets;
  const _PpSection(this.title, this.bullets);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: TextStyle(
                        color: c.green,
                        fontSize: Dimens.font11_5,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: Dimens.font11_5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Terms & Conditions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last updated: 8 August 2026',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
              const SizedBox(height: 6),
              Text(
                'These terms govern the use of Rowdy\'s Den — Club Billing ("the app"). By signing in and using the app, you agree to them. They are written in plain words on purpose — if anything is unclear, ask from the Human Support page.',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: Dimens.font11_5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _PpSection('1. The service', [
          'The app is subscription software for billiards / pool / snooker clubs: live table timers, member billing, dues, counter sales with stock, expenses, financial reports, tournaments and data exports. All money amounts are computed and locked by the server; screens show live estimates.',
        ]),
        const _PpSection('2. Accounts & roles', [
          'Sign-in is via Google. You are responsible for every action taken under your account.',
          'The club owner is responsible for their club\'s data and for the staff accounts they add — staff see operational pages only, by design.',
          'The Master Admin (platform seller) manages subscription plans, user access and the support contact — never your day-to-day club data entry.',
        ]),
        const _PpSection('3. Subscription & billing', [
          'New accounts may start on a trial; paid plans activate only after the Master Admin confirms payment.',
          'When a subscription isn\'t active, billing features lock (a 402 state) — your data stays safe and visible.',
          'Each plan fixes limits (e.g. number of clubs). Upgrades take effect as soon as the Master Admin applies them.',
          'Fees are for the subscription period and are non-refundable, except at the platform\'s discretion.',
        ]),
        const _PpSection('4. Your data', [
          'Your club\'s data belongs to you. You grant the app permission to store and process it only to operate the service (billing, reports, reminders, exports). You can export everything anytime from Settings → Data Export. How data is stored, used and deleted is covered in the Privacy & Policy page.',
        ]),
        const _PpSection('5. Fair use', [
          'Don\'t abuse the service: no scraping, no sharing of accounts across clubs, no attempts to bypass plan limits or role lockdowns. Abuse can lead to the account being blocked (access can be restored by the Master Admin).',
        ]),
        const _PpSection('6. Liability', [
          'The app computes money with server-side, two-decimal precision and keeps an audit log — still, the club owner remains responsible for verifying day-close, statements and tax records.',
        ]),
      ],
    );
  }
}
