import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/main.dart';
import 'package:app/models/character.dart';
import 'package:app/pages/character_session.dart';
import 'package:app/pages/deck_page.dart';
import 'package:app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_service_test.dart' show characterJson;
import 'character_flow_test.dart' show TestAuth, TestUser;

Map<String, dynamic> deckFixture() =>
    jsonDecode(File('test/fixtures/warrior_deck.json').readAsStringSync())
        as Map<String, dynamic>;

ApiService apiFor(Future<http.Response> Function(http.Request) handle) {
  final api = ApiService(
    client: MockClient(handle),
    tokenProvider: () async => 'firebase-token',
  );
  addTearDown(api.close);
  return api;
}

Future<void> showDeck(WidgetTester tester, ApiService api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DeckPage(
        character: Character.fromJson(characterJson()),
        apiService: api,
        onSignOut: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'deck API uses a single authenticated request and resolves 9 normal cards plus Ultimate',
    () async {
      var requests = 0;
      final api = apiFor((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/characters/kael/deck');
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        return http.Response(
          jsonEncode(deckFixture()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final deck = await api.getCharacterDeck('kael');
      expect(requests, 1);
      expect(deck.cards.length, 9);
      expect(deck.cards.first.name, 'Corte');
      expect(deck.cards.first.cost, 1);
      expect(deck.cards.first.elementName, 'Neutro');
      expect(deck.ultimate.name, 'Muralha Inquebrável');
      expect(deck.ultimate.type, 'ultimate');
      expect(deck.cards.any((card) => card.type == 'ultimate'), false);
    },
  );

  for (final status in [403, 404, 409, 503]) {
    test('deck API preserves actionable backend errors: $status', () async {
      final api = apiFor(
        (_) async => http.Response('{"error":"Confira o deck"}', status),
      );
      await expectLater(
        api.getCharacterDeck('kael'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Confira o deck',
          ),
        ),
      );
    });
  }

  for (final invalid in [
    'short',
    'ultimateMissing',
    'wrongCharacter',
    'ultimateInHand',
    'tooManyCopies',
  ]) {
    test('invalid deck data is rejected: $invalid', () async {
      final data = deckFixture();
      final deck = data['deck'] as Map<String, dynamic>;
      switch (invalid) {
        case 'short':
          (deck['cards'] as List).removeLast();
        case 'ultimateMissing':
          deck.remove('ultimate');
        case 'wrongCharacter':
          deck['characterId'] = 'someone-else';
        case 'ultimateInHand':
          (deck['cards'] as List)[0] = deck['ultimate'];
        case 'tooManyCopies':
          deck['cards'] = List.filled(9, (deck['cards'] as List).first);
      }
      final api = apiFor((_) async => http.Response(jsonEncode(data), 200));
      await expectLater(
        api.getCharacterDeck('kael'),
        throwsA(isA<ApiException>()),
      );
    });
  }

  testWidgets(
    'selected Home opens a read-only deck with a separate Ultimate, then returns',
    (tester) async {
      var deckCalls = 0;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/deck')) {
          deckCalls++;
          return http.Response(
            jsonEncode(deckFixture()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'characters': [characterJson()],
          }),
          200,
        );
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
      await tester.ensureVisible(find.text('Ver deck'));
      await tester.tap(find.text('Ver deck'));
      await tester.pumpAndSettle();
      expect(deckCalls, 1);
      expect(find.text('Deck Inicial'), findsOneWidget);
      expect(find.text('Muralha Inquebrável'), findsOneWidget);
      expect(find.byKey(const ValueKey('deck-ultimate')), findsOneWidget);
      expect(find.text('6 energia'), findsOneWidget);
      expect(
        find.text('10 cartas no total: 9 normais + 1 Ultimate'),
        findsOneWidget,
      );
      for (var index = 0; index < 9; index++) {
        final card = find.byKey(ValueKey('deck-card-$index'));
        await tester.scrollUntilVisible(card, 220);
        expect(card, findsOneWidget);
      }
      expect(find.text('Golpe Duplo'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo, Kael!'), findsOneWidget);
    },
  );

  testWidgets('deck loading errors have retry and refresh', (tester) async {
    var fail = true;
    var requests = 0;
    final api = apiFor((_) async {
      requests++;
      return fail
          ? http.Response('{"error":"Seed ausente"}', 503)
          : http.Response(jsonEncode(deckFixture()), 200);
    });
    await showDeck(tester, api);
    expect(find.text('Seed ausente'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Deck Inicial'), findsOneWidget);
    await tester.tap(find.byTooltip('Atualizar deck'));
    await tester.pumpAndSettle();
    expect(requests, 3);
  });

  testWidgets('deck errors do not display another owner or class data', (
    tester,
  ) async {
    final data = deckFixture();
    data['deck']['ownerId'] = 'other-user';
    final api = apiFor((_) async => http.Response(jsonEncode(data), 200));
    await showDeck(tester, api);
    expect(find.textContaining('não corresponde'), findsOneWidget);
    expect(find.text('Muralha Inquebrável'), findsNothing);
  });

  testWidgets(
    'signing out while Deck is loading removes the page and ignores a late response',
    (tester) async {
      final auth = TestAuth();
      addTearDown(auth.events.close);
      final response = Completer<http.Response>();
      final api = apiFor(
        (request) async => request.url.path.endsWith('/deck')
            ? response.future
            : http.Response(
                jsonEncode({
                  'characters': [characterJson()],
                }),
                200,
              ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(auth: auth, apiService: api),
        ),
      );
      auth.events.add(TestUser('user-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kael'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver deck'));
      await tester.tap(find.text('Ver deck'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(DeckPage),
          matching: find.byTooltip('Sair da conta'),
        ),
      );
      await tester.pumpAndSettle();
      response.complete(http.Response(jsonEncode(deckFixture()), 200));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.byType(DeckPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deck remains readable on a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = apiFor(
      (_) async => http.Response(jsonEncode(deckFixture()), 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: DeckPage(
          character: Character.fromJson(characterJson()),
          apiService: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('deck-card-8')),
      200,
    );
    expect(tester.takeException(), isNull);
  });
}
