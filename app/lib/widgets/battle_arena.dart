import 'package:flutter/material.dart';

import '../models/battle_state.dart';
import '../theme/app_theme.dart';
import 'game_ui.dart';

/// Visual feedback is taken only from the authoritative battle event stream.
class BattleParticipantPanel extends StatelessWidget {
  const BattleParticipantPanel({
    super.key,
    required this.participant,
    required this.isPlayer,
    this.feedback,
    this.critical = false,
  });

  final BattleParticipant participant;
  final bool isPlayer;
  final BattleEvent? feedback;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final event = feedback;
    final damage = event?.type == 'DAMAGE' || event?.type == 'STATUS_TICK';
    final heal = event?.type == 'HEAL';
    final number = event?.amount;
    final color = isPlayer ? GameColors.energy : GameColors.health;
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'impact-${isPlayer ? 'player' : 'enemy'}-${event?.id ?? 0}',
      ),
      tween: Tween(begin: event == null ? 0 : 1, end: 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, impact, child) => Transform.translate(
        offset: Offset((damage ? 5 : 0) * impact, 0),
        child: child,
      ),
      child: GamePanel(
        accent: damage ? GameColors.danger : color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPlayer ? Icons.person_outline : Icons.pest_control_outlined,
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPlayer ? 'HERÓI' : 'INIMIGO',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        participant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                if (event != null && number != null && (damage || heal))
                  Semantics(
                    liveRegion: true,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('floating-${event.id}'),
                      tween: Tween(begin: 1, end: 0),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, progress, child) => Opacity(
                        opacity: progress,
                        child: Transform.translate(
                          offset: Offset(0, -12 * (1 - progress)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (critical)
                            const Text(
                              'CRÍTICO',
                              style: TextStyle(
                                color: GameColors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          Text(
                            '${heal ? '+' : '−'}$number',
                            style: TextStyle(
                              color: heal
                                  ? GameColors.success
                                  : GameColors.danger,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GameProgressBar(
              label: 'HP',
              value: participant.hp,
              max: participant.maxHp,
              color: GameColors.health,
              animationKey: ValueKey('health-${isPlayer ? 'player' : 'enemy'}'),
            ),
            if (isPlayer) ...[
              const SizedBox(height: 13),
              GameProgressBar(
                label: 'Energia',
                value: participant.energy,
                max: participant.maxEnergy,
                color: GameColors.energy,
                animationKey: const ValueKey('player-energy'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (participant.guard > 0)
                  GameBadge(
                    label: 'Guarda ${(participant.guard * 100).round()}%',
                    icon: Icons.shield_outlined,
                    color: GameColors.ultimate,
                    tooltip: GameVisual.statusDescription('guard'),
                  ),
                if (participant.element != 'neutral')
                  GameBadge(
                    label:
                        'Elemento: ${GameVisual.elementName(participant.element)}',
                    icon: GameVisual.elementIcon(participant.element),
                    color: GameColors.forElement(participant.element),
                  ),
                for (final status in participant.activeStatuses)
                  GameBadge(
                    label:
                        '${GameVisual.statusName(status.id)} (${status.remainingTurns})'
                        '${status.stacks > 1 ? ' ×${status.stacks}' : ''}',
                    icon: GameVisual.statusIcon(status.id),
                    color: GameVisual.statusColor(status.id),
                    tooltip: GameVisual.statusDescription(status.id),
                  ),
                if (participant.petName != null)
                  GameBadge(
                    label: 'Pet ativo: ${participant.petName}',
                    icon: Icons.pets,
                    color: GameColors.success,
                  ),
                if (participant.trapCount > 0)
                  GameBadge(
                    label: 'Armadilhas ativas: ${participant.trapCount}',
                    icon: Icons.adjust,
                    color: GameColors.warning,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BattleEventFeed extends StatelessWidget {
  const BattleEventFeed({
    super.key,
    required this.battle,
    this.initiallyExpanded = false,
  });
  final BattleState battle;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => GamePanel(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      title: const Text('Últimos eventos'),
      subtitle: battle.recentEvents.isEmpty
          ? null
          : Text(
              battle.recentEvents.last.describe(
                battle.cards,
                playerName: battle.player.name,
                enemyName: battle.enemy.name,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      children: [
        for (final event in battle.recentEvents.reversed.take(20))
          ListTile(
            dense: true,
            leading: Icon(
              _eventIcon(event.type),
              color: _eventColor(event.type),
              size: 20,
            ),
            title: Text(
              event.describe(
                battle.cards,
                playerName: battle.player.name,
                enemyName: battle.enemy.name,
              ),
            ),
          ),
      ],
    ),
  );

  IconData _eventIcon(String type) => switch (type) {
    'DAMAGE' || 'CRITICAL' || 'STATUS_TICK' => Icons.flash_on_outlined,
    'HEAL' => Icons.favorite_outline,
    'CARD_DRAWN' => Icons.style_outlined,
    'GUARD_GAINED' || 'SHIELD_ABSORBED' => Icons.shield_outlined,
    'VICTORY' => Icons.emoji_events_outlined,
    'DEFEAT' => Icons.heart_broken_outlined,
    _ => Icons.auto_awesome,
  };

  Color _eventColor(String type) => switch (type) {
    'DAMAGE' || 'CRITICAL' || 'STATUS_TICK' => GameColors.danger,
    'HEAL' => GameColors.success,
    'VICTORY' => GameColors.gold,
    _ => GameColors.energy,
  };
}
