import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        // O campo de texto fica no título da AppBar
        title: TextField(
          autofocus: true, // Abre o teclado automaticamente
          decoration: const InputDecoration(
            hintText: "Buscar salões, brinquedos...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {
              // Ação de buscar futura
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pesquisas recentes",
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _buildSearchChip("Salão de Festas"),
                _buildSearchChip("Pula Pula"),
                _buildSearchChip("DJ"),
                _buildSearchChip("Buffet Infantil"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.headerBackground,
      labelStyle: const TextStyle(color: AppColors.textPrimary),
    );
  }
}