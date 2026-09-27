import 'dart:async';
import 'dart:convert';

import 'package:app/main.dart';
import 'package:app/pages/character_session.dart';
import 'package:app/pages/home_page.dart';
import 'package:app/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_service_test.dart' show characterJson;

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements FirebaseAuth {
  final events = StreamController<User?>.broadcast();
  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  Future<void> signOut() async => events.add(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestServer {
  List<Map<String, dynamic>> characters = [];
  int listCalls = 0;
  int createCalls = 0;
  int classCalls = 0;
  bool failList = false;
  bool failClasses = false;
  Completer<http.Response>? pendingList;
  Completer<http.Response>? pendingClasses;
  Completer<http.Response>? pendingCreate;

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/api/classes') {
      classCalls++;
      if (pendingClasses != null) return pendingClasses!.future;
      if (failClasses) {
        return http.Response('{"error":"Falha nas classes"}', 500);
      }
      return http.Response(
        jsonEncode({
          'classes': [
            {
              'id': 'warrior',
              'name': 'Guerreiro',
              'description': 'Defesa e combate.',
            },
          ],
        }),
        200,
      );
    }
    if (request.method == 'POST') {
      createCalls++;
      if (pendingCreate != null) return pendingCreate!.future;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final character = characterJson(
        id: 'new-id',
        name: body['name'] as String,
      );
      characters.add(character);
      return http.Response(jsonEncode(character), 201);
    }
    listCalls++;
    if (pendingList != null) return pendingList!.future;
    if (failList) return http.Response('{"error":"Falha ao listar"}', 500);
    return http.Response(jsonEncode({'characters': characters}), 200);
  }

  ApiService createApi() => ApiService(
    client: MockClient(handle),
    tokenProvider: () async => 'test-token',
  );
}

Future<void> pumpSession(WidgetTester tester, TestServer server) async {
  final api = server.createApi();
  addTearDown(api.close);
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
}

