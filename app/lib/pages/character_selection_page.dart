import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
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
      setState(() => _error = error.toString());
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
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 48),
      Icon(icon, size: 56),
      const SizedBox(height: 20),
      Text(text, textAlign: TextAlign.center),
      if (action != null) ...[
        const SizedBox(height: 20),
        Center(child: action),
      ],
    ],
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _characters.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final character = _characters[index];
        return Card(
          child: ListTile(
            key: ValueKey('character-${character.id}'),
            enabled: !_openingPage,
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(character.name),
            subtitle: Text(
              '${character.className} • Nível ${character.level}\n'
              'Vida: ${character.attribute('hp')} • Energia: ${character.attribute('maxEnergy')}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectCharacter(character),
          ),
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
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(onRefresh: _loadCharacters, child: _body()),
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
