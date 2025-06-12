import 'dart:async';

import 'package:conexion/Vendedor/Principal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/auth_service.dart';
import 'services/chofer_servise.dart';
import '../models/chofer.dart';
import 'Administrador/PrincipalAdmin.dart';
import 'BD/global.dart';
import 'dart:io';

class inicio extends StatefulWidget {
  const inicio({super.key});

  @override
  State<inicio> createState() => _inicioState();
}

class _inicioState extends State<inicio> {
  //controladores de Inicio de Sesión
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  // FocusNodes para controlar el foco entre TextFields
  FocusNode _usernameFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();

  // Variable para controlar la visibilidad de la contraseña
  bool _isPasswordVisible = false;

  //Validar si un campo esta vacio
  bool _correovacio = false;
  bool _contvacio = false;

  @override
  void initState() {
    super.initState();
    _verificarConexion();  // <–– comprobar antes de mostrar UI
  }

  Future<void> _verificarConexion() async {
    // Pequeña espera para asegurarnos de que el contexto ya existe
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        _mostrarDialogoSinInternet();
      }
    } on SocketException catch (_) {
      _mostrarDialogoSinInternet();
    } on TimeoutException catch (_) {
      _mostrarDialogoSinInternet();
    }
  }

  void _mostrarDialogoSinInternet() {
    showDialog(
      context: context,
      barrierDismissible: false, // Impide cerrar tocando fuera
      builder: (_) => AlertDialog(
        title: const Text('Sin conexión'),
        content: const Text('No hay internet. La aplicación se cerrará.'),
        actions: [
          TextButton(
            onPressed: () {
              // Cierra el diálogo y sale de la app
              Navigator.of(context).pop();
              SystemNavigator.pop();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  void _validarCampo(){
    setState(() {
      _correovacio = _correoController.text.isEmpty;
      _contvacio = _contrasenaController.text.isEmpty;
    });
  }

  //Reconoces el ID del sistema
  Future<String> obtenerIdDispositivo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? 'unknown_device';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_device';
    } else {
      return 'unsupported_platform';
    }
  }

  //Función para tomar los datos de inicio de sesión y validarlo
  Future<void> _iniciarSesion() async {
    final correo    = _correoController.text.trim();
    final contrasena = _contrasenaController.text;

    // 1) Obtenemos el ID de este dispositivo
    final idDispositivo = await ChoferService.obtenerIdDispositivo();

    // 2) Login con la API (AuthService)
    final usuario = await AuthService.loginApi(correo, contrasena);
    if (usuario == null) {
      return _mostrarError('Correo o contraseña incorrectos');
    }

    final tipo = usuario['tipo'] as String;
    UsuarioActivo.nombre = usuario['nombre'] as String?;
    UsuarioActivo.correo = usuario['correo'] as String?;


    // 3) Busca el chofer en local (ChoferService)
    final Chofer? choferLocal = await ChoferService.obtenerUsuarioLocal(correo);
    if (choferLocal == null) {
      return _mostrarError('Este usuario no está registrado localmente');
    }
    //Asignamos el id del chofer
    UsuarioActivo.idChofer = choferLocal.idChofer;


    // 4) Si es admin, saltamos verificación de dispositivo
    if (tipo == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => principalAdmin()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inicio de sesión exitoso (admin)')),
      );
      return;
    }

    // 5) Si NO es admin, verificamos que este dispositivo esté autorizado
    if (idDispositivo != choferLocal.escaner) {
      return _mostrarError('Este dispositivo no está autorizado para esta cuenta');
    }

    // 6) Finalmente, si es chofer, vamos al dashboard de chofer
    if (tipo == 'chofer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => principal()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inicio de sesión exitoso')),
      );
    }
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Center(child: Text('❌ Error al iniciar sesión')),
        content: Text(mensaje),
        actions: [
          TextButton(
            child: Text('Aceptar'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }


  @override
  void dispose() {
    // Asegúrate de liberar los FocusNodes cuando se destruya el widget
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF3B7D6F), //Color para el fondo
      ),
      body:  Column(
        children: [
          Expanded(child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('assets/logo.jpg',
                  width: 200,
                  height: 200,),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20.0,right: 20.0),
                    child: Text('Correo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600, //Grosor de la fuente
                          color: Colors.black87, //Color del texto
                          shadows: [ //Sombra del texto
                            Shadow(
                                blurRadius: 1, //Difuminado de la sombra
                                color: Color.fromRGBO(158, 158, 158, 0.5,),
                                offset: Offset(0.5, 0.5) //Desplazamiento de la sombra
                            ),
                          ],
                        ),
                        textAlign: TextAlign.left
                    ),
                  ),
                ),
                SizedBox(height: 5,),
                Padding(
                  padding: EdgeInsets.only(left: 20.0,right: 20.0),
                  child: TextField(
                    focusNode: _usernameFocusNode,
                    controller: _correoController,
                    decoration: InputDecoration(
                      errorText: _correovacio ? 'Este campo es obligatorio': null,
                        hintText: 'Escribe tu Correo',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)
                        ),
                        filled: true,
                        fillColor: Color(0xFFF4F4F4),
                    ),
                    onChanged: (value){
                      if(_correovacio){
                        _validarCampo();
                      }
                    },
                    onEditingComplete: (){
                      FocusScope.of(context).requestFocus(_passwordFocusNode); //Dar enter e ir directamente al siguiente textfield
                    },
                  ),
                ),
                SizedBox(height: 10,),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20.0,right: 20.0),
                    child: Text('Contraseña',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          shadows: [
                            Shadow(
                              blurRadius: 1,
                              color: Color.fromRGBO(158, 158, 158, 0.5,),
                              offset: Offset(0.5, 0.5),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.left
                    ),
                  ),
                ),
                SizedBox(height: 5,),
                Padding(padding: EdgeInsets.only(left: 20.0,right: 20.0),
                  child: TextField(
                    obscureText: !_isPasswordVisible,
                    focusNode: _passwordFocusNode,
                    controller: _contrasenaController,
                    decoration: InputDecoration(
                      errorText: _contvacio ? 'Este campo es obligatorio': null,
                      hintText: '************',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)
                      ),
                      filled: true,
                      fillColor: Color(0xFFF4F4F4),
                      suffixIcon: IconButton(
                          onPressed: (){
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                          icon: Icon(_isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                            color: Colors.grey,)
                      ),
                    ),
                    onChanged: (value){
                      if(_contvacio){
                        _validarCampo();
                      }
                    },
                    onEditingComplete: (){
                      if (!_correovacio&&!_contvacio) {
                        _iniciarSesion();
                      }
                    },
                  ),
                ),
                SizedBox(height: 10,),
                Container(
                  width: 300,
                  height: 40,
                  child: TextButton(
                    onPressed: (){
                      _validarCampo();
                      if(!_contvacio&&!_correovacio){
                        _iniciarSesion();
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Color(0xFF479D8D), //Color para botones
                      foregroundColor: Colors.white,
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Bordes redondeados
                      ),
                      elevation: 4,
                      shadowColor: Color.fromRGBO(158, 158, 158, 0.5),
                    ),
                    child:
                    Text('Iniciar Sesión',
                    ),
                  ),
                ),
                SizedBox(height: 5,),
              ],
            ),
          )),
          Container(
            color: Color(0xFF3B7D6F),
            width: double.infinity,
            height: 30,
            alignment: Alignment.center,
          )
        ],
      ),
      );
  }
}


