import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'game_ui.dart';

String authErrorMessage(FirebaseAuthException error) => switch (error.code) {
  'invalid-email' => 'Informe um e-mail válido.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'E-mail ou senha incorretos.',
  'email-already-in-use' => 'Este e-mail já está cadastrado.',
  'weak-password' => 'Escolha uma senha mais forte.',
  'too-many-requests' =>
    'Muitas tentativas. Aguarde um pouco e tente novamente.',
  'network-request-failed' =>
    'Sem conexão. Verifique sua internet e tente novamente.',
  _ => error.message ?? 'Não foi possível continuar. Tente novamente.',
};

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => GameBackdrop(
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const SigilMark(size: 94),
                const SizedBox(height: 18),
                Text(
                  'SIGILBORNE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    letterSpacing: 4,
                    color: GameColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A aventura começa com um sigilo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                GamePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(subtitle),
                      const SizedBox(height: 22),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
