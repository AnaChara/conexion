
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../BD/database.dart';
import '../models/caja.dart';
import '../models/ventadetalle.dart';

class VentaDetalleService {
  /// Inserta o reemplaza un detalle de venta individual
  static Future<void> insertarDetalle(VentaDetalle detalle) async {
    final db = await DBProvider.getDatabase();
    await db.insert(
      'ventaDetalle',
      detalle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta o reemplaza múltiples detalles de venta en batch
  static Future<void> insertarDetalles(List<VentaDetalle> detalles) async {
    final db = await DBProvider.getDatabase();
    final batch = db.batch();
    for (var d in detalles) {
      batch.insert(
        'ventaDetalle',
        d.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Obtiene un detalle de venta por su código QR
  static Future<VentaDetalle?> getByQR(String qr) async {
    final db   = await DBProvider.getDatabase();
    final rows = await db.query(
      'ventaDetalle',
      where: 'qr = ?',
      whereArgs: [qr],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    // rows.first es Map<String,Object?>, casteamos a Map<String,dynamic>
    return VentaDetalle.fromMap(Map<String, dynamic>.from(rows.first));
  }

  /// Alias con nombre más explícito
  static Future<VentaDetalle?> getVentaDetallePorQR(String qr) =>
      getByQR(qr);

  /// Obtiene todos los detalles de una venta dado su folio
  static Future<List<VentaDetalle>> getByFolio(String folio) async {
    final db = await DBProvider.getDatabase();
    final raws = await db.rawQuery(r'''
    SELECT
      vd.idvd,
      vd.idVenta,
      vd.qr,
      vd.pesoNeto,
      vd.subtotal,
      vd.status,
      vd.idproducto,
      vd.folio,
      p.describcion AS descripcion, -- ✅ corregido aquí
      (
        SELECT precio
        FROM precioProducto
        WHERE idProducto = vd.idproducto
        ORDER BY fecha DESC
        LIMIT 1
      ) AS precio
    FROM ventaDetalle vd
    JOIN producto p ON vd.idproducto = p.idproducto
    WHERE vd.folio = ?
  ''', [folio]);

    return raws.map((m) => VentaDetalle.fromMap(m)).toList();
  }




  /// Actualiza un detalle de venta existente
  static Future<int> updateDetalle(VentaDetalle detalle) async {
    final db = await DBProvider.getDatabase();
    return await db.update(
      'ventaDetalle',
      detalle.toMap(),
      where: 'idvd = ?',
      whereArgs: [detalle.idvd],
    );
  }

  /// Elimina un detalle de venta por su ID
  static Future<int> deleteDetalle(int idvd) async {
    final db = await DBProvider.getDatabase();
    return await db.delete(
      'ventaDetalle',
      where: 'idvd = ?',
      whereArgs: [idvd],
    );
  }

  // Datos insertados en ventadetalle
  static Future<List<Map<String, dynamic>>> obtenerTodosLosDetallesComoMap() async {
    final db = await DBProvider.getDatabase();
    return await db.query(
      'ventaDetalle',
      orderBy: 'idvd ASC', // opcional: orden por idvd ascendente
    );
  }

  static Future<List<VentaDetalle>> getDetallesPorQR(String qrBuscado) async {
    final db = await DBProvider.getDatabase();
    final resultados = await db.query(
      'ventaDetalle',  // Nombre real de tu tabla
      columns: [
        'idvd',
        'idVenta',
        'qr',
        'pesoNeto',    // Asegúrate de usar exactamente tu nombre de columna
        'subtotal',
        'status',
        'idproducto',
        'folio',
      ],
      where: 'qr = ?',      // Filtramos por QR
      whereArgs: [qrBuscado],
    );
    return resultados.map((m) => VentaDetalle.fromMap(m)).toList();
  }

  //Función para contar cajas por descripción
  static Future<Map<String, int>> contarCajasPorDescripcionInventario() async {
    final db = await DBProvider.getDatabase();

    final resultado = await db.rawQuery('''
    SELECT p.describcion AS descripcion, COUNT(*) AS cantidad
    FROM ventaDetalle vd
    JOIN producto p ON vd.idproducto = p.idproducto
    WHERE vd.status = 'Inventario'
    GROUP BY p.describcion
  ''');

    // Convertimos el resultado en un mapa tipo { "Mango": 5, "Manzana": 3 }
    final Map<String, int> conteo = {};
    for (var fila in resultado) {
      final descripcion = fila['descripcion'] as String;
      final cantidad = fila['cantidad'] as int;
      conteo[descripcion] = cantidad;
    }

    return conteo;
  }

  //Metodo para obtener las cajas por el id del producto
  static Future<List<Caja>> getCajasInventarioPorIdProducto(int idProducto) async {
    final db = await DBProvider.getDatabase();
    final resultado = await db.rawQuery('''
    SELECT c.id, c.createe, c.qr, c.folio, c.sync, c.fechaEscaneo
    FROM ventaDetalle vd
    JOIN CajasFolioChofer c ON vd.qr = c.qr
    WHERE vd.idproducto = ? AND vd.status = 'Inventario'
  ''', [idProducto]);

    return resultado.map((row) => Caja.fromMap(row)).toList();
  }

  //Actualizar status por QR
  static Future<void> actualizarStatusPorQR(String qr, String nuevoStatus) async {
    final db = await DBProvider.getDatabase();
    await db.update(
      'ventaDetalle',
      {'status': nuevoStatus},
      where: 'qr = ?',
      whereArgs: [qr],
    );
  }

  //Obtener resumen de productos vendidos
  static Future<List<Map<String, dynamic>>> contarCajasVendidasPorFecha(DateTime fecha) async {
    final db = await DBProvider.getDatabase();
    final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);

    final resultado = await db.rawQuery('''
    SELECT 
      p.describcion AS descripcion, 
      COUNT(*) AS cantidad, 
      SUM(vd.pesoNeto) AS pesoTotal,
      SUM(vd.subtotal) AS subtotalReal,  -- ✅ esto es lo importante
      MAX(vd.precio) AS precio
    FROM ventaDetalle vd
    JOIN producto p ON vd.idproducto = p.idproducto
    JOIN Venta v ON v.idVenta = vd.idVenta
    WHERE vd.status = 'Vendido' 
      AND strftime('%Y-%m-%d', v.fecha / 1000, 'unixepoch') = ?
    GROUP BY p.describcion
  ''', [fechaStr]);

    return resultado;
  }


  //Obtener las cajas por cada venta
  static Future<int> contarCajasPorIdVenta(int idVenta) async {
    final db = await DBProvider.getDatabase();
    final resultado = await db.rawQuery('''
    SELECT COUNT(*) as total
    FROM ventaDetalle
    WHERE idVenta = ? AND status = 'Vendido'
  ''', [idVenta]);

    return Sqflite.firstIntValue(resultado) ?? 0;
  }

  //calculando el total xd
  static Future<double> calcularTotalPorMetodoPago(DateTime fecha, String metodoPago) async {
    final db = await DBProvider.getDatabase();
    final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);

    final resultado = await db.rawQuery('''
    SELECT SUM(vd.subtotal) as total
    FROM ventaDetalle vd
    JOIN Venta v ON v.idVenta = vd.idVenta
    WHERE v.metodoPago = ?
      AND vd.status = 'Vendido'
      AND strftime('%Y-%m-%d', v.fecha / 1000, 'unixepoch') = ?
  ''', [metodoPago, fechaStr]);

    return (resultado.first['total'] as num?)?.toDouble() ?? 0.0;
  }




}
