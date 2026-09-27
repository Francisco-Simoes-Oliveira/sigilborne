import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CreateCharacterPage extends StatefulWidget {
  const CreateCharacterPage({super.key});

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
    try {
      final result = await ApiService().getClasses();

      setState(() {
        classes = result;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> createCharacter() async {
    if (selectedClass == null) {
      setState(() {
        error = 'Selecione uma classe.';
      });

      return;
    }

    setState(() {
      creating = true;
      error = null;
    });

    try {
      final character = await ApiService().createCharacter(
        name: nameController.text.trim(),
        classId: selectedClass!,
      );

      if (!mounted) return;

      Navigator.pop(context, character);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar personagem')),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do personagem',
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: ListView.builder(
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final gameClass = classes[index];

                  final id = gameClass['id'];

                  return Card(
                    child: RadioListTile<String>(
                      value: id,
                      groupValue: selectedClass,
                      onChanged: (value) {
                        setState(() {
                          selectedClass = value;
                        });
                      },

                      title: Text(gameClass['name']),

                      subtitle: Text(gameClass['description']),
                    ),
                  );
                },
              ),
            ),

            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: creating ? null : createCharacter,

                child: creating
                    ? const CircularProgressIndicator()
                    : const Text('Criar personagem'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
