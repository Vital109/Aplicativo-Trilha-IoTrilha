// lib/screens/operator_screen.dart
import 'package:aplicativo_trilha/screens/assign_role_screen.dart';
import 'package:aplicativo_trilha/screens/assign_tag_screen.dart';
import 'package:aplicativo_trilha/screens/schedule_management_screen.dart';
import 'package:aplicativo_trilha/screens/tag_manager_screen.dart';
import 'package:aplicativo_trilha/widgets/operator_drawer.dart';
import 'package:flutter/material.dart';
import 'package:aplicativo_trilha/main.dart';
import 'package:intl/intl.dart';
import 'package:aplicativo_trilha/screens/users_list_screen.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  bool _isLoading = true;
  String _erro = "";
  Map<String, dynamic> _dashboardData = {};

  bool _showUserDetails = false;
  bool _showEventDetails = false;
  bool _showScheduleDetails = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _erro = "";
    });
    try {
      final data = await apiService.getDashboardDetalhado();
      if (mounted)
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _erro = "Erro: $e";
          _isLoading = false;
        });
    }
  }

  String _formatarData(dynamic dataString) {
    if (dataString == null) return "--";
    try {
      DateTime data = dataString is String
          ? DateTime.parse(dataString)
          : dataString;
      return DateFormat('dd/MM HH:mm').format(data);
    } catch (e) {
      return dataString.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Central de Comando",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              "Operador de Base",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      drawer: const OperatorDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            )
          : _erro.isNotEmpty
          ? _buildErrorState()
          : RefreshIndicator(
              color: const Color(0xFF1B5E20),
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildActionCard(),
                    const SizedBox(height: 12),
                    _buildAssignTagCard(),
                    const SizedBox(height: 12),
                    _buildAssignRoleCard(),

                    const SizedBox(height: 24),
                    Text(
                      "Métricas do Sistema",
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildExpandableMetricCard(
                      title: "Total de Usuários",
                      value:
                          _dashboardData['total_usuarios']?.toString() ?? '0',
                      icon: Icons.people,
                      color: Colors.blue[800]!,
                      bgColor: Colors.blue[50]!,
                      isExpanded: _showUserDetails,
                      onTap: () =>
                          setState(() => _showUserDetails = !_showUserDetails),
                      expandedContent: Row(
                        children: [
                          // 1 = Trilheiro
                          _buildBadgeCard(
                            "Trilheiros",
                            _dashboardData['qtd_trilheiros']?.toString() ?? '0',
                            Colors.blue,
                            Icons.hiking,
                            1,
                          ),
                          const SizedBox(width: 8),
                          // 2 = Guia/Operador
                          _buildBadgeCard(
                            "Staff",
                            _dashboardData['qtd_operadores']?.toString() ?? '0',
                            Colors.orange,
                            Icons.badge,
                            2,
                          ),
                          const SizedBox(width: 8),
                          // 3 = Admin
                          _buildBadgeCard(
                            "Admins",
                            _dashboardData['qtd_admins']?.toString() ?? '0',
                            Colors.red,
                            Icons.security,
                            3,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildExpandableMetricCard(
                      title: "Eventos de Passagem",
                      value:
                          _dashboardData['total_eventos_passagem']
                              ?.toString() ??
                          '0',
                      icon: Icons.flag,
                      color: Colors.green[800]!,
                      bgColor: Colors.green[50]!,
                      isExpanded: _showEventDetails,
                      onTap: () => setState(
                        () => _showEventDetails = !_showEventDetails,
                      ),
                      expandedContent: Column(
                        children: [
                          _buildMatrixRow([
                            "Métrica",
                            "Valor",
                            "Status",
                          ], isHeader: true),
                          _buildMatrixRow(["Broker MQTT", "Online", "OK"]),
                          _buildMatrixRow([
                            "Última Leitura",
                            _formatarData(_dashboardData['ultimo_evento_data']),
                            "Info",
                          ]),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildExpandableMetricCard(
                      title: "Agendamentos",
                      value:
                          _dashboardData['total_agendamentos']?.toString() ??
                          '0',
                      icon: Icons.calendar_today,
                      color: Colors.purple[800]!,
                      bgColor: Colors.purple[50]!,
                      isExpanded: _showScheduleDetails,
                      onTap: () => setState(
                        () => _showScheduleDetails = !_showScheduleDetails,
                      ),
                      expandedContent: Column(
                        children: [
                          _buildMatrixRow([
                            "Situação",
                            "Qtd.",
                            "Ação",
                          ], isHeader: true),
                          _buildMatrixRow([
                            "Confirmados",
                            _dashboardData['agendamentos_confirmados']
                                    ?.toString() ??
                                '0',
                            "",
                          ]),
                          _buildMatrixRow(
                            [
                              "Pendentes",
                              _dashboardData['agendamentos_pendentes']
                                      ?.toString() ??
                                  '0',
                              "Revisar",
                            ],
                            isHighlight: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ScheduleManagementScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS DE DESIGN ---

  Widget _buildBadgeCard(
    String label,
    String value,
    Color color,
    IconData icon,
    int tipoPerfilFiltro,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UsersListScreen(
                titulo: "Lista de $label",
                tipoPerfilFiltro: tipoPerfilFiltro,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixRow(
    List<String> row, {
    bool isHeader = false,
    bool isHighlight = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row[0],
                style: TextStyle(
                  color: isHeader
                      ? Colors.grey
                      : (isHighlight ? Colors.orange[800] : Colors.black87),
                  fontWeight: isHeader ? FontWeight.normal : FontWeight.w600,
                  fontSize: isHeader ? 12 : 14,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row[1],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isHeader ? Colors.grey : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    row[2],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: row[2] == "Revisar" ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (row[2] == "Revisar") ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.blue,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget expandedContent,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                expandedContent,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TagManagerScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nfc,
                  color: Color(0xFFFF6D00),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Gerenciador de Tags NFC",
                      style: TextStyle(
                        color: Colors.grey[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Provisionar e diagnosticar hardware.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignTagCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AssignTagScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nfc,
                  color: Color(0xFFFF6D00),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Atribuir Tag a Trilheiro",
                      style: TextStyle(
                        color: Colors.grey[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Vincular tag RFID à conta do trilheiro para rastreio na trilha.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignRoleCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AssignRoleScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.manage_accounts,
                  color: Color(0xFF6A1B9A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Atribuir Função a Usuário",
                      style: TextStyle(
                        color: Colors.grey[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Promover trilheiro a guia ou operador de base.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 60),
          const SizedBox(height: 16),
          Text(_erro, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDashboardData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
            ),
            child: const Text(
              "Tentar Novamente",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
