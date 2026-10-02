import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/home/presentation/controllers/home_controller.dart';
import 'package:yvenist/features/client/home/presentation/widgets/home_header.dart';
import 'package:yvenist/features/client/home/presentation/widgets/horizontal_card_list.dart';
import 'package:yvenist/features/client/home/presentation/widgets/section_header.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';

/// Aba inicial: busca, atalhos por categoria e as faixas de anúncios.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          HomeController(context.read<CatalogRepository>())..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final state = controller.state;
    final feed = state.valueOrNull;

    return Scaffold(
      body: Column(
        children: [
          HomeHeader(
            categories: feed?.categories ?? const [],
            eventTypes: feed?.eventTypes ?? const [],
          ),
          Expanded(
            child: switch (state) {
              LoadInProgress() => const LoadingView(label: 'Carregando anúncios'),
              LoadFailure(:final failure) => ErrorStateView(
                  message: failure.message,
                  onRetry: controller.load,
                ),
              LoadSuccess(:final value) => RefreshIndicator(
                  onRefresh: controller.load,
                  child: value.sections.isEmpty
                      ? const _NoListings()
                      : _Sections(sections: value.sections),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({required this.sections});

  final List<HomeSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: section.title,
                subtitle: section.subtitle,
                onSeeAll: () {
                  context
                      .read<ExploreController>()
                      .showCategory(section.categorySlug);
                  context.read<AppTabController>().goTo(AppTab.explore);
                },
              ),
              const SizedBox(height: 8),
              HorizontalCardList(listings: section.listings),
            ],
          ),
        );
      },
    );
  }
}

class _NoListings extends StatelessWidget {
  const _NoListings();

  @override
  Widget build(BuildContext context) {
    // Dentro de um ListView para o "puxar para atualizar" continuar
    // funcionando mesmo sem conteúdo.
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: const EmptyStateView(
              icon: Icons.storefront_outlined,
              title: 'Ainda não há anúncios por aqui',
              message: 'Assim que os primeiros fornecedores forem aprovados, '
                  'eles aparecem nesta tela.',
            ),
          ),
        ],
      ),
    );
  }
}
