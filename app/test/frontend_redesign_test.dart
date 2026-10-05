import 'dart:async';
import 'dart:convert';

import 'package:app/models/battle_state.dart';
import 'package:app/pages/create_character_page.dart';
import 'package:app/pages/login_page.dart';
import 'package:app/pages/register_page.dart';
import 'package:app/services/api_service.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/battle_arena.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'login stays usable on mobile and translates an authentication error',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.dark,
          home: LoginPage(
            signIn: (email, password) {
              expect(email, 'kael@example.com');
              expect(password, 'senha');
              return pending.future;
            },
          ),
        ),
      );
      expect(find.text('SIGILBORNE'), findsOneWidget);
      expect(find.text('Criar conta'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'kael@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'senha');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.completeError(
        FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Internal Firebase credentials error',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.textContaining('Internal Firebase'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration validates matching passwords before Firebase is called',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: GameTheme.dark, home: const RegisterPage()),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Kael');
      await tester.enterText(find.byType(TextField).at(1), 'kael@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'senha123');
      await tester.enterText(find.byType(TextField).at(3), 'outra');
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Criar conta'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pump();
      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('class choice shows its style and server attributes', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'classes': [
              {
                'id': 'warrior',
                'name': 'Guerreiro',
                'description': 'Defende e contra-ataca.',
                'baseAttributes': {'hp': 120, 'strength': 12, 'defense': 12},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      tokenProvider: () async => 'token',
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: GameTheme.dark,
        home: CreateCharacterPage(apiService: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Defesa • Guarda • Contra-ataque'), findsOneWidget);
    expect(find.text('HP: 120'), findsOneWidget);
    await tester.tap(find.text('Guerreiro'));
    await tester.pumpAndSettle();
    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(group.groupValue, 'warrior');
  });

  testWidgets('damage and critical feedback uses the event amount', (
    tester,
  ) async {
    final participant = BattleParticipant.fromJson({
      'name': 'Goblin',
      'hp': 62,
      'maxHp': 80,
      'guard': 0,
      'statuses': {
        'burn': {'remainingTurns': 2},
      },
    });
    final damage = BattleEvent.fromJson({
      'id': 7,
      'type': 'DAMAGE',
      'target': 'enemy',
      'amount': 18,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: GameTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BattleParticipantPanel(
              participant: participant,
              isPlayer: false,
              feedback: damage,
              critical: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('HP: 62 / 80'), findsOneWidget);
    expect(find.text('−18'), findsOneWidget);
    expect(find.text('CRÍTICO'), findsOneWidget);
    expect(find.text('Queimadura (2)'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 550));
    expect(tester.takeException(), isNull);
  });
}
