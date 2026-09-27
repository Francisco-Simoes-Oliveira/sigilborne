import 'dart:async';

import 'package:app/main.dart';
import 'package:app/models/character.dart';
import 'package:app/pages/battle_page.dart';
import 'package:app/pages/character_session.dart';
import 'package:app/pages/enemy_selection_page.dart';
import 'package:app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'battle_test.dart' show fixture, response, showBattle, makeApi;
import 'character_flow_test.dart' show TestAuth, TestUser;

class ProgressionServer {
  ProgressionServer({this.outcome = 'victory'});
  final String outcome;
  int starts = 0;
  int commands = 0;
  int characterReads = 0;
  bool finished = false;
  bool failFinalResponse = false;
  bool failRefresh = false;
  Completer<http.Response>? pendingRefresh;

  Map<String, dynamic> get before => {
    ...fixture('reward_victory')['character'] as Map<String, dynamic>,
    'level': 1,
    'xp': 80,
    'gold': 100,
    'attributePoints': 0,
    'xpToNextLevel': 100,
  };
  Map<String, dynamic> get current => finished
      ? Map<String, dynamic>.from(
          fixture('reward_$outcome')['character'] as Map,
        )
      : before;

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path == '/api/characters') {
      characterReads++;
      if (characterReads > 1 && pendingRefresh != null) {
        return pendingRefresh!.future;
      }
      if (characterReads > 1 && failRefresh) {
        throw http.ClientException('offline');
      }
      return response({
        'characters': [current],
      });
    }
    if (path == '/api/enemies') {
      return response({
        'supportedClassIds': ['warrior'],
        'enemies': [
          {
            'id': 'goblin',
            'name': 'Goblin',
            'description': 'Normal, normal, pesado.',
            'attributes': {'hp': 80},
          },
        ],
      });
    }
    if (path.endsWith('/latest-battle')) {
      if (starts == 0) return response({'battle': null, 'events': []});
      return response(fixture(finished ? 'reward_$outcome' : 'initial'));
    }
    if (path == '/api/battles' && request.method == 'POST') {
      starts++;
      finished = false;
      return response(fixture('initial'), 201);
    }
    if (path.startsWith('/api/battles/') && request.method == 'POST') {
      commands++;
      finished = true;
      if (failFinalResponse) throw http.ClientException('response lost');
      return response(fixture('reward_$outcome'));
    }
    return response(fixture(finished ? 'reward_$outcome' : 'initial'));
  }
}

Future<void> enterBattle(
  WidgetTester tester,
  ProgressionServer server, {
  TestAuth? auth,
}) async {
  final api = makeApi(server.handle);
  await tester.pumpWidget(
    MaterialApp(
      home: auth == null
          ? CharacterSession(
              userId: 'user-a',
              onSignOut: () async {},
              apiService: api,
            )
          : AuthGate(auth: auth, apiService: api),
    ),
  );
  if (auth != null) auth.events.add(TestUser('user-a'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kael'));
  await tester.pumpAndSettle();
  expect(find.text('XP: 80 / 100'), findsOneWidget);
  expect(find.text('Gold: 100'), findsOneWidget);
  await tester.ensureVisible(find.text('Batalhar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Batalhar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Começar luta'));
  await tester.pumpAndSettle();
}

Future<void> finishBattle(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('end-turn')));
  await tester.pumpAndSettle();
}

