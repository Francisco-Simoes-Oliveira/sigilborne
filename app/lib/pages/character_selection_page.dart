import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/logout_button.dart';

class CharacterSelectionPage extends StatefulWidget {
  const CharacterSelectionPage({
    super.key,
    required this.apiService,
    required this.onSignOut,
  });

  final ApiService apiService;
  final Future<void> Function() onSignOut;

  @override
  State<CharacterSelectionPage> createState() => _CharacterSelectionPageState();
}

class _CharacterSelectionPageState extends State<CharacterSelectionPage> {
  List<Character> _characters = [];
  bool _loading = true;
  bool _openingPage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final characters = await widget.apiService.getCharacters();
      if (!mounted) return;
      setState(() => _characters = characters);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCharacter() async {
    if (_openingPage) return;
    setState(() => _openingPage = true);
    try {
      final character = await Navigator.pushNamed<Character>(
        context,
        '/create-character',
      );
      if (!mounted || character == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${character.name} foi criado. Escolha um personagem para entrar.',
          ),
        ),
      );
      await _loadCharacters();
    } finally {
      if (mounted) setState(() => _openingPage = false);
    }
  }

  Future<void> _selectCharacter(Character character) async {
    if (_openingPage) return;
    setState(() => _openingPage = true);
    try {
      await Navigator.pushNamed<void>(context, '/home', arguments: character);
      if (mounted) await _loadCharacters();
    } finally {
      if (mounted) setState(() => _openingPage = false);
    }
  }

  Widget _message({
    required String text,
    required IconData icon,
    Widget? action,
  }) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 42),
      GameEmptyState(
        title: _error == null
            ? 'Sua jornada começa aqui'
            : 'Não foi possível carregar',
        message: text,
        icon: icon,
      ),
      if (action != null) ...[
        const SizedBox(height: 20),
        Center(child: action),
      ],
    ],
  );

  Widget _body() {
    if (_loading) {
      return const GameLoadingView(message: 'Invocando seus personagens...');
    }
    if (_error != null) {
      return _message(
        text: _error!,
        icon: Icons.cloud_off,
        action: FilledButton(
          onPressed: _loadCharacters,
          child: const Text('Tentar novamente'),
        ),
      );
    }
    if (_characters.isEmpty) {
      return _message(
        text:
            'Você ainda não tem personagens. Crie seu primeiro personagem para começar a aventura.',
        icon: Icons.person_add_alt_1,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 590
            ? 2
            : 1;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const GameSectionHeading(
              title: 'Escolha seu herói',
              subtitle: 'Cada personagem guarda sua própria jornada.',
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _characters.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 290,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final character = _characters[index];
                final accent = GameColors.forClass(character.classId);
                return GamePanel(
                  key: ValueKey('character-${character.id}'),
                  accent: accent,
                  onTap: _openingPage
                      ? null
                      : () => _selectCharacter(character),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: accent.withValues(alpha: 0.18),
                            child: Icon(
                              GameVisual.classIcon(character.classId),
                              color: accent,
                            ),
                          ),
                          const Spacer(),
                          GameBadge(
                            label: 'Nível ${character.level}',
                            icon: Icons.star_outline,
                            color: GameColors.gold,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        character.className,
                        style: TextStyle(color: accent),
                      ),
                      const SizedBox(height: 14),
                      GameProgressBar(
                        label: 'XP',
                        value: character.xp,
                        max: character.xpToNextLevel,
                        color: GameColors.gold,
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          GameBadge(
                            label: '${character.attribute('hp')} HP',
                            icon: Icons.favorite_outline,
                            color: GameColors.health,
                          ),
                          GameBadge(
                            label: '${character.gold} Gold',
                            icon: Icons.monetization_on_outlined,
                            color: GameColors.gold,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seus personagens'),
      actions: [
        IconButton(
          tooltip: 'Atualizar personagens',
          onPressed: _loading || _openingPage ? null : _loadCharacters,
          icon: const Icon(Icons.refresh),
        ),
        LogoutButton(onSignOut: widget.onSignOut),
      ],
    ),
    body: GameBackdrop(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: GameLayout.maxContent),
          child: RefreshIndicator(onRefresh: _loadCharacters, child: _body()),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: FilledButton.icon(
        onPressed: _openingPage || _loading ? null : _createCharacter,
        icon: const Icon(Icons.add),
        label: const Text('Criar personagem'),
      ),
    ),
  );
}
