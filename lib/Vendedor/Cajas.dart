import 'dart:async';
import 'dart:math';
import 'package:conexion/services/ventadetalle_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../BD/database.dart';
import '../models/caja.dart';
import '../models/ventadetalle.dart';

import '../services/inventario_service.dart';
import '../services/caja_service.dart';
import '../services/producto_service.dart';
import '../services/venta_services.dart';
import '../BD/global.dart'; // para UsuarioActivo
import '../actividad.dart';


class cajas extends StatefulWidget {
  const cajas({super.key});

  @override
  State<cajas> createState() => _cajasState();
}


class _cajasState extends State<cajas>
with AutomaticKeepAliveClientMixin{

  bool get wantKeepAlive => true;

  List<Caja> listaDeDatos    = [];
  List<Caja> listaFiltrada   = [];

  TextEditingController _searchController = TextEditingController();
  TextEditingController _scanController = TextEditingController();

  bool _esExito = false;
  bool cargando = true;
  bool _modoEscaneoActivo = false;

  FocusNode _focusNode = FocusNode();
  String _mensajeEscaneo = '';


  String obtenerUltimos4(String qr) {
    int puntoIndex = qr.indexOf('.');

    if (puntoIndex != -1 && qr.length > puntoIndex + 1) {
      String antesDelPunto = qr.substring(puntoIndex - 2, puntoIndex);
      String despuesDelPunto = qr.substring(puntoIndex + 1, puntoIndex + 3);
      return antesDelPunto + '.' + despuesDelPunto;
    }

    return ''; // Devuelve una cadena vacía si no se encontró un punto o no hay suficientes caracteres.
  }

  Future<void> cargarDatosInventario({bool force = false}) async {
    // Si NO forzamos y ya hay datos, no recargues
    if (!force && listaDeDatos.isNotEmpty) return;

    setState(() => cargando = true);
    try {
      final correo = UsuarioActivo.correo;
      if (correo == null) throw Exception('No hay usuario activo');

      final datos = await InventarioService.getDatosInventario(correo, 'sv250501.1');

      if (!mounted) return;
      setState(() {
        listaDeDatos  = datos;    // aquí vienen tanto locales como nube
        listaFiltrada = [];       // limpia cualquier filtro
        cargando      = false;
      });
    } catch (e) {
      print('Error al cargar datos del inventario: $e');
      if (!mounted) return;
      setState(() => cargando = false);
    }
  }



  // Función para buscar en la lista según el qr
  void buscarPorQr(String query) {
    final filtered = listaDeDatos.where((item) {
      final qr = item.qr;
      final ultimos4 = obtenerUltimos4(qr);
      return ultimos4.contains(query);  // Filtramos por qr
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        listaFiltrada = filtered; // Actualizamos la lista filtrada
      });
    });
  }

  Map<String, String> parseQrData(String qr) {
    final cleaned = qr.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = cleaned.indexOf('.');
    if (dot < 2 || cleaned.length < dot + 3) {
      throw FormatException('QR en formato inesperado');
    }
    // 1) Peso neto XX.XX
    final neto = cleaned.substring(dot - 2, dot + 3);
    // 2) Resto de dígitos sin el peso
    final before = cleaned.substring(0, dot - 2);
    final after  = cleaned.substring(dot + 3);
    final resto  = before + after;
    // 3) subtotal = primeros 4 dígitos o todo si <4
    final subLen   = resto.length >= 4 ? 4 : resto.length;
    final subtotal = resto.substring(0, subLen);
    // 4) folio = resto después de esos 4
    final folio    = subLen < resto.length ? resto.substring(subLen) : '';
    return {'neto': neto, 'subtotal': subtotal, 'folio': folio};
  }

  Future<bool> _procesarEscaneo(String qrEscaneado) async {
    setState(() => cargando = true);
    _mensajeEscaneo = 'Guardando caja…';

    setState(() => cargando = true);
      try {
        // 1) Validación básica
        debugPrint('➡️ Empezando escaneo de: $qrEscaneado');
        final cleaned = qrEscaneado.replaceAll(RegExp(r'[^0-9.]'), '');
        if (cleaned.length != 29) {
          setState(() {
            _mensajeEscaneo = 'Su QR debe contener 29 caracteres';
            _esExito = false;
          });
          return false;
        }

        // 2) ¿Ya existe en local?
        final Caja? existente = await CajaService.obtenerCajaPorQR(qrEscaneado);
        if (existente != null) {
          setState(() {
            _mensajeEscaneo = 'Este código QR ya está registrado';
            _esExito = false;
          });
          return false;
        }

        // 3) ¿Ya existe en la nube?
        if (await CajaService.qrExisteEnLaNube(qrEscaneado)) {
          setState(() {
            _mensajeEscaneo = 'Este código QR ya está registrado en la nube';
            _esExito = false;
          });
          return false;
        }

        // 4) Crear y guardar el modelo Caja
        final nuevaCaja = Caja(
          id: DateTime.now().millisecondsSinceEpoch,
          createe: DateTime.now().millisecondsSinceEpoch,
          qr: qrEscaneado,
          folio: 'sv250501.1',
          sync: 0,
          fechaEscaneo: DateTime.now().toIso8601String(),
        );
        await CajaService.insertarCajaFolioChofer(nuevaCaja);
        debugPrint('✅ Caja almacenada: ${nuevaCaja.qr}');

        // 5) Parsear datos del QR
        final datosQr  = parseQrData(qrEscaneado);
        final pesoNeto = double.parse(datosQr['neto']!);
        final subtotal = double.parse(datosQr['subtotal']!);
        final folioSim = datosQr['folio']!;

        // 6) Obtener precio con el servicio
        final idProd = _pickRandomId();
        final precio = await ProductoService.getUltimoPrecioProducto(idProd) ?? 0.0;

        // 7) Crear y guardar el modelo VentaDetalle
        final detalle = VentaDetalle(
          idvd: null,
          idVenta: null,
          qr: qrEscaneado,
          pesoNeto: pesoNeto,
          subtotal: subtotal,
          status: 'Inventario',
          idproducto: idProd,
          folio: folioSim,
        );
        await VentaDetalleService.insertarDetalle(detalle);
        debugPrint('💾 Insertando VentaDetalle: idProd=$idProd subtotal=$subtotal');

        // 8) Recargar la lista local
        await cargarDatosLocales();

        setState(() {
          _mensajeEscaneo = 'Escaneo exitoso';
          _esExito        = true;
          _scanController.clear();
        });
        return true;
        debugPrint('✅ _procesarEscaneo terminó sin excepción');
      } catch (e, st) {
        debugPrint('‼️ Error en _procesarEscaneo: $e');
        debugPrint('$st');
        setState(() {
          _mensajeEscaneo = 'Error al procesar escaneo';
          _esExito        = false;
          _scanController.clear();
        });
        return false;
      }
  }

