import 'package:conexion/models/escaneodetalle.dart';
import 'package:conexion/services/producto_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../actividad.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import '../models/cliente.dart';
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
  Cliente? seleccionarcliente;
  Caja? _cajaSeleccionada;

  TextEditingController _scanController = TextEditingController();
  final _searchcliente = TextEditingController();

  FocusNode _focusNode = FocusNode();
  String _mensajeEscaneo = '';

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

      // 2) Compruebo en ventaDetalle
      final detalle = await VentaDetalleService.getVentaDetallePorQR(qrEscaneado);
      if (detalle != null) {
        final status = detalle.status;
        if (status == 'Vendido') {
          setState(() {
            _mensajeEscaneo = 'Producto ya vendido';
            _esExito        = false;
          });
          _mostrarSnack(success: false);
          return false;
        }

        // 2.a) EXTRA: Compruebo duplicados
        if (_detallesEscaneados.any((d) => d.qr == qrEscaneado)) {
          setState(() {
            _mensajeEscaneo = 'Ya agregaste esta caja';
            _esExito        = false;
          });
          _mostrarSnack(success: false);
          return false;
        }

        // Si llego aquí, está en detalle y NO está vendido.
        // Extraigo idProducto, precio y descripción:
        final idProd = detalle.idproducto;
        final precio = await ProductoService.getUltimoPrecioProducto(idProd) ?? 0.0;
        final desc   = await ProductoService.getDescripcionProducto(idProd) ?? '—';

        // 3) Acumulo en la lista de detalles:
        setState(() {
          _mensajeEscaneo   = 'Caja agregada';
          _esExito          = true;
          _cajaSeleccionada = caja;

          _detallesEscaneados.add(
            EscaneoDetalle(
              qr:          qrEscaneado,
              pesoNeto:    detalle.pesoNeto,
              descripcion: desc,
              importe:     precio,
            ),
          );
          _puedeEscanear = true;
        });
        _mostrarSnack(success: true);
        return true;
      }

      // 4) Si no está en ventaDetalle:
      setState(() {
        _mensajeEscaneo = 'No disponible en ventaDetalle';
        _esExito        = false;
      });
      _mostrarSnack(success: false);
      return false;
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

    return GestureDetector(
      onTap: () {
        sessionController.resetInactivityTimer(context);
      },
      onPanUpdate: (_) {
        sessionController.resetInactivityTimer(context);
      },

      child: Scaffold(
        appBar: AppBar(title: Text('Venta')),
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
                                  title: Text(c.nombreCliente),
                                  subtitle: Text(c.calleNumero ?? ''),
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
                          Text('Nombre: ${seleccionarcliente!.nombreCliente}'),
                          Text('Dirección: ${seleccionarcliente!.calleNumero ?? ''}'),
                          Text('Clave: ${seleccionarcliente!.clave}'),
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
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text('Peso neto',    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(child: Text('Descripción',  textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(child: Text('Subtotal',     textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            Divider(),

                            // ── Lista de detalles ──
                            if (_detallesEscaneados.isEmpty)
                              Center(child: Text('No hay cajas escaneadas aún'))
                            else
                            // DESPUÉS: filas “dismissible” que puedes deslizar para borrar
                              ..._detallesEscaneados.asMap().entries.map((entry) {
                                final i = entry.key;
                                final d = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      // Sólo en modo edición muestro el checkbox
                                      if (_modoEdicion)
                                        Checkbox(
                                          value: _seleccionados.contains(i),
                                          onChanged: (v) {
                                            setState(() {
                                              if (v == true) _seleccionados.add(i);
                                              else _seleccionados.remove(i);
                                            });
                                          },
                                        ),

                                      // Tres columnas repartidas
                                      Expanded(
                                        child: Text(
                                          '${d.pesoNeto} kg',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          d.descripcion,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '\$${(d.importe).toStringAsFixed(2)}',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            if (_modoEdicion && _seleccionados.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.delete_sweep),
                                  label: Text('Eliminar ${_seleccionados.length}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      // eliminamos de mayor a menor índice
                                      final indices = _seleccionados.toList()..sort((a, b) => b - a);
                                      for (var idx in indices) {
                                        _detallesEscaneados.removeAt(idx);
                                      }
                                      _seleccionados.clear();
                                      _modoEdicion = false;
                                    });
                                  },
                                ),
                              ),
                            Divider(),
                            // ── Total ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: \$${_detallesEscaneados
                                      .map((d) => d.importe)
                                      .fold(0.0, (sum, x) => sum + x)
                                      .toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
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
                                  label: Text('Escanear otra'),
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
                          ],
                        ),
                      ),
                    ),
                  ],

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
        print('❌ No encontré coordenadas para: $full');
      }
    } catch (e) {
      print('❌ Error en geocoding: $e');
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





