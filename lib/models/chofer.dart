// Archivo: models/chofer.dart
class Chofer {
  final int idChofer;
  final String parnet;
  final String nombre;
  final String escaner;
  final String impresora;
  final String correo;
  final String contrasena;
  final String? token;
  final String? prefijoFolio;

  Chofer({
    required this.idChofer,
    required this.parnet,
    required this.nombre,
    required this.escaner,
    required this.impresora,
    required this.correo,
    required this.contrasena,
    this.token,
    this.prefijoFolio
  });

  factory Chofer.fromMap(Map<String, dynamic> map) => Chofer(
    idChofer:     map['idChofer']    as int,
    parnet:       map['parnet']      as String,
    nombre:       map['nombre']      as String,
    escaner:      map['Escaner']     as String,
    impresora:    map['Impresora']   as String,
    correo:       map['Correo']      as String,
    contrasena:   map['Contrasena']  as String,
    token:        map['Token']       as String?,
    prefijoFolio: map['prefijoFolio'] as String?
  );

  Map<String, dynamic> toMap() => {
    'idChofer':    idChofer,
    'parnet':      parnet,
    'nombre':      nombre,
    'Escaner':     escaner,
    'Impresora':   impresora,
    'Correo':      correo,
    'Contrasena':  contrasena,
    'Token':       token,
    'prefijoFolio': prefijoFolio,
  };

  @override
  String toString() {
    return 'Chofer(idChofer: $idChofer, parnet: $parnet, nombre: $nombre, escaner: $escaner, impresora: $impresora, correo: $correo)';
  }
}
