import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../session.dart';
import '../theme.dart';

/// First-run onboarding (shown once before login — persisted via prefs).
class OnboardingScreen extends StatefulWidget {
  final SessionController session;
  const OnboardingScreen({super.key, required this.session});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      Icons.grid_on,
      'Tables chalao, bill khud bano',
      'Start a table and the timer, rates, peak hours, and glove charges run automatically. Stop it when ready and the server calculates the final bill. Winners never pay.',
    ),
    _Slide(
      Icons.groups_outlined,
      'Players, wallet & due ek jagah',
      'Track every regular player\'s wallet, frame pass, and due. Collect from the Due Desk in one tap, or send a WhatsApp or email reminder.',
    ),
    _Slide(
      Icons.local_cafe_outlined,
      'Counter items & receipts',
      'Add cold drinks, tea, and snacks with a tap and save the bill. Print or share a 58mm thermal receipt instantly. Offline bills queue and sync later.',
    ),
    _Slide(
      Icons.emoji_events_outlined,
      'Tournaments & reports ready',
      'Knockout ya league — bracket, live table billing, champion tak. Day Close, Monthly sheet, P&L — sab Excel/PDF me export.',
    ),
    _Slide(
      Icons.space_dashboard_outlined,
      'Dashboard & Smart Insights',
      'Owner Dashboard pe aaj ki kamai, 14-day graph, income mix aur P&L ek nazar me. Smart Insights khud batata hai — kaunsa table sabse zyada kama raha, kaun player due pe hai.',
    ),
    _Slide(
      Icons.bolt_outlined,
      'Offline bhi chale, themes bhi',
      'Net chala jaye? Bills queue ho jate hain — wapas aate hi auto-sync. Dark/light dono theme, aur Settings se apna club logo bhi upload kar sakte ho.',
    ),
  ];

  void _done() => widget.session.completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _done,
                child: Text(
                  'Skip',
                  style: TextStyle(color: c.textMuted, fontSize: Dimens.font12),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: c.green.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.green.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(s.icon, size: 40, color: c.green),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: Dimens.font13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _page == i ? c.green : c.borderStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: c.onGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed:
                      last
                          ? _done
                          : () => _pager.nextPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                  child: Text(
                    last ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: Dimens.font14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                "Rowdy's Den — Club Billing",
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}
