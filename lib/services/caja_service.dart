// Archivo: services/caja_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:conexion/services/producto_service.dart';
import 'package:conexion/services/ventadetalle_services.dart';
import 'package:sqflite/sqflite.dart';
import '../BD/database.dart';
import '../BD/global.dart';
import '../models/ventadetalle.dart';
import 'auth_service.dart';
import '../models/caja.dart';


class CajaService {

  static Future<void> insertarCajaFolioChofer(Caja caja) async {
    final db = await DBProvider.getDatabase();
    await db.insert(
      'CajasFolioChofer',
      caja.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  static Future<Caja?> obtenerCajaPorQR(String qr) async {
    final db = await DBProvider.getDatabase();

    final local = await db.query(
      'CajasFolioChofer',
      where: 'qr = ?',
      whereArgs: [qr],
    );

    if (local.isNotEmpty) {
      return Caja.fromMap(local.first);
    }

    return null; // Ya no consultamos la nube
  }




  static Future<bool> qrExisteEnLaNube(String qr) async {
    final url = Uri.parse('http://avesyaves.com/saldo/api/vr/folioLogin');
    final correo = UsuarioActivo.correo;
    if (correo == null) return false;
    final response = await AuthService.postWithToken(correo, url, {'folio': 'sv250501.1'});
    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body);
    if (data is Map && data['Result'] is List) {
      return (data['Result'] as List).any((item) => item['qr'] == qr);
    }
    return false;
  }

  //Nos encargamos de buscar las cajas en la nube
  static Future<List<Caja>> buscarCajasEnLaNube(String qr) async {
    final url = Uri.parse('http://avesyaves.com/saldo/api/vr/folioLogin');
    final correo = UsuarioActivo.correo;
    if (correo == null) throw Exception('Usuario no autenticado');

    final response = await AuthService.postWithToken(
      correo,
      url,
      {
        'folio': 'sv250501.1',
        'qr': qr,               // muy importante enviar el qr
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Código ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    if (json is Map && json['Result'] is List) {
      return (json['Result'] as List)
          .map((item) => Caja.fromMap(item)) // o fromJson, como lo tengas
          .toList();
    }
    return [];
  }

  static String generarFolioCV(String qr) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hash = qr.hashCode.abs(); // siempre positivo
    final unico = (now + hash) % 1000000; // máximo 6 dígitos
    final numero = unico.toString().padLeft(6, '0');
    return 'CV$numero';
  }


  static Map<String, String> parseQrData(String qr) {
    final cleaned = qr.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = cleaned.indexOf('.');
    if (dot < 2 || cleaned.length < dot + 3) {
      throw FormatException('QR en formato inesperado');
    }

    final neto = cleaned.substring(dot - 2, dot + 3);
    final before = cleaned.substring(0, dot - 2);
    final after = cleaned.substring(dot + 3);
    final resto = before + after;

    final subLen = resto.length >= 4 ? 4 : resto.length;
    final subtotal = resto.substring(0, subLen);
    final folio = subLen < resto.length ? resto.substring(subLen) : '';

    return {
      'neto': neto,
      'subtotal': subtotal,
      'folio': folio,
    };
  }


  static Future<void> sincronizarDesdeServidor() async {
    final correo = UsuarioActivo.correo;
    if (correo == null) {
      print('⚠️ No hay usuario activo para sincronizar');
      return;
    }

    final db = await DBProvider.getDatabase();

    // 🔍 1. Revisar última sincronización
    final meta = await db.query('Meta', where: 'clave = ?', whereArgs: ['ultima_sync']);
    if (meta.isNotEmpty) {
      final valor = meta.first['valor']?.toString() ?? '';
      final ultimaSync = DateTime.tryParse(valor);
      final ahora = DateTime.now();
      final hoy8AM = DateTime(ahora.year, ahora.month, ahora.day, 8);

      if (ultimaSync != null && ultimaSync.isAfter(hoy8AM)) {
        print('🕗 Ya se sincronizó hoy después de las 8:00 AM. No se repite.');
        return;
      }
    }

    // 🛰️ 2. Consultar servidor
    final url = Uri.parse('http://avesyaves.com/saldo/api/vr/folioLogin');

    try {
      final response = await AuthService.postWithToken(correo, url, {
        'folio': 'sv250501.1',
      });

      if (response.statusCode != 200) {
        print('⚠️ Error al obtener datos del servidor: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      if (data is! Map || data['Result'] is! List) {
        print('⚠️ Respuesta inesperada del servidor');
        return;
      }

      final List resultado = data['Result'];
      print('📦 Cajas recibidas del servidor: ${resultado.length}');

      int cajasInsertadas = 0;

      for (var item in resultado) {
        final qr = item['qr'];
        if (qr == null || qr is! String) {
          print('❌ Item sin QR válido: $item');
          continue;
        }

        final existe = await db.query('CajasFolioChofer', where: 'qr = ?', whereArgs: [qr]);
        if (existe.isNotEmpty) {
          print('ℹ️ Caja ya existe localmente: $qr');
          continue;
        }

        final now = DateTime.now();
        final folioGenerado = generarFolioCV(qr);

        final nuevaCaja = Caja(
          qr: qr,
          folio: folioGenerado,
          createe: DateTime.now().millisecondsSinceEpoch,
          sync: 1,
          fechaEscaneo: now.toIso8601String(),
        );
        await db.insert('CajasFolioChofer', nuevaCaja.toMap());
        cajasInsertadas++;
        print('✅ Caja insertada: ${nuevaCaja.qr} -> ${nuevaCaja.folio}');

        try {
          final datosQr = parseQrData(qr);
          final pesoNeto = double.tryParse(datosQr['neto'] ?? '0.0') ?? 0.0;
          final folioReal = datosQr['folio'] ?? '';
          final precio = await ProductoService.getUltimoPrecioProducto(501) ?? 0.0;
          final subtotal = pesoNeto * precio;

          final detalle = VentaDetalle(
            idvd: null,
            idVenta: null,
            qr: qr,
            pesoNeto: pesoNeto,
            subtotal: subtotal,
            status: 'Inventario',
            idproducto: 501,
            folio: folioReal,
            precio: precio,
          );
          await VentaDetalleService.insertarDetalle(detalle);
          print('🧾 VentaDetalle insertado: peso=$pesoNeto, precio=$precio, subtotal=$subtotal');
        } catch (e) {
          print('❗ Error al procesar QR: $qr -> $e');
        }
      }

      if (cajasInsertadas > 0) {
        await db.insert(
          'Meta',
          {
            'clave': 'ultima_sync',
            'valor': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('🕘 Se actualizó la fecha de sincronización.');
      } else {
        print('📭 No se insertaron nuevas cajas. Fecha de sincronización no actualizada.');
      }

      print('✅ Sincronización completada con $cajasInsertadas nuevas cajas.');
    } catch (e, st) {
      print('‼️ Error al sincronizar: $e\n$st');
    }
  }



}