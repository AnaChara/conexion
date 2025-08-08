import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../BD/database.dart';
import '../actividad.dart';
import '../models/caja.dart';
import '../services/ventadetalle_services.dart';
import '../services/producto_service.dart';
import '../services/precioproducto_services.dart';


class Inventario extends StatefulWidget {
  const Inventario({super.key});


  @override
  State<Inventario> createState() => InventarioState();
}


class InventarioState extends State<Inventario> {


  Map<String, int> conteoCajas = {};
  Map<String, double> pesoTotal = {};
  Map<String, double> precioUnitario = {}; // NUEVO
  Map<String, int> productoIdMap = {};
  Map<String, String> fechaProducto = {};

  bool cargando = true;

  Future<void> cargarInventario() async {
    final db = await DBProvider.getDatabase();
    final resultado = await db.rawQuery('''
    SELECT p.idproducto,
       p.describcion AS descripcion,
       COUNT(*) AS cajas,
       SUM(vd.pesoNeto) AS peso,
       MAX(c.fechaEscaneo) AS ultimaFecha
FROM ventaDetalle vd
JOIN producto p ON vd.idproducto = p.idproducto
JOIN CajasFolioChofer c ON vd.qr = c.qr
WHERE vd.status = 'Inventario'
GROUP BY p.idproducto


  ''');

    final Map<String, int> cajasMap = {};
    final Map<String, double> pesosMap = {};
    final Map<String, double> preciosMap = {};

    for (var row in resultado) {
      final idProducto = row['idproducto'] as int;
      final desc = row['descripcion'] as String;
      final cajas = row['cajas'] as int;
      final peso = (row['peso'] as num).toDouble();
      final fecha = row['ultimaFecha']?.toString().split("T").first ?? 'Sin fecha';

      fechaProducto[desc] = fecha;

      // Guarda el ID
      productoIdMap[desc] = idProducto;

      // Obtén el precio usando ese ID
      final precio = await PrecioProductoService.getUltimoPrecioProducto(idProducto);
      cajasMap[desc] = cajas;
      pesosMap[desc] = peso;
      preciosMap[desc] = precio ?? 0;
    }

    setState(() {
      conteoCajas = cajasMap;
      pesoTotal = pesosMap;
      precioUnitario = preciosMap;
      cargando = false;
    });
  }


  @override
  void initState() {
    super.initState();
    cargarInventario();
  }


  @override
  Widget build(BuildContext context) {
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
          title: const Text(
            "Inventario",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(builder: (context) {
                final filas = <Widget>[];
                double totalPesoGeneral = 0;
                conteoCajas.forEach((desc, cajas) {
                  final resumen = desc.length > 8 ? '${desc.substring(0, 8)}…' : desc;
                  final peso = pesoTotal[desc] ?? 0;
                  final idProducto = productoIdMap[desc] ?? -1;
                  final fecha = fechaProducto[desc] ?? 'Sin fecha';

                  totalPesoGeneral += peso;
                  filas.add(_buildFila(resumen, cajas, peso, idProducto, fecha));
                });

                filas.add(const SizedBox(height: 12));
                filas.add(
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      border: Border.all(color: Colors.teal.shade200, width: 2),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.shade100,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'TOTAL',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                        const Expanded(
                          flex: 1,
                          child: SizedBox(),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${totalPesoGeneral.toStringAsFixed(2)} kg',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildEncabezado(),
                    const SizedBox(height: 8),
                    ...filas,
                  ],
                );
              }),
            ),

          ],
        ),
      )
    );
  }

  Widget _buildEncabezado() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.teal[700],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text("Producto",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Text("Cajas",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text("Peso Neto",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  Widget _buildFila(String producto, int cajas, double peso, int idProducto, String fecha) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CajasPorProductoScreen(
              idProducto: idProducto,
              descripcionProducto: producto,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.teal.shade200),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.shade50,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(producto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 1,
              child: Text('$cajas',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text('${peso.toStringAsFixed(2)} kg',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.teal)),
            ),
          ],
        ),
      ),
    );
  }


}

//Ventana donde muestra las cajas asociadas :D
class CajasPorProductoScreen extends StatefulWidget {
  final int idProducto;
  final String descripcionProducto;

  const CajasPorProductoScreen({
    super.key,
    required this.idProducto,
    required this.descripcionProducto,
  });

  @override
  State<CajasPorProductoScreen> createState() => _CajasPorProductoScreenState();
}

String obtenerUltimos4(String qr) {
  int puntoIndex = qr.indexOf('.');
  if (puntoIndex != -1 && qr.length > puntoIndex + 1) {
    String antesDelPunto = qr.substring(puntoIndex - 2, puntoIndex);
    String despuesDelPunto = qr.substring(puntoIndex + 1, puntoIndex + 3);
    return '$antesDelPunto.$despuesDelPunto';
  }
  return '';
}


class _CajasPorProductoScreenState extends State<CajasPorProductoScreen> {
  List<Caja> cajas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCajasPorProducto();
  }

  Future<void> _cargarCajasPorProducto() async {
    final resultado = await VentaDetalleService.getCajasInventarioPorIdProducto(widget.idProducto);
    final qrUnicos = <String>{};
    final sinDuplicados = resultado.where((c) => qrUnicos.add(c.qr)).toList();

    setState(() {
      cajas = sinDuplicados;
      cargando = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cajas de ${widget.descripcionProducto}'),
        backgroundColor: Colors.teal,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : cajas.isEmpty
          ? const Center(child: Text('No hay cajas para este producto.'))
          : ListView.builder(
        itemCount: cajas.length,
        itemBuilder: (context, index) {
          final caja = cajas[index];
          final ultimos4 = obtenerUltimos4(caja.qr); // Usa tu lógica para peso
          final fecha = caja.fechaEscaneo.split("T").first;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: Colors.teal[800], size: 32),
              title: Text(
                'Peso: $ultimos4',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Fecha: $fecha', style: const TextStyle(fontSize: 16)),
              trailing: IconButton(
                icon: const Icon(Icons.info_outline, size: 28, color: Colors.teal),
                onPressed: () async {
                  final detalle = await VentaDetalleService.getVentaDetallePorQR(caja.qr);
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
                                  Icon(Icons.fitness_center, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Peso Neto:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Center(child: Text('$peso kg', style: const TextStyle(fontSize: 18))),

                              const SizedBox(height: 12),
                              Row(
                                children: const [
                                  Icon(Icons.attach_money, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Precio por kilo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Center(child: Text('\$$precio', style: const TextStyle(fontSize: 18))),

                              const SizedBox(height: 12),
                              Row(
                                children: const [
                                  Icon(Icons.calculate, color: Colors.purple),
                                  SizedBox(width: 8),
                                  Text('Subtotal:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Center(child: Text('\$$subtotal', style: const TextStyle(fontSize: 18))),

                              const SizedBox(height: 12),
                              Row(
                                children: const [
                                  Icon(Icons.date_range, color: Colors.brown),
                                  SizedBox(width: 8),
                                  Text('Fecha escaneo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Center(child: Text(fecha, style: const TextStyle(fontSize: 18))),
                              const SizedBox(height: 12),
                              Row(
                                children: const [
                                  Icon(Icons.description, color: Colors.teal),
                                  SizedBox(width: 8),
                                  Text('Descripción:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Center(child: Text(descripcion, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center,)),

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
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      )
                  );
                },
              ),
            ),
          );
        },
      )
    );
  }
}
