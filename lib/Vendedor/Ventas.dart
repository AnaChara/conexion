import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
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

  //Cargar datos de Ventas
  Future<void> cargarVentas() async {
   // if (listaDeDatos.isNotEmpty) return; <-- Evitar que no recargue pagina
    setState(() => cargando = true);

    final correo = UsuarioActivo.correo;
    if (correo == null) {
      // manejar sin sesión
      return;
    }

    // 1) Traigo las filas ordenadas en SQL (ORDER BY fecha DESC)
    final raws = await VentaService.obtenerVentasPorCorreo(correo);

    // 2) Las convierto en objetos Venta
    final ventas = raws
        .map((m) => Venta.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    // 3) (Opcional) Me aseguro en Dart que sigan ordenadas descendentemente
    ventas.sort((a, b) => b.fecha.compareTo(a.fecha));

    if (!mounted) return;
    setState(() {
      listaDeDatos  = ventas;
      listaFiltrada = ventas;
      cargando      = false;
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
          title: Text('Ventas'),
          actions: [
            IconButton(
                onPressed: (){
                  showSearch(
                      context: context,
                      delegate: VentasSearchDelegate(
                        onSearch: buscarPorNombre,
                        dataList: listaDeDatos
                      ),
                  );
            }
                , icon: Icon(Icons.search)
            ),
            IconButton(
                onPressed: (){
                  showModalBottomSheet(
                      context: context,
                      builder: (_) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text('Ordenar por precio'),
                            onTap: (){
                              ordenarPor('precio');
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: Text('Ordenar por fecha'),
                            onTap: (){
                              ordenarPor('fecha');
                              Navigator.pop(context);
                            },
                          )
                        ],
                      )
                  );
                },
                icon: Icon(Icons.sort)
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
                child: cargando
                    ? Center(child: CircularProgressIndicator())
                    :listaFiltrada.isEmpty
                    ? Center(child: Text("No hay ventas registradas"))
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
                                    leading: Icon(Icons.shopping_cart),
                                    title: Text('Cliente: ${venta.clienteNombre}'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total \$${venta.total}'),
                                        Text('Fecha: $fechaSolo'),
                                      ],
                                    ),
                                  ),
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
          child: Icon(Icons.add),
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
          title: const Text('Bluetooth apagado'),
          content: const Text(
            'Para imprimir, habilita el Bluetooth. '
                'Presiona “Reintentar” una vez que esté encendido.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
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
    }

    // 2) Obtenemos el chofer actual según el correo guardado en UsuarioActivo
    final correo = UsuarioActivo.correo;
    if (correo != null) {
      Chofer? chofer = await ChoferService.obtenerUsuarioLocal(correo);
      if (chofer != null) {
        String nombreImpresoraEsperada = chofer.impresora;
        // Buscamos entre _devices aquel cuyo name o address coincida
        for (BluetoothDevice device in _devices) {
          if (device.name == nombreImpresoraEsperada ||
              device.address == nombreImpresoraEsperada) {
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

  // Función que genera y envía el ticket a la impresora asignada.
  Future<void> _imprimirRecibo(Venta venta, List<VentaDetalle> detalles) async {
    // 1) Verificar que exista impresora en base de datos y esté en la lista
    if (_selectedDevice == null) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Impresora no asignada'),
          content: const Text(
            'No se encontró ninguna impresora configurada para este chofer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // 2) Intentar conectar a la impresora (si no está ya conectado)
    try {
      await _connectPrinter();
    } catch (_) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error de conexión'),
          content: const Text('No se pudo conectar a la impresora. Verifica que esté encendida y emparejada.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // 3) Preguntamos al plugin si realmente quedó conectado
    bool? isConnected = await _printer.isConnected;
    if (isConnected != true) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Impresora desconectada'),
          content: const Text('La impresora Bluetooth no está conectada.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // 4) Si estamos conectados, enviamos el contenido del ticket
    try {
      final dfDate = DateFormat('yyyy-MM-dd');
      final dfTime = DateFormat('HH:mm');
      String fechaStr = dfDate.format(venta.fecha);
      String horaStr = dfTime.format(venta.fecha);

      // Cabecera
      _printer.printNewLine();
      _printer.printCustom("Agropecuaria El Avion", 2, 1);
      _printer.printNewLine();
      _printer.printCustom("Perif. Guadalajara-Mazatlan km 7.1", 1, 1);
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
      _printer.printCustom("Cliente: ${venta.clienteNombre ?? 'N/A'}", 1, 0);
      _printer.printNewLine();
      _printer.printCustom("--------------------------------", 1, 1);

      // Encabezados columnas
      // 1) Define los textos de las tres columnas:
      String left   = "Peso";          // va a la izquierda
      String middle = "Descripcion";   // va en el centro
      String right  = "Importe";       // va a la derecha

      const int anchoTotal = 32;

      int lenLeft   = left.length;     // 4
      int lenMid    = middle.length;   // 11
      int lenRight  = right.length;    // 7


      int espacioRestante = anchoTotal - (lenLeft + lenMid + lenRight);
      int espaciosLM = espacioRestante ~/ 2;          // 10 ~/ 2 = 5
      int espaciosMR = espacioRestante - espaciosLM;  // 10 - 5 = 5

      String headerLine =
          left +
              " " * espaciosLM +
              middle +
              " " * espaciosMR +
              right;

      _printer.printCustom(headerLine, 1, 1);

      _printer.printCustom("--------------------------------", 1, 1);

      // Filas de detalle
      for (final d in detalles) {
        String pesoStr    = (d.pesoNeto as num).toStringAsFixed(2);              // ej. "12.34" (5 chars)
        String importeStr = "\$${(d.subtotal as num).toStringAsFixed(2)}";       // ej. "$56.78" (6 chars)
        String desc       = d.descripcion ?? '';

        const int anchoTotal = 32;

        int lenPeso    = pesoStr.length;    // ex: 5
        int lenImporte = importeStr.length; // ex: 6
        int disponibleParaDesc = anchoTotal - (lenPeso + lenImporte + 2);
        if (disponibleParaDesc < 0) disponibleParaDesc = 0;

        if (desc.length > disponibleParaDesc) {
          if (disponibleParaDesc > 3) {
            desc = desc.substring(0, disponibleParaDesc - 3) + "...";
          } else {
            desc = desc.substring(0, disponibleParaDesc);
          }
        }

        String izquierda = pesoStr + " " + desc;
        int lenIzquierda = izquierda.length; // peso + espacio + descripción recortada

        int espaciosEntre = anchoTotal - (lenIzquierda + lenImporte);
        if (espaciosEntre < 1) espaciosEntre = 1; // al menos un espacio

        // Montamos la línea final:
        String linea = izquierda + " " * espaciosEntre + importeStr;

        // 3) Imprimimos con size=1 (fuente normal):
        _printer.printCustom(linea, 1, 1);
        _printer.printNewLine();
      }

      _printer.printCustom("--------------------------------", 1, 1);

      // Totales
      double total = _toDoubleSafe(venta.total);
      double recibido = _toDoubleSafe(venta.pagoRecibido);
      _printer.printLeftRight("Total:", "\$${total.toStringAsFixed(2)}", 1);
      if (venta.idpago == 1) {
        _printer.printLeftRight("Entregado:", "\$${recibido.toStringAsFixed(2)}", 1);
        _printer.printLeftRight("Cambio:", "\$${(recibido - total).toStringAsFixed(2)}", 1);
      }
      _printer.printNewLine();

      // Pie de ticket
      _printer.printNewLine();
      _printer.printNewLine();
      _printer.printCustom("------------------------------", 1, 1);
      _printer.printCustom("Firma de recibido", 1, 1);
      _printer.printNewLine();
      _printer.printNewLine();

      // Cortar papel
      _printer.paperCut();

      // Mensaje de éxito y cerrar la página
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Listo'),
          content: const Text('El ticket se imprimió correctamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Finalmente, desconectamos para poder seleccionar otra vez en el futuro
      await _printer.disconnect();
      _isPrinterConnected = false;

      // Después de cerrar el diálogo, salimos de esta pantalla con pop(true)
      Navigator.of(context).pop(true);
    } catch (e) {
      // Si falla la impresión
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error al imprimir'),
          content: Text('Hubo un problema al imprimir: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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
                    title: const Text('Salir de la venta'),
                    content: const Text('¿Estás seguro de que quieres salir?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Sí'),
                      ),
                    ],
                  ),
                );
                if (cerrar == true) Navigator.of(context).pop(true);
              },
            ),
            actions: [
              if (!widget.showSolicitudDevolucion)
                IconButton(
                  icon: const Icon(Icons.print),
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
                    style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                ],
                // Resto del ticket: datos de la venta
                Center(
                  child: Text(
                    'Agropecuaria El Avión',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Text(
                    'Perif. Guadalajara-Mazatlan km 7.1 Peñita, Tepic, Nayarit 63167.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: widget.venta.clienteNombre ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1.5),
                const SizedBox(height: 8),

                // Tabla de detalle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: const [
                      SizedBox(width: 48, child: Text('PESO', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('DESCRIPCIÓN', style: TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(width: 64, child: Text('IMPORTE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ...detalles.map((d) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            (d.pesoNeto as num).toStringAsFixed(2),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            d.descripcion ?? '',
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total:    \$${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.venta.idpago == 1) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Entregado: \$${recibido.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Cambio:   \$${(recibido - total).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                const Divider(thickness: 1),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Firma de recibido',
                    style: TextStyle(fontSize: 16),
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






