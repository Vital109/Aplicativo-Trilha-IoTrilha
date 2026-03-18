// lib/widgets/operator_drawer.dart
// ignore_for_file: unused_field

import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/assign_role_screen.dart';
import 'package:aplicativo_trilha/screens/guide_screen.dart';
import 'package:aplicativo_trilha/screens/live_trail_screen.dart';
import 'package:aplicativo_trilha/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OperatorDrawer extends StatefulWidget {
  const OperatorDrawer({super.key});

  @override
  State<OperatorDrawer> createState() => _OperatorDrawerState();
}

class _OperatorDrawerState extends State<OperatorDrawer> {
  bool _isLoading = true;

  int? _userId;
  int _userTipoInt = 3;
  String _userName = "Carregando...";
  String _userEmail = "";
  String? _userPhotoUrl;

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
          _userId = sessionData['id_usuario'] as int?;
          _userTipoInt = int.tryParse(sessionData['user_tipo_perfil'] ?? '3') ?? 3;
          _userName = sessionData['user_nome'] ?? "Operador";
          _userEmail = sessionData['user_email'] ?? "";
          _userPhotoUrl = sessionData['user_foto_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
            decoration: const BoxDecoration(color: Colors.blueGrey),
            accountName: _isLoading
                ? const Text("...")
                : Text(
                    _userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
            accountEmail: _isLoading ? null : Text(_userEmail),
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
                  : (_isLoading ? const CircularProgressIndicator() : null),
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
                if (_userTipoInt >= 2)
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
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.blue),
                  title: const Text("Painel do Operador"),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.manage_accounts,
                    color: Color(0xFF6A1B9A),
                  ),
                  title: const Text("Atribuir Função a Usuário"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssignRoleScreen(),
                      ),
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