// Ejemplo de función auxiliar para elegir un producto
  int _pickRandomId() {
    final posibles = [501, 502, 503];
    return posibles[Random().nextInt(posibles.length)];
  }

  Future<void> cargarDatosLocales() async {
    final rows = await DBProvider.getDatabase()
        .then((db) => db.query('CajasFolioChofer', orderBy: 'fechaEscaneo DESC'));
    final cajas = rows.map((m) => Caja.fromMap(m)).toList();
    // 3) Asigno la lista de modelos y refresco la UI
    setState(() {
      listaDeDatos = cajas;  // ahora es List<Caja>
    });
  }



  @override
  void initState() {
    super.initState();
    cargarDatosInventario();
  }

  void dispose() {
    _searchController.dispose(); // Limpiamos el controlador cuando el widget se destruya
    _scanController.dispose();

    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Accedemos al controlador de sesión para resetear el temporizador
    final sessionController = Provider.of<SessionController>(context, listen: false);
    // Reseteamos el temporizador cuando esta pantalla se construye o cuando se hace alguna acción.
    sessionController.resetInactivityTimer(context);

    return GestureDetector(
      onTap: () {
        // Reinicia el temporizador al tocar cualquier parte de la pantalla
        sessionController.resetInactivityTimer(context);
      },
      onPanUpdate: (_) {
        // Reinicia el temporizador al hacer deslizamientos
        sessionController.resetInactivityTimer(context);
      },

      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Cajas'),
          actions: [
            IconButton(
                onPressed: () async {
                  await showSearch<Caja?>(
                    context: context,
                    delegate: CustomSearchDelegate(
                        onSearch: buscarPorQr, // Pasamos la función de búsqueda
                        dataList: listaDeDatos,
                        obtenerUltimos4: obtenerUltimos4,// Lista completa para la búsqueda
                    ),
                  );
                  await cargarDatosInventario(force: true);
                },
                icon: Icon(Icons.search)
            ),
          ],
        ),
        body: Column(
          children: [
            if (_modoEscaneoActivo)
              Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: (){

                    },
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _scanController,
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Escanea aquí...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value){
                        //presionar enter manualmente
                        _procesarEscaneo(value);
                      },
                    ),
                  )
              ),
            if(_mensajeEscaneo.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: cargando
                    ? BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(128, 128, 128, 0.4),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
                  borderRadius: BorderRadius.circular(8),
                )
                    : BoxDecoration(
                  color: _esExito ? Colors.green[100] : Colors.red[100],
                  border: Border.all(
                    color: _esExito ? Colors.green : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _esExito ? Icons.check_circle : Icons.error,
                      color: _esExito ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mensajeEscaneo,
                        style: TextStyle(
                          color: _esExito ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: listaDeDatos.isEmpty
                  ? Center(child: cargando ? CircularProgressIndicator() : Text('No hay datos cargados'))
              //Lista que desglosa las cajas que hay en el inventario
                  : ListView.builder(
                itemCount: listaFiltrada.isEmpty ? listaDeDatos.length : listaFiltrada.length,
                itemBuilder: (context, index) {
                  final item = listaFiltrada.isEmpty ? listaDeDatos[index] : listaFiltrada[index];
                  final qr = item.qr;
                  final ultimos4 = obtenerUltimos4(qr);
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () async {},
                        child: ListTile(
                          leading: Icon(Icons.inventory),
                          title: Text('Peso: $ultimos4'),
                          subtitle: Text('Folio: ${item.folio}'),
                          onTap: () async {
                            final datosLocales = await CajaService.obtenerCajaPorQR(qr);
                            showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text('Detalles de la caja'),
                                  content: datosLocales == null
                                      ? Text('No se econtraron datos en la base local para este QR')
                                      :Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Folio: ${datosLocales.folio}'),
                                      Text('Fecha de escaneo: ${datosLocales.fechaEscaneo.split('T').first}'),
                                      Text('Sync: ${datosLocales.sync}')
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context),
                                        child: Text('Cerrar')
                                    )
                                  ],
                                )
                            );
                          },
                        ),
                      ),
                    )
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'cajasFAB',
          onPressed: () {
            setState(() {
              _modoEscaneoActivo = !_modoEscaneoActivo;
              if (_modoEscaneoActivo) {
                // Activamos el foco cuando abrimos el escaneo
                Future.delayed(Duration(milliseconds: 10000), () {
                  FocusScope.of(context).requestFocus(_focusNode);
                });
              } else {
                // Limpia al salir del modo escaneo
                _scanController.clear();
                _mensajeEscaneo = '';
                setState(() {
                  cargarDatosInventario();
                });
              }
            });
          },
          child: Icon(_modoEscaneoActivo ? Icons.close : Icons.qr_code_scanner),
          tooltip: _modoEscaneoActivo ? 'Cerrar escaneo' : 'Escanear',
        ),
      ),
    );
  }
}