void main() {
  testWidgets(
    'small screens and the keyboard do not overflow the character flow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final server = TestServer()
        ..characters = [characterJson(name: 'Kael da Montanha Distante')];
      await pumpSession(tester, server);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('character-kael')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar personagem'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending creation blocks duplicate submissions and back navigation',
    (tester) async {
      final server = TestServer()..pendingCreate = Completer<http.Response>();
      await pumpSession(tester, server);
      await tester.tap(find.text('Criar personagem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kael');
      await tester.tap(find.text('Guerreiro'));
      final button = find.widgetWithText(ElevatedButton, 'Criar personagem');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Nome do personagem'), findsOneWidget);
      expect(server.createCalls, 1);
      server.characters = [characterJson()];
      server.pendingCreate!.complete(
        http.Response(jsonEncode(characterJson()), 201),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seus personagens'), findsOneWidget);
      expect(server.listCalls, 2);
    },
  );

  testWidgets(
    'session expiration during creation discards the route and late response',
    (tester) async {
      final server = TestServer()..pendingCreate = Completer<http.Response>();
      final auth = TestAuth();
      final api = server.createApi();
      addTearDown(auth.events.close);
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(auth: auth, apiService: api),
        ),
      );
      auth.events.add(TestUser('user-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar personagem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kael');
      await tester.tap(find.text('Guerreiro'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar personagem'));
      await tester.pump();
      auth.events.add(null);
      await tester.pumpAndSettle();
      server.pendingCreate!.complete(
        http.Response(jsonEncode(characterJson()), 201),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Seus personagens'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failure to refresh after creation offers retry without repeating POST',
    (tester) async {
      final server = TestServer();
      await pumpSession(tester, server);
      await tester.tap(find.text('Criar personagem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kael');
      await tester.tap(find.text('Guerreiro'));
      server.failList = true;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar personagem'));
      await tester.pumpAndSettle();
      expect(find.text('Falha ao listar'), findsOneWidget);
      server.failList = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Kael'), findsOneWidget);
      expect(server.createCalls, 1);
    },
  );

  testWidgets(
    'empty account creates a character, refreshes, and enters its Home',
    (tester) async {
      final server = TestServer();
      await pumpSession(tester, server);
      expect(
        find.textContaining('Você ainda não tem personagens'),
        findsOneWidget,
      );
      await tester.tap(find.text('Criar personagem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lyra');
      await tester.tap(find.text('Guerreiro'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar personagem'));
      await tester.pumpAndSettle();
      expect(server.createCalls, 1);
      expect(server.listCalls, 2);
      expect(find.text('Seus personagens'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('character-new-id')));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo, Lyra!'), findsOneWidget);
      expect(
        tester.widget<HomePage>(find.byType(HomePage)).character.id,
        'new-id',
      );
      expect(find.text('Vida: 120'), findsOneWidget);
      // Let the creation snackbar leave before tapping the bottom action.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Trocar personagem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trocar personagem'));
      await tester.pumpAndSettle();
      expect(find.text('Seus personagens'), findsOneWidget);
      expect(server.listCalls, 3);
    },
  );

  testWidgets(
    'choosing each character supplies the correct identity and back returns to selection',
    (tester) async {
      final server = TestServer()
        ..characters = [
          characterJson(),
          characterJson(id: 'lyra', name: 'Lyra'),
        ];
      await pumpSession(tester, server);
      for (final id in ['kael', 'lyra']) {
        final tile = find.byKey(ValueKey('character-$id'));
        await tester.tap(tile);
        await tester.tap(tile, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(HomePage), findsOneWidget);
        expect(tester.widget<HomePage>(find.byType(HomePage)).character.id, id);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Seus personagens'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'list error offers retry, and refresh fetches newly added characters',
    (tester) async {
      final server = TestServer()..failList = true;
      await pumpSession(tester, server);
      expect(find.text('Falha ao listar'), findsOneWidget);
      server.failList = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      server.characters.add(characterJson());
      await tester.tap(find.byTooltip('Atualizar personagens'));
      await tester.pumpAndSettle();
      expect(find.text('Kael'), findsOneWidget);
      expect(server.listCalls, 3);
    },
  );

  testWidgets(
    'creation can be cancelled while classes load without setState after dispose',
    (tester) async {
      final server = TestServer()..pendingClasses = Completer<http.Response>();
      await pumpSession(tester, server);
      await tester.tap(find.text('Criar personagem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      server.pendingClasses!.complete(http.Response('{"classes":[]}', 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Seus personagens'), findsOneWidget);
      expect(server.listCalls, 1);
    },
  );

  testWidgets(
    'class failures retry and invalid names do not create characters',
    (tester) async {
      final server = TestServer()..failClasses = true;
      await pumpSession(tester, server);
      await tester.tap(find.text('Criar personagem'));
      await tester.pumpAndSettle();
      expect(find.text('Falha nas classes'), findsOneWidget);
      server.failClasses = false;
      await tester.tap(find.text('Recarregar classes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.text('Guerreiro'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar personagem'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pelo menos 3'), findsOneWidget);
      expect(server.createCalls, 0);
    },
  );

  testWidgets(
    'logout from Home removes private routes and a new login starts fresh',
    (tester) async {
      final server = TestServer()..characters = [characterJson()];
      final auth = TestAuth();
      final api = server.createApi();
      addTearDown(auth.events.close);
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(auth: auth, apiService: api),
        ),
      );
      auth.events.add(TestUser('user-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kael'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsNothing);
      server.characters = [
        characterJson(id: 'other', name: 'Nora', ownerId: 'user-b'),
      ];
      auth.events.add(TestUser('user-b'));
      await tester.pumpAndSettle();
      expect(find.text('Nora'), findsOneWidget);
      expect(find.text('Kael'), findsNothing);
    },
  );

  testWidgets(
    'account changes while Home is open discard the previous selection',
    (tester) async {
      final server = TestServer()..characters = [characterJson()];
      final auth = TestAuth();
      final api = server.createApi();
      addTearDown(auth.events.close);
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(auth: auth, apiService: api),
        ),
      );
      auth.events.add(TestUser('user-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kael'));
      await tester.pumpAndSettle();
      server.characters = [];
      auth.events.add(TestUser('user-b'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsNothing);
      expect(
        find.textContaining('Você ainda não tem personagens'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a delayed listing cannot update a disposed session', (
    tester,
  ) async {
    final server = TestServer()..pendingList = Completer<http.Response>();
    final api = server.createApi();
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterSession(
          userId: 'user-a',
          onSignOut: () async {},
          apiService: api,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    server.pendingList!.complete(http.Response('{"characters":[]}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
