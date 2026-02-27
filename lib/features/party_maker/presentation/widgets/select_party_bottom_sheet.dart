import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/value_objects/party_id.dart';
import '../../presentation/controllers/party_maker_controller.dart';

class SelectPartyBottomSheet extends StatelessWidget {
  final String itemName;
  final String price;
  final String externalId;
  final String imageUrl;

  const SelectPartyBottomSheet({
    super.key,
    required this.itemName,
    required this.price,
    required this.externalId,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final parties = controller.parties;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Em qual festa você deseja adicionar\n$itemName?",
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          if (parties.isEmpty)
            const Text("Nenhuma festa criada ainda."),

          ...parties.map((p) {
            return ListTile(
              title: Text(p.title.value),
              subtitle: Text(p.status.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await controller.addCardToParty(
                  partyId: p.id,
                  ownerId: p.ownerId,
                  cardTitle: itemName,
                  cardPrice: price,
                  externalId: externalId,
                  category: p.budget.items.isEmpty
                      ? p.budget.items.isEmpty
                          ? p.budget.items.isEmpty
                              ? p.budget.items.isEmpty
                              : p.budget.items.first.category
                          : p.budget.items.first.category
                      : p.budget.items.first.category,
                  imagePath: imageUrl,
                );

                if (context.mounted) {
                  Navigator.pop(context);

                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(controller.error ?? 'Erro ao adicionar'),
                      ),
                    );
                  }
                }
              },
            );
          }),

          const SizedBox(height: 8),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () async {
              const ownerId = 'user_1';
              final newParty =
                  await controller.startNewParty(ownerId: ownerId);

              await controller.addCardToParty(
                partyId: newParty.id,
                ownerId: ownerId,
                cardTitle: itemName,
                cardPrice: price,
                externalId: externalId,
                category: p.budget.items.first.category,
                imagePath: imageUrl,
              );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Criar nova festa"),
          ),
        ],
      ),
    );
  }
}