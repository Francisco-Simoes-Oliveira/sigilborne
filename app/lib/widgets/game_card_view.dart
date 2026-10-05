import 'package:flutter/material.dart';

import '../models/character_deck.dart';
import '../theme/app_theme.dart';
import 'game_ui.dart';

/// The same card face is used in the deck and in the three-card battle hand.
class GameCardView extends StatelessWidget {
  const GameCardView({
    super.key,
    required this.card,
    this.compact = false,
    this.ultimate = false,
    this.onPlay,
    this.canPlay = true,
    this.busy = false,
    this.reason,
    this.actionKey,
    this.actionLabel,
  });

  final GameCard card;
  final bool compact;
  final bool ultimate;
  final VoidCallback? onPlay;
  final bool canPlay;
  final bool busy;
  final String? reason;
  final Key? actionKey;
  final String? actionLabel;

  static double heightFor(BuildContext context, {bool compact = false}) {
    final scaled = MediaQuery.textScalerOf(context).scale(16) - 16;
    return (compact ? 255.0 : 370.0) + scaled.clamp(0, 32) * 4;
  }

  Widget _actionButton() => SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: actionKey,
      onPressed: canPlay && !busy ? onPlay : null,
      child: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(actionLabel ?? (ultimate ? 'Usar Ultimate' : 'Usar carta')),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final element = card.damage?['element'] as String? ?? 'neutral';
    final color = ultimate
        ? GameColors.ultimate
        : element == 'neutral'
        ? GameColors.forClass(card.classId)
        : GameColors.forElement(element);
    final actionable = onPlay != null;
    final imageUrl = card.imageUrl;
    return Semantics(
      button: actionable,
      enabled: !actionable || (canPlay && !busy),
      label:
          '${card.name}, custo ${card.cost} de energia${reason == null ? '' : ', $reason'}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: actionable && !canPlay ? 0.64 : 1,
        child: SizedBox(
          height: heightFor(context, compact: compact),
          child: GamePanel(
            accent: color,
            padding: const EdgeInsets.all(11),
            onTap: actionable && canPlay && !busy ? onPlay : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 35,
                      width: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GameColors.energy.withValues(alpha: 0.18),
                        border: Border.all(color: GameColors.energy),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${card.cost} energia',
                        style: const TextStyle(
                          color: GameColors.energy,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        ultimate ? 'ULTIMATE' : card.typeName.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Icon(_typeIcon(card.type), color: color, size: 21),
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 7),
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (reason != null)
                    Tooltip(
                      message: reason!,
                      child: Text(
                        reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GameColors.warning,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  _actionButton(),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.27),
                            GameColors.backgroundRaised,
                          ],
                        ),
                        border: Border.all(
                          color: color.withValues(alpha: 0.32),
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: imageUrl == null
                          ? Center(
                              child: SigilMark(
                                size: compact ? 48 : 92,
                                color: color,
                              ),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: SigilMark(
                                  size: compact ? 48 : 92,
                                  color: color,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!compact)
                  Text(
                    card.name,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: GameColors.text,
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (!compact) const SizedBox(height: 4),
                if (!compact)
                  Text(
                    card.description,
                    maxLines: compact ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      GameBadge(
                        label: GameVisual.className(card.classId),
                        icon: GameVisual.classIcon(card.classId),
                        color: GameColors.forClass(card.classId),
                      ),
                      if (card.damage != null)
                        GameBadge(
                          label: GameVisual.elementName(element),
                          icon: GameVisual.elementIcon(element),
                          color: GameColors.forElement(element),
                        ),
                    ],
                  ),
                ],
                if (!compact && card.tags.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    card.tags.take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (actionable && !compact) ...[
                  const SizedBox(height: 8),
                  if (reason != null)
                    Tooltip(
                      message: reason!,
                      child: Text(
                        reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GameColors.warning,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  _actionButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
    'attack' => Icons.gps_fixed,
    'defense' => Icons.shield_outlined,
    'skill' => Icons.auto_awesome,
    _ => Icons.stars_outlined,
  };
}
