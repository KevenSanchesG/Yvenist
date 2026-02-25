import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen ({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Minhas Festas"),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: "Próximas"),
              Tab(text: "Finalizadas"),
              Tab(text: "Canceladas"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PartyList(status: "upcoming"),
            _PartyList(status: "finished"),
            _PartyList(status: "cancelled"),
          ],
        ),
      ),
    );
  }
}

class _PartyList extends StatelessWidget {
  final String status;
  const _PartyList({required this.status});

  @override
  Widget build(BuildContext context) {
    // Mock de dados
    final int count = status == 'upcoming' ? 2 : (status == 'finished' ? 5 : 1);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'upcoming' ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'upcoming' ? "CONFIRMADO" : (status == 'cancelled' ? "CANCELADO" : "REALIZADO"),
                        style: TextStyle(
                          color: status == 'upcoming' ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text("Reserva #593${index}2", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=100&q=80',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Salão Glamour ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text("12 Out, 2024 • 19:00", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          const Text("Campo Grande, RJ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(onPressed: (){}, icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text("Chat")),
                    if (status == 'finished')
                      TextButton.icon(onPressed: (){}, icon: const Icon(Icons.star_border, size: 18), label: const Text("Avaliar"))
                    else
                      TextButton.icon(onPressed: (){}, icon: const Icon(Icons.info_outline, size: 18), label: const Text("Detalhes")),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}