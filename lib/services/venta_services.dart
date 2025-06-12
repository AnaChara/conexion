import 'package:sqflite/sqflite.dart';

import '../BD/database.dart';
import '../BD/global.dart';
import '../models/venta.dart';
import '../models/ventadetalle.dart';

class VentaService {

  /// Inserta la venta en la tabla `Venta` y regresa el id generado (idVenta).
  static Future<int> insertarVenta(Venta venta) async {
    final db = await DBProvider.getDatabase();
    final nuevoId = await db.insert(
      'Venta',
      venta.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return nuevoId;  // <-- aquí devuelves el id para usarlo luego
  }


  static Future<List<Map<String, dynamic>>> obtenerVentasPorCorreo(String correo) async {
    final db = await DBProvider.getDatabase();
    return await db.rawQuery(r'''
    SELECT
      v.*,
      c.nombreCliente    AS clienteNombre,
      c.RFC             AS rfcCliente,
      c.calleNumero || ', ' || c.ciudad || ', ' || c.estado AS direccionCliente,
      f.Describcion      AS metodoPago,
      v.pagoRecibido     AS pagoRecibido,
      CASE 
        WHEN v.idpago = 1 THEN v.pagoRecibido - v.total 
        ELSE NULL 
      END AS cambio
    FROM Venta v
    LEFT JOIN Clientes   c ON v.idcliente = c.idcliente
    LEFT JOIN formaPago  f ON v.idpago    = f.idpago
    JOIN chofer          ch ON v.idchofer  = ch.idChofer
    WHERE ch.Correo = ?
    ORDER BY v.fecha DESC
  ''', [correo]);
  }


  //actualizarFolio
  static Future<int> actualizarFolio(int idVenta, String folio) async {
    final db = await DBProvider.getDatabase();
    return await db.update(
      'Venta',
      {'folio': folio},
      where: 'idVenta = ?',
      whereArgs: [idVenta],
    );
  }

  /// Devuelve el último registro insertado en Venta, según fecha descendente.
  static Future<Map<String, dynamic>?> obtenerUltimaVentaComoMap() async {
  final db = await DBProvider.getDatabase();
  final rows = await db.rawQuery(r'''
      SELECT
        v.idVenta,
        v.fecha,
        v.idcliente,
        v.folio,
        v.idchofer,
        v.total,
        v.idpago,
        v.pagoRecibido
      FROM Venta v
      ORDER BY fecha DESC
      LIMIT 1;
    ''');
  if (rows.isEmpty) return null;
  return Map<String, dynamic>.from(rows.first);
  }

  /// Devuelve la última venta como objeto Venta (o null si no hay ninguna)
  static Future<Venta?> obtenerUltimaVenta() async {
    final map = await obtenerUltimaVentaComoMap();
    if (map == null) return null;
    return Venta.fromMap(map);
  }

}
