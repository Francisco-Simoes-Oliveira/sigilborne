import 'character_deck.dart';

class EnemyOption {
  EnemyOption.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      description = json['description'] as String,
      hp = (json['attributes']['hp'] as num).toInt(),
      element = json['element'] as String? ?? 'neutral',
      xp = (json['rewards']?['xp'] as num?)?.toInt(),
      gold = (json['rewards']?['gold'] as num?)?.toInt();
  final String id;
  final String name;
  final String description;
  final int hp;
  final String element;
  final int? xp;
  final int? gold;
}

class EnemySelection {
  EnemySelection.fromJson(Map<String, dynamic> json)
    : enemies = (json['enemies'] as List)
          .map(
            (item) =>
                EnemyOption.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      supportedClassIds = List<String>.from(json['supportedClassIds'] as List);
  final List<EnemyOption> enemies;
  final List<String> supportedClassIds;
}

class BattleParticipant {
  BattleParticipant.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      hp = (json['hp'] as num).toInt(),
      maxHp = (json['maxHp'] as num).toInt(),
      energy = (json['energy'] as num?)?.toInt() ?? 0,
      maxEnergy = (json['maxEnergy'] as num?)?.toInt() ?? 0,
      guard = (json['guard'] as num).toDouble(),
      element = json['element'] as String? ?? 'neutral',
      statuses = Map<String, dynamic>.from(json['statuses'] as Map? ?? {}),
      pet = json['pet'] == null
          ? null
          : Map<String, dynamic>.from(json['pet'] as Map),
      traps = List<dynamic>.from(json['traps'] as List? ?? []);
  final String name;
  final int hp;
  final int maxHp;
  final int energy;
  final int maxEnergy;
  final double guard;
  final String element;
  final Map<String, dynamic> statuses;
  final Map<String, dynamic>? pet;
  final List<dynamic> traps;
}

class BattleEvent {
  BattleEvent.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      type = json['type'] as String,
      data = json;
  final int id;
  final String type;
  final Map<String, dynamic> data;

  String describe(Map<String, GameCard> cards) {
    final who = data['target'] == 'enemy' ? 'Inimigo' : 'Jogador';
    final actor = data['actor'] == 'enemy' ? 'inimigo' : 'jogador';
    final name = cards[data['cardId']]?.name ?? 'Carta';
    return switch (type) {
      'BATTLE_STARTED' => 'A batalha começou.',
      'CARD_USED' => '$name utilizada.',
      'ULTIMATE_USED' => 'Ultimate: $name!',
      'CARD_DRAWN' => '$name entrou na mão.',
      'ENERGY_SPENT' => '${data['amount']} de energia consumida.',
      'ENERGY_RECOVERED' => '${data['amount']} de energia recuperada.',
      'DAMAGE' => '$who recebeu ${data['amount']} de dano.',
      'HEAL' => '$who recuperou ${data['amount']} de vida.',
      'GUARD_GAINED' => '$who recebeu Guarda.',
      'GUARD_ABSORBED' => 'Guarda impediu ${data['amount']} de dano.',
      'CRITICAL' => 'Crítico de ${data['multiplier']}×!',
      'ENEMY_ACTION' => 'Inimigo: ${data['name']}.',
      'COUNTER_ATTACK' => 'O jogador contra-atacou.',
      'TURN_STARTED' => 'Turno do $actor.',
      'TURN_ENDED' => 'Turno do $actor encerrado.',
      'ACTION_SKIPPED' => 'O $actor perdeu a ação por atordoamento.',
      'ELEMENT_ADVANTAGE' =>
        'Vantagem elemental: ${data['element']} (${data['multiplier']}×).',
      'ELEMENT_RESISTED' =>
        'Resistência elemental: ${data['element']} (${data['multiplier']}×).',
      'ELEMENT_REACTION' =>
        data['reaction'] == 'freeze'
            ? 'Reação elemental: Encharcado + Gelo congelou o alvo.'
            : 'Reação elemental: Encharcado + Eletricidade aumentou o dano.',
      'STATUS_TICK' =>
        '${data['status']} causou ${data['amount']} de dano em $who.',
      'STATUS_REMOVED' => '${data['status']} foi consumido em $who.',
      'SHIELD_ABSORBED' => 'Escudo absorveu ${data['amount']} de dano.',
      'DODGE' => '$who esquivou do ataque.',
      'PET_SUMMONED' => '${data['name']} foi invocado.',
      'PET_ATTACK' => '${data['name']} atacou.',
      'PET_EXPIRED' => '${data['name']} saiu de combate.',
      'TRAP_SET' => 'Armadilha preparada.',
      'TRAP_TRIGGERED' => 'Armadilha ativada antes do ataque inimigo.',
      'TRAP_EXPIRED' => 'Armadilha expirou.',
      'STATUS_APPLIED' => '$who recebeu ${data['status']}.',
      'STATUS_EXPIRED' => '${data['status']} terminou.',
      'VICTORY' => 'VITÓRIA!',
      'DEFEAT' => 'DERROTA!',
      _ => type,
    };
  }
}

class BattleAction {
  BattleAction.fromJson(Map<String, dynamic> json)
    : canPlay = json['canPlay'] as bool,
      reason = json['reason'] as String?,
      target = json['target'] as String;
  final bool canPlay;
  final String? reason;
  final String target;
}

class BattleResult {
  BattleResult.fromJson(Map<String, dynamic> json)
    : rewardsApplied = json['rewardsApplied'] as bool,
      legacy = json['legacy'] as bool? ?? false,
      xp = (json['rewards']['xp'] as num).toInt(),
      gold = (json['rewards']['gold'] as num).toInt(),
      levelBefore = (json['progression']['levelBefore'] as num).toInt(),
      levelAfter = (json['progression']['levelAfter'] as num).toInt(),
      xpAfter = (json['progression']['xpAfter'] as num).toInt(),
      xpToNextLevel = (json['progression']['xpToNextLevel'] as num).toInt(),
      attributePointsGained =
          (json['progression']['attributePointsGained'] as num).toInt(),
      leveledUp = json['progression']['leveledUp'] as bool;

