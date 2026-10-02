import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/shared/listing_results_view.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';

/// Busca por texto no catálogo.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ListingSearchController(context.read<CatalogRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  /// Espera a pessoa parar de digitar antes de buscar: evita uma requisição
  /// por tecla.
  static const Duration _debounce = Duration(milliseconds: 400);
  static const int _minLength = 2;

  final _text = TextEditingController();
  Timer? _timer;
  late final Future<List<CatalogCategory>> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = context.read<CatalogRepository>().categories();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // mostra/esconde o botão de limpar
    _timer?.cancel();
    if (value.trim().length < _minLength) return;
    _timer = Timer(_debounce, () => _search(value));
  }

  void _search(String value) {
    _timer?.cancel();
    final term = value.trim();
    if (term.isEmpty) return;
    context.read<ListingSearchController>().search(ListingQuery(text: term));
  }

  void _useSuggestion(String term) {
    _text.text = term;
    FocusScope.of(context).unfocus();
    setState(() {});
    _search(term);
  }

  void _clear() {
    _timer?.cancel();
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ListingSearchController>();
    final term = _text.text.trim();
    final showResults = controller.hasSearched && term.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _search,
          style: AppTypography.body.copyWith(fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Buscar salões, brinquedos, buffet...',
            hintStyle: TextStyle(color: AppColors.searchPlaceholder),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_text.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Limpar busca',
              onPressed: _clear,
            ),
        ],
      ),
      body: showResults
          ? ListingResultsView(
              controller: controller,
              emptyTitle: 'Nada encontrado para "$term"',
              emptyMessage: 'Confira a grafia ou tente um termo mais geral.',
            )
          : _Suggestions(suggestions: _suggestions, onSelected: _useSuggestion),
    );
  }
}

/// Sugestões de busca: as categorias do catálogo.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onSelected});

  final Future<List<CatalogCategory>> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CatalogCategory>>(
      future: suggestions,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <CatalogCategory>[];
        // Sem sugestões (ainda carregando ou sem rede) a tela fica só com o
        // campo de busca, que funciona do mesmo jeito.
        if (categories.isEmpty) return const SizedBox.shrink();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sugestões', style: AppTypography.sectionTitle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    ActionChip(
                      label: Text(category.name),
                      onPressed: () => onSelected(category.name),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
