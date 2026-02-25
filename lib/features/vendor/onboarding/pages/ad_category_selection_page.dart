import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
// Importa a próxima tela do fluxo (vamos criar logo em seguida)
import 'hall_creation_flow_page.dart'; 

class AdCategorySelectionScreen extends StatelessWidget {
  const AdCategorySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("O que você vai anunciar?"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CategoryCard(
            icon: Icons.home_work_outlined,
            title: "Salão de Festas",
            subtitle: "Sítios, salões, espaços gourmet, rooftops.",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HallCreationFlowScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _CategoryCard(
            icon: Icons.toys_outlined,
            title: "Brinquedos & Atrações",
            subtitle: "Pula-pula, piscina de bolinhas, animadores.",
            onTap: () {
              // Futuro: Implementar fluxo de brinquedos
            },
          ),
          const SizedBox(height: 16),
          _CategoryCard(
            icon: Icons.restaurant_menu,
            title: "Buffet & Bar",
            subtitle: "Salgados, bolos, bartender, churrasco.",
            onTap: () {},
          ),
           const SizedBox(height: 16),
          _CategoryCard(
            icon: Icons.celebration,
            title: "Decoração",
            subtitle: "Temas completos, pegue e monte, painéis.",
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CategoryCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}