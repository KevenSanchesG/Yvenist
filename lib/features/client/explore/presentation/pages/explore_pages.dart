import 'package:flutter/material.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/app_colors.dart';

class ExploreScreen extends StatelessWidget {
  // Recebe a função de voltar
  final VoidCallback onBack;

  const ExploreScreen({
    super.key, 
    required this.onBack, // Obrigatório passar
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Explorar", style: AppTypography.sectionTitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          // Ao clicar, executa a função que volta para a Home
          onPressed: onBack,
        ),
      ),
      body: const Center(
        child: Text("Tela de Explorar", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}