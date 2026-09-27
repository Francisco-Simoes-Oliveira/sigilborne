import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/api_service.dart';

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
        error = e.toString();
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
      setState(() => error = e.toString());
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextField(
                      enabled: !creating,
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do personagem',
                      ),
                    ),
                    const SizedBox(height: 24),
                    RadioGroup<String>(
                      groupValue: selectedClass,
                      onChanged: (value) {
                        if (!creating) setState(() => selectedClass = value);
                      },
                      child: Column(
                        children: [
                          for (final gameClass in classes)
                            Card(
                              child: RadioListTile<String>(
                                value: gameClass['id'] as String,
                                enabled: !creating,
                                title: Text(gameClass['name'] as String),
                                subtitle: Text(
                                  gameClass['description'] as String,
                                ),
                              ),
                            ),
                        ],
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
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: creating || classes.isEmpty
                          ? null
                          : createCharacter,
                      child: creating
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Criar personagem'),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
