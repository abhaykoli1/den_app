import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Readable API error — the backend contract is {detail: "..."}.
class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);

  bool get isAuth => status == 401;
  bool get isSubscription => status == 402;
  bool get isForbidden => status == 403;
  bool get isNetwork => status == -1;

  @override
  String toString() => message;
}

typedef UnauthorizedHandler = void Function();

class Api {
  String? token;
  UnauthorizedHandler? onUnauthorized;
  final http.Client _client;

  /// Keep a single client for the lifetime of the signed-in app. Creating a
  /// fresh client for every request prevents connection reuse and makes even
  /// small API calls pay the connection setup cost.
  Api({http.Client? client}) : _client = client ?? http.Client();

  bool get isLoggedIn => token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final base =
        AppConfig.apiBaseUrl.endsWith('/')
            ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
            : AppConfig.apiBaseUrl;
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _client
          .send(req)
          .timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);
      return _handle(res);
    } on SocketException {
      throw const ApiException(-1, 'No connection — the backend seems offline');
    } on TimeoutException {
      throw const ApiException(-1, 'Request timed out — try again');
    } on http.ClientException {
      throw const ApiException(-1, 'Network error — is the backend running?');
    }
  }

  dynamic _handle(http.Response res) {
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(
        401,
        _detail(data, 'Your session expired — please sign in again'),
      );
    }
    throw ApiException(
      res.statusCode,
      _detail(data, 'Server error (${res.statusCode}) — please try again'),
    );
  }

  String _detail(dynamic data, String fallback) {
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return fallback;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body ?? {});
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send('PATCH', path, body: body ?? {});
  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body: body ?? {});
  Future<dynamic> delete(String path) => _send('DELETE', path);

  void close() => _client.close();
}
