import 'dart:async';
import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:conexion/BD/global.dart';
import 'package:conexion/Vendedor/Venta.dart';
import 'package:conexion/models/ventadetalle.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chofer.dart';
import '../services/chofer_servise.dart';
import '../services/venta_services.dart';
import '../services/ventadetalle_services.dart';
import '../models/venta.dart';
import 'package:intl/intl.dart';

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';

import '../actividad.dart';
import 'dart:convert';


class ventas extends StatefulWidget {
  const ventas({super.key});

  @override
  State<ventas> createState() => _ventasState();
}

class _ventasState extends State<ventas> with AutomaticKeepAliveClientMixin<ventas> {
  List<Venta> listaDeDatos   = [];
  List<Venta> listaFiltrada  = [];
  TextEditingController _searchController = TextEditingController();

  bool cargando = true;
  bool get wantKeepAlive => true;
  bool mostrarBusqueda = false;



  DateTime? fechaSeleccionada;

  //Cargar datos de Ventas
  Future<void> cargarVentas() async {
    setState(() => cargando = true);
    final idChofer = UsuarioActivo.idChofer;
    if (idChofer == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Chofer no identificado.'))
      );
      return;
    }
    final raws = await VentaService.obtenerVentasPorChofer(idChofer);
    final ventas = raws.map((m) => Venta.fromMap(Map<String, dynamic>.from(m))).toList();

    ventas.sort((a, b) => b.fecha.compareTo(a.fecha));

    // Filtro por fecha si se seleccionó
    List<Venta> filtradas = ventas;
    if (fechaSeleccionada != null) {
      final fechaBase = DateFormat('yyyy-MM-dd').format(fechaSeleccionada!);
      filtradas = ventas.where((v) =>
      DateFormat('yyyy-MM-dd').format(v.fecha) == fechaBase
      ).toList();
    }

    if (!mounted) return;
    setState(() {
      listaDeDatos = ventas;
      listaFiltrada = filtradas;
      cargando = false;
    });
  }

  void buscarPorNombre(String query) {
    final filtradas = listaDeDatos.where((venta) {
      final folio = venta.folio.toLowerCase();
      return folio.contains(query.toLowerCase());
    }).toList();

    setState(() {
      listaFiltrada = filtradas;
    });
  }


  void ordenarPor(String criterio) {
    final ordenadas = [...listaFiltrada];

    if (criterio == 'precio') {
      // Comparamos el campo total de cada Venta
      ordenadas.sort((a, b) => b.total.compareTo(a.total));
    } else if (criterio == 'fecha') {
      // Si fecha es double (timestamp), podemos compararlos directamente:
      ordenadas.sort((a, b) => a.fecha.compareTo(b.fecha));
    }

    setState(() {
      listaFiltrada = ordenadas;
    });
  }


  void initState(){
    super.initState();
    cargarVentas();
  }

  void dispose(){
    _searchController.dispose();
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ventas',
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
              tooltip: 'Buscar cliente',
              onPressed: () {
                setState(() {
                  mostrarBusqueda = !mostrarBusqueda;
                  _searchController.clear();
                  listaFiltrada = listaDeDatos;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 32),
              color: Colors.green[800],
              tooltip: 'Seleccionar fecha',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    fechaSeleccionada = picked;
                  });
                  await cargarVentas();
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
                  await cargarVentas();
                },
              ),
          ],
        ),

        body: Column(
          children: [
            if (mostrarBusqueda)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre del cliente...',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (value) {
                    setState(() {
                      listaFiltrada = listaDeDatos.where((venta) =>
                          venta.clienteNombre.toLowerCase().contains(value.toLowerCase())
                      ).toList();
                    });
                  },
                  onSubmitted: (value) {
                    if (value.trim().isEmpty) {
                      setState(() {
                        mostrarBusqueda = false;
                      });
                    }
                  },
                ),
              ),
            Expanded(
                child: cargando
                    ? Center(child: CircularProgressIndicator())
                    :listaFiltrada.isEmpty
                    ? Center(child: Text(fechaSeleccionada != null
                    ? "No hay ventas en esa fecha"
                    : "No hay ventas registradas"))
                    : RefreshIndicator(
                    child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: listaFiltrada.length,
                        itemBuilder: (context, index) {
                          final venta = listaFiltrada[index];
                          final dfDate = DateFormat('yyyy-MM-dd');
                          final fechaSolo = dfDate.format(venta.fecha);
                          return Card(
                              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child:Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () async {
                                    // Lanza la página de detalle y espera el bool que venga con pop(true)
                                    final bool? didFinishVenta = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetalleVentaPage(
                                            venta: venta,
                                            showSolicitudDevolucion: false),
                                      ),
                                    );
                                    // Si detuvo la pantalla de detalle con pop(true), recargo la lista:
                                    if (didFinishVenta == true) {
                                      await cargarVentas();
                                    }
                                  },
                                  child: ListTile(
                                    leading: Icon(Icons.receipt_long, size: 32, color: Colors.green[800]),
                                    title: Text('Cliente: ${venta.clienteNombre}', style: TextStyle(fontSize: 18)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [Icon(Icons.attach_money, size: 20), Text('Total: \$${venta.total}', style: TextStyle(fontSize: 16))]),
                                        Row(children: [Icon(Icons.date_range, size: 20), Text('Fecha: $fechaSolo', style: TextStyle(fontSize: 16))]),
                                      ],
                                    ),
                                  )

                                ),
                              )
                          );
                        }
                    ),
                    onRefresh: () async {
                      await cargarVentas();
                    }
                )
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'ventasFAB',
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const venta()),
            );

            if (result == true && mounted) {
              await cargarVentas();
            }
          },
          child: const Icon(Icons.add, size: 28),
        ),

      ),
    );
  }
}

