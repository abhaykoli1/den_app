import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Offline queue for counter sales — when the network drops, an item-bill
/// payload is stored locally and can be replayed later ("Sync now").
class OfflineQueue extends ChangeNotifier {
  static const _key = 'rd_offline_bills';
  final List<Map<String, dynamic>> _pending = [];

  OfflineQueue() {
    _load();
  }

  List<Map<String, dynamic>> get pending => List.unmodifiable(_pending);
  int get length => _pending.length;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _pending
          ..clear()
          ..addAll(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
          );
        notifyListeners();
      }
    } catch (_) {
      /* corrupted queue starts empty */
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_pending));
  }

  Future<void> enqueue(String clubId, Map<String, dynamic> billPayload) async {
    _pending.add({
      'clubId': clubId,
      'payload': billPayload,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await _save();
    notifyListeners();
  }

  /// Replays everything still pending. Returns (sent, failedLabels).
  Future<(int, List<String>)> sync(Api api) async {
    var sent = 0;
    final failed = <String>[];
    final rest = <Map<String, dynamic>>[];
    for (final entry in _pending) {
      try {
        await api.post(
          '/clubs/${entry['clubId']}/item-bills',
          Map<String, dynamic>.from(entry['payload']),
        );
        sent++;
      } on ApiException catch (e) {
        if (e.isNetwork) {
          rest.add(entry); // still offline — keep it queued
        } else {
          failed.add(
            e.message,
          ); // server rejected — drop with a readable reason
        }
      }
    }
    _pending
      ..clear()
      ..addAll(rest);
    await _save();
    notifyListeners();
    return (sent, failed);
  }

  Future<void> clear() async {
    _pending.clear();
    await _save();
    notifyListeners();
  }
}
