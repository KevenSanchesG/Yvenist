import 'package:flutter/material.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';
import 'package:yvenist/features/client/shared/listing_tile.dart';

/// Resultados de uma consulta ao catálogo, com todos os estados: carregando,
/// erro (com nova tentativa), vazio e lista que busca mais ao rolar.
class ListingResultsView extends StatelessWidget {
  const ListingResultsView({
    super.key,
    required this.controller,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final ListingSearchController controller;
  final String emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    return switch (controller.status) {
      null || LoadInProgress() => const LoadingView(label: 'Buscando anúncios'),
      LoadFailure(:final failure) => ErrorStateView(
        message: failure.message,
        onRetry: controller.refresh,
      ),
      LoadSuccess() when controller.items.isEmpty => EmptyStateView(
        icon: Icons.search_off,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      ),
      LoadSuccess() => _ResultsList(controller: controller),
    };
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.controller});

  final ListingSearchController controller;

  bool _onScroll(ScrollNotification notification) {
    // Perto do fim da lista, pede a próxima página.
    final metrics = notification.metrics;
    if (metrics.axis == Axis.vertical && metrics.extentAfter < 400) {
      controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    final hasFooter = controller.hasMore || controller.loadMoreFailure != null;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView.separated(
          padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
          itemCount: items.length + (hasFooter ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == items.length) return _Footer(controller: controller);
            return ListingTile(
              key: ValueKey(items[index].id),
              listing: items[index],
            );
          },
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final ListingSearchController controller;

  @override
  Widget build(BuildContext context) {
    final failure = controller.loadMoreFailure;
    if (failure != null) {
      return Column(
        children: [
          Text(
            failure.message,
            style: context.text.caption.copyWith(color: context.colors.danger),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: controller.loadMore,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: LoadingView(label: 'Carregando mais anúncios'),
    );
  }
}
