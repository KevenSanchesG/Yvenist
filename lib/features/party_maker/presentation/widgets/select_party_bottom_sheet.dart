import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/enums/party_item_category.dart';
import '../../presentation/controllers/party_maker_controller.dart';

class SelectPartyBottomSheet extends StatelessWidget {
  final String itemName;
  final String price;
  final String externalId;
  final String imageUrl;
  final PartyItemCategory category;

  const SelectPartyBottomSheet({
    super.key,
    required this.itemName,
    required this.price,
    required this.externalId,
    required this.imageUrl,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final parties = controller.parties;

    return Padding(
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
                  category: category,
                  imagePath: imageUrl,
                );

                if (context.mounted) {
                  Navigator.pop(context);

                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.error ?? 'Erro ao adicionar',
                        ),
                      ),
                    );
                  }
                }
              },
            );
          }),

          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _openCreatePartyDialog(context);
            },
            child: const Text("Criar nova festa"),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePartyDialog(BuildContext context) async {
    final controller = context.read<PartyMakerController>();
    final textController = TextEditingController();
    bool isValid = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Nome da nova festa"),
              content: TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Ex: 15 anos da Maria",
                ),
                onChanged: (value) {
                  setState(() {
                    isValid = value.trim().isNotEmpty;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          const ownerId = 'user_1';

                          final newParty =
                              await controller.startNewParty(
                            ownerId: ownerId,
                            title: textController.text,
                          );

                          await controller.addCardToParty(
                            partyId: newParty.id,
                            ownerId: ownerId,
                            cardTitle: itemName,
                            cardPrice: price,
                            externalId: externalId,
                            category: category,
                            imagePath: imageUrl,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      : null,
                  child: const Text("Confirmar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}