// --------------------------- Venta Detalle tipo ticket
//_----------------------------------------------------
//-----------------------------------------------------
//----------------------------------------------------


class DetalleVentaPage extends StatefulWidget {
  final Venta venta;
  final bool showSolicitudDevolucion;
  const DetalleVentaPage({
    Key? key,
    required this.venta,
    this.showSolicitudDevolucion = false,
  }) : super(key: key);


  @override
  State<DetalleVentaPage> createState() => _DetalleVentaPageState();
}

class _DetalleVentaPageState extends State<DetalleVentaPage> {
  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'qrKeyVenta');
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isPrinterConnected = false;


  @override
  void initState() {
    super.initState();
    _initializePrinterSelection();
  }

  //Comprobar si el bluetooth esta encendido, si no se pide al usuario que lo encienda


  // Solicita permisos de Bluetooth/ubicación en Android 12+ y versiones anteriores.
  Future<void> _initializePrinterSelection() async {
    // 1.1) Verificar si el adaptador Bluetooth está habilitado:
    bool? bluetoothOn = await _printer.isOn;
    if (bluetoothOn != true) {
      // Mostrar diálogo solicitando al usuario que habilite el Bluetooth
      final reintentar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.bluetooth_disabled, color: Colors.blueGrey, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bluetooth apagado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Para imprimir, primero habilita el Bluetooth en tu dispositivo.\n\n'
                  'Después, presiona "Recargar".',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsPadding: EdgeInsets.all(12),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón Cancelar
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.cancel, size: 20, color: Colors.white),
                        label: Text('Cancelar', style: TextStyle(fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                    SizedBox(width: 12), // Espacio entre botones

                    // Botón Reintentar
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh, size: 20, color: Colors.white),
                        label: Text('Recargar', style: TextStyle(fontSize: 16, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
      );

      if (reintentar == true) {
        // Esperamos un momento para que el usuario encienda el Bluetooth
        await Future.delayed(const Duration(seconds: 1));
        return _initializePrinterSelection();
      } else {
        return;
      }
    }

    // Pedimos permisos necesarios para Bluetooth/ubicación
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // 1) Obtenemos la lista de dispositivos Bluetooth emparejados
    bool? alreadyConnected = await _printer.isConnected;
    if (alreadyConnected != true) {
      _devices = await _printer.getBondedDevices();
      for (var d in _devices) {
        print('📡 Emparejado: ${d.name} / ${d.address}');
      }
    }

    // 2) Obtenemos el chofer actual según el correo guardado en UsuarioActivo
    final correo = UsuarioActivo.correo;
    if (correo != null) {
      Chofer? chofer = await ChoferService.obtenerUsuarioLocal(correo);
      if (chofer != null) {
        String nombreImpresoraEsperada = chofer.impresora;
        print('Impresora esperada: $nombreImpresoraEsperada');
        // Buscamos entre _devices aquel cuyo name o address coincida
        for (BluetoothDevice device in _devices) {
          final deviceName = device.name?.toLowerCase().trim() ?? '';
          final deviceAddr = device.address?.toLowerCase().trim() ?? '';
          final esperado   = nombreImpresoraEsperada.toLowerCase().trim();

          if (deviceName == esperado || deviceAddr == esperado) {
            print('Impresora encontrada: ${device.name} / ${device.address}');
            _selectedDevice = device;
            break;
          }
        }

      }
    }

    // Refrescar UI ahora que _devices y _selectedDevice están cargados
    setState(() {});
  }

  double _toDoubleSafe(dynamic n) => (n as num?)?.toDouble() ?? 0.0;


  Future<void> setCodigoLatin1() async {
    // Comando ESC t n → 27, 116, n → 27 116 16 (tabla Latin1)
    final List<int> comando = [27, 116, 16];
    _printer.writeBytes(Uint8List.fromList(comando));
  }

  Future<Uint8List> buildQrPng(String data, {double size = 256.0}) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final ui.Image img = await painter.toImage(size); // size es double
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  //RECETEAR LA IMPRESORA
  Future<void> _initPrinterMode() async {
    // ESC @  -> reset
    await _printer.writeBytes(Uint8List.fromList([27, 64]));
    // Línea por defecto
    await _printer.writeBytes(Uint8List.fromList([27, 50]));
  }

  Future<File> _buildQrFile(String data) async {
    final png = await buildQrPng(data, size: 150.0); // antes 256.0
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    return file;
  }


  Future<void> _slowPrint(void Function() fn, [int ms = 70]) async {
    fn();
    await Future.delayed(Duration(milliseconds: ms));
  }

// Reintento si se rompe el socket ("Broken pipe")
  Future<T> _withReconnect<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      if (e.toString().contains('Broken pipe')) {
        try { await _printer.disconnect(); } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 300));
        await _printer.connect(_selectedDevice!);
        await Future.delayed(const Duration(milliseconds: 200));
        await setCodigoLatin1(); // reset borró la codepage
        return await op(); // reintento 1
      }
      rethrow;
    }
  }


  void imprimirTextoCompatible(String texto) {
    final bytes = latin1.encode(texto);
    _printer.writeBytes(Uint8List.fromList(bytes));
    _printer.printNewLine();
  }

  //Contenido para la impresión
  Future<void> _printTicketContent(Venta venta, List<VentaDetalle> detalles) async {
    final dfDate = DateFormat('yyyy-MM-dd');
    final dfTime = DateFormat('HH:mm');
    final fechaStr = dfDate.format(venta.fecha);
    final horaStr  = dfTime.format(venta.fecha);

    await _slowPrint(() => _printer.printNewLine());
    await setCodigoLatin1();
    await _slowPrint(() => imprimirTextoCompatible("Agropecuaria El Avion")); // sin acento por seguridad
    await _slowPrint(() => _printer.printCustom("Perif. Guada-Maza km 7.1", 1, 1));
    await setCodigoLatin1();
    await _slowPrint(() => imprimirTextoCompatible("Penita, Tepic, Nayarit 63167")); // evita 'ñ' si te da guerra
    await _slowPrint(() => _printer.printCustom("RFC: AAV8705296P4", 1, 1));
    await _slowPrint(() => _printer.printNewLine());

    await _slowPrint(() => _printer.printCustom("Fecha: $fechaStr    Hora: $horaStr", 1, 1));
    await _slowPrint(() => _printer.printCustom("Folio: ${venta.folio}", 1, 0));
    await _slowPrint(() => _printer.printCustom("Vendedor: ${UsuarioActivo.nombre ?? ''}", 1, 0));
    await _slowPrint(() => _printer.printNewLine());

    await setCodigoLatin1();
    await _slowPrint(() => imprimirTextoCompatible("Cliente: ${venta.clienteNombre ?? 'N/A'}"));
    await _slowPrint(() => imprimirTextoCompatible("Direccion: ${venta.direccionCliente ?? 'N/A'}"));
    await _slowPrint(() => _printer.printCustom("RFC: ${venta.rfcCliente ?? 'N/A'}", 1, 0));

    await _slowPrint(() => _printer.printNewLine());
    await _slowPrint(() => _printer.printCustom("--------------------------------", 1, 1));

    // Encabezados
    const int ancho1 = 10, ancho2 = 5, ancho3 = 7, ancho4 = 10;
    final headerLine = "Producto".padRight(ancho1) +
        "Peso".padRight(ancho2) +
        "Costo".padRight(ancho3) +
        "subTotal".padRight(ancho4);
    await _slowPrint(() => _printer.printCustom(headerLine, 1, 1));
    await _slowPrint(() => _printer.printCustom("--------------------------------", 1, 1));

    for (final d in detalles) {
      final pesoDouble     = _toDoubleSafe(d.pesoNeto);
      final precioDouble   = _toDoubleSafe(d.precio);
      final subtotalDouble = pesoDouble * precioDouble;

      final peso     = pesoDouble.toStringAsFixed(2);
      final precio   = "\$${precioDouble.toStringAsFixed(2)}";
      final subtotal = "\$${subtotalDouble.toStringAsFixed(2)}";

      var desc = d.descripcion ?? 'Producto';
      if (desc.length > 30) desc = desc.substring(0, 27) + '...';

      await _slowPrint(() => _printer.printCustom(desc, 1, 0));

      final espacio1 = 10 - peso.length;
      final espacio2 = 10 - precio.length;
      final lineaValores = peso + ' ' * espacio1 + precio + ' ' * espacio2 + subtotal;

      await _slowPrint(() => _printer.printCustom(lineaValores, 1, 0));
      await _slowPrint(() => _printer.printNewLine(), 40);
    }

    await _slowPrint(() => _printer.printCustom("--------------------------------", 1, 1));

    final total    = _toDoubleSafe(venta.total);
    final recibido = _toDoubleSafe(venta.pagoRecibido);
    await _slowPrint(() => _printer.printLeftRight("IVA:", "\$0.00", 1));
    await _slowPrint(() => _printer.printLeftRight("Total:", "\$${total.toStringAsFixed(2)}", 1));
    if (venta.idpago == 1) {
      await _slowPrint(() => _printer.printLeftRight("Entregado:", "\$${recibido.toStringAsFixed(2)}", 1));
      await _slowPrint(() => _printer.printLeftRight("Cambio:", "\$${(recibido - total).toStringAsFixed(2)}", 1));
    }

    await _slowPrint(() => _printer.printNewLine());
    await _slowPrint(() => _printer.printNewLine());
    await _slowPrint(() => _printer.printCustom("------------------------------", 1, 1));
    await _slowPrint(() => _printer.printCustom("Firma de recibido", 1, 1));
    await _slowPrint(() => _printer.printNewLine());
    await _slowPrint(() => _printer.printNewLine());

    // QR (con reintento y pausas)
    await _withReconnect(() async {
      await _initPrinterMode();                // reset
      await Future.delayed(const Duration(milliseconds: 200));
      await setCodigoLatin1();                 // reset borró codepage

      final qrFile = await _buildQrFile(venta.folio);
      await _slowPrint(() => _printer.printImage(qrFile.path), 140);
      await _slowPrint(() => _printer.printNewLine(), 120);
      return 0;
    });
    await _slowPrint(() => _printer.printNewLine());
    await _slowPrint(() => _printer.printNewLine());
  }


  // Función que genera y envía el ticket a la impresora asignada.
  Future<void> _imprimirRecibo(Venta venta, List<VentaDetalle> detalles) async {
    // 1) Verificar que haya impresora asignada
    if (_selectedDevice == null) {
      await showDialog(
        context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.print_disabled, color: Colors.red, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Impresora no asignada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'No se encontró ninguna impresora configurada para este chofer.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            actions: [
              ElevatedButton.icon(
                icon: Icon(Icons.check, size: 24, color: Colors.white),
                label: Text(
                  'Entendido',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(140, 48),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          )

      );
      return;
    }

    // 2) Intentar conectar a la impresora (si no está ya conectado)
    try {
      bool? alreadyConnected = await _printer.isConnected;
      if (alreadyConnected != true) {
        await _printer.connect(_selectedDevice!);
      }
      _isPrinterConnected = true;
      await Future.delayed(const Duration(milliseconds: 200));
      await setCodigoLatin1(); // <- muy importante tras conectar
    } catch (_) {
      await showDialog(
        context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.wifi_off, color: Colors.orange, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error de conexión',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'No se pudo conectar a la impresora.\n\n'
                  'Asegúrate de que esté encendida, con batería suficiente y correctamente emparejada por Bluetooth.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.justify,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            actions: [
              ElevatedButton.icon(
                icon: Icon(Icons.refresh, size: 24, color: Colors.white),
                label: Text(
                  'Reintentar',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(160, 48),
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          )

      );
      return;
    }

    // 3) Confirmar que realmente quedó conectado
    bool? isConnected = await _printer.isConnected;
    if (isConnected != true) {
      await showDialog(
        context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.bluetooth_disabled, color: Colors.grey, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Impresora desconectada',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'La impresora Bluetooth no está conectada.\n\n'
                  'Asegúrate de que esté encendida y vinculada correctamente.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.justify,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: EdgeInsets.all(12),
            actions: [
              ElevatedButton.icon(
                icon: Icon(Icons.bluetooth_searching, color: Colors.white),
                label: Text('Verificar', style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  minimumSize: Size(160, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          )

      );
      return;
    }

    // 4) Imprimir la primera copia
    try {
      await _printTicketContent(venta, detalles);
      await Future.delayed(Duration(seconds: 1));

    } catch (e) {
      // Si falla la primera copia, mostramos error y salimos
      await showDialog(
        context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al imprimir',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              'Hubo un problema al imprimir la primera copia:\n\n$e',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.justify,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.all(12),
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Entendido', style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          )

      );
      await _printer.disconnect();
      _isPrinterConnected = false;
      return;
    }

    // 5) Mostrar diálogo para que el usuario corte manualmente el papel
    await showDialog(
      context: context,
      barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.print, color: Colors.green, size: 36),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Primera copia impresa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Por favor, corta el papel de la primera copia.\n\n'
                'Cuando estés listo, presiona el botón para imprimir la segunda copia.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.justify,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            ElevatedButton.icon(
              icon: Icon(Icons.print_outlined, color: Colors.white),
              label: Text('Continuar', style: TextStyle(fontSize: 18, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(200, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        )

    );

    // 6) Imprimir la segunda copia
    try {
      await _printTicketContent(venta, detalles);
    } catch (e) {
      // Si falla la segunda copia, mostramos error
      await showDialog(
        context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.redAccent, size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al imprimir',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              'Hubo un problema al imprimir la segunda copia:\n\n$e',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.justify,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.all(12),
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Entendido', style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          )
      );
    }

    // 7) Desconectar e informar éxito
    await _printer.disconnect();
    _isPrinterConnected = false;

    await showDialog(
      context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 36),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Listo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Se imprimieron ambas copias correctamente.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: EdgeInsets.all(12),
          actions: [
            ElevatedButton.icon(
              icon: Icon(Icons.check, color: Colors.white),
              label: Text('Aceptar', style: TextStyle(fontSize: 18, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(140, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        )
    );

    Navigator.of(context).pop(true);
  }


  @override
  Widget build(BuildContext context) {
    final folio = widget.venta.folio;
    return FutureBuilder<List<VentaDetalle>>(
      future: VentaDetalleService.getByFolio(folio),
      builder: (context, snapshot) {
        final detalles = snapshot.data ?? [];
        final total    = _toDoubleSafe(widget.venta.total);
        final recibido = _toDoubleSafe(widget.venta.pagoRecibido);
        final dfDate = DateFormat('yyyy-MM-dd');
        final dfTime = DateFormat('HH:mm');

        return Scaffold(
          backgroundColor: const Color(0xFFF4F4F4),
          appBar: AppBar(
            title: const Text('Detalles de Venta'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final cerrar = await showDialog<bool>(
                  context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Salir de la ventana',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      content: const Text(
                        '¿Estás seguro de que quieres salir?',
                        style: TextStyle(fontSize: 18),
                      ),
                      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      actionsAlignment: MainAxisAlignment.spaceBetween,
                      actions: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child:  Row(
                            children: [
                              // Botón Cancelar (izquierda)
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
                                  onPressed: () => Navigator.of(context).pop(false),
                                ),
                              ),
                              const SizedBox(width: 12), // Espacio entre botones

                              // Botón Sí (derecha)
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.exit_to_app, size: 20, color: Colors.white),
                                  label: const Text(
                                    'Sí',
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

                        ),
                      ],
                    )
                );
                if (cerrar == true) Navigator.of(context).pop(true);
              },
            ),

            actions: [
              if (!widget.showSolicitudDevolucion)
                IconButton(
                  icon: const Icon(Icons.print, size:30),
                  tooltip: 'Imprimir recibo',
                  onPressed: () {
                    _imprimirRecibo(widget.venta, detalles);
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Muestra qué impresora se asignó
                if (_selectedDevice != null) ...[
                  Text(
                    "Impresora asignada: ${_selectedDevice!.name ?? _selectedDevice!.address}",
                    style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                ],
                // Resto del ticket: datos de la venta
                Center(
                  child: Text(
                    'Agropecuaria El Avion',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Text(
                    'Perif. Guadalajara-Mazatlan km 7.1 Peñita, Tepic, Nayarit 63167.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(thickness: 1.5),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Fecha: ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: dfDate.format(widget.venta.fecha),
                            style: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: 'Hora: ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: dfTime.format(widget.venta.fecha),
                            style: const TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Folio: ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: widget.venta.folio,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Vendedor: ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: UsuarioActivo.nombre ?? '',
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Cliente: ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: widget.venta.clienteNombre ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Dirección: ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: widget.venta.direccionCliente ?? 'N/A',
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'RFC: ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: widget.venta.rfcCliente ?? 'N/A',
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),

                const Divider(thickness: 1.5),
                const SizedBox(height: 8),

                // Tabla de detalle
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      'Producto | peso | costo | subTotal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20, // Tamaño aumentado
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 4),
                ...detalles.map((d) {
                  final nombreProducto = d.descripcion ?? 'Producto';
                  final double pesoDouble = _toDoubleSafe(d.pesoNeto);
                  final double precioPorKilo = _toDoubleSafe(d.precio);

                  final double subtotalDouble = pesoDouble * precioPorKilo;
                  final subtotal = "\$${subtotalDouble.toStringAsFixed(2)}";

                  final peso = pesoDouble.toStringAsFixed(2);
                  final precio = "\$${precioPorKilo.toStringAsFixed(2)}";


                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del producto con guiones
                        Text(
                          '$nombreProducto',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 4),
                        // Segunda línea con peso, costo y subtotal alineados a la derecha
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                peso,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(width: 16),
                            SizedBox(
                              width: 80,
                              child: Text(
                                precio,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(width: 2),
                            SizedBox(
                              width: 100,
                              child: Text(
                                subtotal,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                }).toList(),

                const Divider(thickness: 1.5),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Forma de pago: ${widget.venta.metodoPago ?? 'N/A'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'IVA: \$0.0',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total:    \$${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.venta.idpago == 1) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Entregado: \$${recibido.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Cambio:   \$${(recibido - total).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                const Divider(thickness: 1),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Firma de recibido',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      RepaintBoundary(
                        key: qrKey,
                        child: QrImageView(
                          data: widget.venta.folio,
                          version: QrVersions.auto,
                          size: 100,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 32),
                if (widget.showSolicitudDevolucion) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF479D8D),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('Solicitar devolución'),
                      )
                    ],
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}


class VentasSearchDelegate extends SearchDelegate<Venta?> {
  final Function(String) onSearch;
  final List<Venta> dataList;

  VentasSearchDelegate({
    required this.onSearch,
    required this.dataList,
  }) : super(
    searchFieldLabel: 'Nombre del cliente o folio',
  );

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: Icon(Icons.clear),
      onPressed: () {
        query = '';
        onSearch(query);
      },
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    final results = dataList.where((venta) {
      final nombre = venta.clienteNombre.toLowerCase();
      final folio  = venta.folio.toLowerCase();
      return nombre.contains(query.toLowerCase()) ||
          folio.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final venta = results[index];
        return ListTile(
          title: Text('Folio: ${venta.folio}'),
          subtitle: Text('Cliente: ${venta.clienteNombre}'),
          onTap: () {
            close(context, venta);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleVentaPage(venta: venta),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = dataList.where((venta) {
      final nombre = venta.clienteNombre.toLowerCase();
      final folio  = venta.folio.toLowerCase();
      return nombre.contains(query.toLowerCase()) ||
          folio.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final venta = suggestions[index];
        return ListTile(
          title: Text('Folio: ${venta.folio}'),
          subtitle: Text('Cliente: ${venta.clienteNombre}'),
          onTap: () {
            query = venta.clienteNombre;
            showResults(context);
          },
        );
      },
    );
  }
}






