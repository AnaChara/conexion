import 'dart:async';
import 'dart:math';
import 'package:conexion/services/ventadetalle_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../BD/database.dart';
import '../models/caja.dart';
import '../models/ventadetalle.dart';
import '../services/caja_service.dart';
import '../services/producto_service.dart';
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

  DateTime? fechaSeleccionada;


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

      final db = await DBProvider.getDatabase();
      final rows = await db.query('CajasFolioChofer', orderBy: 'fechaEscaneo DESC');
      final datos = rows.map((m) => Caja.fromMap(m)).toList();
      print('📦 Total de cajas encontradas en SQLite: ${datos.length}');
      if (datos.isNotEmpty) print('🕓 Fecha primera caja: ${datos.first.fechaEscaneo}');


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

  Future<void> cargarDatosInventarioPorFecha(String fecha) async {
    setState(() => cargando = true);
    try {
      final correo = UsuarioActivo.correo;
      if (correo == null) throw Exception('No hay usuario activo');

      final db = await DBProvider.getDatabase();
      final rows = await db.query('CajasFolioChofer');
      final datos = rows.map((m) => Caja.fromMap(m)).toList();
      print('📦 listaDeDatos.length = ${datos.length}');


      final hoy = DateTime.parse(fecha);

      final filtrados = datos.where((caja) {
        final fechaCaja = DateTime.tryParse(caja.fechaEscaneo.split('T').first);
        return fechaCaja != null &&
            fechaCaja.year == hoy.year &&
            fechaCaja.month == hoy.month &&
            fechaCaja.day == hoy.day;
      }).toList();

      if (!mounted) return;
      setState(() {
        listaDeDatos = filtrados;
        listaFiltrada = [];
        cargando = false;
      });
    } catch (e) {
      print('Error al cargar inventario por fecha: $e');
      if (!mounted) return;
      setState(() => cargando = false);
    }
  }


  void programarSincronizacionDiaria() {
    final ahora = DateTime.now();
    final hoy8AM = DateTime(ahora.year, ahora.month, ahora.day, 8);
    final proxima = ahora.isBefore(hoy8AM) ? hoy8AM : hoy8AM.add(const Duration(days: 1));
    final diferencia = proxima.difference(ahora);

    Timer(diferencia, () async {
      await CajaService.sincronizarDesdeServidor();
      programarSincronizacionDiaria(); // reprogramar para el siguiente día
    });
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

  Future<bool> _procesarEscaneo(String qrEscaneado) async {
    FocusScope.of(context).unfocus();
    setState(() {
      cargando = true;
      _mensajeEscaneo = 'Guardando Caja...';
    });

    try {
      // Si ingresa más de 31 dígitos, limpiamos el TextField y mostramos error
      if (qrEscaneado.length > 31) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          cargando = false;
          _mensajeEscaneo = 'El código debe tener solo 29 caracteres';
        });
        _scanController.clear();
        return false;
      }

      // 1) Validación básica
      final cleaned = qrEscaneado.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleaned.length != 29) {
        if (_mensajeEscaneo == 'Su QR debe contener 29 caracteres' && !_esExito) {
          await Future.delayed(const Duration(milliseconds: 100));
          setState(() {
            _mensajeEscaneo='';
          });
          await Future.delayed(const Duration(milliseconds: 100));
        }
        setState(() {
          cargando = false;
          _mensajeEscaneo = 'Su QR debe contener 29 caracteres';
          _esExito = false;
        });
        _scanController.clear();
        return false;
      }

      // 2) ¿Ya existe en local?
      final Caja? existente = await CajaService.obtenerCajaPorQR(qrEscaneado);
      if (existente != null) {
        if (_mensajeEscaneo == 'Este código QR ya está registrado' && !_esExito) {
          await Future.delayed(const Duration(milliseconds: 100));
          setState(() {
            _mensajeEscaneo = '';
          });
          await Future.delayed(const Duration(milliseconds: 100));
        }
        setState(() {
          cargando = false;
          _mensajeEscaneo = 'Este código QR ya está registrado';
          _esExito = false;
        });
        _scanController.clear();
        return false;
      }

      /* 3) ¿Ya existe en la nube?  <--- Esta función no es necesaria
      ya que actualmente los datos se almacenan dentro de SQLite
      if (await CajaService.qrExisteEnLaNube(qrEscaneado)) {
        if (_mensajeEscaneo == 'Este código QR ya está registrado en la nube' && !_esExito) {
          await Future.delayed(const Duration(milliseconds: 100));
          setState(() {
            _mensajeEscaneo = '';
          });
          await Future.delayed(const Duration(milliseconds: 100));
        }
        setState(() {
          cargando = false;
          _mensajeEscaneo = 'Este código QR ya está registrado en la nube';
          _esExito = false;
        });
        _scanController.clear();
        return false;
      } */


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
      debugPrint('Caja almacenada: ${nuevaCaja.qr}');

      // 5) Parsear datos del QR
      final datosQr = CajaService.parseQrData(qrEscaneado);
      final pesoNeto = double.parse(datosQr['neto']!);
      final folioSim = datosQr['folio']!;

      // 6) Obtener precio con el servicio
      final idProd = _pickRandomId();
      final precio = await ProductoService.getUltimoPrecioProducto(idProd) ?? 0.0;

      // 7) Calcular subtotal = pesoNeto * precioPorKilo
      final subtotalCalc = pesoNeto * precio;

      // 8) Crear y guardar el modelo VentaDetalle
      final detalle = VentaDetalle(
        idvd: null,
        idVenta: null,
        qr: qrEscaneado,
        pesoNeto: pesoNeto,
        subtotal: subtotalCalc,
        status: 'Inventario',
        idproducto: idProd,
        folio: folioSim,
      );
      await VentaDetalleService.insertarDetalle(detalle);
      debugPrint('Insertando VentaDetalle: idProd=$idProd subtotal=$subtotalCalc');

      // 8) Recargar la lista local
      await cargarDatosInventario(force: true);
      print('🔄 Lista recargada después de escaneo');


      setState(() {
        cargando = false;
        _mensajeEscaneo = 'Escaneo exitoso';
        _esExito        = true;
        _scanController.clear();
        listaFiltrada.clear(); // 🔥 importante
        fechaSeleccionada = null; // 🔥 Quitar filtro de fecha para que se muestre la nueva caja

      });
      return true;
      debugPrint('✅ _procesarEscaneo terminó sin excepción');
    } catch (e, st) {
      debugPrint('‼️ Error en _procesarEscaneo: $e');
      debugPrint('$st');
      if (_mensajeEscaneo == 'Error al procesar escaneo' && !_esExito) {
        setState(() => _mensajeEscaneo = '');
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Si ya estaba mostrando exactamente ese mismo mensaje de error, lo "reseteamos" brevemente:
      if (_mensajeEscaneo == 'Error al procesar escaneo' && !_esExito) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _mensajeEscaneo = '';
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
      setState(() {
        cargando = false;
        _mensajeEscaneo = 'Error al procesar escaneo';
        _esExito        = false;
        _scanController.clear();
      });
      _scanController.clear();
      return false;
    }
  }