Future<void> resultTap(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'old characters default gold to zero while API thresholds are preserved',
    () {
      final json = ProgressionServer().before..remove('gold');
      expect(Character.fromJson(json).gold, 0);
      json['xpToNextLevel'] = 777;
      expect(Character.fromJson(json).xpToNextLevel, 777);
    },
  );

  testWidgets(
    'victory shows persisted XP, gold and level up, and waits for user choice',
    (tester) async {
      final server = ProgressionServer();
      await enterBattle(tester, server);
      await finishBattle(tester);
      expect(find.byKey(const ValueKey('battle-result')), findsOneWidget);
      expect(find.text('VITÓRIA'), findsOneWidget);
      expect(find.text('+40 XP'), findsOneWidget);
      expect(find.text('+25 Gold'), findsOneWidget);
      expect(find.text('LEVEL UP!'), findsOneWidget);
      expect(find.text('Nível 1 → 2'), findsOneWidget);
      expect(find.text('+2 Pontos de Atributo'), findsOneWidget);
      expect(find.text('XP: 20 / 150'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(BattlePage), findsOneWidget);
      expect(server.commands, 1);
      expect(server.characterReads, 1);
    },
  );

  testWidgets(
    'victory without level up shows rewards but no level-up message',
    (tester) async {
      final data = fixture('reward_victory');
      final progress = data['battle']['result']['progression'] as Map;
      progress['leveledUp'] = false;
      progress['levelAfter'] = 1;
      progress['xpAfter'] = 40;
      progress['xpToNextLevel'] = 100;
      progress['attributePointsGained'] = 0;
      await showBattle(tester, makeApi((_) async => response(data)));
      expect(find.text('+40 XP'), findsOneWidget);
      expect(find.text('LEVEL UP!'), findsNothing);
      expect(find.text('XP: 40 / 100'), findsOneWidget);
    },
  );

  testWidgets(
    'return Home reloads the same character and removes finished battle routes',
    (tester) async {
      final server = ProgressionServer();
      await enterBattle(tester, server);
      await finishBattle(tester);
      await resultTap(tester, 'result-home');
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
      expect(find.byType(BattlePage, skipOffstage: false), findsNothing);
      expect(
        find.byType(EnemySelectionPage, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Guerreiro • Nível 2'), findsOneWidget);
      expect(find.text('XP: 20 / 150'), findsOneWidget);
      expect(find.text('Gold: 125'), findsOneWidget);
      expect(find.text('Pontos de atributo disponíveis: 2'), findsOneWidget);
      expect(server.characterReads, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Seus personagens'), findsOneWidget);
    },
  );

  for (final outcome in ['victory', 'defeat']) {
    testWidgets(
      '$outcome returns to enemy selection without automatically starting a battle',
      (tester) async {
        final server = ProgressionServer(outcome: outcome);
        await enterBattle(tester, server);
        await finishBattle(tester);
        expect(
          find.text(outcome == 'victory' ? 'Nova batalha' : 'Tentar novamente'),
          findsOneWidget,
        );
        if (outcome == 'defeat') {
          expect(find.text('DERROTA'), findsOneWidget);
          expect(find.text('Nenhuma recompensa.'), findsOneWidget);
          expect(find.text('+40 XP'), findsNothing);
          expect(find.text('+25 Gold'), findsNothing);
        }
        await resultTap(tester, 'result-new-battle');
        expect(find.byType(EnemySelectionPage), findsOneWidget);
        expect(
          find.byType(EnemySelectionPage, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byType(BattlePage, skipOffstage: false), findsNothing);
        expect(server.starts, 1);
        expect(find.text('Ver última batalha'), findsOneWidget);
        await tester.tap(find.text('Ver última batalha'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('battle-result')), findsOneWidget);
        expect(server.commands, 1);
        await resultTap(tester, 'result-new-battle');
        await tester.tap(find.text('Começar luta'));
        await tester.pumpAndSettle();
        expect(server.starts, 2);
        expect(find.byKey(const ValueKey('end-turn')), findsOneWidget);
        expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
      },
    );
  }

  testWidgets('defeat Home refresh keeps previous level XP and gold', (
    tester,
  ) async {
    final server = ProgressionServer(outcome: 'defeat');
    await enterBattle(tester, server);
    await finishBattle(tester);
    await resultTap(tester, 'result-home');
    expect(find.text('Guerreiro • Nível 1'), findsOneWidget);
    expect(find.text('XP: 80 / 100'), findsOneWidget);
    expect(find.text('Gold: 100'), findsOneWidget);
    expect(find.text('Pontos de atributo disponíveis: 0'), findsOneWidget);
  });

  testWidgets('returning using system back also refreshes the Home', (
    tester,
  ) async {
    final server = ProgressionServer();
    await enterBattle(tester, server);
    await finishBattle(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Gold: 125'), findsOneWidget);
  });

  testWidgets(
    'old historical battle without result stays readable with clear exits',
    (tester) async {
      await showBattle(
        tester,
        makeApi((_) async => response(fixture('victory'))),
      );
      expect(find.text('VITÓRIA'), findsOneWidget);
      expect(find.textContaining('Batalha antiga'), findsOneWidget);
      expect(find.text('Voltar para Home'), findsOneWidget);
      expect(find.text('Nova batalha'), findsOneWidget);
      expect(find.text('+40 XP'), findsNothing);
    },
  );

  testWidgets(
    'final result is recovered after a lost command response without resending it',
    (tester) async {
      final server = ProgressionServer()..failFinalResponse = true;
      await enterBattle(tester, server);
      await finishBattle(tester);
      expect(find.text('+25 Gold'), findsOneWidget);
      expect(server.commands, 1);
      await resultTap(tester, 'result-home');
      expect(find.text('Gold: 125'), findsOneWidget);
    },
  );

  testWidgets('Home refresh failure shows retry instead of stale balances', (
    tester,
  ) async {
    final server = ProgressionServer()..failRefresh = true;
    await enterBattle(tester, server);
    await finishBattle(tester);
    await resultTap(tester, 'result-home');
    expect(
      find.textContaining('Não foi possível atualizar o personagem'),
      findsOneWidget,
    );
    expect(find.text('Gold: 100'), findsNothing);
    server.failRefresh = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Gold: 125'), findsOneWidget);
  });

  testWidgets(
    'result fits a narrow screen with enlarged text and scrollable exits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = makeApi((_) async => response(fixture('reward_victory')));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: BattlePage(
            battleId: 'test',
            apiService: api,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('result-new-battle')),
        180,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('result-new-battle')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('logout from the result discards private routes', (tester) async {
    final auth = TestAuth();
    addTearDown(auth.events.close);
    await enterBattle(tester, ProgressionServer(), auth: auth);
    await finishBattle(tester);
    await tester.tap(find.byTooltip('Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byType(BattlePage, skipOffstage: false), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets(
    'logout while Home refresh is pending ignores the late balance response',
    (tester) async {
      final auth = TestAuth();
      addTearDown(auth.events.close);
      final server = ProgressionServer()
        ..pendingRefresh = Completer<http.Response>();
      await enterBattle(tester, server, auth: auth);
      await finishBattle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('result-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('result-home')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('Sair da conta'));
      await tester.pumpAndSettle();
      server.pendingRefresh!.complete(
        response({
          'characters': [server.current],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Gold: 125'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
