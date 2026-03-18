// lib/widgets/trail_drawer.dart
// ignore_for_file: unused_field

import 'dart:async';
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/guide_screen.dart';
import 'package:aplicativo_trilha/screens/operator_screen.dart';
import 'package:aplicativo_trilha/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrailDrawer extends StatefulWidget {
  final int? trilhaId;
  final LatLng? userLocation;
  final VoidCallback? onTrilhaFinalizada;

  const TrailDrawer({
    super.key,
    this.trilhaId,
    this.onTrilhaFinalizada,
    this.userLocation,
  });

  @override
  State<TrailDrawer> createState() => _TrailDrawerState();
}

class _TrailDrawerState extends State<TrailDrawer> {
  bool _isLoading = true;

  int? _userId;
  int _userTipoInt = 1;
  String _userName = "Carregando...";
  String _userEmail = "";
  String? _userPhotoUrl;
  String _nomeTrilha = "Sem trilha ativa";
  DateTime? _inicio;
  List<dynamic> _participantes = [];
  Map<String, dynamic>? _clima;
  String _tempoDecorrido = "00:00:00";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _iniciarTimer() {
    if (_inicio == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diferenca = DateTime.now().difference(_inicio!);
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      final horas = twoDigits(diferenca.inHours);
      final minutos = twoDigits(diferenca.inMinutes.remainder(60));
      final segundos = twoDigits(diferenca.inSeconds.remainder(60));
      if (mounted) {
        setState(() {
          _tempoDecorrido = "$horas:$minutos:$segundos";
        });
      }
    });
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final sessionData = await authService.getUserData();

      if (mounted) {
        setState(() {
          _userId = int.tryParse(sessionData['user_id'] ?? '0');
          _userTipoInt = int.tryParse(sessionData['user_tipo_perfil'] ?? '1') ?? 1;
          _userName = sessionData['user_nome'] ?? "Usuário";
          _userEmail = sessionData['user_email'] ?? "";
          _userPhotoUrl = sessionData['user_foto_url'];
        });
      }

      if (widget.trilhaId != null) {
        final trilhaData = await apiService.getDetalhesTrilha(widget.trilhaId!);

        Map<String, dynamic>? climaData;
        if (widget.userLocation != null) {
          try {
            climaData = await apiService.getClima(
              widget.userLocation!.latitude,
              widget.userLocation!.longitude,
            );
          } catch (_) {}
        }

        if (mounted) {
          final info = trilhaData['trilha_info'];
          setState(() {
            _nomeTrilha = info['nome_trilha'];
            _inicio = DateTime.parse(info['iniciada_em_iso']).toLocal();
            _participantes = trilhaData['participantes'];
            _clima = climaData;
          });
          _iniciarTimer();
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print("Erro ao carregar drawer: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await authService.logout();
    if (mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _finalizarTrilha() async {
    if (widget.onTrilhaFinalizada == null || widget.trilhaId == null) return;

    final bool? confirmar = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Finalizar Trilha?"),
        content: const Text(
          "Isso encerrará o rastreamento e salvará o histórico.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Finalizar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await apiService.finalizarTrilha(widget.trilhaId!);
        widget.onTrilhaFinalizada!();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool emTrilha = widget.trilhaId != null;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: emTrilha
                    ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                    : [Colors.blueGrey, Colors.grey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              _userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              emTrilha ? "Em trilha: $_nomeTrilha" : _userEmail,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: (_userPhotoUrl != null && !_isLoading)
                  ? CachedNetworkImageProvider(
                      _userPhotoUrl!.startsWith('http')
                          ? _userPhotoUrl!
                          : '${apiService.baseUrl}/uploads/$_userPhotoUrl',
                    )
                  : null,
              child: (_userPhotoUrl == null && !_isLoading)
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
            onDetailsPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (emTrilha) ...[
                        Container(
                          color: Colors.black.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _tempoDecorrido,
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  fontFamily: 'monospace',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _buildClimaTile(),
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Participantes",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _buildParticipantesList(),
                        const Divider(thickness: 2),
                      ] else ...[
                        const ListTile(
                          leading: Icon(Icons.hiking),
                          title: Text("Nenhuma trilha ativa no momento."),
                          subtitle: Text(
                            "Inicie uma nova trilha para ver estatísticas.",
                          ),
                        ),
                        const Divider(),
                      ],

                      if (_userTipoInt >= 2) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.map, color: Colors.deepOrange),
                          title: const Text("Painel do Guia"),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GuideScreen()),
                            );
                          },
                        ),
                      ],
                      if (_userTipoInt >= 3)
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                          title: const Text("Painel do Operador"),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OperatorScreen()),
                            );
                          },
                        ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.exit_to_app),
                        title: const Text("Sair (Logout)"),
                        onTap: _logout,
                      ),
                    ],
                  ),
          ),

          if (emTrilha) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: _finalizarTrilha,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("Finalizar Trilha"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClimaTile() {
    if (_clima == null) {
      return const ListTile(
        leading: Icon(Icons.cloud_off, color: Colors.grey),
        title: Text("Clima não disponível"),
      );
    }
    return ListTile(
      leading: Image.network(
        'https://openweathermap.org/img/wn/${_clima!['icone']}@2x.png',
        errorBuilder: (c, o, s) => const Icon(Icons.cloud),
      ),
      title: Text("Clima: ${_clima!['descricao']}"),
      subtitle: Text(
        "${_clima!['temp']}°C (Sensação: ${_clima!['sensacao_termica']}°C)",
      ),
    );
  }

  Widget _buildParticipantesList() {
    if (_participantes.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.person),
        title: Text("Apenas você"),
      );
    }
    return ListView.builder(
      itemCount: _participantes.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final user = _participantes[index];
        final fotoUrl = user['url_foto_perfil'] != null
            ? '${apiService.baseUrl}/uploads/${user['url_foto_perfil']}'
            : null;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
            child: fotoUrl == null ? const Icon(Icons.person) : null,
          ),
          title: Text(user['nome']),
        );
      },
    );
  }
}
