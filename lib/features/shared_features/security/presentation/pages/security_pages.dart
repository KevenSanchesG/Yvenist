import 'package:flutter/material.dart';
import '../../../../client/profile/presentation/widgets/profile_widgets.dart'; // Importe os widgets compartilhados

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Segurança e Login"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("ACESSO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          ProfileActionTile(title: "Alterar senha", icon: Icons.lock_outline, onTap: () {}),
          ProfileActionTile(title: "Autenticação em dois fatores", subtitle: "Desativado", icon: Icons.phonelink_lock, onTap: () {}),
          
          const SizedBox(height: 24),
          const Text("DISPOSITIVOS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          ProfileActionTile(title: "Dispositivos conectados", subtitle: "iPhone 13, Chrome Desktop", icon: Icons.devices, onTap: () {}),
          
          const SizedBox(height: 24),
          const Text("DADOS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
           ProfileActionTile(
            title: "Excluir conta", 
            subtitle: "Esta ação é permanente", 
            icon: Icons.delete_forever, 
            isDestructive: true,
            onTap: () {
              // Diálogo de confirmação
            }
          ),
        ],
      ),
    );
  }
}