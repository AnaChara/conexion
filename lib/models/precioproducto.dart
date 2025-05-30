class PrecioProducto {
  final int idproducto;
  final double precio;
  final String fecha;

  PrecioProducto({
    required this.idproducto,
    required this.precio,
    required this.fecha,
  });

  factory PrecioProducto.fromMap(Map<String, dynamic> map) => PrecioProducto(
    idproducto: map['idproducto'],
    precio: map['precio'],
    fecha: map['fecha'],
  );

  Map<String, dynamic> toMap() => {
    'idproducto': idproducto,
    'precio': precio,
    'fecha': fecha,
  };
}