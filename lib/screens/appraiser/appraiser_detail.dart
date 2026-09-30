import 'package:flutter/material.dart';

class AppraiserDetailScreen extends StatelessWidget {
  final String itemId;
  const AppraiserDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AppraiserDetailScreen')));
  }
}
