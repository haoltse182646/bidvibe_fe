import 'package:flutter/material.dart';

// TODO: Người A - làm màn hình BidderPaymentScreen
class BidderPaymentScreen extends StatelessWidget {
  final String auctionId;
  const BidderPaymentScreen({super.key, required this.auctionId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('BidderPaymentScreen')));
  }
}
