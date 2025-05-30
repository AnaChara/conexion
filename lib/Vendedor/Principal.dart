import 'package:flutter/material.dart';
import 'Cajas.dart';
import 'Venta.dart';
import 'Ventas.dart';
import 'package:conexion/iniciodesesion.dart';
import 'package:conexion/BD/global.dart';
import 'package:conexion/actividad.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class principal extends StatefulWidget {
  const principal({super.key});

  @override
  State<principal> createState() => _principalState();
}

class _principalState extends State<principal> {
  //Variables
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() { //Inicializar recursos o configuraciones
    super.initState();
    _pageController = PageController();
  }


  //Liberar recursos y evitar fugas de memoria
  void dispose(){
    _pageController.dispose();
    super.dispose();
  }

//Metodo para cerrar la sesión
  Future<void> _cerrarSesionPorInactividad() async {
    final resultado = await showDialog(
        context: context,
        barrierDismissible: false, //El usuario no puede tocar afuera para cerrar
        builder: (BuildContext context){
          return  AlertDialog(
            title: Center(
              child:
              Text('Sesión cerrada'),
            ),
            content: Text('Sesión cerrada por inactividad'),
            actions: [
              TextButton(
                child: Text('Aceptar'),
                onPressed: () => Navigator.of(context).pop(true),
              )
            ],
          );
        }
    );

    if (resultado == true) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>inicio())
      );
    }
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
          backgroundColor: Color(0xFF3B7D6F),
          actions: [

            IconButton(
                onPressed: (){},
                icon: Icon(Icons.notifications)
            ),
            Builder(
                builder: (context) => IconButton(
                    onPressed: (){
                      Scaffold.of(context).openEndDrawer();
                    },
                    icon: Icon(Icons.account_circle)
                )
            ),
          ],
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,  // Alinea los elementos al inicio
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset('assets/logoSF.png',
                  width: 40,
                  height: 40,
                ),
              )
            ],
          ),
        ),
        endDrawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Container(
                color: Color(0xFF3B7D6F), // Fondo igual al AppBar
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      child: Icon(Icons.person, size: 32),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Bienvenido: ${UsuarioActivo.nombre}",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      "Correo: ${UsuarioActivo.correo}",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 5,),
              ElevatedButton(
                  onPressed: (){},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF479D8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4), // Cambia este valor
                    ),
                  ),
                  child: Text(
                      'Reporte de Inventario',
                      style: TextStyle(color: Colors.white)
                  )
              ),
              SizedBox(height: 5,),
              ElevatedButton(
                  onPressed: (){},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF479D8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4), // Cambia este valor
                    ),
                  ),
                  child: Text(
                      'Reporte de Ventas',
                      style: TextStyle(color: Colors.white)
                  )
              ),
              SizedBox(height: 5,),
              ElevatedButton(
                  onPressed: (){},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF479D8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4), // Cambia este valor
                    ),
                  ),
                  child: Text(
                      'Devoluciones',
                      style: TextStyle(color: Colors.white)
                  )
              ),
              SizedBox(height: 5,),
              ElevatedButton(
                  onPressed: (){},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF479D8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4), // Cambia este valor
                    ),
                  ),
                  child: Text(
                      'Información',
                      style: TextStyle(color: Colors.white)
                  )
              ),
              SizedBox(height: 5,),
              ElevatedButton(
                  onPressed: (){
                    Navigator.pop(context); // Cerrar el drawer
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => inicio()) // Volver a inicio de sesion
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF479D8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4), // Cambia este valor
                    ),
                  ),
                  child: Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.white)
                  )
              ),
              SizedBox(height: 5,),
            ],
          ),
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index){
            setState(() {
              _currentIndex = index;
            });
          },
          children: [
            cajas(),
            ventas(),
            venta(),
          ],
        ) ,

        bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Color(0xFF3B7D6F),
            currentIndex: _currentIndex,
            onTap: (index){
              setState(() {
                _currentIndex = index;
                _pageController.animateToPage(
                    index, duration: Duration(microseconds: 300), curve: Curves.easeInOut);
              });
            },

            items: [
              BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), label: 'Cajas'),
              BottomNavigationBarItem(icon: Icon(Icons.store_mall_directory_outlined), label: 'Ventas'),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Venta'),
            ]
        ),
      ),
    );
  }
}
