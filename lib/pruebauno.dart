import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data'; // Para manejar datos binarios

class Pruebauno extends StatefulWidget {
  const Pruebauno({super.key});

  @override
  State<Pruebauno> createState() => _PruebaunoState();
}

class _PruebaunoState extends State<Pruebauno> {
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;

  @override
  void initState() {
    super.initState();
    requestBluetoothPermissions().then((_) {
      initBluetooth(); // Función para detectar la impresora
    });
  }

  void initBluetooth() async { //Conexión a la impresora
    bool isConnected = await printer.isConnected ?? false;

    if (!isConnected) {
      devices = await printer.getBondedDevices();
      setState(() {});
    }
  }

  Future<void> PrintImage() async {
    await connectIfNeeded();
    printer.printNewLine();
      printer.printNewLine();
      // Redimensionar la imagen
      Uint8List resizedImage = await resizeImage('assets/logo3.jpg', 100, 200);
      // Imprimir mensaje y luego la imagen redimensionada
      printer.printCustom("Fin de la Imagen", 1, 1);
      printer.printImageBytes(resizedImage);
      printer.printNewLine();
      printer.paperCut();
  }

  Future<void> connectPrinter() async {
    if (selectedDevice != null && !isPrinterConnected) {
      await connectIfNeeded();
    }
  }

  Future<void> printText() async {
    await connectIfNeeded();
        printer.printNewLine();
        printer.printNewLine();
        printer.printCustom("Hola desde Flutter, podemos poner coma? y tambien ; y ,,,,,,,,, ,", 3, 1); // Texto
        printer.printNewLine();
        printer.paperCut();
  }


  bool isPrinterConnected = false;

  Future<void> connectIfNeeded() async {
    bool? isConnected = await printer.isConnected;
    if (isConnected != true) {
      try {
        print("Conectando a la impresora...");
        await printer.connect(selectedDevice!);
        isPrinterConnected = true; // Marca como conectado
      } catch (e) {
        print("No se pudo conectar: $e");
        isPrinterConnected = false; // Si no se puede conectar, marcar como no conectado
        return;
      }
    }
  }

  Future<void> requestBluetoothPermissions() async { //Permisos para imprimir usando Bluetooth
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.location]?.isGranted ?? false) {
      print("Permisos concedidos");
    } else {
      print("Permisos denegados");
    }
  }

  // Función para redimensionar la imagen
  Future<Uint8List> resizeImage(String assetPath, int width, int height) async {
    // Cargar la imagen desde los activos
    ByteData data = await rootBundle.load(assetPath);
    List<int> bytes = data.buffer.asUint8List();
    // Decodificar la imagen
    img.Image? image = img.decodeImage(Uint8List.fromList(bytes));
    if (image == null) {
      throw Exception("No se pudo decodificar la imagen");
    }
    // Redimensionar la imagen
    img.Image resized = img.copyResize(image, width: width, height: height);
    // Codificar la imagen redimensionada a bytes
    return Uint8List.fromList(img.encodePng(resized)); // Usando PNG, pero puedes usar otros formatos
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prueba Bixolon")),
      body: Column(
        children: [
          DropdownButton<BluetoothDevice>(
            hint: const Text("Selecciona la impresora"),
            value: selectedDevice,
            items: devices.map((device) {
              return DropdownMenuItem(
                value: device,
                child: Text(device.name ?? ""),
              );
            }).toList(),
            onChanged: (device) => setState(() => selectedDevice = device),
          ),
          SizedBox(width: 40),
          ElevatedButton(
            onPressed: connectPrinter,
            child: const Text("Conectar"),
          ),
          SizedBox(width: 40),
          ElevatedButton(
            onPressed: printText,
            child: const Text("imprimir"),
          ),
          SizedBox(width: 40),
          ElevatedButton(onPressed: PrintImage,
              child: const Text("Imprimir Imagen"),
          )
        ],
      ),
    );
  }
}
