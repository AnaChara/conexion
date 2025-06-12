import 'package:conexion/BD/global.dart';
import 'package:conexion/Vendedor/Ventas.dart';
import 'package:conexion/models/escaneodetalle.dart';
import 'package:conexion/services/producto_service.dart';
import 'package:conexion/services/venta_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../actividad.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import '../models/cliente.dart';
import '../models/detallePrecio.dart';
import '../models/venta.dart';
import '../models/ventadetalle.dart';
import '../services/caja_service.dart';
import '../services/cliente_services.dart';
import '../services/ventadetalle_services.dart';
import 'package:conexion/models/caja.dart';



class venta extends StatefulWidget {
  const venta({super.key});

  @override
  State<venta> createState() => _ventaState();
}

class _ventaState extends State<venta> with AutomaticKeepAliveClientMixin<venta> {

  bool get wantKeepAlive => true;
  bool _showScanner = false;
  bool _puedeEscanear = true;
  bool _modoEscaneoActivo = false;
  bool _esExito = false;
  bool _modoEdicion = false;

  Set<int> _seleccionados = {};

  List<EscaneoDetalle> _detallesEscaneados = [];
  List<Cliente> clientes = [];
  List<Cliente> filtroclientes = [];
  List<DetalleConPrecio> _detallesConPrecio = [];
  Cliente? seleccionarcliente;
  Caja? _cajaSeleccionada;

  TextEditingController _scanController = TextEditingController();
  TextEditingController _paymentAmountController = TextEditingController();
  final _searchcliente = TextEditingController();

  FocusNode _focusNode = FocusNode();
  String _mensajeEscaneo = '';
  String? _selectedPaymentMethod;

  /// Devuelve la lista de opciones según el cliente seleccionado
  List<String> get _paymentOptions {
    final code = seleccionarcliente?.formaPago ?? 0;
    switch (code) {
      case 1:  return ['Efectivo'];
      case 3:  return ['Cheque', 'Efectivo'];
      case 99: return ['Efectivo', 'Cheque', 'Transferencia'];
      default: return ['Crédito'];
    }
  }

  @override
  void initState(){
    super.initState();
    _buscarClientes();
    _searchcliente.addListener(() => _onSearchChanged(_searchcliente.text));
    _focusNode.addListener(() {
      if (_modoEscaneoActivo) _focusNode.requestFocus();
    });
    _initClientes();
  }

  Future<void> _initClientes() async {
    await ClienteService.syncClientes();
    final lista = await ClienteService.obtenerClientes();
    setState(() => clientes = lista);
  }

  Future<void> _buscarClientes() async {
    final datos = await ClienteService.obtenerClientes();
    print('Clientes obtenidos: $datos');
    setState(() => clientes = datos);
  }

