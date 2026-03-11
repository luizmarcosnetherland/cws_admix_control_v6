import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'dropbox_config.dart';

class DropboxAuth {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kAccessToken = 'dbx_access_token';
  static const _kRefreshToken = 'dbx_refresh_token';
  static const _kExpiresAt = 'dbx_expires_at_ms';

  Future<void> signIn() async {
    final authorization = await _appAuth.authorize(
      AuthorizationRequest(
        dropboxClientId,
        dropboxRedirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: dropboxAuthEndpoint,
          tokenEndpoint: dropboxTokenEndpoint,
        ),
        scopes: dropboxScopes,
        // Dropbox: refresh token via offline access
        additionalParameters: const {'token_access_type': 'offline'},
      ),
    );

    final authorizationCode = authorization.authorizationCode;
    final codeVerifier = authorization.codeVerifier;
    if (authorizationCode == null || authorizationCode.isEmpty) {
      throw Exception('Login Dropbox falhou (authorization code vazio).');
    }

    final payload = await _postTokenRequest({
      'grant_type': 'authorization_code',
      'code': authorizationCode,
      'client_id': dropboxClientId,
      if (codeVerifier != null && codeVerifier.isNotEmpty)
        'code_verifier': codeVerifier,
    });
    await _persistTokenPayload(payload);
  }

  Future<Map<String, dynamic>> _postTokenRequest(Map<String, String> body) async {
    final response = await http.post(
      Uri.parse(dropboxTokenEndpoint),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    final raw = response.body;
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error_description'] ?? decoded['error'];
        throw Exception('Falha OAuth Dropbox: ${message ?? raw}');
      }
      throw Exception('Falha OAuth Dropbox: $raw');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Resposta OAuth Dropbox inválida.');
    }

    return decoded;
  }

  Future<void> _persistTokenPayload(Map<String, dynamic> payload) async {
    final accessToken = payload['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Login Dropbox falhou (access token vazio).');
    }

    await _storage.write(key: _kAccessToken, value: accessToken);

    final refreshToken = payload['refresh_token'] as String?;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }

    final expiresIn = payload['expires_in'];
    final expiresInSeconds = expiresIn is int
        ? expiresIn
        : int.tryParse(expiresIn?.toString() ?? '');
    if (expiresInSeconds != null && expiresInSeconds > 0) {
      final expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
      await _storage.write(
        key: _kExpiresAt,
        value: expiresAt.millisecondsSinceEpoch.toString(),
      );
      return;
    }

    final fallback = DateTime.now().add(const Duration(hours: 2));
    await _storage.write(
      key: _kExpiresAt,
      value: fallback.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> _clearStoredSession() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kExpiresAt);
  }

  Future<void> _tryRefreshAccessToken() async {
    try {
      await refreshAccessToken();
    } catch (_) {
      await _clearStoredSession();
    }
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    final accessToken = await _storage.read(key: _kAccessToken);
    if (accessToken == null || accessToken.isEmpty) return null;

    if (forceRefresh) {
      await refreshAccessToken();
      return _storage.read(key: _kAccessToken);
    }

    final expiresAtMsStr = await _storage.read(key: _kExpiresAt);
    final expiresAtMs = int.tryParse(expiresAtMsStr ?? '');
    if (expiresAtMs == null) {
      // sem expiração registrada: tenta usar; se der 401, chamamos refresh externamente
      return accessToken;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    final now = DateTime.now();

    // renova se estiver expirado ou faltando < 60s
    if (now.isAfter(expiresAt.subtract(const Duration(seconds: 60)))) {
      await _tryRefreshAccessToken();
      return _storage.read(key: _kAccessToken);
    }

    return accessToken;
  }

  Future<void> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('Sem refresh token. Faça logout/login novamente.');
    }

    final payload = await _postTokenRequest({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': dropboxClientId,
    });
    await _persistTokenPayload(payload);
  }

  Future<void> signOut() async {
    await _clearStoredSession();
  }
}
