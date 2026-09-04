import 'package:flutter/material.dart';

import '../dimensions.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  final SessionController session;
  const LoginScreen({super.key, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final c = context.colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.bg, c.bgMuted],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Card(
                  color: c.bgElevated,
                  surfaceTintColor: Colors.transparent,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.24),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Text(
                        //   'Welcome to',
                        //   style: TextStyle(
                        //     color: c.textMuted,
                        //     fontSize: Dimens.font12,
                        //     fontWeight: FontWeight.w600,
                        //   ),
                        // ),
                        // const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 116,
                          decoration: BoxDecoration(
                            // color: const Color(0xFF0C0D0F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            // horizontal: 20,
                            // vertical: 12,
                          ),
                          child: Image.asset(
                            'assets/rowdys_den_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'CLUB BILLING & TABLE MANAGEMENT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.green,
                            fontSize: Dimens.font9,
                            letterSpacing: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: c.bgMuted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.borderStrong),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: c.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Secure access for your club operations',
                                  style: TextStyle(
                                    color: c.text,
                                    fontSize: Dimens.font11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.green,
                              foregroundColor: c.onGreen,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: s.busy ? null : s.signInGoogle,
                            icon: const Icon(Icons.g_mobiledata, size: 20),
                            label: Text(
                              s.busy ? 'Signing in…' : 'Continue with Google',
                            ),
                          ),
                        ),
                        if (s.lastError != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: c.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.red),
                            ),
                            child: Text(
                              s.lastError!,
                              style: TextStyle(
                                color: c.red,
                                fontSize: Dimens.font11,
                              ),
                            ),
                          ),
                        ],
                        if (s.devMode) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(height: 1, color: c.border),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'DEV LOGIN',
                                  style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: Dimens.font9,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(height: 1, color: c.border),
                              ),
                            ],
                          ),
                          const FieldLabel('Email'),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: AppText.field.copyWith(color: c.text),
                            decoration: const InputDecoration(
                              hintText: 'owner@rowdys.dev',
                            ),
                          ),
                          const FieldLabel('Name (new accounts)'),
                          TextField(
                            controller: _name,
                            style: AppText.field.copyWith(color: c.text),
                            decoration: const InputDecoration(
                              hintText: 'Raju Bhai',
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed:
                                  s.busy
                                      ? null
                                      : () => s.signInDev(
                                        _email.text.trim(),
                                        name: _name.text.trim(),
                                      ),
                              child: const Text('Sign in (dev)'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Billing, due desk, tournaments & finance — managed from the Master Admin panel.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