  Future<void> _openMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$encoded';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'No se pudo abrir el mapa.';
    }
  }

  Future<bool> _procesarEscaneo(String qrEscaneado) async {
    try {
      // 0) Validar longitud
      final cleanedValue = qrEscaneado.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleanedValue.length != 29) {
        setState(() {
          _mensajeEscaneo = 'Su QR debe contener 29 caracteres';
          _esExito        = false;
        });
        _mostrarSnack(success: false);
        return false;
      }

      // 1) Debe existir en CajasFolioChofer
      final caja = await CajaService.obtenerCajaPorQR(qrEscaneado);
      if (caja == null) {
        setState(() {
          _mensajeEscaneo = 'No disponible';
          _esExito        = false;
        });
        _mostrarSnack(success: false);
        return false;
      }

      // 2) Traer todos los registros de ventaDetalle que tengan ese QR
      final listaDetalles = await VentaDetalleService.getDetallesPorQR(qrEscaneado);

      // 2.a) Verificar si ALGUNO de esos registros ya está “Vendido”
      for (var det in listaDetalles) {
        final statusRaw = det.status ?? '';
        final statusNormalized = statusRaw.trim().toLowerCase();
        if (statusNormalized == 'vendido') {
          setState(() {
            _mensajeEscaneo = 'Producto ya vendido';
            _esExito = false;
          });
          _mostrarSnack(success: false);
          return false;
        }
      }

      // 2.b) Si no hay ninguno con status='vendido', seguimos con el flujo.
      // 3) Compruebo duplicados en memoria (_detallesEscaneados)
      if (_detallesEscaneados.any((d) => d.qr == qrEscaneado)) {
        setState(() {
          _mensajeEscaneo = 'Ya agregaste esta caja';
          _esExito        = false;
        });
        _mostrarSnack(success: false);
        return false;
      }

      // 4) Aprópiate de la “primera” fila para tomar pesoNeto, idproducto, etc.
      VentaDetalle baseDetalle;
      if (listaDetalles.isNotEmpty) {
        baseDetalle = listaDetalles.first;
      } else {
        // Si no existe en ventaDetalle (ni con status=Sincronizado ni Inventario),
        // decides si lo bloqueas o no. Aquí asumimos que debe regresar “no disponible”:
        setState(() {
          _mensajeEscaneo = 'No disponible en ventaDetalle';
          _esExito        = false;
        });
        _mostrarSnack(success: false);
        return false;
      }

      // 5) Obtener precio y descripción según idproducto
      final idProd = baseDetalle.idproducto;
      final precio = await ProductoService.getUltimoPrecioProducto(idProd) ?? 0.0;
      final desc   = await ProductoService.getDescripcionProducto(idProd) ?? '—';


      // 6) Agregarlo a la lista local de escaneados
      setState(() {
        _mensajeEscaneo   = 'Caja agregada';
        _esExito          = true;
        _cajaSeleccionada = caja;
        _detallesEscaneados.add(
          EscaneoDetalle(
            qr:          qrEscaneado,
            pesoNeto:    baseDetalle.pesoNeto,
            descripcion: desc,
            importe:     precio,
            idproducto:  baseDetalle.idproducto,
          ),
        );
        _puedeEscanear = true;
      });
      await cargarDetallesConPrecio();
      _mostrarSnack(success: true);
      print('>>> Escaneo agregado: qr="$qrEscaneado"');
      return true;
    } catch (e) {
      print('Error al procesar escaneo: $e');
      setState(() {
        _mensajeEscaneo = 'Error al procesar escaneo';
        _esExito        = false;
      });
      _mostrarSnack(success: false);
      return false;
    }
  }
//para obtener el precio
  Future<void> cargarDetallesConPrecio() async {
    _detallesConPrecio.clear();
    for (final d in _detallesEscaneados) {
      final precio = await ProductoService.getUltimoPrecioProducto(d.idproducto);
      _detallesConPrecio.add(
        DetalleConPrecio(detalle: d, precioPorKilo: precio ?? 0),
      );
    }
    setState(() {}); // Para redibujar
  }

// Esto es para filtrar los clientes
  void _onSearchChanged(String q) {
    if (q.isEmpty) {
      setState(() => filtroclientes = []);
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      filtroclientes = clientes
          .where((c) => c.nombreCliente.toLowerCase().contains(lower))
          .toList();
    });
  }


  //Mostrar el mensaje cuando se realiza el escaneo
  void _mostrarSnack({bool success = true}) {
    final color = success ? Colors.green[600] : Colors.red[600];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_mensajeEscaneo),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }



// Cuando se selecciona un cliente para mantener sus datos
  void _onClientTap(Cliente client) {
    setState(() {
      seleccionarcliente = client;
      filtroclientes     = [];
      _searchcliente.text = client.nombreCliente;
    });
    print('💡 Cliente seleccionado: ${seleccionarcliente!.nombreCliente}, '
        'formaPago raw = ${seleccionarcliente!.formaPago} '
        '(${seleccionarcliente!.formaPago.runtimeType})');
  }

  @override
  void dispose(){
    _searchcliente.dispose();
    _scanController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sessionController = Provider.of<SessionController>(context, listen: false);
    sessionController.resetInactivityTimer(context);

    //Calcular el total y el monto pagado
    final totalVenta = _detallesConPrecio
        .map((d) => d.detalle.pesoNeto * d.precioPorKilo)
        .fold(0.0, (sum, x) => sum + x);
    final pagoEnEfectivo = double.tryParse(
        _paymentAmountController.text.replaceAll(',', '.')
    ) ?? 0.0;


    // 1) Primero, calculamos el total en centavos:
    final totalCentavos = _detallesConPrecio
        .map((d) => (d.detalle.pesoNeto * d.precioPorKilo * 100).round())
        .fold(0, (suma, cent) => suma + cent);
    // 2) Convertimos totalCentavos a double para mostrar:
    final total = totalCentavos / 100.0;

    // Si el usuario escribe, por ejemplo, "200" o "200.00" o "200,00":
    final recibidoDouble = double.tryParse(
        _paymentAmountController.text.replaceAll(',', '.')
    ) ?? 0.0;

    // Convertimos a centavos:
    final recibidoCentavos = (recibidoDouble * 100).round();

    // Ahora restamos en enteros:
    final cambioCentavos = recibidoCentavos - totalCentavos;

    // Si quieres mostrar cambio negativo como 0.00, puedes:
    // final cambioCentavosDisplay = cambioCentavos < 0 ? 0 : cambioCentavos;
    // Pero aquí asumiremos que permitimos negativos si el cliente pagó menos.
    final cambioDisplay = cambioCentavos / 100.0;

    return GestureDetector(
      onTap: () {
        sessionController.resetInactivityTimer(context);
      },
      onPanUpdate: (_) {
        sessionController.resetInactivityTimer(context);
      },

      child: Scaffold(
        appBar: AppBar(title: Text('Venta',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Sólo muestro el buscador si aún NO hay cliente seleccionado ───
                if (seleccionarcliente == null)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchcliente,
                            decoration: InputDecoration(
                              labelText: 'Nombre del cliente',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.search),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            height: 3 * 56.0,
                            child: ListView.builder(
                              itemCount: _searchcliente.text.isEmpty
                                  ? clientes.length
                                  : filtroclientes.length,
                              itemBuilder: (_, i) {
                                final c = _searchcliente.text.isEmpty ? clientes[i] : filtroclientes[i];
                                return ListTile(
                                  leading: Icon(Icons.person_outline, size: 28, color: Colors.blueGrey),
                                  title: Text(
                                    c.nombreCliente,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    c.calleNumero ?? '',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  onTap: () => _onClientTap(c),
                                );

                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── Cuando ya hay cliente, muestro sólo el card de detalles ───
                if (seleccionarcliente != null) ...[
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cliente seleccionado',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey[700]),
                                onPressed: () {
                                  setState(() {
                                    seleccionarcliente = null;
                                    _searchcliente.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                          Divider(),
                          Row(
                            children: [
                              Icon(Icons.person, size: 20, color: Colors.black54),
                              SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Nombre: ',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                    children: [
                                      TextSpan(
                                        text: seleccionarcliente!.nombreCliente,
                                        style: TextStyle(fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.home, size: 20, color: Colors.black54),
                              SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Dirección: ',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                    children: [
                                      TextSpan(
                                        text: seleccionarcliente!.calleNumero ?? '',
                                        style: TextStyle(fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.vpn_key, size: 20, color: Colors.black54),
                              SizedBox(width: 6),
                              RichText(
                                text: TextSpan(
                                  text: 'RFC: ',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                  children: [
                                    TextSpan(
                                      text: seleccionarcliente!.rfc,
                                      style: TextStyle(fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),


                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.map),
                                label: Text('Cómo llegar'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClienteMapPage(
                                      direccion: seleccionarcliente!.calleNumero ?? '',
                                      ciudad: seleccionarcliente!.ciudad.toString(),
                                      estado: seleccionarcliente!.estado.toString(),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: 8,)
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  // ─── Botón Escáner fuera del Card ────────────────────
                  if (_cajaSeleccionada == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.qr_code_scanner),
                        label: Text('Escáner'),
                        onPressed: () {
                          setState(() {
                            _showScanner      = !_showScanner;
                            _puedeEscanear    = true;
                            _mensajeEscaneo   = '';
                            _cajaSeleccionada = null;
                          });
                          if (_showScanner) {
                            Future.delayed(Duration(milliseconds: 100), () {
                              _focusNode.requestFocus();
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  if (_showScanner && _puedeEscanear)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _scanController,
                        focusNode: _focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Escanea aquí el código QR',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () => _scanController.clear(),
                          ),
                        ),
                        onSubmitted: (qr) async {
                          final ok = await _procesarEscaneo(qr.trim());
                          _scanController.clear();
                          if (ok) {
                            setState(() => _showScanner = false);
                          }
                        },
                      ),
                    ),
                  if (_cajaSeleccionada != null) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Encabezado ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Caja encontrada',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.grey[700]),
                                  onPressed: () {
                                    setState(() {
                                      _cajaSeleccionada   = null;
                                      _detallesEscaneados = [];
                                      _mensajeEscaneo     = '';
                                      _puedeEscanear       = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                            Divider(),
                            // ── Fila de encabezados de columnas ──
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(
                                child: Text(
                                  'Producto | peso | costo | subTotal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),

                            Divider(),

                            // ── Lista de detalles ──
                            if (_detallesConPrecio.isEmpty)
                              Center(child: Text('No hay cajas escaneadas aún'))
                            else
                            // DESPUÉS: filas “dismissible” que puedes deslizar para borrar
                              ..._detallesConPrecio.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final d = item.detalle;
                                final precio = item.precioPorKilo;
                                final peso = d.pesoNeto;
                                final subtotal = peso * precio;

                                final seleccionado = _seleccionados.contains(index);

                                return GestureDetector(
                                  onTap: _modoEdicion
                                      ? () {
                                    setState(() {
                                      if (seleccionado) {
                                        _seleccionados.remove(index);
                                      } else {
                                        _seleccionados.add(index);
                                      }
                                    });
                                  }
                                      : null,
                                  child: Container(
                                    color: seleccionado ? Colors.red[100] : null,
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_modoEdicion)
                                          Checkbox(
                                            value: seleccionado,
                                            onChanged: (_) {
                                              setState(() {
                                                if (seleccionado) {
                                                  _seleccionados.remove(index);
                                                } else {
                                                  _seleccionados.add(index);
                                                }
                                              });
                                            },
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                d.descripcion,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '${peso.toStringAsFixed(2)} kg',
                                                      textAlign: TextAlign.right,
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '\$${precio.toStringAsFixed(2)}',
                                                      textAlign: TextAlign.right,
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '\$${subtotal.toStringAsFixed(2)}',
                                                      textAlign: TextAlign.right,
                                                      style: const TextStyle(fontSize: 16),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                  ),
                                );
                              }).toList(),

                            SizedBox(height: 12,),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  icon: Icon(_modoEdicion ? Icons.cancel : Icons.delete),
                                  label: Text(_modoEdicion ? 'Cancelar' : 'Elimar'),
                                  onPressed: () => setState(() => _modoEdicion = !_modoEdicion),
                                ),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.qr_code_scanner),
                                  label: Text('Agregar'),
                                  onPressed: () {
                                    setState(() {
                                      _mensajeEscaneo   = '';
                                      _puedeEscanear     = true;
                                      _showScanner       = true;
                                      // NO limpiamos _detallesEscaneados aquí
                                    });
                                  },
                                ),
                              ],
                            ),
                            Divider(),
                            // ── Total ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: \$${ (totalCentavos / 100.0).toStringAsFixed(2) }',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Divider(),
                            if (_modoEdicion && _seleccionados.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.delete_sweep),
                                  label: Text('Eliminar ${_seleccionados.length}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirmar = await showDialog<bool>(
                                      context: context,
                                        builder: (_) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Row(
                                            children: const [
                                              Icon(Icons.delete_forever, color: Colors.red, size: 28),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Confirmar eliminación',
                                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            '¿Estás seguro de eliminar ${_seleccionados.length} caja(s)?',
                                            style: const TextStyle(fontSize: 18),
                                            textAlign: TextAlign.center,
                                          ),
                                          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          actions: [
                                            Row(
                                              children: [
                                                // Botón Cancelar
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(Icons.cancel, color: Colors.white, size: 20),
                                                    label: const Text(
                                                      'Cancelar',
                                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.grey[700],
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),

                                                // Botón Eliminar
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                                    label: const Text(
                                                      'Eliminar',
                                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red[700],
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    onPressed: () => Navigator.of(context).pop(true),
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        )
                                    );
                                    //si el usuario confirma, se borra
                                    if (confirmar == true){
                                      setState(() {
                                        final indices = _seleccionados.toList()..sort((a, b) => b - a);
                                        for (var idx in indices) {
                                          _detallesEscaneados.removeAt(idx);
                                          _detallesConPrecio.removeAt(idx);
                                        }
                                        _seleccionados.clear();
                                        _modoEdicion = false;
                                      });
                                    }
                                  },
                                ),
                              ),

                            // ─── Aquí va el dropdown de forma de pago, tras haber escaneado al menos una caja ───
                            if (_detallesEscaneados.isNotEmpty) ...[
                              SizedBox(height: 16),

                              Text('Forma de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
                              DropdownButton<String>(
                                isExpanded: true,
                                hint: Text('Selecciona método'),
                                value: _selectedPaymentMethod,
                                items: _paymentOptions
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (m) => setState(() {
                                  _selectedPaymentMethod = m;
                                  _paymentAmountController.clear();
                                }),
                              ),

                              if (_selectedPaymentMethod == 'Efectivo') ...[
                                SizedBox(height: 12),
                                TextField(
                                  controller: _paymentAmountController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Monto recibido',
                                    prefixText: '\$ ',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                SizedBox(height: 8),
                                if (recibidoCentavos <
                                    totalCentavos)
                                  Text(
                                    'Monto insuficiente',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight:
                                        FontWeight.bold),
                                  )
                                else
                                  Text(
                                    'Cambio: \$${cambioDisplay.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800]),
                                  ),
                              ],
                            ],
                            SizedBox(height: 8),


                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_detallesEscaneados.isNotEmpty &&
                      _selectedPaymentMethod != null &&
                      (
                          (_selectedPaymentMethod == 'Efectivo' && pagoEnEfectivo >= totalVenta)
                              || (_selectedPaymentMethod != 'Efectivo')
                      )
                  )
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check_circle_outline),
                        label: Text('Finalizar Venta'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 48),
                        ),
                        onPressed: () {
                          if(_detallesEscaneados.isEmpty) {
                            showDialog(
                                context: context,
                                builder: (_) =>
                                    AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Row(
                                        children: const [
                                          Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Error',
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: const Text(
                                        'Debes escanear al menos una caja antes de finalizar la venta.',
                                        style: TextStyle(fontSize: 18),
                                        textAlign: TextAlign.center,
                                      ),
                                      actionsAlignment: MainAxisAlignment.center,
                                      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      actions: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.check, size: 20, color: Colors.white),
                                          label: const Text(
                                            'OK',
                                            style: TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            minimumSize: const Size(140, 48),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ],
                                    )
                            );
                            return;
                          }
                            showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext dialogContext){
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Row(
                                      children: const [
                                        Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Confirmar',
                                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: const Text(
                                      '¿Finalizar venta?',
                                      style: TextStyle(fontSize: 18),
                                      textAlign: TextAlign.center,
                                    ),
                                    actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    actions: [
                                      Row(
                                        children: [
                                          // Botón Cancelar
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.cancel, size: 20, color: Colors.white),
                                              label: const Text(
                                                'Cancelar',
                                                style: TextStyle(fontSize: 16, color: Colors.white),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey[700],
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () => Navigator.of(dialogContext).pop(),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Botón Continuar
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.check, size: 20, color: Colors.white),
                                              label: const Text(
                                                'Continuar',
                                                style: TextStyle(fontSize: 16, color: Colors.white),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green[700],
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () async {
                                                Navigator.of(dialogContext).pop();

                                                final nuevoFolio = 'F${DateTime.now().millisecondsSinceEpoch}';

                                                final ventaObj = Venta(
                                                  fecha: DateTime.now(),
                                                  idcliente: seleccionarcliente!.idcliente,
                                                  folio: nuevoFolio,
                                                  idchofer: UsuarioActivo.idChofer!,
                                                  total: totalVenta,
                                                  idpago: (_selectedPaymentMethod == 'Efectivo')
                                                      ? 1
                                                      : (_selectedPaymentMethod == 'Cheque')
                                                      ? 2
                                                      : 3,
                                                  pagoRecibido: (_selectedPaymentMethod == 'Efectivo') ? pagoEnEfectivo : null,
                                                  clienteNombre: seleccionarcliente!.nombreCliente,
                                                  metodoPago: _selectedPaymentMethod!,
                                                  cambio: (_selectedPaymentMethod == 'Efectivo')
                                                      ? (pagoEnEfectivo - totalVenta)
                                                      : null,
                                                  direccionCliente: seleccionarcliente!.calleNumero ?? '',
                                                  rfcCliente: seleccionarcliente!.rfc ?? '',
                                                );

                                                final nuevoId = await VentaService.insertarVenta(ventaObj);

                                                final ventaConID = Venta(
                                                  idVenta: nuevoId,
                                                  fecha: ventaObj.fecha,
                                                  idcliente: ventaObj.idcliente,
                                                  folio: nuevoFolio,
                                                  idchofer: ventaObj.idchofer,
                                                  total: ventaObj.total,
                                                  idpago: ventaObj.idpago,
                                                  pagoRecibido: ventaObj.pagoRecibido,
                                                  clienteNombre: ventaObj.clienteNombre,
                                                  metodoPago: ventaObj.metodoPago,
                                                  cambio: ventaObj.cambio,
                                                  direccionCliente: ventaObj.direccionCliente,
                                                  rfcCliente: ventaObj.rfcCliente,
                                                );

                                                for (final d in _detallesEscaneados) {
                                                  final detalle = VentaDetalle(
                                                    qr: d.qr,
                                                    pesoNeto: d.pesoNeto,
                                                    subtotal: d.importe,
                                                    status: 'Vendido',
                                                    idproducto: d.idproducto,
                                                    folio: nuevoFolio,
                                                    descripcion: d.descripcion,
                                                    idVenta: nuevoId,
                                                  );
                                                  await VentaDetalleService.insertarDetalle(detalle);
                                                }

                                                final ultimaVenta = await VentaService.obtenerUltimaVenta();

                                                Navigator.push<bool>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => DetalleVentaPage(
                                                      venta: ventaConID,
                                                      showSolicitudDevolucion: false,
                                                    ),
                                                  ),
                                                ).then((devolverTrue) {
                                                  if (devolverTrue == true) {
                                                    setState(() {
                                                      _detallesEscaneados.clear();
                                                      seleccionarcliente = null;
                                                      _selectedPaymentMethod = null;
                                                      _paymentAmountController.clear();
                                                      _cajaSeleccionada = null;
                                                      _mensajeEscaneo = '';
                                                      _showScanner = false;
                                                      _puedeEscanear = true;
                                                      _modoEscaneoActivo = false;
                                                      _modoEdicion = false;
                                                      _seleccionados.clear();
                                                      _scanController.clear();
                                                      _searchcliente.clear();
                                                    });
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }
                            );
                          }

                      ),
                    ),
                ],
              ],
            ),
          ),
        )
      ),
    );
  }
}

class ClienteMapPage extends StatefulWidget {
  final String direccion;
  final String ciudad;
  final String estado;

  const ClienteMapPage({
    Key? key,
    required this.direccion,
    required this.ciudad,
    required this.estado,
  }) : super(key: key);


  @override
  State<ClienteMapPage> createState() => _ClienteMapPageState();
}

class _ClienteMapPageState extends State<ClienteMapPage> with SingleTickerProviderStateMixin {
  LatLng? _destino;

  @override
  void initState() {
    super.initState();
    _geocode();
  }

  Future<void> _geocode() async {
    final full = '${widget.direccion}, ${widget.ciudad}, ${widget.estado}';
    try {
      final results = await locationFromAddress(full);
      if (results.isNotEmpty) {
        final loc = results.first;
        setState(() => _destino = LatLng(loc.latitude, loc.longitude));
      } else {
        print('No encontré coordenadas para: $full');
      }
    } catch (e) {
      print('Error en geocoding: $e');
    }
  }


  @override
  void dispose() {
    _geocode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ruta al cliente')),
      body: _destino == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _destino!,
          zoom: 15,
        ),
        markers: {
          Marker(markerId: MarkerId('destino'), position: _destino!),
        },
      ),
    );
  }
}





