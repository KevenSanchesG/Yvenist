import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/pages/my_parties_page.dart';
import 'package:yvenist/features/party_maker/presentation/pages/party_builder_page.dart';

/// Raiz da aba Party Maker. Decide o que mostrar:
///
/// 1. há uma festa aberta -> a montagem dessa festa;
/// 2. senão -> "Minhas Festas", que lista as festas ou, sem nenhuma, convida
///    a criar a primeira.
class PartyMakerEntryPage extends StatelessWidget {
  const PartyMakerEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();

    if (!controller.hasLoaded) {
      return const Scaffold(body: LoadingView(label: 'Carregando suas festas'));
    }
    final loadError = controller.loadError;
    if (loadError != null && controller.parties.isEmpty) {
      return Scaffold(
        body: ErrorStateView(message: loadError, onRetry: controller.load),
      );
    }
    if (controller.activeParty != null) return const PartyBuilderPage();
    return const MyPartiesPage();
  }
}
