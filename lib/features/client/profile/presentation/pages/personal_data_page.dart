import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../widgets/profile_widgets.dart'; // Importe os widgets acima

class PersonalDataScreen extends StatelessWidget {
  const PersonalDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Dados Pessoais"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          TextButton(
            onPressed: () {
              // Lógica de Salvar
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados salvos!")));
            },
            child: const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Upload de Foto
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage('https://br.pinterest.com/pin/606086062341398019/'),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Formulário
            const ProfileTextField(label: "Nome Completo", initialValue: "Keven Sanches"),
            const ProfileTextField(label: "E-mail", initialValue: "keven@email.com", isVerified: true, isReadOnly: true),
            const ProfileTextField(label: "Telefone", initialValue: "(11) 99999-9999", keyboardType: TextInputType.phone),
            const ProfileTextField(label: "Data de Nascimento", initialValue: "20/05/1995", keyboardType: TextInputType.datetime),
            const ProfileTextField(label: "CPF", initialValue: "123.***.***-00", isReadOnly: true), // Bloqueado pois tem anúncio
            
            const Divider(height: 40),
            
            // Preferências Regionais
            DropdownButtonFormField(
              value: "pt_BR",
              decoration: InputDecoration(
                labelText: "Idioma",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: "pt_BR", child: Text("Português (Brasil)")),
                DropdownMenuItem(value: "en_US", child: Text("English (US)")),
              ],
              onChanged: (v) {},
            ),
          ],
        ),
      ),
    );
  }
}