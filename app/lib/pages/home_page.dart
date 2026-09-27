import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
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
      if (mounted) setState(() => _error = error.toString());
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
    body: _refreshing
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Não foi possível atualizar o personagem. $_error'),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Bem-vindo, ${_character.name}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('${_character.className} • Nível ${_character.level}'),
                  const SizedBox(height: 8),
                  Text('XP: ${_character.xp} / ${_character.xpToNextLevel}'),
                  Text('Gold: ${_character.gold}'),
                  Text(
                    'Pontos de atributo disponíveis: ${_character.attributePoints}',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Atributos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
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
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _battle,
                    icon: const Icon(Icons.sports_martial_arts),
                    label: const Text('Batalhar'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/deck',
                      arguments: _character,
                    ),
                    icon: const Icon(Icons.style),
                    label: const Text('Ver deck'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.switch_account),
                    label: const Text('Trocar personagem'),
                  ),
                ],
              ),
            ),
          ),
  );

  Widget _attribute(String label, String key, IconData icon) => Chip(
    avatar: Icon(icon, size: 18),
    label: Text('$label: ${_character.attribute(key)}'),
  );
}
