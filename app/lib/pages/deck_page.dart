import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/character_deck.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card_view.dart';
import '../widgets/game_ui.dart';
import '../widgets/logout_button.dart';

class DeckPage extends StatefulWidget {
  const DeckPage({
    super.key,
    required this.character,
    required this.apiService,
    required this.onSignOut,
  });

  final Character character;
  final ApiService apiService;
  final Future<void> Function() onSignOut;

  @override
  State<DeckPage> createState() => _DeckPageState();
}

class _DeckPageState extends State<DeckPage> {
  CharacterDeck? _deck;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deck = await widget.apiService.getCharacterDeck(
        widget.character.id,
      );
      if (!mounted) return;
      if (deck.ownerId != widget.character.ownerId ||
          [
            ...deck.cards,
            deck.ultimate,
          ].any((card) => card.classId != widget.character.classId)) {
        throw const ApiException(
          'O deck retornado não corresponde ao personagem selecionado.',
        );
      }
      setState(() => _deck = deck);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _card(GameCard card, {required Key key, bool ultimate = false}) =>
      GameCardView(key: key, card: card, ultimate: ultimate);

  Widget _body() {
    if (_loading) {
      return const GameLoadingView(message: 'Abrindo seu grimório...');
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [GameErrorView(message: _error!, onRetry: _loadDeck)],
      );
    }
    final deck = _deck!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 950
            ? 3
            : constraints.maxWidth >= 610
            ? 2
            : 1;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            GamePanel(
              child: Row(
                children: [
                  const SigilMark(size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${widget.character.name} • ${widget.character.className}',
                        ),
                        const Text(
                          '10 cartas no total: 9 normais + 1 Ultimate',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const GameSectionHeading(
              title: 'Ultimate',
              subtitle: 'Separada do ciclo da mão de 3 cartas.',
              icon: Icons.stars_outlined,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: columns == 1 ? double.infinity : 310,
                child: _card(
                  deck.ultimate,
                  key: const ValueKey('deck-ultimate'),
                  ultimate: true,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const GameSectionHeading(
              title: 'Cartas normais (9)',
              subtitle: 'Seu arsenal para cada turno.',
              icon: Icons.style_outlined,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < deck.cards.length; index++)
                  SizedBox(
                    width:
                        (constraints.maxWidth - 12 * (columns - 1)) / columns,
                    child: _card(
                      deck.cards[index],
                      key: ValueKey('deck-card-$index'),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Deck do personagem'),
      actions: [
        IconButton(
          tooltip: 'Atualizar deck',
          onPressed: _loading ? null : _loadDeck,
          icon: const Icon(Icons.refresh),
        ),
        LogoutButton(onSignOut: widget.onSignOut),
      ],
    ),
    body: GameBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: GameLayout.maxContent),
            child: RefreshIndicator(onRefresh: _loadDeck, child: _body()),
          ),
        ),
      ),
    ),
  );
}
