import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/character.dart';
import '../models/character_deck.dart';
import '../models/battle_state.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    http.Client? client,
    Future<String> Function()? tokenProvider,
    String? apiBaseUrl,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? _getToken,
       _baseUrl = apiBaseUrl ?? baseUrl;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  final http.Client _client;
  final Future<String> Function() _tokenProvider;
  final String _baseUrl;
  final Duration requestTimeout;

  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException('Usuário não autenticado. Entre novamente.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Não foi possível obter o token. Entre novamente.',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    int expectedStatus = 200,
  }) async {
    try {
      final token = await _tokenProvider().timeout(requestTimeout);
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(requestTimeout);
      if (response.statusCode == 401) {
        throw const ApiException('Sua sessão expirou. Saia e entre novamente.');
      }
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } on FormatException {
        // A proxy or unavailable server may return HTML instead of JSON.
      }
      if (response.statusCode != expectedStatus) {
        throw ApiException(
          data?['error'] is String
              ? data!['error'] as String
              : 'Não foi possível concluir a solicitação. Tente novamente.',
          code: data?['code'] as String?,
        );
      }
      if (data == null) {
        throw const ApiException('A API retornou uma resposta inválida.');
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar à API. Verifique a conexão.',
      );
    }
  }

  Future<Map<String, dynamic>> getMe() => _request('/api/me');

  Future<List<dynamic>> getClasses() async {
    final data = await _request('/api/classes');
    if (data['classes'] is! List) {
      throw const ApiException('A API retornou uma lista de classes inválida.');
    }
    return data['classes'] as List<dynamic>;
  }

  Future<List<Character>> getCharacters() async {
    final data = await _request('/api/characters');
    try {
      final characters = (data['characters'] as List)
          .map(
            (item) =>
                Character.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      characters.sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
      return characters;
    } on FormatException {
      throw const ApiException('A API retornou um personagem inválido.');
    } on TypeError {
      throw const ApiException(
        'A API retornou uma lista de personagens inválida.',
      );
    }
  }

  Future<Character> getCharacter(String characterId) async {
    final characters = await getCharacters();
    for (final character in characters) {
      if (character.id == characterId) return character;
    }
    throw const ApiException(
      'Personagem não encontrado nesta conta. Volte à seleção.',
    );
  }

  Future<Character> createCharacter({
    required String name,
    required String classId,
  }) async {
    final data = await _request(
      '/api/characters',
      body: {'name': name, 'classId': classId},
      expectedStatus: 201,
    );
    try {
      return Character.fromJson(data);
    } on FormatException {
      throw const ApiException(
        'A API retornou um personagem inválido. Atualize a lista antes de tentar criar novamente.',
      );
    } on TypeError {
      throw const ApiException(
        'A API retornou um personagem inválido. Atualize a lista antes de tentar criar novamente.',
      );
    }
  }

  void close() => _client.close();

  BattleState _battle(Map<String, dynamic> data) {
    try {
      return BattleState.fromJson(
        Map<String, dynamic>.from(data['battle'] as Map),
      );
    } on FormatException {
      throw const ApiException('A API retornou um estado de batalha inválido.');
    } on TypeError {
      throw const ApiException('A API retornou uma batalha incompleta.');
    }
  }

  Future<EnemySelection> getEnemies() async {
    final data = await _request('/api/enemies');
    try {
      return EnemySelection.fromJson(data);
    } on TypeError {
      throw const ApiException(
        'A API retornou uma lista de inimigos inválida.',
      );
    }
  }

  Future<BattleState?> getLatestBattle(String characterId) async {
    final data = await _request(
      '/api/characters/${Uri.encodeComponent(characterId)}/latest-battle',
    );
    return data['battle'] == null ? null : _battle(data);
  }

  Future<BattleState> startBattle({
    required String characterId,
    required String enemyId,
  }) async => _battle(
    await _request(
      '/api/battles',
      body: {'characterId': characterId, 'enemyId': enemyId},
      expectedStatus: 201,
    ),
  );

  Future<BattleState> getBattle(String battleId) async =>
      _battle(await _request('/api/battles/${Uri.encodeComponent(battleId)}'));

  Future<BattleState> playCard({
    required String battleId,
    required String cardId,
    required String target,
    required int expectedVersion,
  }) async => _battle(
    await _request(
      '/api/battles/${Uri.encodeComponent(battleId)}/play-card',
      body: {
        'cardId': cardId,
        'target': target,
        'expectedVersion': expectedVersion,
      },
    ),
  );

  Future<BattleState> playUltimate({
    required String battleId,
    required String target,
    required int expectedVersion,
  }) async => _battle(
    await _request(
      '/api/battles/${Uri.encodeComponent(battleId)}/play-ultimate',
      body: {'target': target, 'expectedVersion': expectedVersion},
    ),
  );

  Future<BattleState> endTurn({
    required String battleId,
    required int expectedVersion,
  }) async => _battle(
    await _request(
      '/api/battles/${Uri.encodeComponent(battleId)}/end-turn',
      body: {'expectedVersion': expectedVersion},
    ),
  );

  Future<CharacterDeck> getCharacterDeck(String characterId) async {
    if (characterId.isEmpty) {
      throw const ApiException('Selecione um personagem.');
    }
    final data = await _request(
      '/api/characters/${Uri.encodeComponent(characterId)}/deck',
    );
    try {
      final deck = CharacterDeck.fromJson(
        Map<String, dynamic>.from(data['deck'] as Map),
      );
      if (deck.characterId != characterId) {
        throw const FormatException('Personagem incorreto.');
      }
      return deck;
    } on FormatException {
      throw const ApiException(
        'A API retornou um deck inválido. Confira se há 9 cartas e uma Ultimate cadastradas.',
      );
    } on TypeError {
      throw const ApiException(
        'A API retornou um deck incompleto. Tente novamente.',
      );
    }
  }
}