class CustomSearchDelegate extends SearchDelegate<Caja?> {
  final Function(String) onSearch;
  final List<Caja> dataList;
  final String Function(String) obtenerUltimos4;

  @override
  String get searchFieldLabel => 'Precio';

  @override
  TextStyle get searchFieldStyle =>
      TextStyle(color: Colors.black54);

  CustomSearchDelegate({
    required this.onSearch,
    required this.dataList,
    required this.obtenerUltimos4,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = ''; // Limpiar la búsqueda
          onSearch(query) ; // Actualizar la lista
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // 1) Le decimos al padre que actualice su listaFiltrada
    onSearch(query);

    // 2) Filtramos la lista local
    final filtered = dataList.where((Caja caja) {
      final ult4 = obtenerUltimos4(caja.qr);
      return ult4.contains(query);
    }).toList();

    // 3) Si no hay resultados
    if (filtered.isEmpty) {
      return Center(child: Text('No hay resultados para “$query”'));
    }

    // 4) Construimos la lista
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final caja = filtered[index];
        final ult4 = obtenerUltimos4(caja.qr);

        return ListTile(
          title: Text('Peso: $ult4'),
          subtitle: Text('Folio: ${caja.folio}'),
          onTap: () async {
            // Aquí va tu AlertDialog
            final datosLocales = await CajaService.obtenerCajaPorQR(caja.qr);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Detalles de la caja'),
                content: datosLocales == null
                    ? const Text('No hay datos locales para este QR')
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Folio: ${datosLocales.folio}'),
                    Text('Fecha: ${datosLocales.fechaEscaneo.split('T').first}'),
                    Text('Sync: ${datosLocales.sync}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = dataList.where((item) {
      final qr = item.qr;
      final ultimos4 = obtenerUltimos4(qr);
      return ultimos4.contains(query);
    }).toList();

    if (suggestions.isEmpty) {
      return const Center(child: Text('No se encontraron resultados'));
    }
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        final qr = item.qr;
        final ultimos4 = obtenerUltimos4(qr);
        return ListTile(
          title: Text('Peso: $ultimos4'),
          subtitle: Text('Folio: ${item.folio}'),
        );
      },
    );
  }
}


