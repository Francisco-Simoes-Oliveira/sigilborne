import 'dart:async';
import 'dart:convert';

import 'package:app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> characterJson({
  String id = 'kael',
  String name = 'Kael',
  String ownerId = 'user-a',
}) => {
  'id': id,
  'ownerId': ownerId,
  'name': name,
  'classId': 'warrior',
  'level': 2,
  'xp': 35,
  'attributes': {'hp': 120, 'maxEnergy': 6},
};

ApiService apiWith(
  Future<http.Response> Function(http.Request) handler, {
  Duration? timeout,
}) {
  final api = ApiService(
    client: MockClient(handler),
    tokenProvider: () async => 'firebase-token',
    requestTimeout: timeout ?? const Duration(seconds: 20),
  );
  addTearDown(api.close);
  return api;
}

void main() {
  test(
    'GET sends a bearer token, no owner parameter, and reads/sorts characters',
    () async {
      final api = apiWith((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/characters');
        expect(request.url.query, isEmpty);
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        return http.Response(
          jsonEncode({
            'characters': [
              characterJson(name: 'Zara'),
              characterJson(id: 'aria', name: 'Aria'),
            ],
          }),
          200,
        );
      });
      final result = await api.getCharacters();
      expect(result.map((character) => character.name), ['Aria', 'Zara']);
      expect(result.first.id, 'aria');
      expect(result.first.attribute('hp'), 120);
      expect(result.first.level, 2);
    },
  );

  test('empty accounts return an empty list', () async {
    final api = apiWith((_) async => http.Response('{"characters":[]}', 200));
    expect(await api.getCharacters(), isEmpty);
  });

  test(
    'creation posts only name and class and preserves the returned document ID',
    () async {
      final api = apiWith((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/characters');
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        expect(jsonDecode(request.body), {
          'name': 'Kael',
          'classId': 'warrior',
        });
        return http.Response(
          jsonEncode(characterJson(id: 'firestore-id')),
          201,
        );
      });
      final result = await api.createCharacter(
        name: 'Kael',
        classId: 'warrior',
      );
      expect(result.id, 'firestore-id');
      expect(result.ownerId, 'user-a');
    },
  );

  test('expired authentication produces an actionable error', () async {
    final api = apiWith((_) async => http.Response('Unauthorized', 401));
    await expectLater(
      api.getCharacters(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('sessão expirou'),
        ),
      ),
    );
  });

  test('server JSON error is preserved', () async {
    final api = apiWith(
      (_) async => http.Response('{"error":"Serviço indisponível."}', 503),
    );
    await expectLater(
      api.getCharacters(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Serviço indisponível.',
        ),
      ),
    );
  });

  for (final body in [
    '<html>error</html>',
    '{}',
    '{"characters":[{"name":"Kael"}]}',
  ]) {
    test('malformed successful response is rejected: $body', () async {
      final api = apiWith((_) async => http.Response(body, 200));
      await expectLater(api.getCharacters(), throwsA(isA<ApiException>()));
    });
  }

  test('offline and timeout errors are translated', () async {
    final offline = apiWith((_) async => throw http.ClientException('offline'));
    await expectLater(
      offline.getCharacters(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('conectar'),
        ),
      ),
    );
    final slow = apiWith(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      slow.getCharacters(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('demorou'),
        ),
      ),
    );
  });
}
