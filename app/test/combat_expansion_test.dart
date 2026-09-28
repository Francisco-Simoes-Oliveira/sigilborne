import 'dart:convert';
import 'dart:io';

import 'package:app/models/battle_state.dart';
import 'package:app/pages/battle_page.dart';
import 'package:app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> initial() =>
    jsonDecode(File('test/fixtures/battle_initial.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('enemy options include element and rewards, with legacy defaults', () {
    final option = EnemyOption.fromJson({
      'id': 'fire_slime',
      'name': 'Slime de Fogo',
      'description': 'Chamas',
      'attributes': {'hp': 72},
      'element': 'fire',
      'rewards': {'xp': 45, 'gold': 30},
    });
    expect(option.element, 'fire');
    expect(option.xp, 45);
    expect(option.gold, 30);
    final legacy = EnemyOption.fromJson({
      'id': 'goblin',
      'name': 'Goblin',
      'description': '',
      'attributes': {'hp': 80},
    });
    expect(legacy.element, 'neutral');
    expect(legacy.xp, isNull);
  });

  test('old battle JSON and new combat fields parse in one model', () {
    final old = BattleState.fromJson(
      Map<String, dynamic>.from(initial()['battle'] as Map),
    );
    expect(old.player.pet, isNull);
    expect(old.player.traps, isEmpty);
    expect(old.enemy.element, 'neutral');
    final json = initial()['battle'] as Map<String, dynamic>;
    (json['player'] as Map)['statuses'] = {
      'prepared': {'remainingTurns': 1},
    };
    (json['player'] as Map)['pet'] = {'name': 'Lobo'};
    (json['player'] as Map)['traps'] = [
      {'trigger': 'beforeEnemyAttack'},
    ];
    (json['enemy'] as Map)['element'] = 'fire';
    final updated = BattleState.fromJson(json);
    expect(updated.player.statuses.containsKey('prepared'), true);
    expect(updated.player.pet?['name'], 'Lobo');
    expect(updated.player.traps.length, 1);
    expect(updated.enemy.element, 'fire');
  });

  test('element, reaction, status and pet events have readable log text', () {
    for (final data in [
      {'type': 'ELEMENT_REACTION', 'reaction': 'freeze'},
      {'type': 'DODGE', 'target': 'player'},
      {'type': 'STATUS_TICK', 'target': 'enemy', 'status': 'burn', 'amount': 4},
      {'type': 'PET_ATTACK', 'name': 'Lobo'},
      {'type': 'TRAP_TRIGGERED'},
    ]) {
      final line = BattleEvent.fromJson({'id': 1, ...data}).describe({});
      expect(line, isNot(equals(data['type'])));
      expect(line, isNotEmpty);
    }
  });

  testWidgets('single battle screen shows statuses, element and Hunter pet', (
    tester,
  ) async {
    final payload = initial();
    final battle = payload['battle'] as Map<String, dynamic>;
    (battle['player'] as Map)['statuses'] = {
      'prepared': {'remainingTurns': 1},
    };
    (battle['player'] as Map)['pet'] = {'name': 'Lobo'};
    (battle['enemy'] as Map)['element'] = 'fire';
    (battle['enemy'] as Map)['statuses'] = {
      'marked': {'remainingTurns': 2},
    };
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      tokenProvider: () async => 'token',
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BattlePage(
          battleId: battle['id'] as String,
          apiService: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Elemento: Fogo'), findsOneWidget);
    expect(find.text('Marcado (2)'), findsOneWidget);
    expect(find.text('Preparado (1)'), findsOneWidget);
    expect(find.text('Pet ativo: Lobo'), findsOneWidget);
  });
}
