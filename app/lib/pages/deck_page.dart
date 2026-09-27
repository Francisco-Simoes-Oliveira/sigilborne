import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/character_deck.dart';
import '../services/api_service.dart';
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
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _card(GameCard card, {required Key key, bool ultimate = false}) =>
      Card(
        key: key,
        color: ultimate
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    avatar: const Icon(Icons.bolt, size: 18),
                    label: Text('${card.cost} energia'),
                  ),
                  Chip(label: Text(card.typeName)),
                  if (card.elementName != null)
                    Chip(label: Text(card.elementName!)),
                  if (card.damageNatureName != null)
                    Chip(label: Text(card.damageNatureName!)),
                ],
              ),
              const SizedBox(height: 8),
              Text(card.description),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.style_outlined, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _loadDeck,
              child: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }
    final deck = _deck!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(deck.name, style: Theme.of(context).textTheme.headlineSmall),
        Text('${widget.character.name} • ${widget.character.className}'),
        const SizedBox(height: 8),
        const Text('10 cartas no total: 9 normais + 1 Ultimate'),
        const SizedBox(height: 24),
        Text('Ultimate', style: Theme.of(context).textTheme.titleLarge),
        const Text('Separada do ciclo da mão de 3 cartas.'),
        const SizedBox(height: 8),
        _card(
          deck.ultimate,
          key: const ValueKey('deck-ultimate'),
          ultimate: true,
        ),
        const SizedBox(height: 24),
        Text(
          'Cartas normais (9)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < deck.cards.length; index++)
          _card(deck.cards[index], key: ValueKey('deck-card-$index')),
      ],
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
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(onRefresh: _loadDeck, child: _body()),
        ),
      ),
    ),
  );
}
