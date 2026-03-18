// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:aplicativo_trilha/services/database_service.dart';

class ApiService {
  final String baseUrl = 'http://200.19.144.16:5000';
  final DatabaseService _dbService = DatabaseService.instance;
  Future<dynamic> _fetchWithCache(String endpoint, String cacheKey) async {
    try {
      print("[ApiService] Buscando online: $endpoint");
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          await _dbService.salvarCacheLista(cacheKey, data);
        } else {
          await _dbService.salvarCache(cacheKey, data);
        }
        return data;
      } else {
        throw Exception("Erro HTTP ${response.statusCode}");
      }
    } catch (e) {
      print(
        "[ApiService] Falha na rede ($e). Tentando ler cache local: $cacheKey",
      );

      final cachedData = await _dbService.lerCache(cacheKey);
      if (cachedData != null) {
        print("[ApiService] SUCESSO! Dados recuperados do Cache SQL.");
        return cachedData;
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboardGeral() async {
    return await _fetchWithCache('/api/dashboard/geral', 'dash_geral');
  }

  Future<Map<String, dynamic>> getDashboardDetalhado() async {
    return await _fetchWithCache(
      '/api/dashboard/detalhado',
      'dash_operador_detalhado',
    );
  }

  Future<Map<String, dynamic>> getEventosPorTag(int tagId) async {
    return await _fetchWithCache('/api/eventos/tag/$tagId', 'tag_info_$tagId');
  }

  Future<Map<String, dynamic>> getDetalhesTrilha(int trilhaId) async {
    return await _fetchWithCache(
      '/api/trilha/detalhes/$trilhaId',
      'trilha_detalhes_$trilhaId',
    );
  }

  Future<Map<String, dynamic>> getClima(double lat, double lon) async {
    return await _fetchWithCache('/api/clima?lat=$lat&lon=$lon', 'clima_local');
  }

  Future<Map<String, dynamic>> buscarUsuarioPorCpf(String cpf) async {
    final cpfLimpo = cpf.replaceAll(RegExp(r'\D'), '');
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/usuario/buscar-cpf/$cpfLimpo'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) throw Exception('Usuário não encontrado para o CPF informado.');
      if (response.statusCode != 200) throw Exception('Erro do servidor (${response.statusCode}).');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Resposta inválida do servidor. Verifique se o servidor está atualizado e reiniciado.');
    }
  }

  Future<void> atualizarPerfilUsuario(int userId, int tipoPerfil) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/usuario/$userId/perfil'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'tipo_perfil': tipoPerfil}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(data['erro'] ?? 'Erro ao atualizar perfil');
      }
    } on FormatException {
      throw Exception('Resposta inválida do servidor. Verifique se o servidor está atualizado e reiniciado.');
    }
  }

  Future<List<dynamic>> getUsuarios({int? tipoPerfil}) async {
    String endpoint = '/api/usuarios';
    String key = 'lista_todos_usuarios';

    if (tipoPerfil != null) {
      endpoint += '?tipo_perfil=$tipoPerfil';
      key = 'lista_usuarios_tipo_$tipoPerfil';
    }

    final data = await _fetchWithCache(endpoint, key);
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getHistoricoTrilhas(String userId) async {
    final data = await _fetchWithCache(
      '/api/trilhas/usuario/$userId/historico',
      'historico_trilheiro_$userId',
    );
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getTagsFisicas() async {
    final data = await _fetchWithCache('/api/tags', 'lista_tags_fisicas');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getAgendamentosGuia(int guiaId) async {
    final data = await _fetchWithCache(
      '/api/guia/$guiaId/agendamentos',
      'agenda_guia_$guiaId',
    );
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> iniciarTrilha(
    Map<String, dynamic> dadosTrilha,
  ) async {
    print("[ApiService] Enviando dados para /api/trilha/iniciar");
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trilha/iniciar'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dadosTrilha),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception('Falha ao iniciar trilha: ${data['erro']}');
      }
    } catch (e) {
      print("[ApiService] Exceção: $e");
      throw Exception('Falha ao conectar ao servidor da API');
    }
  }

  Future<void> finalizarTrilha(int trilhaId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trilha/finalizar/$trilhaId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao finalizar trilha: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> atualizarFotoPerfil(int userId, File imagem) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/usuario/$userId/foto'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('foto_perfil', imagem.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url_nova_foto'];
      } else {
        throw Exception('Erro ao atualizar: ${response.body}');
      }
    } catch (e) {
      print("[ApiService] Erro upload: $e");
      rethrow;
    }
  }

  Future<void> deletarTag(int tagId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/tags/$tagId'));
      if (response.statusCode != 200) {
        throw Exception('Falha ao deletar tag');
      }
    } catch (e) {
      print("Erro api deletarTag: $e");
      rethrow;
    }
  }

  Future<int> provisionarTag(String uidHardware) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tags/provisionar'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'uid_hardware': uidHardware}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return data['proximo_id'];
      } else {
        throw Exception('Falha ao provisionar: ${data['erro']}');
      }
    } catch (e) {
      print("Erro api provisionar: $e");
      rethrow;
    }
  }

  Future<void> deletarUsuario(int userId) async {
    print("[ApiService] Deletando conta do usuário $userId");
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/usuario/$userId'),
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['erro'] ?? 'Falha ao deletar conta');
      }
    } catch (e) {
      print("[ApiService] Erro ao deletar usuário: $e");
      rethrow;
    }
  }

  Future<void> updateStatusGuia(int guiaId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/guia/$guiaId/status'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode != 200) {
        throw Exception('Falha ao atualizar status');
      }
    } catch (e) {
      print("Erro api updateStatusGuia: $e");
      rethrow;
    }
  }

  Future<void> atualizarDadosUsuario(
    int userId,
    Map<String, dynamic> dados,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/usuario/$userId/dados'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dados),
      );
      if (response.statusCode != 200) {
        throw Exception('Falha ao atualizar dados: ${response.body}');
      }
    } catch (e) {
      print("Erro atualizarDadosUsuario: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDadosUsuarioCompleto(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/usuario/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao buscar dados do usuário');
      }
    } catch (e) {
      print("Erro getDadosUsuarioCompleto: $e");
      rethrow;
    }
  }

  Future<void> recuperarSenha(String email, String novaSenha) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recuperar-senha'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'nova_senha': novaSenha}),
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['erro'] ?? 'Erro ao redefinir senha');
      }
    } catch (e) {
      print("Erro recuperarSenha: $e");
      rethrow;
    }
  }

  Future<void> atualizarStatusAgendamento(
    int agendamentoId,
    String status,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/agendamento/$agendamentoId/status'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao atualizar status do agendamento');
      }
    } catch (e) {
      print("Erro atualizarStatusAgendamento: $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getAgendamentosPendentes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/agendamentos/pendentes'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao buscar pendentes');
      }
    } catch (e) {
      print("Erro getAgendamentosPendentes: $e");
      rethrow;
    }
  }

  Future<void> atribuirGuia(int agendamentoId, int guiaId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/agendamento/$agendamentoId/atribuir'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'id_guia': guiaId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao atribuir guia');
      }
    } catch (e) {
      print("Erro atribuirGuia: $e");
      rethrow;
    }
  }
}
