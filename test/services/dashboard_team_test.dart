import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';

import '../helpers/mock_http_adapter.dart';

const _teamPath = '/v1/me/team';

void main() {
  late MockHttpAdapter adapter;

  setUp(() {
    adapter = MockHttpAdapter();
    DashboardService.setDioForTesting(dioWithMockAdapter(adapter));
  });

  tearDown(DashboardService.resetDio);

  group('fetchTeamStatus (CR54)', () {
    test('returns the team and membership from GET /v1/me/team with the bearer token', () async {
      adapter.stubJson('GET', {
        'domain': 'acme.com',
        'team': {'id': 'org-team', 'name': 'acme.com'},
        'member': false,
      }, path: _teamPath);

      final res = await DashboardService.fetchTeamStatus(jwt: 'tok');

      expect(res, isA<TeamAvailable>());
      final team = res as TeamAvailable;
      expect(team.teamId, 'org-team');
      expect(team.teamName, 'acme.com');
      expect(team.member, isFalse);
      expect(adapter.requestLog.single.path, endsWith(_teamPath));
      expect(adapter.requestLog.single.headers['Authorization'], 'Bearer tok');
    });

    test('reports member only for a literal true', () async {
      adapter.stubJson('GET', {
        'team': {'id': 'org-team', 'name': 'acme.com'},
        'member': 'true',
      }, path: _teamPath);

      final res = await DashboardService.fetchTeamStatus(jwt: 'tok') as TeamAvailable;

      expect(res.member, isFalse);
    });

    final unavailable = <String, void Function(MockHttpAdapter)>{
      'no team org': (a) => a.stubJson('GET', {'domain': 'acme.com', 'team': null, 'member': false}, path: _teamPath),
      'a team with no id': (a) => a.stubJson('GET', {'team': {'name': 'acme.com'}}, path: _teamPath),
      'a 401': (a) => a.stubJson('GET', {'error': {}}, statusCode: 401, path: _teamPath),
      'a 500': (a) => a.stubJson('GET', {'error': {}}, statusCode: 500, path: _teamPath),
      'a network error': (a) => a.stubError('GET', DioExceptionType.connectionError, path: _teamPath),
    };
    unavailable.forEach((label, arrange) {
      test('treats $label as nothing to offer', () async {
        arrange(adapter);
        expect(await DashboardService.fetchTeamStatus(jwt: 'tok'), isA<TeamUnavailable>());
      });
    });
  });

  group('joinTeam (CR54)', () {
    test('POSTs once and returns the team org id', () async {
      adapter.stubJson('POST', {'organizationId': 'org-team', 'role': 'member', 'joined': true}, path: _teamPath);

      final res = await DashboardService.joinTeam(jwt: 'tok');

      expect((res as JoinTeamSuccess).teamId, 'org-team');
      expect(adapter.requestCount('POST'), 1);
      expect(adapter.requestLog.single.headers['Authorization'], 'Bearer tok');
    });

    const messages = {
      401: 'Authentication required. Please log in again.',
      403: 'Verify your email address, then try again.',
      404: 'No team exists for your email domain.',
      409: 'Your membership of this team is not active. Ask a team owner.',
      503: 'Server error. Please try again.',
      418: 'An unexpected error occurred.',
    };
    messages.forEach((status, message) {
      test('maps $status to a safe message', () async {
        adapter.stubJson('POST', {'error': {'message': 'raw'}}, statusCode: status, path: _teamPath);

        final res = await DashboardService.joinTeam(jwt: 'tok');

        expect((res as JoinTeamError).error, message);
      });
    });

    test('a 200 without an organization id is an error, not a success', () async {
      adapter.stubJson('POST', {'joined': true}, path: _teamPath);
      expect(await DashboardService.joinTeam(jwt: 'tok'), isA<JoinTeamError>());
    });

    test('does not retry a network error', () async {
      adapter.stubError('POST', DioExceptionType.connectionError, path: _teamPath);

      final res = await DashboardService.joinTeam(jwt: 'tok');

      expect((res as JoinTeamError).error, 'Network error. Please try again.');
      expect(adapter.requestCount('POST'), 1);
    });
  });
}
