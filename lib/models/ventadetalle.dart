class VentaDetalle {
  final int? idvd;
  final int? idVenta;
  final String qr;
  final double pesoNeto;
  final double subtotal;
  final String status;
  final int idproducto;
  final String folio;
  final String? descripcion;
  final double precio;

  VentaDetalle({
    this.idvd,
    this.idVenta,
    required this.qr,
    required this.pesoNeto,
    required this.subtotal,
    this.status = 'Inventario',
    required this.idproducto,
    required this.folio,
    this.descripcion,
    this.precio = 0.0,
  });


  /// Para mapear desde SQLite
  factory VentaDetalle.fromMap(Map<String, dynamic> m) => VentaDetalle(
    idvd:      m['idvd']       as int?,
    idVenta:   m['idVenta']    as int?,
    qr:        m['qr']         as String,
    pesoNeto:  (m['pesoNeto']   as num).toDouble(),
    subtotal:  (m['subtotal']   as num).toDouble(),
    status:    m['status']     as String,
    idproducto:(m['idproducto']as int),
    folio:     m['folio']      as String,
      descripcion:m['descripcion'] as String?,
      precio:    (m['precio']   as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toMap() => {
    'idvd': idvd,
    'idVenta': idVenta,
    'qr': qr,
    'pesoNeto': pesoNeto,
    'subtotal': subtotal,
    'status': status,
    'idproducto': idproducto,
    'folio': folio,
    'precio': precio,
  };
}
