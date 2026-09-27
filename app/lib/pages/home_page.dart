import 'package:flutter/material.dart';

import '../models/character.dart';
import '../widgets/logout_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.character, required this.onSignOut});

  final Character character;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sigilborne'),
      actions: [LogoutButton(onSignOut: onSignOut)],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Bem-vindo, ${character.name}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${character.className} • Nível ${character.level}'),
            const SizedBox(height: 8),
            Text('Experiência: ${character.xp} XP'),
            Text(
              'Pontos de atributo disponíveis: ${character.attributePoints}',
            ),
            const SizedBox(height: 24),
            Text('Atributos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _attribute('Vida', 'hp', Icons.favorite),
                _attribute('Energia', 'maxEnergy', Icons.bolt),
                _attribute('Força', 'strength', Icons.fitness_center),
                _attribute('Poder mágico', 'magicPower', Icons.auto_awesome),
                _attribute('Defesa', 'defense', Icons.shield),
                _attribute('Velocidade', 'speed', Icons.speed),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/enemies',
                arguments: character,
              ),
              icon: const Icon(Icons.sports_martial_arts),
              label: const Text('Batalhar'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/deck', arguments: character),
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
    label: Text('$label: ${character.attribute(key)}'),
  );
}
