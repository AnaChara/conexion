import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../BD/global.dart';
import '../models/venta.dart';
import '../services/venta_services.dart';
import '../actividad.dart';
import '../services/ventadetalle_services.dart';
import 'Ventas.dart';

class reporteventa extends StatefulWidget {
  const reporteventa({super.key});

  @override
  State<reporteventa> createState() => _reporteventaState();
}

class _reporteventaState extends State<reporteventa> with AutomaticKeepAliveClientMixin {
  bool get wantKeepAlive => true;

  List<Venta> ventasDelDia = [];
  List<Venta> ventasFiltradas = [];

  List<Map<String, dynamic>> productosVendidos = [];
  TextEditingController _controller = TextEditingController();
  bool cargando = true;
  DateTime fechaSeleccionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    cargarVentasDelDia();
  }

  Future<void> cargarVentasDelDia() async {
    productosVendidos = await VentaDetalleService.contarCajasVendidasPorFecha(fechaSeleccionada);
    print('Productos vendidos: $productosVendidos');

    final idChofer = UsuarioActivo.idChofer;
    if (idChofer == null) return;

    final raws = await VentaService.obtenerVentasPorChofer(idChofer);
    final ventas = raws.map((m) => Venta.fromMap(Map<String, dynamic>.from(m))).toList();

    final fechaFiltro = DateFormat('yyyy-MM-dd').format(fechaSeleccionada);
    final filtradas = ventas.where((v) {
      final fechaVenta = DateFormat('yyyy-MM-dd').format(v.fecha);
      return fechaVenta == fechaFiltro;
    }).toList();

    setState(() {
      ventasDelDia = filtradas;
      ventasFiltradas = filtradas;
      cargando = false;
    });
  }

  void filtrarPorCliente(String query) {
    setState(() {
      ventasFiltradas = ventasDelDia.where((venta) =>
          venta.clienteNombre.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sessionController = Provider.of<SessionController>(context, listen: false);
    sessionController.resetInactivityTimer(context);

    return GestureDetector(
      onTap: () => sessionController.resetInactivityTimer(context),
      onPanUpdate: (_) => sessionController.resetInactivityTimer(context),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B7D6F),
          title: const Text(
            'Venta Total',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 28),
              tooltip: 'Seleccionar fecha',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: fechaSeleccionada,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && picked != fechaSeleccionada) {
                  setState(() => fechaSeleccionada = picked);
                  await cargarVentasDelDia();
                }
              },
            ),
          ],
        ),
        body: InteractiveViewer(
            child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cargando
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFE0F2F1),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text(
                              'Fecha: ${DateFormat('dd/MM/yyyy').format(fechaSeleccionada)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
                            ),
                          ),
                        ),
                        if (!cargando && ventasFiltradas.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                  child: Text(
                                    'TIPO   |   CAJAS   |   TOTAL',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                                const Divider(thickness: 1.5, color: Colors.black54),
                                ..._construirResumenPago(),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6, // o el % que quieras
                          child: productosVendidos.isEmpty
                              ? const Center(
                            child: Text(
                              "No hay ventas registradas en esta fecha",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                            ),
                          )
                              : ListView.builder(
                            itemCount: productosVendidos.length,
                            itemBuilder: (context, index) {
                              final producto = productosVendidos[index];
                              final descripcion = producto['descripcion'] ?? 'Sin nombre';
                              final cantidad = producto['cantidad'] ?? 0;
                              final subtotal = producto['subtotalReal'] ?? 0.0;
                              final peso = producto['pesoTotal'] ?? 0.0;
                              final precio = producto['precio'] ?? 0.0;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(descripcion,
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.fitness_center, size: 28),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('Peso total: ${peso.toStringAsFixed(2)} kg',
                                                style: const TextStyle(fontSize: 18)),
                                          ),
                                          const Icon(Icons.inbox),
                                          const SizedBox(width: 6),
                                          Text('Cajas: $cantidad', style: const TextStyle(fontSize: 18)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Precio x kilo: \$${precio.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 20)),
                                      const SizedBox(height: 8),
                                      Text('Subtotal: \$${subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )

                      ],
                    ),
                  ],
                ),
              ),
            )
        )
      ),
    );
  }

  List<Widget> _construirResumenPago() {
    final Map<String, double> montoPorPago = {};

    for (var venta in ventasFiltradas) {
      final tipo = venta.metodoPago;
      final monto = venta.total ?? 0.0;

      montoPorPago[tipo] = (montoPorPago[tipo] ?? 0.0) + monto;
    }

    return montoPorPago.keys.map((tipo) {
      final monto = montoPorPago[tipo] ?? 0.0;
      return FutureBuilder<int>(
        future: Future.wait(
          ventasFiltradas
              .where((v) => v.metodoPago == tipo)
              .map((v) => VentaDetalleService.contarCajasPorIdVenta(v.idVenta ?? 0))  // 👈 NO uses async aquí
              .toList(),  // 👈 Esto es clave
        ).then((List<int> listaInts) => listaInts.fold<int>(0, (suma, actual) => suma + actual)),
          builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Cargando resumen...'),
            );
          }

          final cajas = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    tipo,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '$cajas',
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),

          );
          },
      );
    }).toList();
  }

}
