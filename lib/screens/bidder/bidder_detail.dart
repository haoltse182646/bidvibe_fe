import 'package:flutter/material.dart';

class BidderDetailScreen extends StatelessWidget {
  final String auctionId;
  const BidderDetailScreen({super.key, required this.auctionId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('BidderDetailScreen')));
  }
}
