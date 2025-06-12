import '../BD/database.dart';

class ProductoService {
  /// Devuelve el precio más reciente (por kilo) para el idProducto dado,
  /// o null si no existe ninguno.
  static Future<double?> getUltimoPrecioProducto(int idProducto) async {
    final db = await DBProvider.getDatabase();
    // Consulta la columna 'precio', ordenando por fecha descendente
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
