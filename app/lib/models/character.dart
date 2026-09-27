class Character {
  Character({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.classId,
    this.level = 1,
    this.xp = 0,
    this.gold = 0,
    int? xpToNextLevel,
    this.attributePoints = 0,
    Map<String, dynamic> attributes = const {},
    Map<String, dynamic> equipment = const {},
    this.equippedDeckId,
  }) : _xpToNextLevel = xpToNextLevel,
       attributes = Map.unmodifiable(attributes),
       equipment = Map.unmodifiable(equipment);

  factory Character.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Personagem com campo inválido: $key.');
      }
      return value;
    }

    return Character(
      id: requiredText('id'),
      ownerId: requiredText('ownerId'),
      name: requiredText('name'),
      classId: requiredText('classId'),
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      gold: (json['gold'] as num?)?.toInt() ?? 0,
      xpToNextLevel: (json['xpToNextLevel'] as num?)?.toInt(),
      attributePoints: (json['attributePoints'] as num?)?.toInt() ?? 0,
      attributes: Map<String, dynamic>.from(json['attributes'] as Map? ?? {}),
      equipment: Map<String, dynamic>.from(json['equipment'] as Map? ?? {}),
      equippedDeckId: json['equippedDeckId'] as String?,
    );
  }

  final String id;
  final String ownerId;
  final String name;
  final String classId;
  final int level;
  final int xp;
  final int gold;
  final int? _xpToNextLevel;
  // The API supplies this value. The fallback only displays older responses.
  int get xpToNextLevel => _xpToNextLevel ?? 100 + (level - 1) * 50;
  final int attributePoints;
  final Map<String, dynamic> attributes;
  final Map<String, dynamic> equipment;
  final String? equippedDeckId;

  String get className => switch (classId) {
    'warrior' => 'Guerreiro',
    'mage' => 'Mago',
    'rogue' => 'Ladino',
    'hunter' => 'Hunter',
    _ => classId,
  };

  int attribute(String name) => (attributes[name] as num?)?.toInt() ?? 0;
}
