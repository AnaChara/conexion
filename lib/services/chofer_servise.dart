import 'package:device_info_plus/device_info_plus.dart';
import '../BD/database.dart';
import '../models/chofer.dart'; // ✅ Importación del modelo

class ChoferService {
  static Future<String> obtenerIdDispositivo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id ?? 'Desconocido';
  }

  static Future<Chofer?> obtenerUsuarioLocal(String correo) async {
    final db = await DBProvider.getDatabase();
    final result = await db.query(
      'chofer',
      where: 'LOWER(Correo) = ?',
      whereArgs: [correo.toLowerCase()],
    );
    return result.isNotEmpty ? Chofer.fromMap(result.first) : null;
  }

  static Future<Chofer?> getNameByCorreo(String correo) async {
    final db = await DBProvider.getDatabase();
    final res = await db.query('chofer', where: 'Correo = ?', whereArgs: [correo]);
    return res.isNotEmpty ? Chofer.fromMap(res.first) : null;
  }
}
