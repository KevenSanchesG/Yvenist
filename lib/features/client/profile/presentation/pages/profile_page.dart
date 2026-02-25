import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/domain/vendor_session.dart';
import '../../../../vendor/onboarding/pages/vendor_welcome_page.dart';

// --- IMPORTS DAS TELAS INTERNAS (NÍVEL 2) ---
import 'personal_data_page.dart';
import '../../../events/presentation/pages/my_bookings_pages.dart';
import '../../../../shared_features/payments/payment_methods_pages.dart';
import '../../../../shared_features/security/presentation/pages/security_pages.dart';
import '../../../../shared_features/legal/presentation/pages/legal_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isVendorMode = false;

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funcionalidade em desenvolvimento 🛠️")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- CABEÇALHO ---
            _buildHeader(context),

            const SizedBox(height: 24),

            // --- CONTEÚDO DINÂMICO ---
            if (_isVendorMode) 
              _buildVendorContent()
            else 
              _buildClientContent(),
            
            const SizedBox(height: 40),
            
            _buildCommonFooter(),
            
            const SizedBox(height: 100), 
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1. CABEÇALHO
  // ---------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    final double toggleWidth = MediaQuery.of(context).size.width * 0.85;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Fundo Colorido
        Container(
          height: 280, 
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isVendorMode 
                  ? [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)] 
                  : [AppColors.primary, AppColors.primary.withOpacity(0.8)], 
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: (_isVendorMode ? Colors.black : AppColors.primary).withOpacity(0.3), 
                blurRadius: 20, 
                offset: const Offset(0, 10)
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 60, right: 20, left: 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
                
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage('https://br.pinterest.com/pin/606086062341398019/'),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Keven Sanches",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _isVendorMode ? "Fornecedora Verificada ✅" : "Festeira Iniciante 🎉",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ),

        // O TOGGLE (Alternador de Modo)
        Positioned(
          bottom: -25,
          child: Container(
            width: toggleWidth,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                // Lado Cliente
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isVendorMode = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isVendorMode ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(25)),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Modo Cliente",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: !_isVendorMode ? AppColors.primary : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Lado Fornecedor
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                        setState(() => _isVendorMode = true);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isVendorMode ? const Color(0xFF2C3E50).withOpacity(0.1) : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(25)),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Modo Fornecedor",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _isVendorMode ? const Color(0xFF2C3E50) : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 2. CONTEÚDO MODO CLIENTE (COM NAVEGAÇÃO ATUALIZADA)
  // ---------------------------------------------------------
  Widget _buildClientContent() {
    final vendorStatus = VendorSession().status;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          
          _DashboardCard(
            items: [
              _StatItem(count: "2", label: "Próximas\nFestas", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()))),
              _VerticalDivider(),
              _StatItem(count: "15", label: "Favoritos\nSalvos", onTap: () => _showComingSoon(context)),
              _VerticalDivider(),
              _StatItem(count: "3", label: "Orçamentos\nAbertos", onTap: () => _showComingSoon(context)),
            ],
          ),

          const SizedBox(height: 24),

          // --- ÁREA DE BANNER DINÂMICO ---
          if (vendorStatus == VendorStatus.none)
            _PromoBanner(
              title: "Tem um salão ou serviço?",
              subtitle: "Mude para o modo fornecedor e anuncie grátis.",
              color1: const Color(0xFF2C3E50),
              color2: const Color(0xFF4CA1AF),
              icon: Icons.storefront,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VendorWelcomeScreen()),
                ).then((_) => setState((){}));
              },
            )
          else if (vendorStatus == VendorStatus.review)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, color: Colors.amber),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Análise em andamento", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                        Text("Estamos verificando seus dados.", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      VendorSession().approveVendor();
                      setState((){});
                    },
                    child: const Text("Aprovar (Dev)"),
                  )
                ],
              ),
            )
          else if (vendorStatus == VendorStatus.approved)
            _PromoBanner(
              title: "Você é um fornecedor!",
              subtitle: "Mude para o Modo Fornecedor no topo para gerenciar.",
              color1: Colors.green.shade700,
              color2: Colors.green.shade400,
              icon: Icons.check_circle,
              onTap: () => setState(() => _isVendorMode = true),
            ),
          // -------------------------------

          const SizedBox(height: 24),

          const _SectionHeader(title: "MINHA CONTA"),
          _MenuContainer(children: [
            _MenuItem(
              icon: Icons.person_outline, 
              title: "Dados Pessoais", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDataScreen())),
            ),
            _Divider(),
            _MenuItem(
              icon: Icons.location_on_outlined, 
              title: "Endereços de Eventos", 
              onTap: () => _showComingSoon(context), // Placeholder
            ),
            _Divider(),
            _MenuItem(
              icon: Icons.credit_card, 
              title: "Formas de Pagamento", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
            ),
          ]),

          const SizedBox(height: 20),

          const _SectionHeader(title: "GESTÃO"),
          _MenuContainer(children: [
            _MenuItem(
              icon: Icons.event_note, 
              title: "Minhas Festas", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
            ),
            _Divider(),
            _MenuItem(
              icon: Icons.receipt_long, 
              title: "Histórico de Pagamentos", 
              onTap: () => _showComingSoon(context), // Placeholder
            ),
            _Divider(),
            _MenuItem(
              icon: Icons.star_border, 
              title: "Minhas Avaliações", 
              onTap: () => _showComingSoon(context), // Placeholder
            ),
          ]),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 3. CONTEÚDO MODO FORNECEDOR
  // ---------------------------------------------------------
  Widget _buildVendorContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),

          _DashboardCard(
            items: [
              _StatItem(count: "R\$ 2.5k", label: "Saldo\nDisponível", onTap: () {}, isMoney: true),
              _VerticalDivider(),
              _StatItem(count: "4.9", label: "Nota\nMédia", onTap: () {}, isStar: true),
              _VerticalDivider(),
              _StatItem(count: "8", label: "Novos\nPedidos", onTap: () {}),
            ],
          ),

          const SizedBox(height: 24),

          _PromoBanner(
            title: "Impulsione seus anúncios",
            subtitle: "Aumente suas reservas em até 3x hoje.",
            color1: Colors.orange.shade800,
            color2: Colors.orange.shade400,
            icon: Icons.rocket_launch,
            onTap: () {},
          ),

          const SizedBox(height: 24),

          const _SectionHeader(title: "MEU NEGÓCIO"),
          _MenuContainer(children: [
            _MenuItem(icon: Icons.store, title: "Dados do Negócio", onTap: () => _showComingSoon(context)),
            _Divider(),
            _MenuItem(icon: Icons.campaign, title: "Meus Anúncios", onTap: () => _showComingSoon(context)),
            _Divider(),
            _MenuItem(icon: Icons.calendar_month, title: "Agenda & Disponibilidade", onTap: () => _showComingSoon(context)),
          ]),

          const SizedBox(height: 20),

          const _SectionHeader(title: "FINANCEIRO"),
          _MenuContainer(children: [
            _MenuItem(icon: Icons.attach_money, title: "Extrato e Saques", onTap: () => _showComingSoon(context)),
            _Divider(),
            _MenuItem(icon: Icons.account_balance, title: "Dados Bancários", onTap: () => _showComingSoon(context)),
          ]),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 4. RODAPÉ COMUM (COM NAVEGAÇÃO ATUALIZADA)
  // ---------------------------------------------------------
  Widget _buildCommonFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: "CONFIGURAÇÕES E SUPORTE"),
          _MenuContainer(children: [
            _MenuItem(
              icon: Icons.lock_outline, 
              title: "Segurança e Senha", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
            ),
            _Divider(),
            _MenuItem(
              icon: Icons.help_outline, 
              title: "Central de Ajuda", 
              onTap: () => _showComingSoon(context), // Placeholder
            ),
            _Divider(),
            _MenuItem(
              icon: Icons.description_outlined, 
              title: "Termos e Política", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen())),
            ),
          ]),

          const SizedBox(height: 24),

          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Sair da conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 10),
          const Center(child: Text("Versão 1.0.4", style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// WIDGETS AUXILIARES
// ---------------------------------------------------------

class _DashboardCard extends StatelessWidget {
  final List<Widget> items;
  const _DashboardCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: items),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback onTap;
  final bool isMoney;
  final bool isStar;

  const _StatItem({
    required this.count, 
    required this.label, 
    required this.onTap, 
    this.isMoney = false,
    this.isStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: isMoney ? Colors.green[700] : (isStar ? Colors.amber[700] : AppColors.primary)
                ),
              ),
              if (isStar) Icon(Icons.star, size: 16, color: Colors.amber[700]),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color1, color2;
  final IconData icon;
  final VoidCallback onTap;

  const _PromoBanner({
    required this.title, required this.subtitle, required this.color1, required this.color2, required this.icon, required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color1.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }
}

class _MenuContainer extends StatelessWidget {
  final List<Widget> children;
  const _MenuContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.grey[700], size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey[100], indent: 56);
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 24, width: 1, color: Colors.grey[200]);
  }
}