import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../BD/database.dart';
import '../models/cliente.dart';

class ClienteService {
  static const _endpoint = 'https://avesyaves.com/saldo/api/rutaChofer/clientes/VTH12';

  static Future<void> syncClientes({
    Duration refreshInterval = const Duration(hours: 168),
  }) async {
    final prefs    = await SharedPreferences.getInstance();
    final last     = prefs.getString('clientes_last_sync');
    final lastSync = last == null ? null : DateTime.tryParse(last);

    final db    = await DBProvider.getDatabase();
    final count = await firstIntValueFromRawQuery(db, 'SELECT COUNT(*) FROM Clientes') ?? 0;

    if (count > 0 &&
        lastSync != null &&
        DateTime.now().difference(lastSync) < refreshInterval) {
      return;
    }

    final resp = await http.get(Uri.parse(_endpoint));
    if (resp.statusCode != 200) {
      throw Exception('Error al cargar clientes: ${resp.statusCode}');
    }

    final decoded = json.decode(resp.body);
    late final List<dynamic> rawList;

    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['clientes'] is List) {
      rawList = decoded['clientes'];
    } else {
      throw Exception('Formato de respuesta inesperado: ${resp.body}');
    }

    final clientes = rawList
        .map((j) => Cliente.fromJson(j as Map<String, dynamic>))
        .toList();

    await guardarClientesEnLocal(clientes);
    await prefs.setString('clientes_last_sync', DateTime.now().toIso8601String());
  }

  static Future<void> guardarClientesEnLocal(List<Cliente> clientes) async {
    final db = await DBProvider.getDatabase();
    await db.transaction((txn) async {
      for (final c in clientes) {
        await txn.insert(
          'Clientes',
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<Cliente>> obtenerClientes() async {
    final db = await DBProvider.getDatabase();
    final rows = await db.query('Clientes');
    return rows.map((row) => Cliente.fromMap(row)).toList();
  }

  //Metodo que ayuda para ejecutar consultas SQL que devuelven un valor numerico y lo extraen como int
  static Future<int?> firstIntValueFromRawQuery(Database db, String query) async {
    final rows = await db.rawQuery(query);
    if (rows.isEmpty) return null;
    final value = rows.first.values.first;
    return value is int ? value : int.tryParse(value.toString());
  }
}
