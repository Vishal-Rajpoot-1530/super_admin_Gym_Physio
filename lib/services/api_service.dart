import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:http/http.dart' as http;

enum Module { clinic, gym }

String _moduleLabel(Module module) =>
    module == Module.gym ? 'Gym Management' : 'Physio Clinic';

enum Plan {
  monthly('1 Month', 150, 'monthly'),
  quarterly('Quarter (3 Months)', 300, 'quarterly'),
  annual('Annual', 1000, 'yearly');

  final String label;
  final int price;
  final String apiValue;
  const Plan(this.label, this.price, this.apiValue);
}

class ApiConfig {
  final String baseUrl;
  const ApiConfig(this.baseUrl);

  static final defaultClinic = ApiConfig(
    const String.fromEnvironment('PHYSIO_API_BASE_URL').isNotEmpty
        ? const String.fromEnvironment('PHYSIO_API_BASE_URL')
        : kIsWeb
        ? 'http://localhost:3002/api/v1'
        : 'http://10.0.2.2:3002/api/v1',
  );
  static final defaultGym = ApiConfig(
    const String.fromEnvironment('GYM_API_BASE_URL').isNotEmpty
        ? const String.fromEnvironment('GYM_API_BASE_URL')
        : kIsWeb
        ? 'http://localhost:3001/api/v1'
        : 'http://10.0.2.2:3001/api/v1',
  );

  static final Map<Module, ApiConfig> _saved = {};
  static const _storage = FlutterSecureStorage();
  static final Map<Module, String> _panelTokens = {};
  static String? storageWarning;
  static ApiConfig get clinic => _saved[Module.clinic] ?? defaultClinic;
  static ApiConfig get gym => _saved[Module.gym] ?? defaultGym;

  static String normalizeBaseUrl(Module module, String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ApiException('Enter a valid API base URL, including /api/v1.');
    }

    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    path = path.replaceFirst(RegExp(r'/physio$', caseSensitive: false), '');
    if (path.isEmpty) {
      path = '/api/v1';
    } else if (!path.endsWith('/api/v1')) {
      path = '$path/api/v1';
    }

    final servicePort = module == Module.gym ? 3001 : 3002;
    final port =
        uri.scheme == 'http' ||
            const {3000, 3001, 3002, 3004}.contains(uri.port)
        ? servicePort
        : uri.port;
    return uri.replace(port: port, path: path).toString();
  }

  static String sessionStorageKey(Module module) =>
      'panel_access_token_${module.name}';

  static String? panelTokenFor(Module module) => _panelTokens[module];

  static String migrateSavedConfig(Module module, String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> || decoded['url'] is! String) {
      throw ApiException('Saved API configuration is invalid.');
    }
    final url = normalizeBaseUrl(module, decoded['url'] as String);
    return jsonEncode({'url': url});
  }

  static Future<void> load() async {
    try {
      for (final module in Module.values) {
        final value = await _storage.read(key: 'api_config_${module.name}');
        if (value != null) {
          final migrated = migrateSavedConfig(module, value);
          final data = jsonDecode(migrated) as Map<String, dynamic>;
          final url = data['url'] as String;
          _saved[module] = ApiConfig(url);
          if (migrated != value) {
            await _storage.write(
              key: 'api_config_${module.name}',
              value: migrated,
            );
            await _storage.delete(key: sessionStorageKey(module));
          }
        }
      }
      for (final module in Module.values) {
        final token = await _storage.read(key: sessionStorageKey(module));
        if (token != null && token.isNotEmpty) _panelTokens[module] = token;
      }
      final legacyToken = await _storage.read(key: 'panel_access_token');
      if (legacyToken != null && legacyToken.isNotEmpty) {
        if (!_panelTokens.containsKey(Module.gym)) {
          await _storage.write(
            key: sessionStorageKey(Module.gym),
            value: legacyToken,
          );
          _panelTokens[Module.gym] = legacyToken;
        }
        await _storage.delete(key: 'panel_access_token');
      }
      storageWarning = null;
    } catch (_) {
      storageWarning = 'Saved API settings could not be migrated. Open API Connection and verify both backend URLs and sessions.';
    }
  }

  static ApiConfig validate(Module module, String url) {
    return ApiConfig(normalizeBaseUrl(module, url));
  }

  static Future<void> save(Module module, String url) async {
    final config = validate(module, url);
    if (forModule(module).baseUrl != config.baseUrl) {
      await _storage.delete(key: sessionStorageKey(module));
      _panelTokens.remove(module);
    }
    await _storage.write(
      key: 'api_config_${module.name}',
      value: jsonEncode({'url': config.baseUrl}),
    );
    _saved[module] = config;
    storageWarning = null;
  }

  static Future<void> savePanelToken(Module module, String token) async {
    await _storage.write(key: sessionStorageKey(module), value: token);
    _panelTokens[module] = token;
  }

  static Future<void> clearPanelToken(Module module) async {
    await _storage.delete(key: sessionStorageKey(module));
    _panelTokens.remove(module);
  }

  static ApiConfig forModule(Module m) => m == Module.clinic ? clinic : gym;
}

