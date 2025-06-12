class Cliente {
  final int    idcliente;
  final String clave;
  final String nombreCliente;
  String? calleNumero;
  String? rfc; // ← RFC desde descripcionSubCat
  final String? parnet;
  final String? clienteGrupo;
  final int    formaPago;
  final String? latitud;
  final String? longitud;
  String? ciudad;
  String? estado;

  Cliente({
    required this.idcliente,
    required this.clave,
    required this.nombreCliente,
    this.calleNumero,
    this.rfc,
    this.parnet,
    this.clienteGrupo,
    required this.formaPago,
    this.latitud,
    this.longitud,
    this.ciudad,
    this.estado,
  });

  factory Cliente.fromMap(Map<String, dynamic> m) {
    final rawPago = m['FormaPago'] ?? m['formaPago'];
    final pago = rawPago is num
        ? rawPago.toInt()
        : int.tryParse(rawPago.toString()) ?? 0;

    return Cliente(
      idcliente:     m['idcliente']     as int,
      clave:         m['clave']         as String,
      nombreCliente: m['nombreCliente'] as String,
      calleNumero:   m['calleNumero']   as String?,
      rfc:           m['RFC']           as String?, // ← leer RFC desde SQLite
      parnet:        m['parnet']        as String?,
      clienteGrupo:  m['ClienteGrupo']  as String?,
      formaPago:     pago,
      latitud:       m['latitud']       as String?,
      longitud:      m['longitud']      as String?,
      ciudad:        m['ciudad']        as String?,
      estado:        m['estado']        as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'idcliente'     : idcliente,
    'clave'         : clave,
    'nombreCliente' : nombreCliente,
    'calleNumero'   : calleNumero,
    'rfc'           : rfc, // ← guardar RFC en base de datos
    'parnet'        : parnet,
    'ClienteGrupo'  : clienteGrupo,
    'FormaPago'     : formaPago,
    'latitud'       : latitud,
    'longitud'      : longitud,
    'ciudad'        : ciudad,
    'estado'        : estado,
  };

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
      rfc:           j['descripcionCat'] as String?, // ← asignado correctamente
      parnet:        j['descripcionSubCat']    as String?,
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
        'rfc: $rfc, '
        'formaPago: $formaPago, '
        'calle: $calleNumero, '
        'ciudad: $ciudad, '
        'estado: $estado'
        ')';
  }
}
