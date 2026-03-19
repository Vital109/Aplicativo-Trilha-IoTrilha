// lib/screens/assign_tag_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:flutter/material.dart';

class AssignTagScreen extends StatefulWidget {
  const AssignTagScreen({super.key});

  @override
  State<AssignTagScreen> createState() => _AssignTagScreenState();
}

class _AssignTagScreenState extends State<AssignTagScreen> {
  final _tagIdController = TextEditingController();
  final _cpfController = TextEditingController();

  bool _buscando = false;
  bool _salvando = false;

  Map<String, dynamic>? _usuario;
  String? _erroTag;
  String? _erroCpf;

  int? get _tagId {
    final val = int.tryParse(_tagIdController.text.trim());
    return val;
  }

  Future<void> _buscarTrilheiro() async {
    final cpf = _cpfController.text.trim();
    if (cpf.replaceAll(RegExp(r'\D'), '').length != 11) {
      setState(() => _erroCpf = 'Digite um CPF válido com 11 dígitos.');
      return;
    }
    if (_tagId == null) {
      setState(() => _erroTag = 'Digite um ID de tag válido antes de buscar o trilheiro.');
      return;
    }
    setState(() {
      _buscando = true;
      _erroCpf = null;
      _erroTag = null;
      _usuario = null;
    });
    try {
      final resultado = await apiService.buscarUsuarioPorCpf(cpf);
      if (resultado['tipo_perfil'] != 1) {
        setState(() => _erroCpf = 'Este usuário não é um trilheiro (perfil: ${resultado['tipo_perfil']}).');
        return;
      }
      setState(() => _usuario = resultado);
    } catch (e) {
      setState(() => _erroCpf = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _confirmar() async {
    if (_usuario == null || _tagId == null) return;
    setState(() => _salvando = true);
    try {
      await apiService.atribuirTagAoTrilheiro(_tagId!, _usuario!['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tag $_tagId atribuída a ${_usuario!['nome']} com sucesso!',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
        setState(() {
          _usuario = null;
          _tagIdController.clear();
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
    _tagIdController.dispose();
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
          'Atribuir Tag a Trilheiro',
          style: TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTagIdCard(),
            if (_erroTag != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(_erroTag!),
            ],
            const SizedBox(height: 12),
            _buildCpfCard(),
            if (_erroCpf != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(_erroCpf!),
            ],
            if (_usuario != null) ...[
              const SizedBox(height: 16),
              _buildUserCard(),
              const SizedBox(height: 24),
              _buildConfirmButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagIdCard() {
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
              'Passo 1 — ID Lógico da Tag',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Digite o número gravado na tag física que será entregue ao trilheiro.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagIdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'ID da Tag',
                hintText: 'Ex: 42',
                prefixIcon: const Icon(Icons.nfc, color: Color(0xFFFF6D00)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_erroTag != null) setState(() => _erroTag = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCpfCard() {
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
              'Passo 2 — Buscar Trilheiro por CPF',
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
                    onChanged: (_) {
                      if (_erroCpf != null) setState(() => _erroCpf = null);
                    },
                    onSubmitted: (_) => _buscarTrilheiro(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _buscando ? null : _buscarTrilheiro,
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

  Widget _buildErrorBanner(String erro) {
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
            child: Text(erro, style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    final usuario = _usuario!;
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
              'Confirmar Atribuição',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.nfc, color: Color(0xFFFF6D00), size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tag a ser atribuída',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'ID $_tagId',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6D00),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return ElevatedButton.icon(
      onPressed: _salvando ? null : _confirmar,
      icon: _salvando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.link),
      label: Text(
        _salvando ? 'Atribuindo...' : 'Confirmar Atribuição da Tag',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6D00),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
    );
  }
}
