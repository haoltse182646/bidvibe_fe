import 'package:flutter/material.dart';

class SellerEditScreen extends StatelessWidget {
  final String listingId;
  const SellerEditScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('SellerEditScreen')));
  }
}
