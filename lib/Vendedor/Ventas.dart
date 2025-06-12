import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
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


import '../actividad.dart';

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

  DateTime? fechaSeleccionada;

  //Cargar datos de Ventas
  Future<void> cargarVentas() async {
    setState(() => cargando = true);
    final correo = UsuarioActivo.correo;
    if (correo == null) return;

    final raws = await VentaService.obtenerVentasPorCorreo(correo);
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
          title: Text('Ventas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          actions: [
            Row(
              children: [
                TextButton.icon(
                  icon: Icon(Icons.calendar_today, size: 28,),
                  label: Text(fechaSeleccionada != null
                      ? DateFormat('dd/MM/yyyy').format(fechaSeleccionada!)
                      : 'Todas las fechas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );

                    setState(() {
                      fechaSeleccionada = picked;
                    });
                    await cargarVentas();
                  },
                ),
                if (fechaSeleccionada != null)
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () async {
                      setState(() {
                        fechaSeleccionada = null;
                      });
                      await cargarVentas();
                    },
                  ),
              ],
            ),

          ],
        ),
        body: Column(
          children: [
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
            onPressed: () {
              Navigator.push(context,
              MaterialPageRoute(builder: (_)=> venta()));
            },
          child: Icon(Icons.add,size: 28),
        ),
      ),
    );
  }
}


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
                        onPressed: () => Navigator.of(context).pop(false),
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
        print('🖨️ Impresora esperada: $nombreImpresoraEsperada');
        // Buscamos entre _devices aquel cuyo name o address coincida
        for (BluetoothDevice device in _devices) {
          final deviceName = device.name?.toLowerCase().trim() ?? '';
          final deviceAddr = device.address?.toLowerCase().trim() ?? '';
          final esperado   = nombreImpresoraEsperada.toLowerCase().trim();

          if (deviceName == esperado || deviceAddr == esperado) {
            print('✅ Impresora encontrada: ${device.name} / ${device.address}');
            _selectedDevice = device;
            break;
          }
        }

      }
    }

    // Refrescar UI ahora que _devices y _selectedDevice están cargados
    setState(() {});
  }

  // Intenta conectar al dispositivo seleccionado si aún no está conectado.
  Future<void> _connectPrinter() async {
    if (_selectedDevice == null) {
      throw Exception('No se encontró impresora asignada al chofer');
    }
    bool? alreadyConnected = await _printer.isConnected;
    if (alreadyConnected == true) {
      _isPrinterConnected = true;
      return;
    }
    await _printer.connect(_selectedDevice!);
    _isPrinterConnected = true;
  }

  double _toDoubleSafe(dynamic n) => (n as num?)?.toDouble() ?? 0.0;


  String quitarAcentos(String texto) {
    const acentos = 'áéíóúÁÉÍÓÚñÑüÜ';
    const reemplazos = 'aeiouAEIOUnNuU';

    return texto.split('').map((c) {
      final index = acentos.indexOf(c);
      return index != -1 ? reemplazos[index] : c;
    }).join();
  }

  //Contenido para la impresión
  Future<void> _printTicketContent(Venta venta, List<VentaDetalle> detalles) async {
    final dfDate = DateFormat('yyyy-MM-dd');
    final dfTime = DateFormat('HH:mm');
    String fechaStr = dfDate.format(venta.fecha);
    String horaStr = dfTime.format(venta.fecha);

    // Cabecera
    _printer.printNewLine();
    _printer.printCustom("Agropecuaria El Avión", 2, 1);
    _printer.printNewLine();
    _printer.printCustom("Perif. Guada-Maza km 7.1", 1, 1);
    _printer.printCustom("Penita, Tepic, Nayarit 63167", 1, 1);
    _printer.printNewLine();

    // Fecha y hora
    _printer.printLeftRight("F: $fechaStr", "H: $horaStr", 1);
    _printer.printNewLine();

    // Folio y vendedor
    _printer.printCustom("Folio: ${venta.folio}", 1, 0);
    _printer.printCustom("Vendedor: ${UsuarioActivo.nombre ?? ''}", 1, 0);
    _printer.printNewLine();

    // Cliente
    _printer.printCustom("Cliente: ${quitarAcentos(venta.clienteNombre ?? 'N/A')}", 1, 0);
    _printer.printCustom("Direccion: ${quitarAcentos(venta.direccionCliente ?? 'N/A')}", 1, 0);
    // NUEVO: RFC
    _printer.printCustom("RFC: ${venta.rfcCliente ?? 'N/A'}", 1, 0);

    _printer.printNewLine();
    _printer.printCustom("--------------------------------", 1, 1);

    // Encabezados columnas
    const int anchoTotal = 32;

    String col1 = "Producto";
    String col2 = "Peso";
    String col3 = "Costo";
    String col4 = "subTotal";

// Asignamos longitud fija a cada columna para que cuadre con 32
    int ancho1 = 10; // Producto
    int ancho2 = 5;  // Peso
    int ancho3 = 7;  // Costo
    int ancho4 = 10; // subTotal

    String headerLine =
        col1.padRight(ancho1) +
            col2.padRight(ancho2) +
            col3.padRight(ancho3) +
            col4.padRight(ancho4);

    _printer.printCustom(headerLine, 1, 1);
    _printer.printCustom("--------------------------------", 1, 1);

    // Filas de detalle
    for (final d in detalles) {
      final peso = (d.pesoNeto as num).toStringAsFixed(2);
      final precio = "\$${(d.precio as num).toStringAsFixed(2)}";
      final subtotal = "\$${(d.subtotal as num).toStringAsFixed(2)}";
      String desc = d.descripcion ?? 'Producto';

      // 👉 Limita descripción a una sola línea legible
      if (desc.length > 30) {
        desc = desc.substring(0, 27) + '...';
      }

      // 🖨 Línea 1: descripción
      _printer.printCustom(desc, 1, 0); // alineado a la izquierda

      // 🖨 Línea 2: peso - precio - subtotal, con espacio entre cada uno
      final espacio1 = 10 - peso.length;
      final espacio2 = 10 - precio.length;

      final lineaValores =
          peso + ' ' * espacio1 +
              precio + ' ' * espacio2 +
              subtotal;

      _printer.printCustom(lineaValores, 1, 0); // alineado a la izquierda
      _printer.printNewLine();
    }


    _printer.printCustom("--------------------------------", 1, 1);

    // Totales (IVA fijo 0.00)
    double total = _toDoubleSafe(venta.total);
    double recibido = _toDoubleSafe(venta.pagoRecibido);
    _printer.printLeftRight("IVA:", "\$0.00", 1);
    _printer.printLeftRight("Total:", "\$${total.toStringAsFixed(2)}", 1);
    if (venta.idpago == 1) {
      _printer.printLeftRight("Entregado:", "\$${recibido.toStringAsFixed(2)}", 1);
      _printer.printLeftRight("Cambio:", "\$${(recibido - total).toStringAsFixed(2)}", 1);
    }
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.printCustom("------------------------------", 1, 1);
    _printer.printCustom("Firma de recibido", 1, 1);
    _printer.printNewLine();
    _printer.printNewLine();
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
              'No se encontró ninguna impresora configurada para este chofer.\n\n'
                  'Por favor, verifica la configuración en el apartado de impresoras.',
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
                  final peso = (d.pesoNeto as num).toStringAsFixed(2);
                  final precio = '\$${(d.precio as num).toStringAsFixed(2)}';
                  final subtotal = '\$${(d.subtotal as num).toStringAsFixed(2)}';

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
                const SizedBox(height: 48),
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






