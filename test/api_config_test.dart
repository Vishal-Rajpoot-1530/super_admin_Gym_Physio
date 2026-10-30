import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:multyapp_pannel/services/api_service.dart';

void main() {
  test('legacy local backend URLs migrate to their module ports', () {
    expect(
      ApiConfig.normalizeBaseUrl(
        Module.clinic,
        'http://localhost:3004/api/v1/physio',
      ),
      'http://localhost:3002/api/v1',
    );
    expect(
      ApiConfig.normalizeBaseUrl(Module.gym, 'http://10.0.2.2:3002/api/v1'),
      'http://10.0.2.2:3001/api/v1',
    );
    expect(
      ApiConfig.normalizeBaseUrl(Module.clinic, 'http://localhost:3002'),
      'http://localhost:3002/api/v1',
    );
  });

  test('Gym and Physio keep separate secure session keys', () {
    expect(
      ApiConfig.sessionStorageKey(Module.gym),
      isNot(ApiConfig.sessionStorageKey(Module.clinic)),
    );
  });

  test('legacy saved Physio settings drop the API key and migrate its URL', () {
    expect(
      ApiConfig.migrateSavedConfig(
        Module.clinic,
        '{"url":"http://localhost:3004/api/v1/physio","key":"old-key"}',
      ),
      '{"url":"http://localhost:3002/api/v1"}',
    );
  });

  test('each backend signs in and receives its own bearer session', () async {
    final requests = <http.BaseRequest>[];
    final oldFactory = ApiService.clientFactory;
    ApiService.clientFactory = () => MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        final token = request.url.port == 3001
            ? 'gym-session'
            : 'physio-session';
        return http.Response('{"token":"$token"}', 200);
      }
      return http.Response('[]', 200);
    });

    try {
      final gym = await ApiService.testConnection(
        Module.gym,
        'http://localhost:3001/api/v1',
        email: 'gym-admin@example.com',
        password: 'gym-password',
      );
      final physio = await ApiService.testConnection(
        Module.clinic,
        'http://localhost:3002/api/v1',
        email: 'physio-admin@example.com',
        password: 'physio-password',
      );

      expect(gym.panelToken, 'gym-session');
      expect(physio.panelToken, 'physio-session');
      final userRequests = requests.where((request) => request.method == 'GET');
      expect(userRequests.map((request) => request.headers['Authorization']), [
        'Bearer gym-session',
        'Bearer physio-session',
      ]);
      expect(userRequests.map((request) => request.url.port), [3001, 3002]);
      expect(
        userRequests.every(
          (request) => !request.headers.containsKey('x-super-admin-key'),
        ),
        isTrue,
      );
    } finally {
      ApiService.clientFactory = oldFactory;
    }
  });
}
