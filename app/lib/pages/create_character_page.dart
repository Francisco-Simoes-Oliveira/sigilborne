import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_ui.dart';

class CreateCharacterPage extends StatefulWidget {
  const CreateCharacterPage({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<CreateCharacterPage> createState() => _CreateCharacterPageState();
}

class _CreateCharacterPageState extends State<CreateCharacterPage> {
  final nameController = TextEditingController();
  List<dynamic> classes = [];
  String? selectedClass;
  bool loading = true;
  bool creating = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadClasses();
  }

  Future<void> loadClasses() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.apiService.getClasses();
      if (!mounted) return;
      setState(() {
        classes = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = friendlyError(e);
        loading = false;
      });
    }
  }

  Future<void> createCharacter() async {
    if (creating) return;
    if (nameController.text.trim().length < 3) {
      setState(() => error = 'O nome precisa ter pelo menos 3 caracteres.');
      return;
    }
    if (selectedClass == null) {
      setState(() => error = 'Selecione uma classe.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      creating = true;
      error = null;
    });
    try {
      final character = await widget.apiService.createCharacter(
        name: nameController.text.trim(),
        classId: selectedClass!,
      );
      if (!mounted) return;
      Navigator.pop<Character>(context, character);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Character>(
    canPop: !creating,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Criar personagem'),
        automaticallyImplyLeading: !creating,
      ),
      body: GameBackdrop(
        child: loading
            ? const GameLoadingView(message: 'Consultando classes...')
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: GameLayout.maxContent,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const GameSectionHeading(
                        title: 'Forje seu destino',
                        subtitle:
                            'Dê um nome ao seu herói e escolha uma classe.',
                        icon: Icons.auto_awesome,
                      ),
                      const SizedBox(height: 18),
                      GamePanel(
                        child: TextField(
                          enabled: !creating,
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nome do personagem',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(color: GameColors.danger),
                          ),
                        ),
                      const SizedBox(height: 22),
                      const GameSectionHeading(
                        title: 'Classes',
                        subtitle: 'Selecione o estilo que combina com você.',
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<String>(
                        groupValue: selectedClass,
                        onChanged: (value) {
                          if (!creating) setState(() => selectedClass = value);
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 700 ? 2 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: classes.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 250,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                              itemBuilder: (context, index) {
                                final gameClass = classes[index] as Map;
                                final id = gameClass['id'] as String;
                                final color = GameColors.forClass(id);
                                final selected = selectedClass == id;
                                final focus = switch (id) {
                                  'warrior' =>
                                    'Defesa • Guarda • Contra-ataque',
                                  'mage' => 'Magia • Elementos • Reações',
                                  'rogue' => 'Velocidade • Preparo • Críticos',
                                  'hunter' => 'Precisão • Marcas • Pet',
                                  _ => 'Escolha seu estilo de combate',
                                };
                                final attributes =
                                    gameClass['baseAttributes'] is Map
                                    ? gameClass['baseAttributes'] as Map
                                    : const {};
                                return AnimatedScale(
                                  scale: selected ? 1 : 0.985,
                                  duration: const Duration(milliseconds: 180),
                                  child: GamePanel(
                                    accent: selected ? color : null,
                                    padding: const EdgeInsets.all(10),
                                    onTap: creating
                                        ? null
                                        : () => setState(
                                            () => selectedClass = id,
                                          ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RadioListTile<String>(
                                          value: id,
                                          enabled: !creating,
                                          contentPadding: EdgeInsets.zero,
                                          secondary: Icon(
                                            GameVisual.classIcon(id),
                                            color: color,
                                          ),
                                          title: Text(
                                            gameClass['name'] as String,
                                          ),
                                          subtitle: const Text(
                                            'Selecionar classe',
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                          ),
                                          child: Text(
                                            gameClass['description'] as String,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          focus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (attributes.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 5,
                                            children: [
                                              _classStat(
                                                'HP',
                                                attributes['hp'],
                                                Icons.favorite_outline,
                                                GameColors.health,
                                              ),
                                              _classStat(
                                                id == 'mage'
                                                    ? 'Magia'
                                                    : 'Força',
                                                attributes[id == 'mage'
                                                    ? 'magicPower'
                                                    : 'strength'],
                                                Icons.auto_awesome,
                                                color,
                                              ),
                                              _classStat(
                                                id == 'rogue'
                                                    ? 'Velocidade'
                                                    : 'Defesa',
                                                attributes[id == 'rogue'
                                                    ? 'speed'
                                                    : 'defense'],
                                                Icons.shield_outlined,
                                                color,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (classes.isEmpty) ...[
                        const Text(
                          'Nenhuma classe disponível. Tente carregar novamente.',
                        ),
                        TextButton(
                          onPressed: loadClasses,
                          child: const Text('Recarregar classes'),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading || creating || classes.isEmpty
                    ? null
                    : createCharacter,
                child: creating
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar personagem'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _classStat(String label, Object? value, IconData icon, Color color) =>
      GameBadge(label: '$label: ${value ?? '—'}', icon: icon, color: color);
}
