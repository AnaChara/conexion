import 'package:conexion/BD/global.dart';
import 'package:conexion/models/ventadetalle.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    if (listaDeDatos.isNotEmpty) return;
    setState(() => cargando = true);

    final correo = UsuarioActivo.correo;
    if (correo == null) {
      // manejar sin sesión
      return;
    }

    // llamamos al nuevo método
    final raws = await VentaService.obtenerVentasPorCorreo(correo);

    final ventas = raws
        .map((m) => Venta.fromMap(Map<String, dynamic>.from(m)))
        .toList();

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
      ordenadas.sort((a, b) => b.fecha.compareTo(a.fecha));
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
                    : ListView.builder(
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
                            onTap: () async {},
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
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => DetalleVentaPage(venta: venta))
                                )
                            ),
                          ),
                        )
                      );
                    }
                )
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'ventasFAB',
            onPressed: (){
              setState(() {
                
              });
            },
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}

class DetalleVentaPage extends StatelessWidget {
  final Venta venta;
  const DetalleVentaPage({Key? key, required this.venta}) : super(key: key);

  double _toDoubleSafe(dynamic n) =>
      (n as num?)?.toDouble() ?? 0.0;


  @override
  Widget build(BuildContext context) {
    final folio = venta.folio;
    return FutureBuilder<List<VentaDetalle>>(
      future: VentaDetalleService.getByFolio(folio),
      builder:(context, snapshot) {
        final detalles = snapshot.data ?? [];
        final total    = _toDoubleSafe(venta.total);
        final recibido = _toDoubleSafe(venta.pagoRecibido);
        final dfDate = DateFormat('yyyy-MM-dd');
        final dfTime = DateFormat('HH:mm');

        return Scaffold(
          backgroundColor: Color(0xFFF4F4F4),
          appBar: AppBar(
            title: Text('Detalles de Venta'),
          ),
          body: Padding(
              padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
        child: Text(
        'Agropecuaria El Avión',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(
          child: Text(
          'Perif. Guadalajara-Mazatlan km 7.1 Peñita, Tepic, Nayarit 63167.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]), textAlign: TextAlign.center ,
          ),
          ),
        Divider(thickness: 1.5),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Fecha: ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: dfDate.format(venta.fecha),
                            style: TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),

                    Text.rich(
                      TextSpan(
                        text: 'Hora: ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: dfTime.format(venta.fecha),
                            style: TextStyle(fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Folio: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: venta.folio,
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Vendedor: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: UsuarioActivo.nombre,
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Cliente: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: venta.clienteNombre ?? 'N/A',
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(thickness: 1.5),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,              // <-- aquí
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // cabecera...
                Row(
                  children: [
                    SizedBox(width: 48, child: Text('PESO', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('DESCRIPCIÓN', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 64, child: Text('IMPORTE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                SizedBox(height: 4),

                // filas de detalle
                ...detalles.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      // Peso Neto
                      SizedBox(
                        width: 48,
                        child: Text(
                          (d.pesoNeto as num?)?.toStringAsFixed(2) ?? '0.00',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),

                      // Descripción (usa Flexible, no Expanded)
                      Flexible(
                        fit: FlexFit.loose,              // <-- aquí
                        child: Text(
                          d.descripcion?? '',
                          style: TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          '\$${(d.subtotal as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          Divider(thickness: 1.5),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1) Siempre mostramos la forma de pago a la izquierda:
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Forma de pago: ${venta.metodoPago ?? 'N/A'}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    'IVA CERO',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 8),

                // 2) Subtotales
                ...detalles.map((d) {
                  final sub = _toDoubleSafe(d.subtotal);
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'SubTotal: \$${sub.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }),

                // 3) Total general
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total:    \$${total.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // 4) Si es pago en efectivo (idpago == 1) mostramos "Entregado" y "Cambio"
                if ((venta.idpago) == 1) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Entregado: \$${recibido.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Cambio:   \$${(recibido - total).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 30),
        Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Divider(thickness: 1),
        ),
        SizedBox(height: 8),
        Text(
        'Firma de recibido',
        style: TextStyle(fontSize: 16), textAlign: TextAlign.center,
        ),
        SizedBox(height: 48),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF479D8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  // lógica devolución
                },
                child: Text('Solicitar devolución'),
              )
            ],
          ),
        ]
        )
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






