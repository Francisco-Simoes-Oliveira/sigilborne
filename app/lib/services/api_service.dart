import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final token = await user.getIdToken();

    if (token == null) {
      throw Exception('Não foi possível obter o token.');
    }

    return token;
  }

  Future<Map<String, dynamic>> getMe() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final token = await user.getIdToken();

    if (token == null) {
      throw Exception('Não foi possível obter o token do usuário.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Erro ao acessar API.');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<List<dynamic>> getClasses() async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/api/classes'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Erro ao carregar classes.');
    }

    return data['classes'];
  }

  Future<Map<String, dynamic>> createCharacter({
    required String name,
    required String classId,
  }) async {
    final token = await _getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/api/characters'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'classId': classId}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Erro ao criar personagem.');
    }

    return Map<String, dynamic>.from(data);
  }
}
