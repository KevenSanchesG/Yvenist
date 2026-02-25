import 'package:flutter/material.dart';
import '../../../../client/profile/presentation/widgets/profile_widgets.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Legal"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ProfileActionTile(title: "Termos de Uso", icon: Icons.description_outlined, onTap: () {}),
          ProfileActionTile(title: "Política de Privacidade", icon: Icons.privacy_tip_outlined, onTap: () {}),
          ProfileActionTile(title: "Contrato do Fornecedor", icon: Icons.gavel_outlined, onTap: () {}),
          ProfileActionTile(title: "Solicitar meus dados (LGPD)", icon: Icons.folder_shared_outlined, onTap: () {}),
        ],
      ),
    );
  }
}