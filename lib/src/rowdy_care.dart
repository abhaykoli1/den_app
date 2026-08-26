import 'package:flutter/material.dart';

import 'dimensions.dart';

import 'session.dart';
import 'theme.dart';

/// ✨ Rowdy Care — customer-care chat (§19). Pure rule engine, in-memory
/// conversation, Hinglish replies. Floating on every screen via HomeShell.
/// ★ v3.24 — web parity: floating help ab slim RIGHT-EDGE TAB hai
/// (mobile web ki .support-fab jaisa: 30×54, left-rounded, mid-screen).
class RightEdgeTabLocation extends FloatingActionButtonLocation {
  const RightEdgeTabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) {
    final w = g.floatingActionButtonSize.width;
    final h = g.floatingActionButtonSize.height;
    return Offset(
      g.scaffoldSize.width - w,
      g.scaffoldSize.height * 0.62 - h / 2,
    );
  }
}

class RowdyCareFab extends StatelessWidget {
  final SessionController session;
  const RowdyCareFab({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 30,
      height: 54,
      child: Material(
        color: c.green,
        elevation: 3,
        shadowColor: Colors.black54,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
          ),
          onTap:
              () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RowdyCareSheet(session: session),
              ),
          child: Icon(Icons.headset_mic_outlined, size: 18, color: c.onGreen),
        ),
      ),
    );
  }
}

class RowdyCareSheet extends StatefulWidget {
  final SessionController session;
  const RowdyCareSheet({super.key, required this.session});

  @override
  State<RowdyCareSheet> createState() => _RowdyCareSheetState();
}

class _Msg {
  final String text;
  final bool bot;
  const _Msg(this.text, {this.bot = false});
}

class _Topic {
  final List<String> keys;
  final String reply;
  final bool support; // human handoff → live contact from /platform/support
  const _Topic(this.keys, this.reply, {this.support = false});
}

