// lib/features/vendor_onboarding/screens/hall_creation_flow_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/vendor_session.dart'; // Importe seu Singleton

class HallCreationFlowScreen extends StatefulWidget {
  const HallCreationFlowScreen({super.key});

  @override
  State<HallCreationFlowScreen> createState() => _HallCreationFlowScreenState();
}

class _HallCreationFlowScreenState extends State<HallCreationFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 7;

  // Modelo de Dados Temporário (Poderia ser uma classe separada)
  final Map<String, dynamic> _adData = {
    'tipoPessoa': 'PF',
    'servicos': <String>[],
    'eventos': <String>[],
  };

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitAd();
    }
  }

  void _submitAd() {
    // 1. Simula envio ao backend
    // 2. Atualiza estado da sessão global
    VendorSession().submitAdForReview();

    // 3. Feedback e saída
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Anúncio Enviado! 🎉"),
        content: const Text("Seu anúncio foi enviado para análise. Avisaremos assim que seu perfil de fornecedor for aprovado."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha dialog
              Navigator.of(ctx).popUntil((route) => route.isFirst); // Volta pra Home
            },
            child: const Text("Entendido"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcula progresso (0.0 a 1.0)
    double progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          color: AppColors.primary,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        actions: [
          TextButton(
            onPressed: () {}, // Salvar rascunho
            child: const Text("Salvar e Sair", style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Bloqueia swipe manual
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _Step1LegalData(),
                _Step2Identity(),
                _Step3EventTypes(
                  selectedEvents: _adData['eventos'], 
                  onChanged: (list) => setState(() => _adData['eventos'] = list)
                ),
                _Step4Structure(
                  selectedServices: _adData['servicos'],
                  onChanged: (list) => setState(() => _adData['servicos'] = list)
                ),
                const _Step5Media(),
                const _Step6Price(),
                _Step7Review(adData: _adData),
              ],
            ),
          ),
          
          // BARRA INFERIOR FIXA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentStep == 0 ? null : () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  child: const Text("Voltar", style: TextStyle(color: Colors.black)),
                ),
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    _currentStep == _totalSteps - 1 ? "Enviar Anúncio" : "Avançar",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS DE CADA ETAPA (Resumidos para caber na resposta) ---

class _Step1LegalData extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Vamos começar com o legal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Precisamos desses dados para garantir a segurança da plataforma.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          DropdownButtonFormField(
            items: const [DropdownMenuItem(value: 'PF', child: Text("Pessoa Física")), DropdownMenuItem(value: 'PJ', child: Text("Pessoa Jurídica"))],
            onChanged: (v) {},
            decoration: const InputDecoration(labelText: "Tipo de Pessoa", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: "CPF do Proprietário", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder())),
        ],
      ),
    );
  }
}

class _Step2Identity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Fale sobre o seu salão", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const TextField(decoration: InputDecoration(labelText: "Nome do Salão (Ex: Espaço Crystal)", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const TextField(
            maxLines: 4,
            decoration: InputDecoration(labelText: "Descrição (Conte o que torna seu espaço único)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: TextField(decoration: InputDecoration(labelText: "Área (m²)", border: OutlineInputBorder()))),
              SizedBox(width: 16),
              Expanded(child: TextField(decoration: InputDecoration(labelText: "Capacidade Máx.", border: OutlineInputBorder()))),
            ],
          )
        ],
      ),
    );
  }
}

class _Step3EventTypes extends StatelessWidget {
  final List<String> selectedEvents;
  final ValueChanged<List<String>> onChanged;

  const _Step3EventTypes({required this.selectedEvents, required this.onChanged});

  final List<String> options = const ["Casamentos", "15 Anos", "Infantil", "Corporativo", "Churrasco", "Formatura"];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Que eventos você aceita?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((event) {
              final isSelected = selectedEvents.contains(event);
              return FilterChip(
                label: Text(event),
                selected: isSelected,
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
                onSelected: (selected) {
                  final newList = List<String>.from(selectedEvents);
                  selected ? newList.add(event) : newList.remove(event);
                  onChanged(newList);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Step4Structure extends StatelessWidget {
  final List<String> selectedServices;
  final ValueChanged<List<String>> onChanged;

  const _Step4Structure({required this.selectedServices, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Map<String, IconData> items = {
      "Cozinha Equipada": Icons.kitchen,
      "Ar Condicionado": Icons.ac_unit,
      "Estacionamento": Icons.local_parking,
      "Área Kids": Icons.child_care,
      "Wifi": Icons.wifi,
      "Acessibilidade": Icons.wheelchair_pickup,
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text("O que o espaço oferece?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ...items.entries.map((entry) {
          final isSelected = selectedServices.contains(entry.key);
          return CheckboxListTile(
            title: Text(entry.key),
            secondary: Icon(entry.value),
            value: isSelected,
            activeColor: AppColors.primary,
            onChanged: (val) {
               final newList = List<String>.from(selectedServices);
               val == true ? newList.add(entry.key) : newList.remove(entry.key);
               onChanged(newList);
            },
          );
        }).toList()
      ],
    );
  }
}

class _Step5Media extends StatelessWidget {
  const _Step5Media();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mostre seu espaço", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("A primeira foto será a capa do anúncio.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          
          // Placeholder de Upload Principal
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text("Adicionar foto de capa"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Grid para outras fotos
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(child: Icon(Icons.add, color: Colors.grey)),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _Step6Price extends StatelessWidget {
  const _Step6Price();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quanto custa?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Preço base (Diária ou Evento)",
              prefixText: "R\$ ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Política de Cancelamento", style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile(value: 1, groupValue: 1, onChanged: (v){}, title: const Text("Flexível"), subtitle: const Text("Reembolso total até 48h antes.")),
          RadioListTile(value: 2, groupValue: 1, onChanged: (v){}, title: const Text("Moderada"), subtitle: const Text("Reembolso de 50% até 7 dias antes.")),
        ],
      ),
    );
  }
}

class _Step7Review extends StatelessWidget {
  final Map<String, dynamic> adData;
  const _Step7Review({required this.adData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text("Tudo pronto!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text(
            "Ao clicar em enviar, nossa equipe analisará os dados do seu salão. Isso costuma levar até 24 horas.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                _ReviewRow(label: "Tipo", value: "Salão de Festas"),
                _ReviewRow(label: "Eventos", value: "${(adData['eventos'] as List).length} selecionados"),
                _ReviewRow(label: "Serviços", value: "${(adData['servicos'] as List).length} inclusos"),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}