class Cliente {
  final int    idcliente;
  final String clave;
  final String nombreCliente;
  final String? calleNumero;
  final String? parnet;
  final String? clienteGrupo;
  final int    formaPago;
  final String? latitud;
  final String? longitud;
  final String? ciudad;
  final String? estado;

  Cliente({
    required this.idcliente,
    required this.clave,
    required this.nombreCliente,
    this.calleNumero,
    this.parnet,
    this.clienteGrupo,
    required this.formaPago,
    this.latitud,
    this.longitud,
    this.ciudad,
    this.estado,
  });

  /// Para leer de SQLite
  factory Cliente.fromMap(Map<String, dynamic> m) {
    // raw puede venir como String o num, lo normalizamos a int
    final rawPago = m['FormaPago'] ?? m['formaPago'];
    final pago = rawPago is num
        ? rawPago.toInt()
        : int.tryParse(rawPago.toString()) ?? 0;

    return Cliente(
      idcliente:     m['idcliente']     as int,
      clave:         m['clave']         as String,
      nombreCliente: m['nombreCliente'] as String,
      calleNumero:   m['calleNumero']   as String?,
      parnet:        m['parnet']        as String?,
      clienteGrupo:  m['ClienteGrupo']  as String?,
      formaPago:     pago,
      latitud:       m['latitud']       as String?,
      longitud:      m['longitud']      as String?,
      ciudad:        m['ciudad']        as String?,
      estado:        m['estado']        as String?,
    );
  }

  /// Para insertar/actualizar en SQLite
  Map<String, dynamic> toMap() => {
    'idcliente'     : idcliente,
    'clave'         : clave,
    'nombreCliente' : nombreCliente,
    'calleNumero'   : calleNumero,
    'parnet'        : parnet,
    'ClienteGrupo'  : clienteGrupo,
    'FormaPago'     : formaPago,
    'latitud'       : latitud,
    'longitud'      : longitud,
    'ciudad'        : ciudad,
    'estado'        : estado,
  };

  /// Para parsear JSON de la API
  factory Cliente.fromJson(Map<String, dynamic> j) {
    final rawPago = j['FormaPago'];
    final pago = rawPago is num
        ? rawPago.toInt()
        : int.tryParse(rawPago.toString()) ?? 0;

    final codigos = j['codigos'] as String? ?? '';
    return Cliente(
      idcliente:     int.tryParse(codigos.replaceAll(' ', '')) ?? 0,
      clave:         codigos,
      nombreCliente: j['descripcionArt']    as String? ?? '',
      calleNumero:   j['bmp']               as String?,
      parnet:        j['descripcionSubCat'] as String?,
      clienteGrupo:  j['descripcionCat']    as String?,
      formaPago:     pago,
      latitud:       j['latitud']           as String?,
      longitud:      j['longitud']          as String?,
      ciudad:        j['ciudad']            as String?,
      estado:        j['estado']            as String?,
    );
  }

  @override
  String toString() {
    return 'Cliente('
        'id: $idcliente, '
        'clave: $clave, '
        'nombre: $nombreCliente, '
        'formaPago: $formaPago, '
        'calle: $calleNumero, '
        'ciudad: $ciudad, '
        'estado: $estado'
        ')';
  }
}
