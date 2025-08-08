import '../BD/database.dart';

class PrecioProductoService {
  static Future<double?> getUltimoPrecioProducto(int idProducto) async {
    final db = await DBProvider.getDatabase();
    final rows = await db.query(
      'precioProducto',
      columns: ['precio'],
      where: 'idproducto = ?',
      whereArgs: [idProducto],
      orderBy: 'fecha DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return (rows.first['precio'] as num).toDouble();
    }
    return null;
  }
}
