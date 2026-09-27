import 'package:flutter/material.dart';
import '../models/battle_state.dart';
import '../services/api_service.dart';
import '../widgets/logout_button.dart';
import '../widgets/battle_result_panel.dart';

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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final battle = await widget.apiService.getBattle(widget.battleId);
      if (!mounted) return;
      setState(() {
        _battle = battle;
        _needsSync = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
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
      if (mounted) setState(() => _battle = battle);
    } catch (error) {
      // Never replay an uncertain command: fetch the authoritative state first.
      try {
        final latest = await widget.apiService.getBattle(widget.battleId);
        if (mounted) setState(() => _battle = latest);
      } catch (_) {
        if (mounted) setState(() => _needsSync = true);
      }
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _participant(BattleParticipant actor, String key) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(actor.name, style: Theme.of(context).textTheme.titleLarge),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              'HP: ${actor.hp} / ${actor.maxHp}',
              key: ValueKey('$key-${actor.hp}'),
            ),
          ),
          LinearProgressIndicator(value: actor.hp / actor.maxHp),
          if (key == 'player')
            Text(
              'Energia: ${actor.energy} / ${actor.maxEnergy}',
              key: const ValueKey('player-energy'),
            ),
          if (actor.guard > 0) Text('Guarda: ${(actor.guard * 100).round()}%'),
        ],
      ),
    ),
  );

  Widget _result(BattleState battle) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        key: const ValueKey('battle-result-view'),
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
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
          ExpansionTile(
            title: const Text('Ver log da batalha'),
            children: [
              for (final event in battle.recentEvents.reversed.take(20))
                ListTile(title: Text(event.describe(battle.cards))),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _card(String cardId, int index, {bool ultimate = false}) {
    final state = _battle!;
    final card = state.cards[cardId]!;
    final action = state.actions[cardId]!;
    return Card(
      key: ValueKey(ultimate ? 'battle-ultimate' : 'hand-$index'),
      color: ultimate ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.name, style: Theme.of(context).textTheme.titleMedium),
            Text('${card.cost} de energia'),
            Text(card.description),
            if (ultimate)
              Text(
                'Carga: ${state.ultimateCharge} / ${state.ultimateMaxCharge}',
              ),
            if (action.reason != null) Text(action.reason!),
            const SizedBox(height: 8),
            FilledButton(
              key: ValueKey(ultimate ? 'use-ultimate' : 'play-$index'),
              onPressed: _busy || _needsSync || !action.canPlay
                  ? null
                  : () => _command(
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
              child: Text(ultimate ? 'Usar Ultimate' : 'Usar carta'),
            ),
          ],
        ),
      ),
    );
  }

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
      body: battle == null
          ? Center(
              child: _busy
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Batalha indisponível.'),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
            )
          : battle.status != 'active'
          ? _result(battle)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_needsSync)
                      FilledButton(
                        onPressed: _busy ? null : _refresh,
                        child: const Text('Sincronizar batalha'),
                      ),
                    Text(
                      'Turno ${battle.turn}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _participant(battle.enemy, 'enemy'),
                    _participant(battle.player, 'player'),
                    const SizedBox(height: 12),
                    Text(
                      'Mão (3 cartas)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (var index = 0; index < battle.hand.length; index++)
                      _card(battle.hand[index], index),
                    const SizedBox(height: 12),
                    _card(battle.ultimateId, 0, ultimate: true),
                    ExpansionTile(
                      title: const Text('Fila do ciclo (6 cartas)'),
                      children: [
                        for (
                          var index = 0;
                          index < battle.queue.length;
                          index++
                        )
                          ListTile(
                            title: Text(
                              '${index + 1}. ${battle.cards[battle.queue[index]]!.name}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Últimos eventos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final event in battle.recentEvents.reversed.take(20))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(event.describe(battle.cards)),
                      ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: battle == null || battle.status != 'active'
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: FilledButton(
                key: const ValueKey('end-turn'),
                onPressed: _busy || _needsSync || !battle.canEndTurn
                    ? null
                    : () => _command(
                        (latest) => widget.apiService.endTurn(
                          battleId: latest.id,
                          expectedVersion: latest.version,
                        ),
                      ),
                child: const Text('Finalizar Turno'),
              ),
            ),
    );
  }
}
