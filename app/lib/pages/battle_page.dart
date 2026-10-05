import 'package:flutter/material.dart';
import '../models/battle_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/battle_arena.dart';
import '../widgets/battle_result_panel.dart';
import '../widgets/game_card_view.dart';
import '../widgets/game_ui.dart';
import '../widgets/logout_button.dart';

class BattlePage extends StatefulWidget {
  const BattlePage({
    super.key,
    required this.battleId,
    required this.apiService,
    required this.onSignOut,
  });
  final String battleId;
  final ApiService apiService;
  final Future<void> Function() onSignOut;
  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  BattleState? _battle;
  bool _busy = true;
  bool _needsSync = false;
  String? _error;
  BattleEvent? _playerFeedback;
  BattleEvent? _enemyFeedback;
  bool _playerCritical = false;
  bool _enemyCritical = false;
  String? _cue;
  int _cueSerial = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _adopt(BattleState next, {bool animate = false}) {
    final previous = _battle;
    final lastId = previous == null || previous.recentEvents.isEmpty
        ? -1
        : previous.recentEvents.last.id;
    final fresh = animate
        ? next.recentEvents.where((e) => e.id > lastId).toList()
        : <BattleEvent>[];
    BattleEvent? feedback(String target) {
      for (final event in fresh.reversed) {
        if (event.target == target &&
            ['DAMAGE', 'HEAL', 'STATUS_TICK'].contains(event.type)) {
          return event;
        }
      }
      return null;
    }

    final important = <String>{
      'CRITICAL',
      'ENEMY_ACTION',
      'TURN_STARTED',
      'CARD_DRAWN',
      'STATUS_APPLIED',
      'ENERGY_SPENT',
      'ENERGY_RECOVERED',
    };
    BattleEvent? cueEvent;
    for (final event in fresh.reversed) {
      if (important.contains(event.type)) {
        cueEvent = event;
        break;
      }
    }
    final cue = switch (cueEvent?.type) {
      'TURN_STARTED' =>
        cueEvent!.data['actor'] == 'enemy' ? 'TURNO DO INIMIGO' : 'SEU TURNO',
      'ENEMY_ACTION' => '${next.enemy.name} usou ${cueEvent!.data['name']}',
      'CRITICAL' => 'CRÍTICO!',
      'CARD_DRAWN' =>
        'Nova carta: ${next.cards[cueEvent!.data['cardId']]?.name ?? 'carta'}',
      'STATUS_APPLIED' =>
        '${GameVisual.statusName(cueEvent!.data['status'] as String? ?? '')} aplicado',
      'ENERGY_SPENT' => '−${cueEvent!.amount ?? 0} Energia',
      'ENERGY_RECOVERED' => '+${cueEvent!.amount ?? 0} Energia',
      _ => null,
    };
    _cueSerial++;

    setState(() {
      _battle = next;
      _playerFeedback = feedback('player');
      _enemyFeedback = feedback('enemy');
      _playerCritical = fresh.any(
        (e) => e.type == 'CRITICAL' && e.target == 'player',
      );
      _enemyCritical = fresh.any(
        (e) => e.type == 'CRITICAL' && e.target == 'enemy',
      );
      _cue = cue;
      _needsSync = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final battle = await widget.apiService.getBattle(widget.battleId);
      if (mounted) _adopt(battle);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _needsSync = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _command(
    Future<BattleState> Function(BattleState) command,
  ) async {
    if (_busy || _needsSync || _battle == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final battle = await command(_battle!);
      if (mounted) _adopt(battle, animate: true);
    } catch (error) {
      // Never replay an uncertain command; fetch the authoritative state.
      try {
        final latest = await widget.apiService.getBattle(widget.battleId);
        if (mounted) _adopt(latest, animate: true);
      } catch (_) {
        if (mounted) setState(() => _needsSync = true);
      }
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(String cardId, int index, {bool ultimate = false}) {
    final state = _battle!;
    final action = state.actions[cardId]!;
    return GameCardView(
      key: ValueKey(ultimate ? 'battle-ultimate' : 'hand-$index'),
      card: state.cards[cardId]!,
      compact: true,
      ultimate: ultimate,
      canPlay: action.canPlay && !_needsSync,
      busy: _busy,
      reason: action.reason,
      actionKey: ValueKey(ultimate ? 'use-ultimate' : 'play-$index'),
      onPlay: () => _command(
        (latest) => ultimate
            ? widget.apiService.playUltimate(
                battleId: latest.id,
                target: action.target,
                expectedVersion: latest.version,
              )
            : widget.apiService.playCard(
                battleId: latest.id,
                cardId: cardId,
                target: action.target,
                expectedVersion: latest.version,
              ),
      ),
    );
  }

  Widget _result(BattleState battle) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        key: const ValueKey('battle-result-view'),
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
          BattleResultPanel(
            battle: battle,
            onHome: _busy
                ? null
                : () => Navigator.of(context).popUntil(
                    (route) => route.settings.name == '/home' || route.isFirst,
                  ),
            onNewBattle: _busy
                ? null
                : () => Navigator.of(context).popUntil(
                    (route) =>
                        route.settings.name == '/enemies' || route.isFirst,
                  ),
          ),
          const SizedBox(height: 16),
          BattleEventFeed(battle: battle),
        ],
      ),
    ),
  );

  Widget _ultimate(BattleState battle) => AnimatedScale(
    scale: battle.ultimateCharge >= battle.ultimateMaxCharge ? 1.02 : 1,
    duration: const Duration(milliseconds: 250),
    child: Column(
      children: [
        GameProgressBar(
          label: 'Carga',
          value: battle.ultimateCharge,
          max: battle.ultimateMaxCharge,
          color: GameColors.ultimate,
        ),
        const SizedBox(height: 12),
        if (battle.ultimateCharge >= battle.ultimateMaxCharge)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: GameBadge(
              label: 'Ultimate carregada',
              icon: Icons.stars,
              color: GameColors.ultimate,
            ),
          ),
        _card(battle.ultimateId, 0, ultimate: true),
      ],
    ),
  );

