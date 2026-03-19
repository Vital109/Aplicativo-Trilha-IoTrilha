// lib/widgets/guide_drawer.dart
// ignore_for_file: unused_field

import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/live_trail_screen.dart';
import 'package:aplicativo_trilha/screens/operator_screen.dart';
import 'package:aplicativo_trilha/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GuideDrawer extends StatefulWidget {
  const GuideDrawer({super.key});

  @override
  State<GuideDrawer> createState() => _GuideDrawerState();
}

class _GuideDrawerState extends State<GuideDrawer> {
  bool _isLoading = true;

  int? _userId;
  int _userTipoInt = 2;
  String _userName = "...";
  String _userEmail = "";
  String? _userPhotoUrl;
  String _statusGuia = "offline";

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    setState(() => _isLoading = true);
    try {
      final sessionData = await authService.getUserData();
      if (mounted) {
        setState(() {
          _userId = int.tryParse(sessionData['user_id'] ?? '0');
          _userTipoInt = int.tryParse(sessionData['user_tipo_perfil'] ?? '2') ?? 2;
          _userName = sessionData['user_nome'] ?? "Guia";
          _userEmail = sessionData['user_email'] ?? "";
          _userPhotoUrl = sessionData['user_foto_url'];
          _statusGuia = sessionData['user_status_guia'] ?? 'offline';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor() {
    switch (_statusGuia) {
      case 'disponivel':
        return Colors.green;
      case 'reservado':
        return Colors.orange;
      case 'em_trilha':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_statusGuia) {
      case 'disponivel':
        return "Disponível";
      case 'reservado':
        return "Reservado";
      case 'em_trilha':
        return "Em Trilha";
      default:
        return "Offline / Fora de Horário";
    }
  }

  Future<void> _logout() async {
    await authService.logout();
    if (mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.8),
            ),
            accountName: Row(
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userEmail),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _isLoading ? Colors.grey : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLoading ? "..." : _getStatusText(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  ? const Icon(Icons.person, size: 35, color: Colors.grey)
                  : null,
            ),
            currentAccountPictureSize: Size(55, 55),
            onDetailsPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.hiking, color: Color(0xFF2E7D32)),
                  title: const Text("Painel do Trilheiro"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LiveTrailScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.deepOrange),
                  title: const Text("Painel do Guia"),
                  onTap: () => Navigator.pop(context),
                ),
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
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text("Sair (Logout)"),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
