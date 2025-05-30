import 'package:flutter/material.dart';

class ventasA extends StatelessWidget {
  const ventasA({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Ventas Generales'),
        actions: [
          IconButton(
              onPressed: (){},
              icon: Icon(Icons.search)
          ),
        ],
      ),
    );
  }
}
