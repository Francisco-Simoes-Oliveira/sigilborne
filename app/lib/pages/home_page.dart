import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sigilborne'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Perfil não encontrado no Firestore.'),
            );
          }

          final data = snapshot.data!.data();

          final username = data?['username'] ?? 'Jogador';

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SIGILBORNE',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                Text(
                  'Bem-vindo, $username!',
                  style: const TextStyle(fontSize: 22),
                ),

                const SizedBox(height: 8),

                Text(user.email ?? ''),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    try {
                      final result = await ApiService().getMe();

                      if (!context.mounted) {
                        return;
                      }

                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Resposta da API'),
                            content: Text(result.toString()),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text('Testar API'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final character = await Navigator.pushNamed(
                      context,
                      '/create-character',
                    );

                    if (character != null) {
                      print('Personagem criado: $character');
                    }
                  },
                  child: const Text('Criar personagem'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
