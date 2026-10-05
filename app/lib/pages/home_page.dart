import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/logout_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.character,
    required this.onSignOut,
    required this.apiService,
  });

  final Character character;
  final Future<void> Function() onSignOut;
  final ApiService apiService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Character _character = widget.character;
  bool _refreshing = false;
  String? _error;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final updated = await widget.apiService.getCharacter(widget.character.id);
      if (!mounted) return;
      if (updated.ownerId != widget.character.ownerId) {
        throw const ApiException('Personagem indisponível nesta conta.');
      }
      setState(() => _character = updated);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _battle() async {
    await Navigator.pushNamed<void>(context, '/enemies', arguments: _character);
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sigilborne'),
      actions: [
        IconButton(
          tooltip: 'Atualizar personagem',
          onPressed: _refreshing ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        LogoutButton(onSignOut: widget.onSignOut),
      ],
    ),
    body: GameBackdrop(
      child: _refreshing
          ? const GameLoadingView(message: 'Atualizando personagem...')
          : _error != null
          ? GameErrorView(
              message: 'Não foi possível atualizar o personagem. $_error',
              onRetry: _refresh,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: GameLayout.maxContent,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        final hero = GamePanel(
                          accent: GameColors.forClass(_character.classId),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    GameVisual.classIcon(_character.classId),
                                    size: 34,
                                    color: GameColors.forClass(
                                      _character.classId,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bem-vindo, ${_character.name}!',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                        Text(
                                          '${_character.className} • Nível ${_character.level}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              GameProgressBar(
                                label: 'XP',
                                value: _character.xp,
                                max: _character.xpToNextLevel,
                                color: GameColors.gold,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  GameBadge(
                                    label: 'Gold: ${_character.gold}',
                                    icon: Icons.monetization_on_outlined,
                                    color: GameColors.gold,
                                  ),
                                  GameBadge(
                                    label:
                                        'Pontos de atributo disponíveis: ${_character.attributePoints}',
                                    icon: Icons.add_circle_outline,
                                    color: GameColors.ultimate,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                        final actions = GamePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const GameSectionHeading(
                                title: 'Próximo passo',
                                subtitle:
                                    'Escolha como continuar sua aventura.',
                                icon: Icons.explore_outlined,
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _battle,
                                icon: const Icon(Icons.sports_martial_arts),
                                label: const Text('Batalhar'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/deck',
                                  arguments: _character,
                                ),
                                icon: const Icon(Icons.style_outlined),
                                label: const Text('Ver deck'),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.switch_account),
                                label: const Text('Trocar personagem'),
                              ),
                            ],
                          ),
                        );
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: hero),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: actions),
                                ],
                              )
                            : Column(
                                children: [
                                  hero,
                                  const SizedBox(height: 16),
                                  actions,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 22),
                    const GameSectionHeading(
                      title: 'Atributos',
                      subtitle: 'As forças que definem seu personagem.',
                      icon: Icons.auto_graph,
                    ),
                    const SizedBox(height: 12),
                    GamePanel(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _attribute('Vida', 'hp', Icons.favorite),
                          _attribute('Energia', 'maxEnergy', Icons.bolt),
                          _attribute('Força', 'strength', Icons.fitness_center),
                          _attribute(
                            'Poder mágico',
                            'magicPower',
                            Icons.auto_awesome,
                          ),
                          _attribute('Defesa', 'defense', Icons.shield),
                          _attribute('Velocidade', 'speed', Icons.speed),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    ),
  );

  Widget _attribute(String label, String key, IconData icon) => Chip(
    avatar: Icon(icon, size: 18),
    label: Text('$label: ${_character.attribute(key)}'),
  );
}
