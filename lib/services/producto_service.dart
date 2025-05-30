// Archivo: services/producto_service.dart
import '../BD/database.dart';

class ProductoService {
  static Future<double?> getUltimoPrecioProducto(int idProducto) async {
    final db = await DBProvider.getDatabase();
    final res = await db.query('precioProducto', columns: ['precio'], where: 'idProducto = ?', whereArgs: [idProducto], orderBy: 'fecha DESC', limit: 1);
    if (res.isEmpty) return null;
    return (res.first['precio'] as num).toDouble();
  }

  static Future<String?> getDescripcionProducto(int idProducto) async {
    final db = await DBProvider.getDatabase();
    final res = await db.query('producto', columns: ['describcion'], where: 'idproducto = ?', whereArgs: [idProducto], limit: 1);
    if (res.isEmpty) return null;
    final valor = res.first['describcion'];
    return valor != null ? valor.toString() : null;
  }
}