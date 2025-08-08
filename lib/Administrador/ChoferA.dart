import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../BD/database.dart';
import '../models/chofer.dart';

class choferA extends StatefulWidget {
  const choferA({super.key});

  @override
  State<choferA> createState() => _choferAState();
}

class _choferAState extends State<choferA> {
  List<Chofer> choferes = [];
  List<Chofer> filtrados = [];
  TextEditingController _busquedaController = TextEditingController();

  bool cargando = true;

  String? idDispositivo;

  @override
  void initState() {
    super.initState();
    _cargarChoferes();
    _obtenerIdDispositivo();
  }

  Future<void> _obtenerIdDispositivo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    setState(() {
      idDispositivo = androidInfo.id;
    });
  }


  Future<void> _cargarChoferes() async {
    final db = await DBProvider.getDatabase();
    final res = await db.query('chofer');
    setState(() {
      choferes = res.map((e) => Chofer.fromMap(e)).toList();
      filtrados = choferes;
      cargando = false;
    });
  }

  void _filtrar(String query) {
    setState(() {
      filtrados = choferes.where((c) {
        return c.nombre.toLowerCase().contains(query.toLowerCase()) ||
            c.correo.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _editarCampo(Chofer chofer, String campo, String valorNuevo) async {
    final db = await DBProvider.getDatabase();
    await db.update(
      'chofer',
      {campo: valorNuevo},
      where: 'idChofer = ?',
      whereArgs: [chofer.idChofer],
    );
    await _cargarChoferes();
  }

  void _mostrarDialogoEditar(Chofer chofer) {
    final escanerCtrl = TextEditingController(text: chofer.escaner);
    final impresoraCtrl = TextEditingController(text: chofer.impresora);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: const [
            Icon(Icons.edit, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Editar Chofer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                children: [
                  const Icon(Icons.person, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nombre: ${chofer.nombre}',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Escáner',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: escanerCtrl,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Icon(Icons.print, color: Colors.purple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Impresora',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: impresoraCtrl,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel, size: 20, color: Colors.white),
                label: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  minimumSize: const Size(120, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 20, color: Colors.white),
                label: const Text(
                  'Guardar',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(120, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _editarCampo(chofer, 'Escaner', escanerCtrl.text.trim());
                  await _editarCampo(chofer, 'Impresora', impresoraCtrl.text.trim());
                },
              ),
            ],
          )
        ],



      ),
    );

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Choferes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarChoferes,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _filtrar,
            ),
          ),
          if (idDispositivo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ID del dispositivo actual:\n$idDispositivo',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: filtrados.length,
              itemBuilder: (context, index) {
                final chofer = filtrados[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 32, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                chofer.nombre,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 28),
                              onPressed: () => _mostrarDialogoEditar(chofer),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Correo: ${chofer.correo}', style: const TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.qr_code_scanner, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Escáner: ${chofer.escaner}', style: const TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.print, color: Colors.purple),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Impresora: ${chofer.impresora}', style: const TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

              },
            ),
          ),
        ],
      ),
    );
  }
}