  Widget _active(BattleState battle) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= GameLayout.wide;
      final medium = constraints.maxWidth >= GameLayout.compact;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: GameLayout.maxContent),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: GameColors.danger),
                  ),
                ),
              if (_needsSync)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sincronizar batalha'),
                  ),
                ),
              Row(
                children: [
                  const Icon(Icons.sports_martial_arts, color: GameColors.gold),
                  const SizedBox(width: 10),
                  Text(
                    'Turno ${battle.turn}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _cue == null
                          ? const SizedBox.shrink()
                          : TweenAnimationBuilder<double>(
                              key: ValueKey('cue-$_cueSerial'),
                              tween: Tween(begin: 1, end: 0),
                              duration: const Duration(milliseconds: 900),
                              builder: (context, progress, child) => Opacity(
                                opacity: progress,
                                child: IgnorePointer(
                                  ignoring: progress < 0.01,
                                  child: child,
                                ),
                              ),
                              child: Tooltip(
                                message: _cue!,
                                child: Text(
                                  _cue!,
                                  textAlign: TextAlign.end,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: GameColors.gold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (battle.catalogChanged)
                    const Tooltip(
                      message:
                          'O catálogo mudou; esta batalha usa as cartas com que começou.',
                      child: Icon(
                        Icons.info_outline,
                        color: GameColors.warning,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (medium)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: BattleParticipantPanel(
                        participant: battle.player,
                        isPlayer: true,
                        feedback: _playerFeedback,
                        critical: _playerCritical,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 44,
                      ),
                      child: Text(
                        'VS',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: GameColors.gold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: BattleParticipantPanel(
                        participant: battle.enemy,
                        isPlayer: false,
                        feedback: _enemyFeedback,
                        critical: _enemyCritical,
                      ),
                    ),
                  ],
                )
              else ...[
                BattleParticipantPanel(
                  participant: battle.enemy,
                  isPlayer: false,
                  feedback: _enemyFeedback,
                  critical: _enemyCritical,
                ),
                const SizedBox(height: 12),
                BattleParticipantPanel(
                  participant: battle.player,
                  isPlayer: true,
                  feedback: _playerFeedback,
                  critical: _playerCritical,
                ),
              ],
              const SizedBox(height: 10),
              const GameSectionHeading(
                title: 'Mão (3 cartas)',
                icon: Icons.style_outlined,
              ),
              const SizedBox(height: 8),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var index = 0;
                      index < battle.hand.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 230),
                          child: KeyedSubtree(
                            key: ValueKey('slot-$index-${battle.hand[index]}'),
                            child: _card(battle.hand[index], index),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 18),
                    SizedBox(width: 248, child: _ultimate(battle)),
                  ],
                )
              else ...[
                for (var index = 0; index < battle.hand.length; index++) ...[
                  Center(
                    child: SizedBox(
                      width: medium ? 410 : double.infinity,
                      child: _card(battle.hand[index], index),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: SizedBox(
                    width: medium ? 410 : double.infinity,
                    child: _ultimate(battle),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GamePanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Fila do ciclo (6 cartas)'),
                  subtitle: const Text(
                    'As próximas cartas que entrarão na mão.',
                  ),
                  children: [
                    for (var index = 0; index < battle.queue.length; index++)
                      ListTile(
                        dense: true,
                        leading: Text('${index + 1}'),
                        title: Text(battle.cards[battle.queue[index]]!.name),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BattleEventFeed(battle: battle),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batalha'),
        actions: [
          IconButton(
            tooltip: 'Atualizar batalha',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          LogoutButton(onSignOut: widget.onSignOut),
        ],
      ),
      body: GameBackdrop(
        child: battle == null
            ? _busy
                  ? const GameLoadingView(message: 'Entrando na arena...')
                  : GameErrorView(
                      message: _error ?? 'Batalha indisponível.',
                      onRetry: _refresh,
                    )
            : battle.status == 'active'
            ? _active(battle)
            : _result(battle),
      ),
      bottomNavigationBar: battle == null || battle.status != 'active'
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('end-turn'),
                      onPressed: _busy || _needsSync || !battle.canEndTurn
                          ? null
                          : () => _command(
                              (latest) => widget.apiService.endTurn(
                                battleId: latest.id,
                                expectedVersion: latest.version,
                              ),
                            ),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Finalizar Turno'),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
