import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
import 'character_selection_page.dart';
import 'create_character_page.dart';
import 'home_page.dart';
import 'deck_page.dart';

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
      case '/create-character':
        return MaterialPageRoute<Character>(
          settings: settings,
          builder: (_) => CreateCharacterPage(apiService: _api),
        );
      case '/home':
      case '/deck':
        final character = settings.arguments;
        if (character is Character && character.ownerId == widget.userId) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == '/deck'
                ? DeckPage(
                    character: character,
                    apiService: _api,
                    onSignOut: widget.onSignOut,
                  )
                : HomePage(character: character, onSignOut: widget.onSignOut),
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
