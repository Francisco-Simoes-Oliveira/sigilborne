import 'package:flutter/material.dart';
import '../models/battle_state.dart';

class BattleResultPanel extends StatelessWidget {
  const BattleResultPanel({
    super.key,
    required this.battle,
    this.onHome,
    this.onNewBattle,
  });
  final BattleState battle;
  final VoidCallback? onHome;
  final VoidCallback? onNewBattle;

  @override
  Widget build(BuildContext context) {
    final victory = battle.status == 'victory';
    final result = battle.result;
    final historical =
        result == null || result.legacy || !result.rewardsApplied;
    return Card(
      key: const ValueKey('battle-result'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                victory ? 'VITÓRIA' : 'DERROTA',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            Text(
              victory
                  ? '${battle.enemy.name} derrotado.'
                  : '${battle.enemy.name} venceu.',
            ),
            const SizedBox(height: 16),
            Text('Recompensas', style: Theme.of(context).textTheme.titleLarge),
            if (historical)
              const Text(
                'Batalha antiga, sem recompensas de progressão. Nenhum XP ou Gold será concedido ao reabrir este resultado.',
              )
            else ...[
              if (victory) ...[
                Text('+${result.xp} XP'),
                Text('+${result.gold} Gold'),
              ] else
                const Text('Nenhuma recompensa.'),
              if (result.leveledUp) ...[
                const SizedBox(height: 16),
                Text(
                  'LEVEL UP!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Nível ${result.levelBefore} → ${result.levelAfter}'),
                Text('+${result.attributePointsGained} Pontos de Atributo'),
              ],
              const SizedBox(height: 8),
              Text('XP: ${result.xpAfter} / ${result.xpToNextLevel}'),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('result-home'),
              onPressed: onHome,
              child: const Text('Voltar para Home'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('result-new-battle'),
              onPressed: onNewBattle,
              child: Text(victory ? 'Nova batalha' : 'Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
