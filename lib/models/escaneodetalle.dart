// models/escaneo_detalle.dart
class EscaneoDetalle {
  final String qr;
  final double pesoNeto;
  final String descripcion;
  final double importe;
  final int idproducto;
  

  EscaneoDetalle({
    required this.qr,
    required this.pesoNeto,
    required this.descripcion,
    required this.importe,
    required this.idproducto,
  });
}
