class Venta {
  final int?      idVenta;
  final DateTime  fecha;       // ← ahora es DateTime
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

    return Venta(
      idVenta: m['idVenta'] != null ? parseInt(m['idVenta']) : null,
      // parseamos el TEXT SQLite a DateTime
      fecha: DateTime.parse(m['fecha'] as String),
      idcliente: parseInt(m['idcliente']),
      folio: m['folio'] as String,
      idchofer: parseInt(m['idchofer']),
      total: parseDouble(m['total']),
      idpago: parseInt(m['idpago']),
      pagoRecibido: m['pagoRecibido'] != null
          ? parseDouble(m['pagoRecibido'])
          : null,
      clienteNombre: m['clienteNombre'] as String? ?? '',
      metodoPago:    m['metodoPago']    as String? ?? 'N/A',
      cambio:       m['cambio'] != null
          ? parseDouble(m['cambio'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'idVenta':    idVenta,
    // si vuelves a guardar fecha, puedes usar:
    // 'fecha': fecha.toIso8601String(),
    'idcliente':  idcliente,
    'folio':      folio,
    'idchofer':   idchofer,
    'total':      total,
    'idpago':     idpago,
    'pagoRecibido': pagoRecibido,
  };
}
