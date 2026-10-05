import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/battle_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/logout_button.dart';

class EnemySelectionPage extends StatefulWidget {
  const EnemySelectionPage({
    super.key,
    required this.character,
    required this.apiService,
    required this.onSignOut,
  });
  final Character character;
  final ApiService apiService;
  final Future<void> Function() onSignOut;
  @override
  State<EnemySelectionPage> createState() => _EnemySelectionPageState();
}

class _EnemySelectionPageState extends State<EnemySelectionPage> {
  EnemySelection? _selection;
  BattleState? _latest;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selection = await widget.apiService.getEnemies();
      final latest = await widget.apiService.getLatestBattle(
        widget.character.id,
      );
      if (!mounted) return;
      setState(() {
        _selection = selection;
        _latest = latest;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open({EnemyOption? enemy}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final battle = enemy == null
          ? _latest!
          : await widget.apiService.startBattle(
              characterId: widget.character.id,
              enemyId: enemy.id,
            );
      if (!mounted) return;
      await Navigator.pushNamed<void>(context, '/battle', arguments: battle);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Selecionar inimigo'),
      actions: [LogoutButton(onSignOut: widget.onSignOut)],
    ),
    body: GameBackdrop(
      child: _loading
          ? const GameLoadingView(message: 'Procurando adversários...')
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: GameLayout.maxContent,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GameSectionHeading(
                      title: 'Escolha seu desafio',
                      subtitle: 'Herói: ${widget.character.name}',
                      icon: Icons.sports_martial_arts,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      GamePanel(
                        accent: GameColors.danger,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: GameColors.danger),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Atualizar'),
                      ),
                    ],
                    if (_latest != null) ...[
                      const SizedBox(height: 16),
                      GamePanel(
                        accent: _latest!.status == 'active'
                            ? GameColors.gold
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GameSectionHeading(
                              title: 'Sua última batalha',
                              icon: Icons.history,
                            ),
                            if (_latest!.status == 'active') ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Existe uma batalha em andamento.',
                                style: TextStyle(
                                  color: GameColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _open(),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  _latest!.status == 'active'
                                      ? 'Continuar batalha'
                                      : 'Ver última batalha',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_selection != null &&
                        !_selection!.supportedClassIds.contains(
                          widget.character.classId,
                        ))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Esta classe ainda não está disponível para batalha.',
                        ),
                      ),
                    if (_selection?.enemies.isEmpty ?? false)
                      const GameEmptyState(
                        title: 'Arena vazia',
                        message:
                            'Nenhum inimigo cadastrado. Execute o seed de inimigos no servidor.',
                        icon: Icons.hourglass_empty,
                      ),
                    const SizedBox(height: 20),
                    if (_selection?.enemies.isNotEmpty ?? false)
                      const GameSectionHeading(
                        title: 'Adversários',
                        subtitle:
                            'Veja o elemento e a recompensa antes de lutar.',
                        icon: Icons.gps_fixed,
                      ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760 ? 2 : 1;
                        final enemies = _selection?.enemies ?? <EnemyOption>[];
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: enemies.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 250,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                              ),
                          itemBuilder: (context, index) {
                            final enemy = enemies[index];
                            final color = GameColors.forElement(enemy.element);
                            return GamePanel(
                              accent: color,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        GameVisual.elementIcon(enemy.element),
                                        color: color,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          enemy.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    enemy.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: [
                                      GameBadge(
                                        label: 'Vida: ${enemy.hp}',
                                        icon: Icons.favorite_outline,
                                        color: GameColors.health,
                                      ),
                                      GameBadge(
                                        label:
                                            'Elemento: ${GameVisual.elementName(enemy.element)}',
                                        icon: GameVisual.elementIcon(
                                          enemy.element,
                                        ),
                                        color: color,
                                      ),
                                    ],
                                  ),
                                  if (enemy.xp != null &&
                                      enemy.gold != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Recompensa: ${enemy.xp} XP · ${enemy.gold} Gold',
                                      style: const TextStyle(
                                        color: GameColors.gold,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed:
                                          _busy ||
                                              !_selection!.supportedClassIds
                                                  .contains(
                                                    widget.character.classId,
                                                  ) ||
                                              _latest?.status == 'active'
                                          ? null
                                          : () => _open(enemy: enemy),
                                      child: const Text('Começar luta'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (_busy) const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
    ),
  );
}
