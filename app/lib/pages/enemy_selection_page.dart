import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/battle_state.dart';
import '../services/api_service.dart';
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
      if (mounted) setState(() => _error = error.toString());
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
      if (mounted) setState(() => _error = error.toString());
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
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    widget.character.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Atualizar'),
                    ),
                  ],
                  if (_latest != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _open(),
                      child: Text(
                        _latest!.status == 'active'
                            ? 'Continuar batalha'
                            : 'Ver última batalha',
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
                        'Esta primeira batalha está disponível para Guerreiro.',
                      ),
                    ),
                  if (_selection?.enemies.isEmpty ?? false)
                    const Text(
                      'Nenhum inimigo cadastrado. Execute o seed de inimigos no servidor.',
                    ),
                  for (final enemy in _selection?.enemies ?? <EnemyOption>[])
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enemy.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text('Vida: ${enemy.hp}'),
                            Text(enemy.description),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed:
                                  _busy ||
                                      !_selection!.supportedClassIds.contains(
                                        widget.character.classId,
                                      ) ||
                                      _latest?.status == 'active'
                                  ? null
                                  : () => _open(enemy: enemy),
                              child: const Text('Começar luta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
  );
}
