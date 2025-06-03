// models/venta.dart
class Venta {
  final int?      idVenta;
  final DateTime  fecha;
  final int       idcliente;
  final String    folio;
  final int       idchofer;
  final double    total;
  final int       idpago;
  final double?   pagoRecibido;
  final String    clienteNombre;
  final String    metodoPago;
  final double?   cambio;

  Venta({
    this.idVenta,
    required this.fecha,
    required this.idcliente,
    required this.folio,
    required this.idchofer,
    required this.total,
    required this.idpago,
    this.pagoRecibido,
    required this.clienteNombre,
    required this.metodoPago,
    this.cambio,
  });

  factory Venta.fromMap(Map<String, dynamic> m) {
    int parseInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    // 1) Extraemos el valor crudo de 'fecha' del Map
    final dynamic rawFecha = m['fecha'];

    // 2) Convertimos rawFecha a DateTime, según su tipo
    DateTime fecha;
    if (rawFecha is String) {
      // Si viene como String (ej. "2025-06-03T10:00:00"), usamos DateTime.parse
      fecha = DateTime.parse(rawFecha);
    } else if (rawFecha is num) {
      // Si viene como número (milisegundos desde epoch), usamos fromMillisecondsSinceEpoch
      fecha = DateTime.fromMillisecondsSinceEpoch(rawFecha.toInt());
    } else {
      // Por si acaso viene null o algo inesperado, hacemos un fallback (o lanza excepción)
      fecha = DateTime.tryParse(rawFecha.toString()) ?? DateTime.now();
    }

    return Venta(
      idVenta: m['idVenta'] != null ? parseInt(m['idVenta']) : null,
      fecha: fecha,
      idcliente: parseInt(m['idcliente']),
      folio: m['folio'] as String,
      idchofer: parseInt(m['idchofer']),
      total: parseDouble(m['total']),
      idpago: parseInt(m['idpago']),
      pagoRecibido: m['pagoRecibido'] != null
          ? parseDouble(m['pagoRecibido'])
          : null,
      clienteNombre: m['clienteNombre'] as String? ?? '',
      metodoPago:    m['metodoPago']   as String? ?? 'N/A',
      cambio: m['cambio'] != null
          ? parseDouble(m['cambio'])
          : null,
    );
  }


  Map<String, dynamic> toMap() => {
    'fecha':        fecha.millisecondsSinceEpoch,
    'idcliente':    idcliente,
    'folio':        folio,
    'idchofer':     idchofer,
    'total':        total,
    'idpago':       idpago,
    'pagoRecibido': pagoRecibido,
  };
}
