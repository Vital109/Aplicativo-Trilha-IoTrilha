// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String _baseUrl = 'http://200.19.144.16:5000';

  final _storage = const FlutterSecureStorage();
  static const _vaultKey = 'mapl_users_vault_v1';

  //MÉTODOS DO COFRE LOCAL
  Future<void> registerLocalUser({
    required String cpf,
    required String email,
    required String realPassword,
  }) async {
    Map<String, dynamic> vault = await _getVault();

    vault[cpf] = {
      'email': email,
      'real_pass': realPassword,
      'local_pass': realPassword,
    };

    await _saveVault(vault);
    print("[AuthService] Usuário CPF $cpf salvo no cofre seguro.");
  }

  Future<String> loginHybrid(String identifier, String passwordInput) async {
    Map<String, dynamic> vault = await _getVault();

    String? foundCpf;
    Map<String, dynamic>? userData;

    if (vault.containsKey(identifier)) {
      foundCpf = identifier;
      userData = vault[identifier];
    } else {
      for (var key in vault.keys) {
        if (vault[key]['email'] == identifier) {
          foundCpf = key;
          userData = vault[key];
          break;
        }
      }
    }

    if (userData != null) {
      print(
        "[AuthService] Usuário encontrado no cofre local (CPF: $foundCpf).",
      );

      if (userData['local_pass'] == passwordInput) {
        print(
          "[AuthService] Senha local correta. Trocando para senha real da API...",
        );
        return await login(userData['email'], userData['real_pass']);
      } else {
        return "Senha incorreta (Validação Local).";
      }
    }

    print(
      "[AuthService] Usuário não está no cofre. Tentando login direto na API...",
    );
    return await login(identifier, passwordInput);
  }

  Future<bool> updateLocalPassword(String cpf, String newPass) async {
    Map<String, dynamic> vault = await _getVault();

    if (!vault.containsKey(cpf)) return false;

    vault[cpf]['local_pass'] = newPass;
    await _saveVault(vault);
    print("[AuthService] Senha local do CPF $cpf atualizada com sucesso.");
    return true;
  }

  Future<bool> checkCpfExistsLocal(String cpf) async {
    Map<String, dynamic> vault = await _getVault();
    return vault.containsKey(cpf);
  }

  Future<Map<String, dynamic>> _getVault() async {
    String? data = await _storage.read(key: _vaultKey);
    if (data == null) return {};
    return jsonDecode(data);
  }

  Future<void> _saveVault(Map<String, dynamic> vault) async {
    await _storage.write(key: _vaultKey, value: jsonEncode(vault));
  }

  //MÉTODOS DE SESSÃO

  Future<void> _saveUserSession(Map<String, dynamic> userData) async {
    await _storage.write(
      key: 'user_id',
      value: userData['id_usuario']?.toString(),
    );
    await _storage.write(key: 'user_nome', value: userData['nome']);
    await _storage.write(key: 'user_email', value: userData['email']);
    await _storage.write(
      key: 'user_tipo_perfil',
      value: userData['tipo_perfil']?.toString(),
    );
    await _storage.write(
      key: 'user_status_guia',
      value: userData['status_guia'] ?? 'offline',
    );
    if (userData['url_foto_perfil'] != null) {
      await _storage.write(
        key: 'user_foto_url',
        value: '$_baseUrl/uploads/${userData['url_foto_perfil']}',
      );
    }
  }

  Future<Map<String, String?>> getUserData() async => await _storage.readAll();

  Future<void> logout() async {
    final all = await _storage.readAll();
    for (var key in all.keys) {
      if (key != _vaultKey) {
        await _storage.delete(key: key);
      }
    }
  }

  Future<String?> getLoggedInUserId() async =>
      await _storage.read(key: 'user_id');
  Future<void> updateUserPhotoSession(String newUrl) async =>
      await _storage.write(key: 'user_foto_url', value: newUrl);

  // MÉTODOS DE API

  Future<String> login(String email, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveUserSession(data);
        return "OK";
      } else {
        return data['erro'] ?? 'Erro desconhecido';
      }
    } catch (e) {
      return "Erro de conexão: $e";
    }
  }

  Future<String> register({
    required String nome,
    required String email,
    required String senha,
    required int tipoPerfil,
    String? telefone,
    String? dataNascimento,
    String? sexo,
    String? adminCode,
    XFile? fotoPerfil,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/register'),
      );
      request.fields['nome'] = nome;
      request.fields['email'] = email;
      request.fields['senha'] = senha;
      request.fields['tipo_perfil'] = tipoPerfil.toString();
      if (telefone != null) request.fields['telefone'] = telefone;
      if (dataNascimento != null) request.fields['data_nascimento'] = dataNascimento;
      if (sexo != null) request.fields['sexo'] = sexo;
      if (adminCode != null) request.fields['admin_code'] = adminCode;
      if (fotoPerfil != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto_perfil', fotoPerfil.path),
        );
      }

      final response = await http.Response.fromStream(await request.send());
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _saveUserSession(data);
        return "OK";
      } else {
        return data['erro'] ?? 'Erro no registro';
      }
    } catch (e) {
      return "Erro de conexão: $e";
    }
  }
}
