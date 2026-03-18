// lib/screens/assign_role_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:flutter/material.dart';

class AssignRoleScreen extends StatefulWidget {
  const AssignRoleScreen({super.key});

  @override
  State<AssignRoleScreen> createState() => _AssignRoleScreenState();
}

class _AssignRoleScreenState extends State<AssignRoleScreen> {
  final _cpfController = TextEditingController();

  bool _buscando = false;
  bool _salvando = false;

  Map<String, dynamic>? _usuario;
  String? _erro;
  int? _novoTipoPerfil;

  static const _roles = {
    2: ('Guia', Icons.hiking, Color(0xFF1565C0)),
    3: ('Operador de Base', Icons.admin_panel_settings, Color(0xFF6A1B9A)),
  };

  String _nomePerfil(int tipo) {
    if (tipo == 1) return 'Trilheiro';
    if (tipo == 2) return 'Guia';
    if (tipo == 3) return 'Operador de Base';
    return 'Desconhecido';
  }

  Future<void> _buscar() async {
    final cpf = _cpfController.text.trim();
    if (cpf.replaceAll(RegExp(r'\D'), '').length != 11) {
      setState(() => _erro = 'Digite um CPF válido com 11 dígitos.');
      return;
    }
    setState(() {
      _buscando = true;
      _erro = null;
      _usuario = null;
      _novoTipoPerfil = null;
    });
    try {
      final resultado = await apiService.buscarUsuarioPorCpf(cpf);
      setState(() => _usuario = resultado);
    } catch (e) {
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _salvar() async {
    if (_usuario == null || _novoTipoPerfil == null) return;
    setState(() => _salvando = true);
    try {
      await apiService.atualizarPerfilUsuario(
        _usuario!['id'] as int,
        _novoTipoPerfil!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Perfil de ${_usuario!['nome']} atualizado para ${_nomePerfil(_novoTipoPerfil!)}!',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
        setState(() {
          _usuario = null;
          _novoTipoPerfil = null;
          _cpfController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Atribuir Função a Usuário',
          style: TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchCard(),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(),
            ],
            if (_usuario != null) ...[
              const SizedBox(height: 16),
              _buildUserCard(),
              const SizedBox(height: 16),
              _buildRoleSelector(),
              const SizedBox(height: 24),
              _buildConfirmButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar Usuário por CPF',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    decoration: InputDecoration(
                      labelText: 'CPF (somente números)',
                      prefixIcon: const Icon(Icons.badge),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _buscando ? null : _buscar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _buscando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_erro!, style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    final usuario = _usuario!;
    final tipoAtual = usuario['tipo_perfil'] as int? ?? 1;
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, size: 34, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario['nome'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usuario['email'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Perfil atual: ${_nomePerfil(tipoAtual)}',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecionar Nova Função',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            ..._roles.entries.map((entry) {
              final tipo = entry.key;
              final (label, icon, color) = entry.value;
              final selected = _novoTipoPerfil == tipo;
              return GestureDetector(
                onTap: () => setState(() => _novoTipoPerfil = tipo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.1) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? color : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: selected ? color : Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? color : Colors.grey[700],
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, color: color),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return ElevatedButton.icon(
      onPressed: (_novoTipoPerfil == null || _salvando) ? null : _salvar,
      icon: _salvando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.check),
      label: Text(
        _salvando ? 'Salvando...' : 'Confirmar Atribuição',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
    );
  }
}