class _RowdyCareSheetState extends State<RowdyCareSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [
    const _Msg(
      'Namaste! Main Rowdy Care hoon 👋 — billing, dues, day close, '
      'tournaments, exports… jo bhi help chahiye pooch lo, ya quick topic chuno.',
      bot: true,
    ),
  ];
  bool _typing = false;
  String _supportLine = '';

  static const _chips = [
    'Table billing',
    'Day Close kya hai',
    'Due collect kaise',
    'Advance / Note / Move',
    'League tournament',
    'Stock kam ho to',
    'Excel & PDF export',
    'Plan / subscription',
    'Winner kaun pay karta hai',
    'Human se baat',
  ];

  List<_Topic> _topics() => [
    const _Topic(
      [
        'human',
        'baat',
        'owner se',
        'insaan',
        'master',
        'contact',
        'phone',
        'call',
      ],
      '',
      support: true,
    ),
    const _Topic(
      [
        'plan',
        'subscription',
        'pricing',
        'trial',
        'payment',
        'activate',
        '402',
        'lock',
        'upgrade',
      ],
      'Plan & pricing 💳 — naye accounts trial pe start hote hain. Payment Master Admin confirm karta hi plan active ho jata hai aur billing lock (402) turant khul jata hai. Club limit plan se fix hoti hai — zyada clubs chahiye to Master Admin se upgrade manga jata hai. Subscription status Settings me dikhta hai.',
    ),
    const _Topic(
      [
        'winner',
        'jeet',
        'pay',
        'kaun',
        'billing',
        'timer',
        'table',
        'frame',
        'stop',
      ],
      'Table billing ⏱️ — timer minute-by-minute chalta hai: paisa = (rate/60) × minutes, 2-dp exact (koi rounding-up nahi). Final amount HAMESHA server compute karta hai — app sirf estimate dikhata hai. Rule #1: WINNER kabhi pay nahi karta — bill losers pe split hota hai. 2v2 me puri losing team split karti hai.',
    ),
    const _Topic(
      ['day close', 'dayclose', 'close', 'drawer', 'closing'],
      'Day Close 🌙 — More → Admin → Day Close pe aaj ka poora hisaab: mode-wise collection (cash/UPI/card), source-wise (frames/items/plans/dues/tournaments), kharch, aur closing drawer check. Cash collected − expenses = drawer cash. UPI/card apne statement se match karo. Raat ko band karte time ek nazar — sab clear?',
    ),
    const _Topic(
      ['due', 'udhaar', 'baaki', 'collect', 'due desk', 'limit'],
      'Due Desk 💸 — sabse PURANA due pehle clear hota hai (old-due-first): payment hamesha sabse pehle khule bills ko settle karti hai. Due limit club setting hai — member limit ke paas/par ho to bell icon pe red alert aata hai. Remind button se WhatsApp reminder khulta hai.',
    ),
    const _Topic(
      ['wallet', 'balance', 'prepaid', 'credit'],
      'Wallet 👛 — prepaid credit. Billing pe wallet PEHLE kat-ta hai, jo bachta hai wo due me jata hai (wallet-first rule). Wallet ka paisa club ki liability hai — balance sheet me gina jata hai. Players screen pe Set Balance se top-up/adjust karo.',
    ),
    const _Topic(
      ['pass', 'frame pass', 'frames pack'],
      'Frame pass 🎟️ — pass = frames ka pack (e.g. 10 frames). Bill confirm karte waqt loser ke paas pass ho to 1 frame pass se kat sakta hai. Pass frames Players screen pe dikhte hain aur expire bhi ho sakte hain.',
    ),
    const _Topic(
      [
        'tournament',
        'league',
        'knockout',
        'bracket',
        'match',
        'prize',
        'entry',
      ],
      'Tournaments 🏆 — entry fees income me count hoti hai. Knockout = bracket (single elimination), League = round robin (Make Fixtures se matches bante hain, points table auto). Match ko table pe lagao (▶ On Table) — timer chalega, table charge LOSER deta hai, winner select karte hi prize auto-record. Final pe prize money expense me chali jati hai.',
    ),
    const _Topic(
      ['stock', 'restock', 'item', 'reorder', 'kam', 'inventory', 'menu'],
      'Stock 📦 — Items tab se menu manage karo. Stock add karte hi uska kharch AUTO expense (stock category) ban jata hai — double entry nahi. Reorder level set karo: uske neeche/pahunche hi low-stock alert bell pe aata hai. 0 pe item billing chips se hat jata hai.',
    ),
    const _Topic(
      ['advance', 'note', 'move', 'shift'],
      'Advance / Note / Move ⚡ — live table ke 3 handy actions: Advance = beech game me paisa collect (final bill se minus hota hai), Note = table pe memo (e.g. cue issue), Move = session dusri FREE table pe shift — nayi table ka rate (peak samet) move ke baad se lagta hai.',
    ),
    const _Topic(
      ['peak', 'happy hour', 'rate'],
      'Peak pricing 🕕 — Settings → Table Pricing me peak rate + from/to hour set karo. Session start jo bhi peak window me ho, hourly rate peak wala lagta hai. Move pe rate naye table ke hisaab se dobara resolve hota hai.',
    ),
    const _Topic(
      ['export', 'excel', 'pdf', 'xlsx', 'backup', 'csv', 'download'],
      'Exports 📤 — sab real files, on-device banti hain (server sirf calculator hai):\n• Settings → Data Export: All-in-one Excel (multi-sheet .xlsx), Members/Frames/Item Bills/Expenses .xlsx, Full Backup JSON\n• Finance: P&L / Daily / Stock .xlsx + P&L PDF\n• Monthly: Transactions / Per-day .xlsx + Month PDF\n• Day Close: Closing Slip PDF\n• Item Bill ya Frame card pe print icon: 58mm receipt PDF\nShare sheet se Files/Drive me save ya accountant ko WhatsApp pe forward karo. Sab 2-dp money ke saath.',
    ),
    const _Topic(
      ['setting', 'due limit', 'logo', 'discount', 'configure'],
      'Settings ⚙️ — Club Settings me due limit, winner bonus, default advance, monthly fallback discount, logo. Table Pricing aur Membership Plans bhi yahin se bante hain. Save karte hi sab jagah apply.',
    ),
    const _Topic(
      ['login', 'session', 'expire', 'google', 'sign'],
      'Login 🔐 — Sign-in Google se hota hai. "Session expired" aaye to bas dobara Google se sign in karo — club ka data bilkul waisa hi rahega jaise chhoda tha.',
    ),
    const _Topic(
      ['staff', 'role', 'lockdown', 'admin area', 'owner'],
      'Staff roles 👥 — staff billing, players, dues, items aur tournaments handle karte hain; money-admin pages (Day Close, Finance, Expenses, Staff) owner-only rehte hain — ye by design lockdown hai.',
    ),
    const _Topic(
      ['thank', 'shukriya', 'dhanyavad', 'nice', 'great'],
      'Anytime! 🎱 Play fair, bill fair. Aur kuch chahiye to main yahin hoon.',
    ),
    const _Topic(
      ['hello', 'hi', 'hey', 'namaste', 'namaskar'],
      'Namaste! 😊 Batao — billing, dues, stock, tournament… kis cheez me madad karoon? Niche quick topics bhi hain.',
    ),
  ];

  static const _fallback =
      'Hmm, ye thoda alag sawaal hai 🤔 — main in topics me expert hoon: table billing, winner rule, dues, wallet, frame pass, tournaments/league, stock, advance/note/move, day close, exports, plans. Neeche chips se chuno, ya "Human se baat" likho.';

  Future<void> _send(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(q));
      _typing = true;
    });
    _jump();
    await Future.delayed(const Duration(milliseconds: 650));
    final t = _match(q.toLowerCase());
    String reply = t?.reply ?? _fallback;
    if (t?.support == true) {
      reply = await _supportReply();
    }
    if (!mounted) return;
    setState(() {
      _typing = false;
      _msgs.add(_Msg(reply, bot: true));
    });
    _jump();
  }

  _Topic? _match(String q) {
    _Topic? best;
    var bestScore = 0;
    for (final t in _topics()) {
      var score = 0;
      for (final k in t.keys) {
        if (q.contains(k)) score += k.length;
      }
      if (score > bestScore) {
        best = t;
        bestScore = score;
      }
    }
    return bestScore == 0 ? null : best;
  }

  Future<String> _supportReply() async {
    if (_supportLine.isNotEmpty) return _supportLine;
    var email = 'master@rowdys.dev';
    var phone = '';
    try {
      final s = await widget.session.api.get('/platform/support');
      if (s is Map) {
        if ((s['email'] ?? '').toString().isNotEmpty) email = '${s['email']}';
        phone = '${s['phone'] ?? ''}';
      }
    } catch (_) {
      /* offline — default email dikha do */
    }
    _supportLine =
        'Human handoff 🤝 — seedha Master Admin se baat karo:\n✉️ $email${phone.isNotEmpty ? '\n📞 $phone (call/WhatsApp)' : ''}\nApna registered email likhna — account turant mil jayega. Plan activation, club limit, account issue — sab yahin se solve hota hai.';
    return _supportLine;
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = MediaQuery.of(context).size.height * 0.82;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            // ------------------------------------------------ header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.headset_mic_outlined,
                      color: c.onGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rowdy Care',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Customer care · turant jawab',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.green.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ONLINE',
                          style: TextStyle(
                            color: c.green,
                            fontSize: Dimens.font9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: c.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ------------------------------------------------ messages
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final m in _msgs)
                    Align(
                      alignment:
                          m.bot ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color:
                              m.bot
                                  ? c.bgMuted
                                  : c.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                m.bot
                                    ? c.border
                                    : c.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font12_5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  if (_typing)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.bgMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: const _TypingDots(),
                      ),
                    ),
                  // quick topics (under the last bot message)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in _chips)
                        ActionChip(
                          label: Text(
                            chip,
                            style: TextStyle(
                              fontSize: Dimens.font11,
                              color: c.textSecondary,
                            ),
                          ),
                          backgroundColor: c.bg,
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          onPressed: () => _send(chip),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // ------------------------------------------------ input
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font13,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Apna sawaal likho…',
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _send(_input.text),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: c.onGreen,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctl,
      builder:
          (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Opacity(
                  opacity: (((_ctl.value * 3) - i).clamp(0.0, 1.0) * 0.7) + 0.3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
    );
  }
}
