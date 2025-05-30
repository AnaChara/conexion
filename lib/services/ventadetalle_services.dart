
import 'package:sqflite/sqflite.dart';
import '../BD/database.dart';
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
    final rows = await db.rawQuery('''
    SELECT 
      vd.idvd,
      vd.idVenta,
      vd.qr,
      vd.pesoNeto,
      vd.subtotal,
      vd.status,
      vd.idproducto,
      vd.folio,
      p.describcion    AS descripcion   -- nombre de columna de tu tabla producto
    FROM ventaDetalle vd
    JOIN producto p 
      ON vd.idproducto = p.idproducto
    WHERE vd.folio = ?
    ORDER BY vd.idvd ASC
  ''', [folio]);

    return rows
        .map((m) => VentaDetalle.fromMap(Map<String, dynamic>.from(m)))
        .toList();
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
}
