import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/enums/party_status.dart';
import '../controllers/party_maker_controller.dart';
import '../../../client/home/presentation/pages/home_client_page.dart';

class MyPartiesPage extends StatefulWidget {
  const MyPartiesPage({super.key});

  @override
  State<MyPartiesPage> createState() => _MyPartiesPageState();
}

class _MyPartiesPageState extends State<MyPartiesPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartyMakerController>().refreshFromRepo();
    });
  }

  String _statusLabel(PartyStatus status) {
    switch (status) {
      case PartyStatus.draft:
        return "Rascunho";
      case PartyStatus.planning:
        return "Em planejamento";
      case PartyStatus.locked:
        return "Orçamento solicitado";
      case PartyStatus.paid:
        return "Pago";
      case PartyStatus.cancelled:
        return "Cancelado";
    }
  }

  Color _statusColor(PartyStatus status) {
    switch (status) {
      case PartyStatus.locked:
        return AppColors.primary;
      case PartyStatus.paid:
        return Colors.green;
      case PartyStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PartyMakerController>(
      builder: (_, controller, __) {
        final parties = controller.parties;
        final activeId = controller.activePartyId;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              "Minhas Festas",
              style: AppTypography.sectionTitle,
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,

            // ✅ SETA DE VOLTAR PARA HOME (aba 0)
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: AppColors.primary,
              ),
              onPressed: () => HomeScreen.changeTab(context, 0),
            ),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: parties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final p = parties[index];
              final isActive = p.id == activeId;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.primary : Colors.grey.shade200,
                    width: 1.6,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    p.title.value,
                    style: AppTypography.cardTitle,
                  ),
                  subtitle: Text(
                    _statusLabel(p.status),
                    style: TextStyle(
                      color: _statusColor(p.status),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),

                  /// ✅ Seleciona e vai para o Builder (aba 2) sem Navigator
                  onTap: () {
                    controller.setActiveParty(p.id);
                    HomeScreen.changeTab(context, 2);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}