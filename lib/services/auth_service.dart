import 'dart:convert';
import 'package:http/http.dart' as http;
import '../BD/database.dart';
import '../BD/global.dart';
import '../models/chofer.dart'; // 👈 Importamos el modelo
import '../services/chofer_servise.dart';

class AuthService {
  static Future<Map<String, dynamic>?> loginApi(String email, String password /*, String deviceId*/) async {
    final url = Uri.parse('http://avesyaves.com/saldo/api/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
         /* 'device_id':deviceId,*/
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 👇 Integramos el modelo
        final Chofer? choferLocal = await ChoferService.getNameByCorreo(email);
        if (choferLocal != null) {
          await AuthService.updateTokenByCorreo(email, data['access_token']);
        }

        return {
          'token': data['access_token'],
          'tipo': data['tipo'],
          'user': data['user'],
          'pase': data['pase'],
          'expires_at': data['expires_at'],
          'correo': email,
          'nombre': choferLocal?.nombre, // 👈 Ahora usando el modelo
        };
      }
    } catch (e) {
      print('Error en loginApi: $e');
    }

    return null;
  }

  static Future<int> updateTokenByCorreo(String correo, String token) async {
    final db = await DBProvider.getDatabase();
    return await db.update('chofer', {'Token': token}, where: 'Correo = ?', whereArgs: [correo]);
  }

  static Future<String?> getTokenByCorreo(String correo) async {
    final db = await DBProvider.getDatabase();
    final res = await db.query('chofer', columns: ['Token'], where: 'Correo = ?', whereArgs: [correo]);
    if (res.isNotEmpty) return res.first['Token'] as String;
    return null;
  }

  static Future<http.Response> getWithToken(String correo, Uri url) async {
    final token = await getTokenByCorreo(correo);
    if (token == null) throw Exception('Token no encontrado para el correo $correo');

    return await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  static Future<http.Response> postWithToken(String correo, Uri url, Map<String, dynamic> body) async {
    final token = await getTokenByCorreo(correo);
    if (token == null) throw Exception('Token no encontrado para el correo $correo');

    return await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
}
