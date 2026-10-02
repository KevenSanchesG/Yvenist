import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/client/shared/catalog_presentation.dart';
import 'package:yvenist/features/client/shared/listing_results_view.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';

/// Aba Explorar: o catálogo inteiro, com filtros por categoria e por tipo de
/// evento, e escolha da ordenação.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  @override
  void initState() {
    super.initState();
    // Depois do primeiro frame: carregar notifica os ouvintes, o que não pode
    // acontecer durante a construção da tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ExploreController>().ensureStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExploreController>();
    final query = controller.query;
    final hasFilters =
        query.categorySlug != null || query.eventTypeSlug != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar ao início',
          onPressed: () => context.read<AppTabController>().goTo(AppTab.home),
        ),
        actions: [
          PopupMenuButton<ListingSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar: ${query.sort.label}',
            initialValue: query.sort,
            onSelected: controller.sortBy,
            itemBuilder: (_) => [
              for (final sort in ListingSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (controller.categories.isNotEmpty)
            _FilterRow(
              label: 'Filtrar por categoria',
              children: [
                for (final category in controller.categories)
                  FilterChip(
                    label: Text(category.name),
                    avatar: Icon(
                      iconForCategory(category.iconKey),
                      size: 18,
                      color: AppColors.primaryStrong,
                    ),
                    selected: query.categorySlug == category.slug,
                    onSelected: (_) => controller.toggleCategory(category.slug),
                  ),
              ],
            ),
          if (controller.eventTypes.isNotEmpty)
            _FilterRow(
              label: 'Filtrar por tipo de evento',
              children: [
                for (final eventType in controller.eventTypes)
                  FilterChip(
                    label: Text(eventType.name),
                    selected: query.eventTypeSlug == eventType.slug,
                    onSelected: (_) =>
                        controller.toggleEventType(eventType.slug),
                  ),
              ],
            ),
          Expanded(
            child: ListingResultsView(
              controller: controller,
              emptyTitle: 'Nenhum anúncio encontrado',
              emptyMessage: hasFilters
                  ? 'Tente outra combinação de filtros.'
                  : 'Ainda não há anúncios publicados.',
              emptyActionLabel: hasFilters ? 'Limpar filtros' : null,
              onEmptyAction: hasFilters ? controller.clearFilters : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) => Center(child: children[index]),
        ),
      ),
    );
  }
}
