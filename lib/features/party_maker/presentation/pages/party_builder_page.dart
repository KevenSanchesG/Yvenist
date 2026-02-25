import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/party_maker_controller.dart';
import '../widgets/party_budget_item_tile.dart';
import '../../../client/home/presentation/pages/home_client_page.dart';

class PartyBuilderPage extends StatefulWidget {
  const PartyBuilderPage({super.key});

  @override
  State<PartyBuilderPage> createState() => _PartyBuilderPageState();
}

class _PartyBuilderPageState extends State<PartyBuilderPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartyMakerController>().refreshFromRepo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PartyMakerController>(
      builder: (context, controller, _) {
        final party = controller.activeParty;
        final items = controller.budgetItemViews;
        final totalCents = controller.activePartyTotalCents;

        final isLocked = controller.isActivePartyLocked;
        final isBusy = controller.isBusy;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              party?.title.value ?? "Minha Festa",
              style: AppTypography.sectionTitle,
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,

            // ✅ Sempre mostra back arrow (IndexedStack não tem pop)
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: AppColors.primary,
              ),
              onPressed: () {
                // ✅ encerra a sessão ativa
                controller.clearActiveParty();

                // ✅ volta para Home
                HomeScreen.changeTab(context, 0);
              },
            ),

            // ✅ remove o botão de hub (não precisamos mais)
            actions: const [],
          ),

          body: (party == null)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cake, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        "Nenhuma festa ativa",
                        style: AppTypography.sectionTitle.copyWith(
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Adicione itens clicando no botão + na Home",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cake, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            "Sua festa está vazia",
                            style: AppTypography.sectionTitle.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Adicione itens clicando no botão +",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                "${items.length} itens selecionados",
                                style: AppTypography.sectionSubtitle.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (isLocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    "Bloqueada",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, index) {
                              final item = items[index];

                              return PartyBudgetItemTile(
                                item: item,
                                isBusy: isBusy,
                                onRemove: () async {
                                  if (isLocked) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Essa festa já foi bloqueada para orçamento.",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final ok = await controller
                                      .removeItemFromActivePartyById(item.id);
                                  if (!context.mounted) return;

                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          controller.error ??
                                              "Erro ao remover item",
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),

                        // ============================================================
                        // Footer
                        // ============================================================
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Total",
                                    style: AppTypography.sectionSubtitle.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "R\$ ${(totalCents / 100).toStringAsFixed(2)}",
                                    style: AppTypography.sectionSubtitle.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (isLocked) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                          ),
                                          onPressed: isBusy
                                              ? null
                                              : () async {
                                                  const ownerId = 'user_1';

                                                  try {
                                                    await controller.startNewParty(
                                                      ownerId: ownerId,
                                                    );

                                                    if (!context.mounted) return;

                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "Nova festa criada!",
                                                        ),
                                                      ),
                                                    );
                                                  } catch (_) {
                                                    if (!context.mounted) return;

                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          controller.error ??
                                                              "Erro ao criar nova festa",
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                          child: const Text(
                                            "Criar nova festa",
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                          ),
                                          onPressed: isBusy
                                              ? null
                                              : () async {
                                                  final ok = await controller
                                                      .unlockActiveParty();

                                                  if (!context.mounted) return;

                                                  if (!ok) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          controller.error ??
                                                              "Erro ao desbloquear festa",
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        "Festa desbloqueada. Você pode editar novamente!",
                                                      ),
                                                    ),
                                                  );
                                                },
                                          child: const Text(
                                            "Editar festa",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () async {
                                            final ok = await controller
                                                .lockActivePartyForPayment();
                                            if (!context.mounted) return;

                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    controller.error ??
                                                        "Erro ao solicitar orçamento",
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Festa bloqueada. Orçamento solicitado!",
                                                ),
                                              ),
                                            );
                                          },
                                    child: const Text(
                                      "Solicitar Orçamento",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}