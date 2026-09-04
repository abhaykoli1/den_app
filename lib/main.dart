import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/api.dart';
import 'src/config.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/screens/shell.dart';
import 'src/screens/subscription_screen.dart';
import 'src/session.dart';
import 'src/theme.dart';

/// Rowdy's Den — Club Billing (Flutter companion).
///
/// The FastAPI backend is the ONLY authoritative calculator — every screen
/// here shows client-side estimates at best; final numbers always come from
/// the server's confirm/billing endpoints.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController(Api());
  final prefs = await SharedPreferences.getInstance();
  // First-run intro (once): tables → dues → reports → tournaments.
  session.showOnboarding = !(prefs.getBool('rd_seen_onboarding') ?? false);
  runApp(RowdysDenApp(session: session));
  // Restore token + profile after first frame so the loader paints first.
  session.restore();
}

class RowdysDenApp extends StatelessWidget {
  final SessionController session;
  const RowdysDenApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder:
          (context, _) => MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            // Match the member app's charcoal, cream, gold, and green theme.
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: session.darkMode ? ThemeMode.dark : ThemeMode.light,
            themeAnimationDuration: const Duration(milliseconds: 260),
            themeAnimationCurve: Curves.easeOutCubic,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(session.textScale)),
                  child: child!,
                ),
            home: _route(),
          ),
    );
  }

  Widget _route() {
    if (session.restoring) {
      return const BrandSplashScreen();
    }
    if (!session.isLoggedIn && session.showOnboarding) {
      return OnboardingScreen(session: session);
    }
    if (!session.isLoggedIn) return LoginScreen(session: session);
    // First sign-in and 402 renewal wall. A pending request stays here until
    // the Master Admin changes its status to active/trial.
    if (session.subscriptionLocked || session.needsSubscriptionSetup) {
      return SubscriptionScreen(session: session);
    }
    return HomeShell(session: session);
  }
}

/// Branded Flutter splash shown after the native launch screen while the
/// saved session is restored.
class BrandSplashScreen extends StatelessWidget {
  const BrandSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 42),
            child: Transform.translate(
              offset: Offset.zero,
              child: SizedBox(
                width: 220,
                height: 220,
                child: Image(
                  image: AssetImage('assets/rowdys_den_logo_square.png'),
                  fit: BoxFit.contain,
                  semanticLabel: "Rowdy's Den",
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
