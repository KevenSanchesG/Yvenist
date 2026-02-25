import 'package:flutter/material.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/app_colors.dart';

class ChatScreen extends StatelessWidget {
  final VoidCallback onBack;

  const ChatScreen({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mensagens", style: AppTypography.sectionTitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: onBack,
        ),
      ),
      body: const Center(
        child: Text("Suas conversas aparecerão aqui", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}