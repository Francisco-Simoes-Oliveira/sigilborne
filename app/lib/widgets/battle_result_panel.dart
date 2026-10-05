import 'package:flutter/material.dart';
import '../models/battle_state.dart';
import '../theme/app_theme.dart';
import 'game_ui.dart';

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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: ((progress - 0.7) / 0.3).clamp(0.0, 1.0),
        child: Transform.scale(scale: progress, child: child),
      ),
      child: GamePanel(
        key: const ValueKey('battle-result'),
        accent: victory ? GameColors.gold : GameColors.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Icon(
                victory
                    ? Icons.emoji_events_outlined
                    : Icons.heart_broken_outlined,
                size: 56,
                color: victory ? GameColors.gold : GameColors.danger,
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                victory ? 'VITÓRIA' : 'DERROTA',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: victory ? GameColors.gold : GameColors.danger,
                ),
              ),
            ),
            Text(
              victory
                  ? '${battle.enemy.name} derrotado.'
                  : '${battle.enemy.name} venceu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            const GameSectionHeading(
              title: 'Recompensas',
              icon: Icons.stars_outlined,
            ),
            const SizedBox(height: 12),
            if (historical)
              const Text(
                'Batalha antiga, sem recompensas de progressão. Nenhum XP ou Gold será concedido ao reabrir este resultado.',
              )
            else ...[
              if (victory) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GameBadge(
                      label: '+${result.xp} XP',
                      icon: Icons.auto_graph,
                      color: GameColors.success,
                    ),
                    GameBadge(
                      label: '+${result.gold} Gold',
                      icon: Icons.monetization_on_outlined,
                      color: GameColors.gold,
                    ),
                  ],
                ),
              ] else
                const Text('Nenhuma recompensa.'),
              if (result.leveledUp) ...[
                const SizedBox(height: 16),
                Text(
                  'LEVEL UP!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: GameColors.gold),
                ),
                Text('Nível ${result.levelBefore} → ${result.levelAfter}'),
                Text('+${result.attributePointsGained} Pontos de Atributo'),
              ],
              const SizedBox(height: 14),
              GameProgressBar(
                label: 'XP',
                value: result.xpAfter,
                max: result.xpToNextLevel,
                color: GameColors.gold,
              ),
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
