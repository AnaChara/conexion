import 'package:sqflite/sqflite.dart';

import '../BD/database.dart';
import '../BD/global.dart';
import '../models/venta.dart';
import '../models/ventadetalle.dart';

class VentaService {
  static Future<int> insertarVenta(Venta venta) async {
    final db = await DBProvider.getDatabase();
    return await db.insert('Venta', venta.toMap());
  }

  static Future<List<Map<String, dynamic>>> obtenerVentasPorCorreo(String correo) async {
    final db = await DBProvider.getDatabase();
    return await db.rawQuery(r'''
      SELECT
        v.*,
        c.nombreCliente    AS clienteNombre,
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
}
