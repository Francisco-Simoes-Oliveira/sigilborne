import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
import 'character_selection_page.dart';
import 'create_character_page.dart';
import 'home_page.dart';
import 'deck_page.dart';
import 'enemy_selection_page.dart';
import 'battle_page.dart';
import '../models/battle_state.dart';

/// This navigator belongs to one login and is disposed when that user signs out.
class CharacterSession extends StatefulWidget {
  const CharacterSession({
    super.key,
    required this.userId,
    required this.onSignOut,
    this.apiService,
  });

  final String userId;
  final Future<void> Function() onSignOut;
  final ApiService? apiService;

  @override
  State<CharacterSession> createState() => _CharacterSessionState();
}

class _CharacterSessionState extends State<CharacterSession> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ApiService _api = widget.apiService ?? ApiService();

  @override
  void dispose() {
    if (widget.apiService == null) _api.close();
    super.dispose();
  }

  Route<dynamic> _route(RouteSettings settings) {
    switch (settings.name) {
      case '/battle':
        final battle = settings.arguments;
        if (battle is! BattleState) {
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Batalha indisponível.')),
            ),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BattlePage(
            battleId: battle.id,
            apiService: _api,
            onSignOut: widget.onSignOut,
          ),
        );
      case '/create-character':
        return MaterialPageRoute<Character>(
          settings: settings,
          builder: (_) => CreateCharacterPage(apiService: _api),
        );
      case '/home':
      case '/deck':
      case '/enemies':
        final character = settings.arguments;
        if (character is Character && character.ownerId == widget.userId) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == '/enemies'
                ? EnemySelectionPage(
                    character: character,
                    apiService: _api,
                    onSignOut: widget.onSignOut,
                  )
                : settings.name == '/deck'
                ? DeckPage(
                    character: character,
                    apiService: _api,
                    onSignOut: widget.onSignOut,
                  )
                : HomePage(
                    character: character,
                    onSignOut: widget.onSignOut,
                    apiService: _api,
                  ),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Personagem indisponível')),
            body: const Center(
              child: Text('Volte e selecione um personagem da sua conta.'),
            ),
          ),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => CharacterSelectionPage(
            apiService: _api,
            onSignOut: widget.onSignOut,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => _navigatorKey.currentState!.maybePop(result),
      child: Navigator(key: _navigatorKey, onGenerateRoute: _route),
    ),
  );
}