  final bool rewardsApplied;
  final bool legacy;
  final int xp;
  final int gold;
  final int levelBefore;
  final int levelAfter;
  final int xpAfter;
  final int xpToNextLevel;
  final int attributePointsGained;
  final bool leveledUp;
}

class BattleState {
  BattleState.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      characterId = json['characterId'] as String,
      status = json['status'] as String,
      turn = (json['turn'] as num).toInt(),
      version = (json['version'] as num).toInt(),
      player = BattleParticipant.fromJson(
        Map<String, dynamic>.from(json['player'] as Map),
      ),
      enemy = BattleParticipant.fromJson(
        Map<String, dynamic>.from(json['enemy'] as Map),
      ),
      hand = List<String>.from(json['player']['hand'] as List),
      queue = List<String>.from(json['player']['queue'] as List),
      ultimateId = json['player']['ultimate']['id'] as String,
      ultimateCharge = (json['player']['ultimate']['charge'] as num).toInt(),
      ultimateMaxCharge = (json['player']['ultimate']['maxCharge'] as num)
          .toInt(),
      cards = {
        for (final data in json['cards'] as List)
          data['id'] as String: GameCard.fromJson(
            Map<String, dynamic>.from(data as Map),
          ),
      },
      actions = (json['playable'] as Map).map(
        (key, value) => MapEntry(
          key as String,
          BattleAction.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      canEndTurn = json['canEndTurn'] as bool,
      catalogChanged = json['catalogChanged'] as bool,
      result = json['result'] == null
          ? null
          : BattleResult.fromJson(
              Map<String, dynamic>.from(json['result'] as Map),
            ),
      recentEvents = (json['recentEvents'] as List)
          .map(
            (item) =>
                BattleEvent.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList() {
    if (hand.length != 3 ||
        queue.length != 6 ||
        [
          ...hand,
          ...queue,
          ultimateId,
        ].any((id) => !cards.containsKey(id) || !actions.containsKey(id))) {
      throw const FormatException('Ciclo de cartas inválido.');
    }
  }
  final String id;
  final String characterId;
  final String status;
  final int turn;
  final int version;
  final BattleParticipant player;
  final BattleParticipant enemy;
  final List<String> hand;
  final List<String> queue;
  final String ultimateId;
  final int ultimateCharge;
  final int ultimateMaxCharge;
  final Map<String, GameCard> cards;
  final Map<String, BattleAction> actions;
  final bool canEndTurn;
  final bool catalogChanged;
  final BattleResult? result;
  final List<BattleEvent> recentEvents;
}
