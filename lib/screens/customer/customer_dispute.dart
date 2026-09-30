import 'package:flutter/material.dart';

class CustomerDisputeScreen extends StatelessWidget {
  final String source;
  final String title;
  final String? auctionId;
  final String? listingId;
  const CustomerDisputeScreen({super.key, required this.source, required this.title, this.auctionId, this.listingId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('CustomerDisputeScreen')));
  }
}
