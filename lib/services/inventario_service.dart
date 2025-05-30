// services/inventario_service.dart
import 'dart:convert';
import '../BD/database.dart';
import '../models/caja.dart';
import 'auth_service.dart';

class InventarioService {
  static Future<List<Caja>> getDatosInventario(String correo, String folio) async {
    final db = await DBProvider.getDatabase();

    // 1) Locales
    final localRows = await db.query(
      'CajasFolioChofer',
      where: 'folio = ?',
      whereArgs: [folio],
    );
    final locales = localRows.map((r) => Caja.fromMap(r)).toList();

    // 2) Remotos
    final url  = Uri.parse('https://avesyaves.com/saldo/api/vr/folioLogin');
    final resp = await AuthService.postWithToken(correo, url, {'folio': folio});
    final remotos = <Caja>[];
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is Map && data['Result'] is List) {
        remotos.addAll((data['Result'] as List)
            .whereType<Map<String, dynamic>>()
            .map((j) => Caja.fromJson(j)));
      }
    }

    return [...locales, ...remotos];
  }
}
