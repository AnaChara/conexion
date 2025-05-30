import 'package:flutter/material.dart';

class cajasA extends StatelessWidget {
  const cajasA({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Cajas General'),
        actions: [
          IconButton(
              onPressed: () {},
              icon: Icon(Icons.search)
          ),
        ],
      ),
    );
  }
}