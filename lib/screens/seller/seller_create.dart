import 'package:flutter/material.dart';

// TODO: Người B - làm màn hình SellerCreateScreen
class SellerCreateScreen extends StatelessWidget {
  final VoidCallback onDone;
  const SellerCreateScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('SellerCreateScreen')));
  }
}
