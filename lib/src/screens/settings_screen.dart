import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../config.dart';
import '../dimensions.dart';
import '../exporter.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'info_screens.dart';

/// Settings — profile, club settings, table pricing, membership plans,
/// data export & backup, help links (§16).
class SettingsScreen extends StatefulWidget {
  final SessionController session;
  final ClubController club;
  const SettingsScreen({super.key, required this.session, required this.club});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _bonus = TextEditingController();
  final _dueLimit = TextEditingController();
  final _advance = TextEditingController();
  final _monthlyDisc = TextEditingController();
  final _clubName = TextEditingController();
  final _clubLogo = TextEditingController();
  final _clubQrCode = TextEditingController();
  bool _pickingLogo = false;
  bool _pickingQrCode = false;

  // ★ v3.26 — gallery se logo chuno (chhota karke): base64 data-URL banti
  // hai, backend ka `logo` string wahi store hota hai — koi API change nahi.
  // ignore: unused_element
  Future<void> _pickLogo() async {
    if (_pickingLogo) return;
    setState(() => _pickingLogo = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 72,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > 1200 * 1024) {
        if (mounted) {
          toast(
            context,
            'Image is too large — keep it within 1–2 MB',
            error: true,
          );
        }
        return;
      }
      final mime = x.mimeType ?? 'image/png';
      setState(
        () => _clubLogo.text = 'data:$mime;base64,${base64Encode(bytes)}',
      );
      if (mounted) toast(context, 'Logo ready — remember to save');
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Could not select the photo — allow photo permission',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _pickQrCode() async {
    if (_pickingQrCode) return;
    setState(() => _pickingQrCode = true);
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 100,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > 1200 * 1024) {
        if (mounted) {
          toast(
            context,
            'QR image is too large — keep it within 1–2 MB',
            error: true,
          );
        }
        return;
      }
      final mime = x.mimeType ?? 'image/png';
      setState(
        () => _clubQrCode.text = 'data:$mime;base64,${base64Encode(bytes)}',
      );
      if (mounted) toast(context, 'QR ready — remember to save');
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Could not select the QR image — allow photo permission',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingQrCode = false);
    }
  }

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  bool _savingClub = false;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sync);
    widget.club.addListener(_onData);
    _sync();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  void _sync() {
    final club = widget.session.activeClub;
    if (club != null) {
      _bonus.text = fmtNum(club.winnerBonus);
      _dueLimit.text = fmtNum(club.dueLimit);
      _advance.text = fmtNum(club.defaultAdvance);
      _monthlyDisc.text = fmtNum(club.monthlyTableDiscount);
      _clubName.text = club.name;
      _clubLogo.text = club.logo;
      _clubQrCode.text = club.qrCode ?? '';
    }
    final u = widget.session.user;
    if (u != null) {
      _name.text = u.name;
      _phone.text = u.phone;
      _location.text = u.location;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_sync);
    widget.club.removeListener(_onData);
    for (final t in [
      _bonus,
      _dueLimit,
      _advance,
      _monthlyDisc,
      _clubName,
      _clubLogo,
      _clubQrCode,
      _name,
      _phone,
      _location,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _saveClub() async {
    final club = widget.session.activeClub;
    final newName = _clubName.text.trim();
    // ★ Fix: QR/logo ko save se PEHLE capture karo. `saveClubSettings()` →
    // notifyListeners() → _sync() server wale club se in controllers ko
    // reset kar deta hai. Baad mein padhne se freshly-picked QR/logo gayab
    // ho jata hai ("save ke baad image gyab" bug).
    final newLogo = _clubLogo.text.trim();
    final newQrCode = _clubQrCode.text.trim();
    if (club != null && newName.length < 2) {
      toast(context, 'Club name must contain at least 2 letters', error: true);
      return;
    }
    setState(() => _savingClub = true);
    final ok = await widget.session.saveClubSettings({
      'winnerBonus': double.tryParse(_bonus.text.trim()) ?? 0,
      'dueLimit': double.tryParse(_dueLimit.text.trim()) ?? 0,
      'defaultAdvance': double.tryParse(_advance.text.trim()) ?? 0,
      'monthlyTableDiscount': double.tryParse(_monthlyDisc.text.trim()) ?? 0,
    });
    // Club identity (name / logo / QR) — PATCH /clubs/{id}, only when changed
    if (ok && club != null) {
      final patch = <String, dynamic>{};
      if (newName != club.name) patch['name'] = newName;
      if (newLogo != club.logo) patch['logo'] = newLogo;
      if (newQrCode != (club.qrCode ?? '')) patch['qrCode'] = newQrCode;
      if (patch.isNotEmpty) {
        try {
          await widget.session.api.patch('/clubs/${club.id}', patch);
          await widget.session.loadClubs();
        } on ApiException catch (e) {
          setState(() => _savingClub = false);
          if (mounted) toast(context, e.message, error: true);
          return;
        }
      }
    }
    setState(() => _savingClub = false);
    if (mounted) {
      toast(
        context,
        ok
            ? 'Club settings saved'
            : (widget.session.lastError ?? 'Save failed'),
        error: !ok,
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    final ok = await widget.session.updateProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      location: _location.text.trim(),
    );
    setState(() => _savingProfile = false);
    if (mounted) {
      toast(
        context,
        ok ? 'Profile updated' : (widget.session.lastError ?? 'Save failed'),
        error: !ok,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = widget.session.user;
    final isStaff = u?.isStaff ?? false;
    final hasClub = widget.session.activeClub != null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'My Profile',
          trailing: ToneBadge(
            u?.role == 'master' ? 'Master Admin' : (u?.role ?? 'owner'),
            u?.role == 'master' ? c.gold : c.blue,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your login account (${u?.email ?? ''}). Phone & city show to Master Admin and help support reach you.',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: Dimens.font10,
                  height: 1.3,
                ),
              ),
              const FieldLabel('Display name'),
              TextField(
                controller: _name,
                style: AppText.field.copyWith(color: c.text),
              ),
              const FieldLabel('Phone number'),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(hintText: '98XXXXXXXX'),
              ),
              const FieldLabel('City / location'),
              TextField(
                controller: _location,
                style: AppText.field.copyWith(color: c.text),
                decoration: const InputDecoration(
                  hintText: 'Jaipur, Rajasthan',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.green,
                    foregroundColor: c.onGreen,
                  ),
                  onPressed: _savingProfile ? null : _saveProfile,
                  child: Text(_savingProfile ? 'Saving…' : 'Save Profile'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Text Size',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust text size across the entire app.',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.text_decrease, size: 18, color: c.textMuted),
                  Expanded(
                    child: Slider(
                      value: widget.session.textScale,
                      min: 0.85,
                      max: 1.25,
                      divisions: 8,
                      label: '${(widget.session.textScale * 100).round()}%',
                      onChanged: widget.session.setTextScale,
                    ),
                  ),
                  Icon(Icons.text_increase, size: 18, color: c.textMuted),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      widget.session.textScale == 1.0
                          ? null
                          : () => widget.session.setTextScale(1.0),
                  child: const Text('Reset to default'),
                ),
              ),
            ],
          ),
        ),
        if (!isStaff && hasClub) ...[
          const SizedBox(height: 10),
          SectionCard(
            title: 'Club Settings',
            trailing:
                widget.session.activeClub!.logo.isNotEmpty
                    ? ClubLogo(
                      logo: widget.session.activeClub!.logo,
                      size: 26,
                      borderRadius: 6,
                    )
                    : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row2('Currency', 'INR · ₹ (fixed)'),
                Divider(color: c.border, height: 14),
                const FieldLabel('Club name'),
                TextField(
                  controller: _clubName,
                  textCapitalization: TextCapitalization.words,
                  style: AppText.field.copyWith(color: c.text),
                  decoration: const InputDecoration(hintText: "Rowdy's Den"),
                ),
                const FieldLabel('Payment QR code (optional)'),
                Row(
                  children: [
                    ClubLogo(
                      logo: _clubQrCode.text,
                      size: 54,
                      borderRadius: 4,
                      fallbackIcon: Icons.qr_code_2_outlined,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickingQrCode ? null : _pickQrCode,
                        icon: Icon(
                          _pickingQrCode
                              ? Icons.hourglass_top
                              : Icons.upload_outlined,
                          size: 15,
                        ),
                        label: Text(
                          _clubQrCode.text.isEmpty ? 'Upload QR' : 'Change QR',
                        ),
                      ),
                    ),
                    if (_clubQrCode.text.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Remove QR code',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _clubQrCode.text = ''),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 17,
                          color: c.red,
                        ),
                      ),
                    ],
                  ],
                ),
                // Club logo upload is temporarily hidden. Keep this block so
                // it can be enabled again without rebuilding the upload flow.
                /*
                const FieldLabel('Club logo (optional)'),
                Row(
                  children: [
                    ClubLogo(logo: _clubLogo.text),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickingLogo ? null : _pickLogo,
                        icon: Icon(
                          _pickingLogo
                              ? Icons.hourglass_top
                              : Icons.upload_outlined,
                          size: 15,
                        ),
                        label: Text(
                          _clubLogo.text.isEmpty
                              ? 'Upload photo'
                              : 'Change photo',
                        ),
                      ),
                    ),
                    if (_clubLogo.text.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Remove logo',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _clubLogo.text = ''),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 17,
                          color: c.red,
                        ),
                      ),
                    ],
                  ],
                ),
                */
                Divider(color: c.border, height: 14),
                const FieldLabel('Winner bonus (₹)'),
                TextField(
                  controller: _bonus,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: AppText.field.copyWith(color: c.text),
                ),
                const FieldLabel('Due limit (₹)'),
                TextField(
                  controller: _dueLimit,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: AppText.field.copyWith(color: c.text),
                ),
                const FieldLabel('Default advance (₹)'),
                TextField(
                  controller: _advance,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: AppText.field.copyWith(color: c.text),
                ),
                const FieldLabel('Monthly fallback discount (%)'),
                TextField(
                  controller: _monthlyDisc,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: AppText.field.copyWith(color: c.text),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.green,
                      foregroundColor: c.onGreen,
                    ),
                    onPressed: _savingClub ? null : _saveClub,
                    child: Text(_savingClub ? 'Saving…' : 'Save Settings'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _tablesCard(c),
          const SizedBox(height: 10),
          _plansCard(c),
          const SizedBox(height: 10),
          _exportCard(c),
        ],
        const SizedBox(height: 10),
        SectionCard(
          title: 'Help & Legal',
          child: Column(
            children: [
              _linkPlain(
                c,
                Icons.headset_mic_outlined,
                'Human Support',
                SupportScreen(session: widget.session),
              ),
              _linkPlain(
                c,
                Icons.privacy_tip_outlined,
                'Privacy & Policy',
                const PrivacyScreen(),
              ),
              _linkPlain(
                c,
                Icons.description_outlined,
                'Terms & Conditions',
                const TermsScreen(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'About',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('App', '${AppConfig.appName} v${AppConfig.appVersion}'),
              _row('Backend', AppConfig.apiBaseUrl),
              _row('Signed in as', '${u?.name ?? ''} · ${u?.email ?? ''}'),
              _row('Role', u?.role ?? '-'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.red,
              side: BorderSide(color: c.red.withValues(alpha: 0.6)),
            ),
            onPressed: () => widget.session.signOut(),
            icon: const Icon(Icons.logout, size: 15),
            label: const Text('Sign out'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Powered by Rowdy\'s Den · v${AppConfig.appVersion}',
            style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
          ),
        ),
      ],
    );
  }

  Widget _linkPlain(AppColors c, IconData icon, String label, Widget page) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => Scaffold(
                    appBar: AppBar(
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 19),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          color: c.text,
                          fontSize: Dimens.font15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    body: SafeArea(child: page),
                  ),
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 15, color: c.green),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c.text,
                  fontSize: Dimens.font12_5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            k,
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: Dimens.font11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: context.colors.text,
              fontSize: Dimens.font12,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _row2(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            k.toUpperCase(),
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: Dimens.font9_5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: context.colors.text,
              fontSize: Dimens.font12_5,
            ),
          ),
        ),
      ],
    ),
  );

  // ============================================================== games
  Widget _tablesCard(AppColors c) {
    final tables = widget.club.tables;
    return SectionCard(
      title: 'Pricing',
      trailing: TextButton.icon(
        onPressed: () => _tableForm(null),
        icon: Icon(Icons.add, size: 14, color: c.green),
        label: Text(
          'Add Table/Game',
          style: TextStyle(color: c.green, fontSize: Dimens.font12),
        ),
      ),
      child:
          tables.isEmpty
              ? Text(
                'No games yet — add Pool, PS, PS4, PS5 or any game with rates.',
                style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
              )
              : Column(
                children: [
                  for (final t in tables)
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
                                        t.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              t.active ? c.text : c.textMuted,
                                          fontSize: Dimens.font13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (!t.active) ...[
                                      const SizedBox(width: 4),
                                      ToneBadge('off', c.red),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${fmtMoney(t.hourlyRate)}/hr · min ${fmtMoney(t.minCharge)}'
                                  '${_peakNote(t)}'
                                  '${t.glovePrice > 0 ? ' · gloves ${fmtMoney(t.glovePrice)}' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textMuted,
                                    fontSize: Dimens.font10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: t.active ? 'Deactivate' : 'Activate',
                            onPressed: () async {
                              try {
                                await widget.session.api.post(
                                  '/clubs/${widget.club.clubId}/tables/${t.id}/toggle-active',
                                );
                                await widget.club.refresh();
                              } on ApiException catch (e) {
                                if (mounted) {
                                  toast(context, e.message, error: true);
                                }
                              }
                            },
                            icon: Icon(
                              Icons.power_settings_new,
                              size: 15,
                              color: t.active ? c.green : c.textMuted,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _tableForm(t),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: c.textSecondary,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deleteTable(t),
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

  String _peakNote(ClubTable t) {
    final rate = t.rate['peakHourlyRate'];
    if (rate == null || (rate as num) == 0) return '';
    final from = t.rate['peakStartHour'] ?? 0;
    final to = t.rate['peakEndHour'] ?? 0;
    return ' · peak ${fmtMoney(rate)} (${_h(from as int)}–${_h(to as int)})';
  }

  String _h(int h) {
    final ampm = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12$ampm';
  }

  Future<void> _deleteTable(ClubTable t) async {
    final sure = await confirmSheet(
      context,
      title: 'Delete ${t.name}?',
      message:
          'History stays in frames; the table just disappears from billing.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await widget.session.api.delete(
        '/clubs/${widget.club.clubId}/tables/${t.id}',
      );
      await widget.club.refresh();
      if (mounted) toast(context, 'Table deleted');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _tableForm(ClubTable? existing) async {
    final c = context.colors;
    final name = TextEditingController(text: existing?.name ?? '');
    final rate = TextEditingController(
      text: existing == null ? '' : fmtNum(existing.hourlyRate),
    );
    final minCharge = TextEditingController(
      text: existing == null ? '20' : fmtNum(existing.minCharge),
    );
    final rate2p = TextEditingController(
      text: '${existing?.rate['ratesByPlayers']?['2'] ?? ''}',
    );
    final rate3p = TextEditingController(
      text: '${existing?.rate['ratesByPlayers']?['3'] ?? ''}',
    );
    final rate4p = TextEditingController(
      text: '${existing?.rate['ratesByPlayers']?['4'] ?? ''}',
    );
    final peakRate = TextEditingController(
      text: '${existing?.rate['peakHourlyRate'] ?? ''}',
    );
    final glove = TextEditingController(
      text: existing == null ? '' : fmtNum(existing.glovePrice),
    );
    int peakFrom = (existing?.rate['peakStartHour'] ?? 18) as int;
    int peakTo = (existing?.rate['peakEndHour'] ?? 23) as int;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existing == null ? 'Add' : 'Edit ${existing.name}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const FieldLabel('Game name *'),
                        TextField(
                          controller: name,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: const InputDecoration(
                            hintText: 'Snooker , Pool, PS4, PS5, etc.',
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel('₹ / hour *'),
                                  TextField(
                                    controller: rate,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
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
                                  const FieldLabel('Min charge ₹'),
                                  TextField(
                                    controller: minCharge,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
                                    ),
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
                                  const FieldLabel('2P rate (opt)'),
                                  TextField(
                                    controller: rate2p,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'base',
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
                                  const FieldLabel('3P rate (opt)'),
                                  TextField(
                                    controller: rate3p,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'base',
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
                                  const FieldLabel('4P rate (opt)'),
                                  TextField(
                                    controller: rate4p,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'base',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(color: c.border, height: 18),
                        Text(
                          'PEAK PRICING (OPTIONAL)',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: Dimens.font9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel('Peak ₹/hr'),
                                  TextField(
                                    controller: peakRate,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: AppText.field.copyWith(
                                      color: c.text,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'blank = no peak',
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
                                  const FieldLabel('From hour'),
                                  DropdownButtonFormField<int>(
                                    style: AppText.dropdown.copyWith(
                                      color: c.text,
                                    ),
                                    initialValue: peakFrom,
                                    items: [
                                      for (var h = 0; h < 24; h++)
                                        DropdownMenuItem(
                                          value: h,
                                          child: Text(_h(h)),
                                        ),
                                    ],
                                    onChanged:
                                        (v) => set(() => peakFrom = v ?? 18),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel('To hour'),
                                  DropdownButtonFormField<int>(
                                    style: AppText.dropdown.copyWith(
                                      color: c.text,
                                    ),
                                    initialValue: peakTo,
                                    items: [
                                      for (var h = 0; h < 24; h++)
                                        DropdownMenuItem(
                                          value: h,
                                          child: Text(_h(h)),
                                        ),
                                    ],
                                    onChanged:
                                        (v) => set(() => peakTo = v ?? 23),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const FieldLabel(
                          'Glove rent ₹/pair (0 = gloves disabled)',
                        ),
                        TextField(
                          controller: glove,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.green,
                              foregroundColor: c.onGreen,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Save table'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    if (ok != true) return;
    final hourly = double.tryParse(rate.text.trim()) ?? 0;
    if (name.text.trim().isEmpty || hourly <= 0) {
      if (mounted) toast(context, 'Name + hourly rate required', error: true);
      return;
    }
    final ratesByPlayers = <String, double>{};
    final r2 = double.tryParse(rate2p.text.trim());
    final r3 = double.tryParse(rate3p.text.trim());
    final r4 = double.tryParse(rate4p.text.trim());
    if (r2 != null && r2 > 0) ratesByPlayers['2'] = r2;
    if (r3 != null && r3 > 0) ratesByPlayers['3'] = r3;
    if (r4 != null && r4 > 0) ratesByPlayers['4'] = r4;
    final peak = double.tryParse(peakRate.text.trim());
    final rateBody = <String, dynamic>{
      'hourlyRate': hourly,
      if (ratesByPlayers.isNotEmpty) 'ratesByPlayers': ratesByPlayers,
      'minCharge': double.tryParse(minCharge.text.trim()) ?? 0,
      if (peak != null && peak > 0) ...{
        'peakHourlyRate': peak,
        'peakStartHour': peakFrom,
        'peakEndHour': peakTo,
      } else ...{
        'peakHourlyRate': null,
        'peakStartHour': null,
        'peakEndHour': null,
      },
      'glovePrice': double.tryParse(glove.text.trim()) ?? 0,
    };
    try {
      final api = widget.session.api;
      final base = '/clubs/${widget.club.clubId}/tables';
      if (existing == null) {
        await api.post(base, {'name': name.text.trim(), 'rate': rateBody});
      } else {
        await api.patch('$base/${existing.id}', {
          'name': name.text.trim(),
          'rate': rateBody,
        });
      }
      await widget.club.refresh();
      if (mounted) {
        toast(context, existing == null ? 'Table added' : 'Table updated');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ============================================================== plans
  Widget _plansCard(AppColors c) {
    final plans = widget.club.plans;
    return SectionCard(
      title: 'Membership Plans',
      trailing: TextButton.icon(
        onPressed: () => _planForm(null),
        icon: Icon(Icons.add, size: 14, color: c.green),
        label: Text(
          'Add Plan',
          style: TextStyle(color: c.green, fontSize: Dimens.font12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet = prepaid credit · Pass = frame pack · Monthly = premium table % discount',
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font10,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          if (plans.isEmpty)
            Text(
              'No plans yet — create wallet, pass or monthly plans to sell to members.',
              style: TextStyle(color: c.textMuted, fontSize: Dimens.font11),
            )
          else
            for (final p in plans) _planRow(c, p),
        ],
      ),
    );
  }

  Widget _planRow(AppColors c, ClubPlan p) {
    final tone =
        p.type == 'wallet'
            ? c.gold
            : p.type == 'pass'
            ? c.blue
            : c.green;
    String detail;
    if (p.type == 'wallet') {
      detail = 'pay ${fmtMoney(p.amount)} → wallet ${fmtMoney(p.value)}';
    } else if (p.type == 'pass') {
      detail =
          '${fmtMoney(p.amount)} → ${p.frames} frames${p.days > 0 ? ' · ${p.days}d valid' : ''}';
    } else {
      detail =
          '${fmtMoney(p.amount)} → ${fmtNum(p.tableDiscountPercent)}% off table${p.days > 0 ? ' · ${p.days}d' : ''}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ToneBadge(p.type, tone),
                    if (p.isDefault) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.star, size: 12, color: c.gold),
                    ],
                    if (!p.active) ...[
                      const SizedBox(width: 4),
                      ToneBadge('off', c.red),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  p.name,
                  style: TextStyle(
                    color: p.active ? c.text : c.textMuted,
                    fontSize: Dimens.font12_5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: p.active ? 'Deactivate' : 'Activate',
            onPressed: () async {
              try {
                await widget.session.api.post(
                  '/clubs/${widget.club.clubId}/plans/${p.id}/toggle-active',
                );
                await widget.club.refresh();
              } on ApiException catch (e) {
                if (mounted) toast(context, e.message, error: true);
              }
            },
            icon: Icon(
              Icons.power_settings_new,
              size: 15,
              color: p.active ? c.green : c.textMuted,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _planForm(p),
            icon: Icon(Icons.edit_outlined, size: 14, color: c.textSecondary),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _deletePlan(p),
            icon: Icon(Icons.delete_outline, size: 14, color: c.red),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlan(ClubPlan p) async {
    final sure = await confirmSheet(
      context,
      title: 'Delete ${p.name}?',
      message: 'Members who already bought it keep their balance/frames.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure) return;
    try {
      await widget.session.api.delete(
        '/clubs/${widget.club.clubId}/plans/${p.id}',
      );
      await widget.club.refresh();
      if (mounted) toast(context, 'Plan deleted');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _planForm(ClubPlan? existing) async {
    final c = context.colors;
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(
      text: existing == null ? '' : fmtNum(existing.amount),
    );
    final value = TextEditingController(
      text: existing == null ? '' : fmtNum(existing.value),
    );
    final frames = TextEditingController(
      text:
          existing == null || existing.frames == 0 ? '' : '${existing.frames}',
    );
    final days = TextEditingController(
      text: existing == null || existing.days == 0 ? '' : '${existing.days}',
    );
    final discount = TextEditingController(
      text:
          existing?.tableDiscountPercent == null
              ? ''
              : fmtNum(existing!.tableDiscountPercent),
    );
    String type = existing?.type ?? 'wallet';
    bool isDefault = existing?.isDefault ?? false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existing == null
                              ? 'Add Membership Plan'
                              : 'Edit ${existing.name}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: Dimens.font15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const FieldLabel('Plan type'),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: 'wallet',
                                label: Text('Wallet'),
                              ),
                              ButtonSegment(value: 'pass', label: Text('Pass')),
                              ButtonSegment(
                                value: 'monthly',
                                label: Text('Monthly'),
                              ),
                            ],
                            selected: {type},
                            onSelectionChanged:
                                (v) => set(() => type = v.first),
                          ),
                        ),
                        const FieldLabel('Plan name *'),
                        TextField(
                          controller: name,
                          style: AppText.field.copyWith(color: c.text),
                          decoration: InputDecoration(
                            hintText:
                                type == 'wallet'
                                    ? 'Gold Wallet'
                                    : type == 'pass'
                                    ? '10-Frame Pack'
                                    : 'Monthly Pro',
                          ),
                        ),
                        const FieldLabel('Price (₹ member pays) *'),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.field.copyWith(color: c.text),
                        ),
                        if (type == 'wallet') ...[
                          const FieldLabel('Wallet credit ₹ (usually ≥ price)'),
                          TextField(
                            controller: value,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppText.field.copyWith(color: c.text),
                            decoration: const InputDecoration(
                              hintText: 'blank = same as price',
                            ),
                          ),
                        ],
                        if (type == 'pass')
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FieldLabel('Frames in pack *'),
                                    TextField(
                                      controller: frames,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: AppText.field.copyWith(
                                        color: c.text,
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
                                    const FieldLabel(
                                      'Valid days (0 = no expiry)',
                                    ),
                                    TextField(
                                      controller: days,
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: AppText.field.copyWith(
                                        color: c.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (type == 'monthly') ...[
                          const FieldLabel('Table discount %'),
                          TextField(
                            controller: discount,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppText.field.copyWith(color: c.text),
                          ),
                          const FieldLabel('Valid days (0 = 30)'),
                          TextField(
                            controller: days,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppText.field.copyWith(color: c.text),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => set(() => isDefault = !isDefault),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDefault ? Icons.star : Icons.star_border,
                                size: 16,
                                color: isDefault ? c.gold : c.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Default plan for new members',
                                style: TextStyle(
                                  color: isDefault ? c.gold : c.textSecondary,
                                  fontSize: Dimens.font11,
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
                              backgroundColor: c.green,
                              foregroundColor: c.onGreen,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Save plan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amount.text.trim()) ?? 0;
    if (name.text.trim().isEmpty || amt <= 0) {
      if (mounted) toast(context, 'Name + price required', error: true);
      return;
    }
    if (type == 'pass' && (int.tryParse(frames.text.trim()) ?? 0) <= 0) {
      if (mounted) toast(context, 'Pass needs frames in pack', error: true);
      return;
    }
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'type': type,
      'amount': amt,
      'isDefault': isDefault,
      if (type == 'wallet') 'value': double.tryParse(value.text.trim()) ?? amt,
      if (type == 'pass') 'frames': int.tryParse(frames.text.trim()) ?? 0,
      if (type != 'wallet') 'days': int.tryParse(days.text.trim()) ?? 0,
      if (type == 'monthly')
        'tableDiscountPercent': double.tryParse(discount.text.trim()) ?? 0,
    };
    try {
      final api = widget.session.api;
      final base = '/clubs/${widget.club.clubId}/plans';
      if (existing == null) {
        await api.post(base, body);
      } else {
        body.remove('type'); // type locked after create
        await api.patch('$base/${existing.id}', body);
      }
      await widget.club.refresh();
      if (mounted) {
        toast(context, existing == null ? 'Plan added' : 'Plan updated');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  // ============================================================== export (§30: Excel + PDF, no CSV)
  bool get _isStaff => widget.session.user?.isStaff ?? false;

  Future<void> _safeExport(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (mounted) toast(context, 'Export failed: $e', error: true);
    }
  }

  Widget _exportCard(AppColors c) {
    final ym = thisMonth();
    return SectionCard(
      title: 'Data Export & Backup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real multi-sheet .xlsx files build on-device from your club snapshot — the share sheet lets you save to Files/Drive or forward to the accountant on WhatsApp. Nothing extra is stored in MongoDB. Frames / Item Bills / Expenses sheets cover the latest 200 records each.',
            style: TextStyle(
              color: c.textMuted,
              fontSize: Dimens.font10,
              height: 1.35,
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
              onPressed: _allInOneExcel,
              icon: const Icon(Icons.table_view_outlined, size: 15),
              label: const Text('All-in-one Excel (.xlsx)'),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _exportBtn(
                c,
                'Members.xlsx',
                () => shareXlsx('rowdys-den-members-$ym.xlsx', {
                  'Members': _membersSheet(),
                }),
              ),
              _exportBtn(
                c,
                'Frames.xlsx',
                () => shareXlsx('rowdys-den-frames-$ym.xlsx', {
                  'Frames': _framesSheet(),
                }),
              ),
              _exportBtn(
                c,
                'Item Bills.xlsx',
                () => shareXlsx('rowdys-den-item-bills-$ym.xlsx', {
                  'Item Bills': _itemBillsSheet(),
                }),
              ),
              if (!_isStaff) // expenses button staff se hidden (spec)
                _exportBtn(
                  c,
                  'Expenses.xlsx',
                  () => shareXlsx('rowdys-den-expenses-$ym.xlsx', {
                    'Expenses': _expensesSheet(),
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
              ),
              onPressed: () => _safeExport(_backupJson),
              icon: const Icon(Icons.download_outlined, size: 15),
              label: const Text('Full Backup (JSON file)'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The full backup packs Members + Frames + Item Bills + Expenses + Logs + Tournaments into one JSON — keep a copy every month.',
            style: TextStyle(color: c.textMuted, fontSize: Dimens.font10),
          ),
        ],
      ),
    );
  }

  Widget _exportBtn(AppColors c, String label, Future<void> Function() onTap) {
    return OutlinedButton.icon(
      onPressed: () => _safeExport(onTap),
      icon: Icon(Icons.download_outlined, size: 13, color: c.green),
      label: Text(
        label,
        style: TextStyle(color: c.textSecondary, fontSize: Dimens.font11),
      ),
    );
  }

  Future<void> _allInOneExcel() {
    final sheets = <String, List<List<dynamic>>>{
      'Members': _membersSheet(),
      'Frames': _framesSheet(),
      'Item Bills': _itemBillsSheet(),
      if (!_isStaff) 'Expenses': _expensesSheet(),
      'Logs': _logsSheet(),
      'Tournaments': _tournamentsSheet(),
    };
    return _safeExport(
      () => shareXlsx('rowdys-den-all-in-one-${thisMonth()}.xlsx', sheets),
    );
  }

  List<List<dynamic>> _membersSheet() => [
    [
      'name',
      'phone',
      'email',
      'wallet',
      'due',
      'passFrames',
      'plan',
      'planType',
      'planExpires',
      'active',
    ],
    for (final m in widget.club.members)
      [
        m.name,
        m.phone,
        m.email,
        m.walletBalance,
        m.dueAmount,
        m.passFramesLeft,
        m.planName ?? '',
        m.planType ?? '',
        m.planExpiresAt,
        m.active,
      ],
  ];

  List<List<dynamic>> _framesSheet() => [
    [
      'date',
      'table',
      'players',
      'winners',
      'frameAmount',
      'collected',
      'gloveCharges',
      'mode',
      'minutes',
    ],
    for (final f in widget.club.frames)
      [
        f['createdAt'] ?? '',
        f['tableName'] ?? '',
        (((f['players'] as List?) ?? const []).map(
          (p) => p['label'],
        )).join(' | '),
        (((f['winners'] as List?) ?? const [])).join(' | '),
        ((f['frameAmount'] ?? 0) as num).toDouble(),
        ((f['cashCollected'] ?? 0) as num).toDouble(),
        ((f['gloveCharges'] ?? 0) as num).toDouble(),
        f['matchMode'] ?? '',
        f['durationMinutes'] ?? f['minutes'] ?? 0,
      ],
  ];

  List<List<dynamic>> _itemBillsSheet() => [
    [
      'date',
      'customer',
      'items',
      'amount',
      'discount',
      'paid',
      'mode',
      'status',
    ],
    for (final b in widget.club.itemBills)
      [
        b['createdAt'] ?? '',
        b['customerName'] ?? '',
        (((b['items'] as List?) ?? const []).map(
          (i) => '${i['name']}x${i['qty']}',
        )).join(' | '),
        ((b['amount'] ?? 0) as num).toDouble(),
        ((b['discount'] ?? 0) as num).toDouble(),
        b['paid'] == true,
        b['mode'] ?? '',
        b['status'] ?? '',
      ],
  ];

  List<List<dynamic>> _expensesSheet() => [
    ['date', 'title', 'category', 'amount', 'note', 'auto'],
    for (final e in widget.club.expenses)
      [
        e['date'] ?? '',
        e['title'] ?? '',
        e['category'] ?? '',
        ((e['amount'] ?? 0) as num).toDouble(),
        e['note'] ?? '',
        e['auto'] == true,
      ],
  ];

  List<List<dynamic>> _logsSheet() => [
    ['date', 'tag', 'message', 'actor', 'mode', 'amount'],
    for (final l in widget.club.logs)
      [
        l['createdAt'] ?? '',
        l['tag'] ?? '',
        l['message'] ?? '',
        l['actor'] ?? '',
        l['mode'] ?? '',
        ((l['amount'] ?? 0) as num).toDouble(),
      ],
  ];

  List<List<dynamic>> _tournamentsSheet() => [
    [
      'name',
      'date',
      'game',
      'format',
      'status',
      'players',
      'entryFee',
      'collected',
    ],
    for (final t in widget.club.tournaments)
      [
        t['name'] ?? '',
        t['date'] ?? '',
        t['game'] ?? '',
        t['format'] ?? '',
        t['status'] ?? '',
        t['playerCount'] ?? (((t['players'] as List?) ?? const []).length),
        ((t['entryFee'] ?? 0) as num).toDouble(),
        ((t['collected'] ?? 0) as num).toDouble(),
      ],
  ];

  Future<void> _backupJson() async {
    final club = widget.session.activeClub;
    final payload = {
      'club':
          club == null
              ? null
              : {'id': club.id, 'name': club.name, 'settings': club.settings},
      'exportedAt': DateTime.now().toIso8601String(),
      'members': [for (final m in widget.club.members) _memberJson(m)],
      'frames': widget.club.frames,
      'itemBills': widget.club.itemBills,
      'expenses': widget.club.expenses,
      'logs': widget.club.logs,
      'tournaments': widget.club.tournaments,
    };
    await shareJson('rowdys-den-backup-${thisMonth()}.json', payload);
  }

  Map<String, dynamic> _memberJson(Member m) => {
    'id': m.id,
    'name': m.name,
    'phone': m.phone,
    'email': m.email,
    'active': m.active,
    'walletBalance': m.walletBalance,
    'dueAmount': m.dueAmount,
    'passFramesLeft': m.passFramesLeft,
    'planName': m.planName,
    'planType': m.planType,
    'planExpiresAt': m.planExpiresAt,
    'badge': m.badge,
  };
}
