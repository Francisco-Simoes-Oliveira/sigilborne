import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/main.dart';
import 'package:app/pages/battle_page.dart';
import 'package:app/pages/character_session.dart';
import 'package:app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_service_test.dart' show characterJson;
import 'character_flow_test.dart' show TestAuth, TestUser;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/battle_$name.json').readAsStringSync())
        as Map<String, dynamic>;
http.Response response(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
final battleId = fixture('initial')['battle']['id'] as String;

ApiService makeApi(Future<http.Response> Function(http.Request) handler) {
  final api = ApiService(
    client: MockClient(handler),
    tokenProvider: () async => 'token',
  );
  addTearDown(api.close);
  return api;
}

Future<void> showBattle(WidgetTester tester, ApiService api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BattlePage(
        battleId: battleId,
        apiService: api,
        onSignOut: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'battle API uses authenticated commands and version without client HP or damage',
    () async {
      final requests = <http.Request>[];
      final api = makeApi((request) async {
        requests.add(request);
        return response(
          fixture('initial'),
          request.url.path == '/api/battles' ? 201 : 200,
        );
      });
      final battle = await api.startBattle(
        characterId: 'hero',
        enemyId: 'goblin',
      );
      expect(battle.hand.length, 3);
      expect(battle.queue.length, 6);
      expect(jsonDecode(requests.last.body), {
        'characterId': 'hero',
        'enemyId': 'goblin',
      });
      await api.getBattle(battle.id);
      await api.playCard(
        battleId: battle.id,
        cardId: battle.hand.first,
        target: 'enemy',
        expectedVersion: 1,
      );
      expect(jsonDecode(requests.last.body), {
        'cardId': battle.hand.first,
        'target': 'enemy',
        'expectedVersion': 1,
      });
      expect(requests.last.url.path, '/api/battles/${battle.id}/play-card');
      await api.endTurn(battleId: battle.id, expectedVersion: 2);
      expect(jsonDecode(requests.last.body), {'expectedVersion': 2});
      await api.playUltimate(
        battleId: battle.id,
        target: 'self',
        expectedVersion: 3,
      );
      expect(requests.last.url.path, '/api/battles/${battle.id}/play-ultimate');
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer token',
        ),
        true,
      );
    },
  );

  testWidgets(
    'battle loads and exposes three hand cards, six queued cards and separate Ultimate',
    (tester) async {
      final api = makeApi((_) async => response(fixture('initial')));
      await showBattle(tester, api);
      expect(find.text('Goblin'), findsOneWidget);
      expect(find.text('HP: 80 / 80'), findsOneWidget);
      expect(find.text('Energia: 6 / 6'), findsOneWidget);
      for (var index = 0; index < 3; index++) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('hand-$index')),
          200,
        );
        expect(find.byKey(ValueKey('hand-$index')), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('battle-ultimate')),
        200,
      );
      expect(find.text('Carga: 0 / 100'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('use-ultimate')))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Fila do ciclo (6 cartas)'),
        200,
      );
      expect(find.text('Fila do ciclo (6 cartas)'), findsOneWidget);
    },
  );

  testWidgets(
    'server-disabled cards remain disabled for energy or unmet requirements',
    (tester) async {
      final data = fixture('initial');
      final battle = data['battle'] as Map<String, dynamic>;
      battle['player']['energy'] = 0;
      for (final id in battle['player']['hand'] as List) {
        battle['playable'][id] = {
          'canPlay': false,
          'reason': 'Energia insuficiente.',
          'target': 'enemy',
        };
      }
      final api = makeApi((_) async => response(data));
      await showBattle(tester, api);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-0')),
        150,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('play-0')))
            .onPressed,
        isNull,
      );
      // Requirements are also an authoritative flag, even with sufficient energy.
      battle['player']['energy'] = 6;
      battle['playable'][battle['player']['hand'][0]]['reason'] =
          'Requisito da carta não atendido.';
      await tester.tap(find.byTooltip('Atualizar batalha'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('play-0')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'playing a card refreshes energy, enemy HP and the hand from the API',
    (tester) async {
      var playCalls = 0;
      final api = makeApi((request) async {
        if (request.url.path.endsWith('/play-card')) {
          playCalls++;
          expect(jsonDecode(request.body)['expectedVersion'], 1);
          return response(fixture('played'));
        }
        return response(fixture('initial'));
      });
      await showBattle(tester, api);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-0')),
        150,
      );
      await tester.tap(find.byKey(const ValueKey('play-0')));
      await tester.pumpAndSettle();
      expect(playCalls, 1);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('player-energy')),
        -150,
      );
      expect(find.text('Energia: 5 / 6'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('HP: 70 / 80'), -150);
      expect(find.text('HP: 70 / 80'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('hand-2')),
        180,
      );
      expect(find.text('Golpe de Escudo'), findsOneWidget);
    },
  );

  testWidgets(
    'end turn is sent once during rapid taps and shows the next turn',
    (tester) async {
      var endCalls = 0;
      final pending = Completer<http.Response>();
      final api = makeApi((request) async {
        if (request.url.path.endsWith('/end-turn')) {
          endCalls++;
          return pending.future;
        }
        return response(fixture('played'));
      });
      await showBattle(tester, api);
      await tester.tap(find.byKey(const ValueKey('end-turn')));
      await tester.tap(find.byKey(const ValueKey('end-turn')));
      await tester.pump();
      expect(endCalls, 1);
      pending.complete(response(fixture('next_turn')));
      await tester.pumpAndSettle();
      expect(find.text('Turno 2'), findsOneWidget);
      expect(find.text('Energia: 6 / 6'), findsOneWidget);
      expect(find.text('HP: 115 / 120'), findsOneWidget);
    },
  );

  for (final outcome in ['victory', 'defeat']) {
    testWidgets('saved $outcome renders and disables further actions', (
      tester,
    ) async {
      final api = makeApi((_) async => response(fixture(outcome)));
      await showBattle(tester, api);
      expect(
        find.text(outcome == 'victory' ? 'VITÓRIA' : 'DERROTA'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('end-turn')))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-0')),
        180,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('play-0')))
            .onPressed,
        isNull,
      );
    });
  }

  testWidgets(
    'stale commands refresh authoritative state without replaying the command',
    (tester) async {
      var reads = 0;
      var commands = 0;
      final api = makeApi((request) async {
        if (request.method == 'POST') {
          commands++;
          return response({
            'error': 'A batalha já mudou.',
            'code': 'STALE_BATTLE',
          }, 409);
        }
        reads++;
        return response(fixture(reads == 1 ? 'initial' : 'played'));
      });
      await showBattle(tester, api);
      await tester.tap(find.byKey(const ValueKey('end-turn')));
      await tester.pumpAndSettle();
      expect(commands, 1);
      expect(reads, 2);
      expect(find.text('Energia: 5 / 6'), findsOneWidget);
      expect(find.text('A batalha já mudou.'), findsOneWidget);
    },
  );

  testWidgets(
    'network uncertainty disables commands until a successful refresh',
    (tester) async {
      var firstRead = true;
      var failing = true;
      final api = makeApi((request) async {
        if (firstRead) {
          firstRead = false;
          return response(fixture('initial'));
        }
        if (failing) throw http.ClientException('offline');
        return response(fixture('played'));
      });
      await showBattle(tester, api);
      await tester.tap(find.byKey(const ValueKey('end-turn')));
      await tester.pumpAndSettle();
      expect(find.text('Sincronizar batalha'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('end-turn')))
            .onPressed,
        isNull,
      );
      failing = false;
      await tester.tap(find.text('Sincronizar batalha'));
      await tester.pumpAndSettle();
      expect(find.text('Sincronizar batalha'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('end-turn')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Home to enemy selection to battle and back can reopen the latest fight',
    (tester) async {
      var hasBattle = false;
      final api = makeApi((request) async {
        final path = request.url.path;
        if (path == '/api/characters') {
          return response({
            'characters': [characterJson(id: 'hero')],
          });
        }
        if (path == '/api/enemies') {
          return response({
            'enemies': [
              {
                'id': 'goblin',
                'name': 'Goblin',
                'description': 'Normal, normal, pesado.',
                'attributes': {'hp': 80},
              },
            ],
            'supportedClassIds': ['warrior'],
          });
        }
        if (path.endsWith('/latest-battle')) {
          return hasBattle
              ? response(fixture('initial'))
              : response({'battle': null, 'events': []});
        }
        if (path == '/api/battles') {
          hasBattle = true;
          return response(fixture('initial'), 201);
        }
        return response(fixture('initial'));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterSession(
            userId: 'user-a',
            onSignOut: () async {},
            apiService: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kael'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Batalhar'));
      await tester.tap(find.text('Batalhar'));
      await tester.pumpAndSettle();
      expect(find.text('Goblin'), findsOneWidget);
      await tester.tap(find.text('Começar luta'));
      await tester.pumpAndSettle();
      expect(find.text('Mão (3 cartas)'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Continuar batalha'), findsOneWidget);
      await tester.tap(find.text('Continuar batalha'));
      await tester.pumpAndSettle();
      expect(find.byType(BattlePage), findsOneWidget);
    },
  );

  testWidgets('logout removes the battle and ignores a pending response', (
    tester,
  ) async {
    final auth = TestAuth();
    addTearDown(auth.events.close);
    final pending = Completer<http.Response>();
    final api = makeApi((request) async {
      if (request.url.path == '/api/characters') {
        return response({
          'characters': [characterJson()],
        });
      }
      return pending.future;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(auth: auth, apiService: api),
      ),
    );
    auth.events.add(TestUser('user-a'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Seus personagens'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattlePage(
          battleId: battleId,
          apiService: api,
          onSignOut: auth.signOut,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(
      find.descendant(
        of: find.byType(BattlePage),
        matching: find.byTooltip('Sair da conta'),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(response(fixture('initial')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byType(BattlePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('battle is usable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = makeApi((_) async => response(fixture('initial')));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: BattlePage(
          battleId: battleId,
          apiService: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('hand-2')), 180);
    expect(tester.takeException(), isNull);
  });
}
