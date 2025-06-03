// Archivo: services/caja_service.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../BD/database.dart';
import '../BD/global.dart';
import 'auth_service.dart';
import '../models/caja.dart';


class CajaService {
  static Future<void> insertarCajaFolioChofer(Caja caja) async {
    final db = await DBProvider.getDatabase();
    await db.insert(
      'CajasFolioChofer',
      caja.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  static Future<Caja?> obtenerCajaPorQR(String qr) async {
    final db = await DBProvider.getDatabase();

    // 1) Primero: busco en local
    final local = await db.query(
      'CajasFolioChofer',
      where: 'qr = ?',
      whereArgs: [qr],
    );
    if (local.isNotEmpty) {
      return Caja.fromMap(local.first);
    }

    // 2) Si no existe localmente, voy al servidor
    try {
      // Opción A: solo comprobar existencia remota
      final existe = await qrExisteEnLaNube(qr);
      if (!existe) return null;

      //traer datos completos de la caja desde la nube
      final remotas = await buscarCajasEnLaNube(qr);
      if (remotas.isEmpty) return null;

      final cajaRemota = remotas.first;

      // 3) (Opcional) Guardar esa caja remota en local para la próxima vez
      await db.insert(
        'CajasFolioChofer',
        cajaRemota.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return cajaRemota;
    } catch (e) {
      // Si falla la llamada remota, devolvemos null o manejamos el error a tu gusto
      print('Error al buscar QR en la nube: $e');
      return null;
    }
  }



  static Future<bool> qrExisteEnLaNube(String qr) async {
    final url = Uri.parse('http://avesyaves.com/saldo/api/vr/folioLogin');
    final correo = UsuarioActivo.correo;
    if (correo == null) return false;
    final response = await AuthService.postWithToken(correo, url, {'folio': 'sv250501.1'});
    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body);
    if (data is Map && data['Result'] is List) {
      return (data['Result'] as List).any((item) => item['qr'] == qr);
    }
    return false;
  }

  //Nos encargamos de buscar las cajas en la nube
  static Future<List<Caja>> buscarCajasEnLaNube(String qr) async {
    final url = Uri.parse('http://avesyaves.com/saldo/api/vr/folioLogin');
    final correo = UsuarioActivo.correo;
    if (correo == null) throw Exception('Usuario no autenticado');

    final response = await AuthService.postWithToken(
      correo,
      url,
      {
        'folio': 'sv250501.1',
        'qr': qr,               // muy importante enviar el qr
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Código ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    if (json is Map && json['Result'] is List) {
      return (json['Result'] as List)
          .map((item) => Caja.fromMap(item)) // o fromJson, como lo tengas
          .toList();
    }
    return [];
  }
}