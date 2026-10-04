String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Campo inválido no deck: $key.');
  }
  return value;
}

class GameCard {
  GameCard.fromJson(Map<String, dynamic> json)
    : id = _requiredText(json, 'id'),
      name = _requiredText(json, 'name'),
      classId = _requiredText(json, 'classId'),
      description = _requiredText(json, 'description'),
      type = _requiredText(json, 'type'),
      cost = (json['cost'] as num).toInt(),
      damage = json['damage'] == null
          ? null
          : Map.unmodifiable(Map<String, dynamic>.from(json['damage'] as Map)),
      data = Map.unmodifiable(json) {
    if (cost < 0 ||
        json['cost'] != cost ||
        !['attack', 'defense', 'skill', 'ultimate'].contains(type)) {
      throw const FormatException('Tipo ou custo da carta inválido.');
    }
  }

  final String id;
  final String name;
  final String classId;
  final String description;
  final String type;
  final int cost;
  final Map<String, dynamic>? damage;
  // Retains generic effects/conditions for future features without interpreting combat.
  final Map<String, dynamic> data;

  List<String> get tags =>
      (data['tags'] as List?)?.whereType<String>().toList() ?? const [];
  String? get imageUrl =>
      data['imageUrl'] is String && (data['imageUrl'] as String).isNotEmpty
      ? data['imageUrl'] as String
      : null;

  String get typeName => switch (type) {
    'attack' => 'Ataque',
    'defense' => 'Defesa',
    'skill' => 'Habilidade',
    'ultimate' => 'Ultimate',
    _ => type,
  };

  String? get elementName => switch (damage?['element']) {
    'neutral' => 'Neutro',
    'fire' => 'Fogo',
    'ice' => 'Gelo',
    'earth' => 'Terra',
    'electric' => 'Elétrico',
    final String value => value,
    _ => null,
  };

  String? get damageNatureName => switch (damage?['nature']) {
    'physical' => 'Físico',
    'magical' => 'Mágico',
    _ => null,
  };
}

class CharacterDeck {
  CharacterDeck.fromJson(Map<String, dynamic> json)
    : id = _requiredText(json, 'id'),
      name = _requiredText(json, 'name'),
      ownerId = _requiredText(json, 'ownerId'),
      characterId = _requiredText(json, 'characterId'),
      cards = List.unmodifiable(
        (json['cards'] as List).map(
          (item) => GameCard.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      ultimate = GameCard.fromJson(
        Map<String, dynamic>.from(json['ultimate'] as Map),
      ) {
    if (cards.length != 9 ||
        ultimate.type != 'ultimate' ||
        cards.any(
          (card) => card.type == 'ultimate' || card.id == ultimate.id,
        )) {
      throw const FormatException(
        'O deck precisa ter 9 cartas normais e 1 Ultimate separada.',
      );
    }
    final copies = <String, int>{};
    for (final card in cards) {
      copies[card.id] = (copies[card.id] ?? 0) + 1;
      if (copies[card.id]! > 3) {
        throw const FormatException('Quantidade de cópias inválida.');
      }
    }
  }

  final String id;
  final String name;
  final String ownerId;
  final String characterId;
  final List<GameCard> cards;
  final GameCard ultimate;
}
