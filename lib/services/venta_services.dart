import 'dart:convert';

import 'package:conexion/services/ventadetalle_services.dart';
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

    // 🔍 Verifica que se guardó correctamente (incluyendo metodoPago)
    final rows = await db.query(
      'Venta',
      where: 'idVenta = ?',
      whereArgs: [nuevoId],
    );
    if (rows.isNotEmpty) {
      print('✅ Venta almacenada:');
      print(rows.first); // Aquí verás metodoPago y demás campos
    }

    return nuevoId;
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

  // Devuelve la última venta como objeto Venta (o null si no hay ninguna)
  static Future<Venta?> obtenerUltimaVenta() async {
    final map = await obtenerUltimaVentaComoMap();
    if (map == null) return null;
    return Venta.fromMap(map);
  }

  //Obtener ventas por el id del chofer
  static Future<List<Map<String, dynamic>>> obtenerVentasPorChofer(int idChofer) async {
    final db = await DBProvider.getDatabase();
    return await db.rawQuery('''
    SELECT 
      v.*, 
      c.nombreCliente AS clienteNombre, 
      c.RFC AS rfcCliente, 
      c.calleNumero AS direccionCliente
    FROM Venta v
    JOIN Clientes c ON v.idcliente = c.idcliente
    WHERE v.idchofer = ?
    ORDER BY v.fecha DESC
  ''', [idChofer]);
  }

  //Contar las ventas
  static Future<int> contarVentasDelDiaPorFolio(String prefijo, DateTime fecha) async {
    final db = await DBProvider.getDatabase();
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString().substring(2);

    final baseFolio = '$prefijo$anio$mes$dia';

    final result = await db.rawQuery('''
    SELECT COUNT(*) as total FROM Venta 
    WHERE folio LIKE ?
  ''', ['$baseFolio%']);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> generarJsonSinRepetir({int tamanoGrupo = 2}) async {
    final idChofer = UsuarioActivo.idChofer;
    if (idChofer == null) {
      print('❌ Chofer no autenticado.');
      return;
    }

    final db = await DBProvider.getDatabase();

    // Obtener todas las ventas NO sincronizadas (jsonSync = 0)
    final ventasNoSync = await db.rawQuery('''
  SELECT 
    v.*, 
    c.nombreCliente AS clienteNombre,
    f.Describcion AS metodoPago,
    c.RFC AS rfcCliente,
    c.calleNumero || ', ' || c.ciudad || ', ' || c.estado AS direccionCliente,
    CASE 
      WHEN v.idpago = 1 THEN v.pagoRecibido - v.total 
      ELSE NULL 
    END AS cambio
  FROM Venta v
  LEFT JOIN Clientes c ON v.idcliente = c.idcliente
  LEFT JOIN formaPago f ON v.idpago = f.idpago
  WHERE v.idchofer = ? AND v.jsonSync = 0
  ORDER BY v.fecha ASC
''', [idChofer]);


    final ventas = ventasNoSync.map((m) => Venta.fromMap(m)).toList();

    if (ventas.isEmpty) {
      print('⚠️ No hay ventas nuevas para generar JSON.');
      return;
    }

    // Agrupar de N en N
    for (int i = 0; i < ventas.length; i += tamanoGrupo) {
      final grupo = ventas.skip(i).take(tamanoGrupo).toList();

      // Si no hay suficientes para un grupo completo, detenemos
      if (grupo.length < tamanoGrupo) break;

      double totalVendido = 0.0;
      List<Map<String, dynamic>> listaVentasJson = [];

      for (final venta in grupo) {
        final detalles = await VentaDetalleService.getByFolio(venta.folio);

        totalVendido += venta.total;

        final detallesJson = detalles.map((d) => {
          'Producto': d.descripcion ?? '—',
          'pesoNeto': d.pesoNeto,
          'precioKg': d.precio,
          'Total': d.subtotal
        }).toList();

        listaVentasJson.add({
          'EncabezadoVenta': {
            'Total': venta.total,
            'Folio': venta.folio,
            'Cliente': venta.clienteNombre,
            'TipoPago': venta.metodoPago,
            'DetalleVenta': detallesJson
          }
        });
      }

      final jsonCompleto = {
        'idChofer': idChofer,
        'totalVendido': totalVendido,
        'ventas': listaVentasJson,
      };

      // 👉 Mostrar en consola
      print('🧾 JSON generado (sin repetir):');
      print(const JsonEncoder.withIndent('  ').convert(jsonCompleto));

      // ✅ Marcar como sincronizadas
      final batch = db.batch();
      for (final venta in grupo) {
        batch.update(
          'Venta',
          {'jsonSync': 1},
          where: 'idVenta = ?',
          whereArgs: [venta.idVenta],
        );
      }
      await batch.commit(noResult: true);
    }
  }



}