// Ejemplo de función auxiliar para elegir un producto
  int _pickRandomId() {
    final posibles = [501, 502, 503];
    return posibles[Random().nextInt(posibles.length)];
  }

  @override
  void initState() {
    super.initState();
    cargarDatosInventario();
    programarSincronizacionDiaria();

    print('🧪 Ejecutando sincronización manual desde initState...');
    CajaService.sincronizarDesdeServidor().then((_) {
      print('🔄 Sincronización terminada. Recargando datos...');
      cargarDatosInventario(force: true);  // 🔥 fuerza la recarga
    });
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entradas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (fechaSeleccionada != null)
                Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(fechaSeleccionada!)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, size: 32),
              color: Colors.green[800],
              tooltip: 'Buscar Caja',
              onPressed: () async {
                final resultado = await showSearch<Caja?>(
                  context: context,
                  delegate: CustomSearchDelegate(
                    onSearch: buscarPorQr,
                    dataList: listaDeDatos,
                    obtenerUltimos4: obtenerUltimos4,
                  ),
                );
                // Si el usuario no seleccionó nada y no hay fecha, recargar todos
                if (resultado == null && fechaSeleccionada == null) {
                  await cargarDatosInventario();
                } else if (fechaSeleccionada != null) {
                  await cargarDatosInventarioPorFecha(
                    fechaSeleccionada!.toIso8601String().split('T').first,
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 32),
              color: Colors.green[800],
              tooltip: 'Seleccionar fecha',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: fechaSeleccionada ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    fechaSeleccionada = picked;
                  });
                  await cargarDatosInventarioPorFecha(
                    picked.toIso8601String().split('T').first,
                  );
                }
              },
            ),
            if (fechaSeleccionada != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 32),
                color: Colors.green[800],
                tooltip: 'Quitar filtro',
                onPressed: () async {
                  setState(() {
                    fechaSeleccionada = null;
                  });
                  await cargarDatosInventario(); // Carga todo
                },
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
                      onSubmitted: (value) async {
                        //presionar enter manualmente
                        await _procesarEscaneo(value);
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
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                )
                    : BoxDecoration(
                  color: _esExito ? Colors.green[100] : Colors.red[100],
                  border: Border.all(color: _esExito ? Colors.green : Colors.red,),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!cargando)...[
                      Icon(_esExito ? Icons.check_circle : Icons.error,
                        color:_esExito ? Colors.green : Colors.red,),
                      const SizedBox(width: 8,)
                    ],
                    Expanded(
                        child: Text(
                          cargando ? 'Guardando caja ...' : _mensajeEscaneo,
                          style: TextStyle(
                            color: cargando
                                ? Colors.black
                                :(_esExito ? Colors.green[800] : Colors.red[800]),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )
                    )
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Icon(Icons.inventory_2_outlined, size: 32, color: Colors.green[800]),
                              title: Text(
                                'Peso: $ultimos4',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Folio: ${item.folio}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              trailing: const Icon(Icons.info_outline, size: 28, color: Colors.green),
                                onTap: () async {
                                  final qr = item.qr;

                                  final detalle = await VentaDetalleService.getVentaDetallePorQR(qr);
                                  String descripcion = 'null';
                                  String precio = 'null';
                                  String peso = 'null';
                                  String subtotal = 'null';

                                  if (detalle != null) {
                                    peso = detalle.pesoNeto?.toStringAsFixed(2) ?? 'null';
                                    subtotal = detalle.subtotal?.toStringAsFixed(2) ?? 'null';

                                    final idProd = detalle.idproducto ?? -1;
                                    final desc = await ProductoService.getDescripcionProducto(idProd);
                                    if (desc != null) descripcion = desc;

                                    final precioNum = await ProductoService.getUltimoPrecioProducto(idProd);
                                    if (precioNum != null) precio = precioNum.toStringAsFixed(2);
                                  }
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Row(
                                        children: const [
                                          Icon(Icons.inventory_2_outlined, color: Colors.green, size: 36),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Detalles de la Caja',
                                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 12),
                                            Row(
                                              children: const [
                                                Icon(Icons.confirmation_number, color: Colors.blueGrey),
                                                SizedBox(width: 8),
                                                Text('Folio:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Center(child: Text(item.folio, style: TextStyle(fontSize: 18))),

                                            const SizedBox(height: 12),
                                            Row(
                                              children: const [
                                                Icon(Icons.fitness_center, color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text('Peso Neto:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Center(child: Text('$peso kg', style: TextStyle(fontSize: 18))),

                                            const SizedBox(height: 12),
                                            Row(
                                              children: const [
                                                Icon(Icons.attach_money, color: Colors.green),
                                                SizedBox(width: 8),
                                                Text('Precio por kilo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Center(child: Text('\$$precio', style: TextStyle(fontSize: 18))),

                                            const SizedBox(height: 12),
                                            Row(
                                              children: const [
                                                Icon(Icons.calculate, color: Colors.purple),
                                                SizedBox(width: 8),
                                                Text('Subtotal:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Center(child: Text('\$$subtotal', style: TextStyle(fontSize: 18))),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: const [
                                                Icon(Icons.date_range, color: Colors.brown),
                                                SizedBox(width: 8),
                                                Text('Fecha escaneo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Center(child: Text(item.fechaEscaneo.split("T").first, style: TextStyle(fontSize: 18))),

                                            const SizedBox(height: 12),
                                            Row(
                                              children: const [
                                                Icon(Icons.description, color: Colors.teal),
                                                SizedBox(width: 8),
                                                Text('Descripción:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Text(descripcion, style: TextStyle(fontSize: 18), textAlign: TextAlign.center,),

                                             ],
                                        ),
                                      ),
                                      actionsAlignment: MainAxisAlignment.end,
                                      actionsPadding: const EdgeInsets.all(12),
                                      actions: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.close, size: 20, color: Colors.white),
                                          label: const Text('Cerrar', style: TextStyle(fontSize: 16, color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                            )

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
          onPressed: () async {
            setState(() {
              _modoEscaneoActivo = !_modoEscaneoActivo;
            });

            if (_modoEscaneoActivo) {
              // Activamos el foco cuando abrimos el escaneo
              Future.delayed(Duration(milliseconds: 500), () {
                FocusScope.of(context).requestFocus(_focusNode);
              });
            } else {
              // Limpia al salir del modo escaneo
              _scanController.clear();
              _mensajeEscaneo = '';
              fechaSeleccionada = null; // 🔥 Limpiar filtro por fecha
              await cargarDatosInventario(force: true); // 🔄 Recargar sin filtro
            }
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
  String get searchFieldLabel => 'Peso';

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
            close(context, caja); // <-- esto es lo importante
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


