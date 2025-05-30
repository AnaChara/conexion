import 'dart:async';
import 'package:conexion/iniciodesesion.dart';
import 'package:flutter/material.dart';

class SessionController with ChangeNotifier {
  Timer? _inactivityTimer;

  void resetInactivityTimer(BuildContext context) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(minutes: 50),
          () {
        cerrarSesionPorInactividad(context);
      },
    );
  }

  Future<void> cerrarSesionPorInactividad(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('Sesión cerrada')),
          content: Text('Sesión cerrada por inactividad'),
          actions: [
            TextButton(
              child: Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/inicio'); // Aquí rediriges
              },
            ),
          ],
        );
      },
    );
  }

  void disposeTimer() {
    _inactivityTimer?.cancel();
  }
}