class Membership {
  final String id;
  final Plan plan;
  final int price;
  final DateTime start;
  final DateTime end;
  final String status;
  const Membership(
    this.id,
    this.plan,
    this.price,
    this.start,
    this.end,
    this.status,
  );
  bool get expired => status == 'expired' || DateTime.now().isAfter(end);

  factory Membership.fromJson(Map<String, dynamic> j) {
    final raw = (j['plan_type'] ?? '').toString().toLowerCase();
    final plan = Plan.values.firstWhere(
      (p) => p.apiValue == raw,
      orElse: () => Plan.monthly,
    );
    return Membership(
      '${j['id']}',
      plan,
      (j['price'] as num?)?.toInt() ?? plan.price,
      DateTime.parse(j['start_date'].toString()),
      DateTime.parse(j['expiry_date'].toString()),
      (j['status'] ?? '').toString().toLowerCase(),
    );
  }
}

class AppUser {
  final String id;
  final Module module;
  final String name, email, phone, type;
  final DateTime createdAt;
  final bool isActive;
  final Membership? membership;
  const AppUser({
    required this.id,
    required this.module,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    required this.createdAt,
    required this.isActive,
    this.membership,
  });

  factory AppUser.fromJson(Module module, Map<String, dynamic> j) => AppUser(
    id: '${j['id']}',
    module: module,
    name: (j['name'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    type: (j['type'] ?? 'offline').toString().toLowerCase(),
    createdAt:
        DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
    isActive: (j['status'] ?? '').toString().toLowerCase() == 'active',
    membership: j['subscription'] is Map<String, dynamic>
        ? Membership.fromJson(j['subscription'])
        : null,
  );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiConnectionResult {
  final int userCount;
  final String? panelToken;
  const ApiConnectionResult({required this.userCount, this.panelToken});
}

class ApiService {
  // Injectable HTTP factory and timeout allow deterministic contract tests.
  static http.Client Function() clientFactory = http.Client.new;
  static Duration requestTimeout = const Duration(seconds: 20);

  static Future<dynamic> _request(
    Module module,
    String method,
    String path, [
    Map<String, dynamic>? body,
    ApiConfig? override,
    String? tokenOverride,
  ]) async {
    final config = override ?? ApiConfig.forModule(module);
    final checked = ApiConfig.validate(module, config.baseUrl);
    final token = tokenOverride ?? ApiConfig.panelTokenFor(module);
    if (token == null || token.isEmpty) {
      throw ApiException(
        '${_moduleLabel(module)} panel is not signed in. Open API Connection and sign in.',
      );
    }
    final uri = Uri.parse('${checked.baseUrl}$path');
    final client = clientFactory();
    try {
      final req = http.Request(method, uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        });
      if (body != null) req.body = jsonEncode(body);
      final response = await (() async {
        final stream = await client.send(req);
        return http.Response.fromStream(stream);
      })().timeout(requestTimeout);
      dynamic decoded;
      try {
        decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      } catch (_) {
        throw ApiException(
          'Server returned an invalid response (${response.statusCode}). Check the API URL.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map
            ? (decoded['message'] ?? decoded['error'])
            : null;
        final message = detail is List
            ? detail.join(', ')
            : detail?.toString() ?? 'Request failed';
        if (response.statusCode == 401 || response.statusCode == 403) {
          await ApiConfig.clearPanelToken(module);
          throw ApiException(
            '${_moduleLabel(module)} panel sign-in was rejected or expired. Open API Connection and sign in again. $message',
          );
        }
        if (response.statusCode == 404) {
          throw ApiException(
            'API route not found. Check the base URL including /api/v1.',
          );
        }
        throw ApiException(message);
      }
      return decoded;
    } on TimeoutException {
      throw ApiException(
        method == 'GET'
            ? 'The server did not respond within 20 seconds. Check API Connection, backend port and network.'
            : 'The server response timed out. The operation may have been saved. Refresh and verify the user before retrying.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the backend. Check API Connection, firewall and backend HOST. For Flutter Web also check CORS.',
      );
    } finally {
      client.close();
    }
  }

  static Future<String> _panelLogin(
    Module module,
    ApiConfig config,
    String email,
    String password,
  ) async {
    final checked = ApiConfig.validate(module, config.baseUrl);
    final client = clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('${checked.baseUrl}/super-admin/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(requestTimeout);
      dynamic decoded;
      try {
        decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      } catch (_) {
        throw ApiException(
          'Server returned an invalid sign-in response (${response.statusCode}).',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map
            ? (decoded['message'] ?? decoded['error'])
            : null;
        throw ApiException(
          detail is List
              ? detail.join(', ')
              : detail?.toString() ?? 'Panel sign-in failed.',
        );
      }
      if (decoded is! Map || decoded['token'] is! String) {
        throw ApiException('Backend returned an invalid panel session.');
      }
      return decoded['token'] as String;
    } on TimeoutException {
      throw ApiException(
        'The server did not respond within 20 seconds. Check the API URL and network.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the backend. Check API URL, firewall and backend HOST.',
      );
    } finally {
      client.close();
    }
  }

  static Future<ApiConnectionResult> testConnection(
    Module module,
    String url, {
    String email = '',
    String password = '',
  }) async {
    final config = ApiConfig.validate(module, url);
    final token = await _panelLogin(module, config, email, password);
    final data = await _request(
      module,
      'GET',
      '/super-admin/users',
      null,
      config,
      token,
    );
    if (data is! List) {
      throw ApiException('Invalid users response. Check the backend URL.');
    }
    return ApiConnectionResult(userCount: data.length, panelToken: token);
  }

  static Future<List<AppUser>> fetchUsers(Module m) async {
    final data = await _request(m, 'GET', '/super-admin/users');
    if (data is! List) throw ApiException('Invalid users response');
    return data
        .map((e) => AppUser.fromJson(m, Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<AppUser> signUp({
    required Module module,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String type,
    Plan? plan,
  }) async {
    if (module == Module.gym && plan == null) {
      throw ApiException('Select a gym subscription plan.');
    }
    final data = await _request(module, 'POST', '/super-admin/users', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'phone': phone.trim(),
      'type': type.toLowerCase(),
      if (module == Module.gym) 'planType': plan!.apiValue,
    });
    final user = AppUser.fromJson(module, Map<String, dynamic>.from(data));
    if (module == Module.gym && user.membership == null) {
      throw ApiException(
        'The backend returned an account without a subscription. Install the matching backend fix; refresh before retrying.',
      );
    }
    return user;
  }

  static Future<void> updateStatus(Module m, String id, bool active) async {
    await _request(m, 'PATCH', '/super-admin/users/$id/status', {
      'active': active,
    });
  }

  static Future<void> updateUser(
    Module m,
    String id, {
    required String name,
    required String email,
    required String phone,
    required String type,
  }) async {
    await _request(m, 'PATCH', '/super-admin/users/$id', {
      'name': name,
      'email': email,
      'phone': phone,
      'type': type.toLowerCase(),
    });
  }

  static Future<void> assignPlan(Module m, String id, Plan plan) async {
    await _request(m, 'POST', '/super-admin/users/$id/subscription', {
      'planType': plan.apiValue,
    });
  }

  static Future<void> renewPlan(Module m, String id, Plan plan) async {
    await _request(m, 'POST', '/super-admin/users/$id/subscription/renew', {
      'planType': plan.apiValue,
    });
  }

  static Future<void> resetPassword(
    Module m,
    String id,
    String password,
  ) async {
    await _request(m, 'POST', '/super-admin/users/$id/reset-password', {
      'password': password,
    });
  }
}
