import 'package:flutter/material.dart';

class usuarios extends StatelessWidget {
  const usuarios({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Choferes'),
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
