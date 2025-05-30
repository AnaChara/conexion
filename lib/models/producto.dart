class Producto {
  final int idproducto;
  final String describcion;

  Producto({
    required this.idproducto,
    required this.describcion,
  });

  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    idproducto: map['idproducto'],
    describcion: map['describcion'],
  );

  Map<String, dynamic> toMap() => {
    'idproducto': idproducto,
    'describcion': describcion,
  };
}