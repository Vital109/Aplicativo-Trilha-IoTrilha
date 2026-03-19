// lib/screens/profile_screen.dart
// ignore_for_file: unused_field

import 'dart:io';
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/guide_screen.dart';
import 'package:aplicativo_trilha/screens/login_screen.dart';
import 'package:aplicativo_trilha/screens/operator_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  //ESTADO GERAL DO USUÁRIO
  String _userName = "Carregando...";
  String _userEmail = "";
  String _userTipo = "Trilheiro";
  int _userTipoInt = 1;
  String? _userPhotoUrl;
  String _userTelefone = "";
  String _userIdade = "";
  String _userSexo = "";

  // ESTADO DO TRILHEIRO
  int _totalTagsLidas = 0;
  int _eventosPendentes = 0;
  Map<String, dynamic>? _ultimaTag;
  List<dynamic> _historicoTrilhas = [];
  bool _isLoadingHistorico = false;

  // ESTADO DO GUIA
  bool _isGuiaOnline = false;

  //GERAL
  bool _isLoadingLocal = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Color get _themeColor => const Color(0xFF2E7D32);

  Future<void> _loadAllData() async {
    await _loadUserData();
    await _loadLocalDataTrilheiro();
    await _loadHistoricoTrilheiro();
  }

  Future<void> _loadUserData() async {
    final localData = await authService.getUserData();
    final userId = await authService.getLoggedInUserId();
    Map<String, dynamic> fullData = {};

    if (userId != null) {
      try {
        fullData = await apiService.getDadosUsuarioCompleto(int.parse(userId));
      } catch (e) {
        print("Erro ao buscar dados completos: $e");
        fullData = localData;
      }
    }

    if (mounted) {
      setState(() {
        _userName = fullData['nome'] ?? localData['user_nome'] ?? "Viajante";
        _userEmail = fullData['email'] ?? localData['user_email'] ?? "";
        _userPhotoUrl = localData['user_foto_url'];

        // Telefone
        _userTelefone =
            (fullData['telefone'] != null &&
                fullData['telefone'].toString().isNotEmpty)
            ? fullData['telefone'].toString()
            : "Não informado";

        // Idade
        _userIdade =
            (fullData['idade'] != null && fullData['idade'].toString() != "0")
            ? "${fullData['idade']} anos"
            : "N/A";

        // Sexo
        String rawSexo =
            fullData['sexo']?.toString().trim().toUpperCase() ?? "";
        if (rawSexo == 'M' || rawSexo.startsWith('MASC')) {
          _userSexo = "Masc";
        } else if (rawSexo == 'F' || rawSexo.startsWith('FEM')) {
          _userSexo = "Fem";
        } else {
          _userSexo = rawSexo.isNotEmpty ? rawSexo : "--";
        }

        // Tipo de Perfil
        var rawTipo =
            fullData['tipo_perfil'] ?? localData['user_tipo_perfil'] ?? '1';
        _userTipoInt = int.tryParse(rawTipo.toString()) ?? 1;

        if (_userTipoInt == 2) {
          _userTipo = "Trilheiro • Guia";
          _isGuiaOnline = localData['status_guia'] == 'disponivel';
        } else if (_userTipoInt == 3) {
          _userTipo = "Trilheiro • Guia • Operador";
        } else {
          _userTipo = "Trilheiro";
        }
      });
    }
  }

  Future<void> _loadLocalDataTrilheiro() async {
    setState(() => _isLoadingLocal = true);
    final total = await dbService.countTotalEvents();
    final pendentes = await dbService.countPendingEvents();
    final ultimo = await dbService.getLastEvent();
    if (mounted) {
      setState(() {
        _totalTagsLidas = total;
        _eventosPendentes = pendentes;
        _ultimaTag = ultimo;
        _isLoadingLocal = false;
      });
    }
  }

  Future<void> _loadHistoricoTrilheiro() async {
    if (!mounted) return;
    setState(() => _isLoadingHistorico = true);
    try {
      final userId = await authService.getLoggedInUserId();
      if (userId != null) {
        final lista = await apiService.getHistoricoTrilhas(userId);
        if (mounted) setState(() => _historicoTrilhas = lista);
      }
    } catch (e) {
      print("Erro histórico: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistorico = false);
    }
  }


  //FUNÇÕES DE FOTO

  Future<void> _pickImage(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (status.isDenied) status = await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      try {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
        );

        if (pickedFile != null) {
          _uploadNewPhoto(File(pickedFile.path));
        }
      } catch (e) {
        print("Erro ao pegar imagem: $e");
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permissão necessária. Vá em Configurações."),
          ),
        );
      }
    }
  }

  Future<void> _uploadNewPhoto(File imagem) async {
    setState(() => _isLoadingLocal = true);
    try {
      final userId = await authService.getLoggedInUserId();
      if (userId != null) {
        final novaUrl = await apiService.atualizarFotoPerfil(
          int.parse(userId),
          imagem,
        );
        await authService.updateUserPhotoSession(novaUrl);
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Foto atualizada!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro upload: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Galeria'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text('Câmera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }

  //FUNÇÕES DE EDIÇÃO DE DADOS
  Future<void> _showEditUserDataDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = await authService.getLoggedInUserId();
      if (userId == null) {
        Navigator.pop(context);
        return;
      }
      final dados = await apiService.getDadosUsuarioCompleto(int.parse(userId));
      Navigator.pop(context);

      final _formKey = GlobalKey<FormState>();
      final txtNome = TextEditingController(text: dados['nome']);
      final txtEmail = TextEditingController(text: dados['email']);
      final txtTelefone = TextEditingController(text: dados['telefone'] ?? "");
      final txtIdade = TextEditingController(
        text: dados['idade']?.toString() ?? "",
      );
      final txtSenha = TextEditingController();
      String? sexoSelecionado = dados['sexo'];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Editar Perfil"),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: txtNome,
                    decoration: const InputDecoration(
                      labelText: "Nome",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: txtIdade,
                    decoration: const InputDecoration(
                      labelText: "Idade",
                      prefixIcon: Icon(Icons.cake),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: (sexoSelecionado == 'M' || sexoSelecionado == 'F')
                        ? sexoSelecionado
                        : null,
                    decoration: const InputDecoration(
                      labelText: "Sexo",
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text("Masculino")),
                      DropdownMenuItem(value: 'F', child: Text("Feminino")),
                    ],
                    onChanged: (v) => sexoSelecionado = v,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: txtTelefone,
                    decoration: const InputDecoration(
                      labelText: "Telefone",
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: txtEmail,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: txtSenha,
                    decoration: const InputDecoration(
                      labelText: "Nova Senha (Opcional)",
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(ctx);
                  Map<String, dynamic> update = {
                    "nome": txtNome.text,
                    "email": txtEmail.text,
                    "telefone": txtTelefone.text,
                    "idade": txtIdade.text,
                    "sexo": sexoSelecionado,
                  };
                  if (txtSenha.text.isNotEmpty) update["senha"] = txtSenha.text;

                  await apiService.atualizarDadosUsuario(
                    int.parse(userId),
                    update,
                  );
                  _loadUserData();
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
    }
  }

  // DETALHES DA TRILHA
  void _mostrarDetalhesTrilha(Map<String, dynamic> trilha) {
    showDialog(
      context: context,
      builder: (context) {
        final inicio = DateTime.parse(trilha['data_inicio']).toLocal();
        final fim = trilha['data_fim'] != null
            ? DateTime.parse(trilha['data_fim']).toLocal()
            : DateTime.now();
        final duracaoReal = fim.difference(inicio);

        return AlertDialog(
          title: Text(trilha['nome_trilha']),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                _buildDialogRow(
                  Icons.terrain,
                  "Dificuldade",
                  trilha['dificuldade'],
                ),
                _buildDialogRow(Icons.category, "Tipo", trilha['tipo']),
                const Divider(),
                _buildDialogRow(
                  Icons.timer,
                  "Duração",
                  "${duracaoReal.inMinutes} min",
                ),
                _buildDialogRow(
                  Icons.calendar_today,
                  "Data",
                  "${inicio.day}/${inicio.month}/${inicio.year}",
                ),
                const Divider(),
                const Text(
                  "Notas:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  trilha['notas'] ?? "Sem notas",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Conta"),
        content: const Text("Tem certeza? Isso apagará tudo."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final userId = await authService.getLoggedInUserId();
    if (userId != null) {
      try {
        await apiService.deletarUsuario(int.parse(userId));
        await authService.logout();
        if (mounted)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (c) => const LoginScreen()),
            (r) => false,
          );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Perfil: $_userTipo',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _themeColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: "Editar",
            onPressed: _showEditUserDataDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),

      body: Column(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            decoration: BoxDecoration(
              color: _themeColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(
                                _userPhotoUrl!.startsWith('http')
                                    ? _userPhotoUrl!
                                    : '${apiService.baseUrl}/uploads/$_userPhotoUrl',
                              )
                            : null,
                        child: (_userPhotoUrl == null)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _showImagePickerModal,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _themeColor, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: _themeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard("Nome", _userName, isDestacado: true),
                      const SizedBox(height: 6),
                      _buildInfoCard("Categoria", _userTipo),
                      const SizedBox(height: 6),
                      _buildInfoCard(
                        "E-mail",
                        _userEmail.length > 25
                            ? "${_userEmail.substring(0, 22)}..."
                            : _userEmail,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildInfoCard("Idade", _userIdade)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildInfoCard("Sexo", _userSexo)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBodyContent(),

                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(
                          Icons.delete_forever,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          "Excluir Conta / Sair",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    return Column(
      children: [
        _buildTrilheiroContent(),
        if (_userTipoInt >= 2) ...[
          const SizedBox(height: 24),
          _buildFuncoesHabilitadas(),
        ],
      ],
    );
  }

  //CONTEÚDO DO TRILHEIRO
  Widget _buildTrilheiroContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Tags Lidas",
                "$_totalTagsLidas",
                Icons.nfc,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                "Pendentes",
                "$_eventosPendentes",
                Icons.cloud_upload,
                _eventosPendentes > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pin_drop, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Último Registro",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_ultimaTag != null) ...[
                  Text(
                    "Tag ID: ${_ultimaTag!['id_tag']}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Direção: ${_ultimaTag!['direcao'].toString().toUpperCase()}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ] else
                  const Text(
                    "Nenhum registro local.",
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Histórico de Aventuras",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        _isLoadingHistorico
            ? const CircularProgressIndicator()
            : _historicoTrilhas.isEmpty
            ? const Text(
                "Nenhuma trilha finalizada.",
                style: TextStyle(color: Colors.grey),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _historicoTrilhas.length,
                itemBuilder: (context, index) {
                  final trilha = _historicoTrilhas[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[50],
                        child: const Icon(Icons.hiking, color: Colors.green),
                      ),
                      title: Text(
                        trilha['nome_trilha'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${trilha['tipo']} • ${trilha['dificuldade']}",
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onTap: () => _mostrarDetalhesTrilha(trilha),
                    ),
                  );
                },
              ),
      ],
    );
  }

  // FUNÇÕES HABILITADAS (Guia / Operador)
  Widget _buildFuncoesHabilitadas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Funções Habilitadas",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        if (_userTipoInt >= 2)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepOrange[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map, color: Colors.deepOrange, size: 28),
              ),
              title: const Text(
                "Painel do Guia",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Agenda, disponibilidade e trilhas guiadas"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GuideScreen()),
              ),
            ),
          ),
        if (_userTipoInt >= 2) const SizedBox(height: 12),
        if (_userTipoInt >= 3)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.blue, size: 28),
              ),
              title: const Text(
                "Painel do Operador de Base",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Gestão de usuários, tags e sistema"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OperatorScreen()),
              ),
            ),
          ),
      ],
    );
  }

  //WIDGETS AUXILIARES
  Widget _buildInfoCard(
    String label,
    String value, {
    bool isDestacado = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isDestacado ? 18 : 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
