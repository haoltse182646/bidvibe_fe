import 'package:flutter/material.dart';

// TODO: Người A - làm màn hình BidderDoneScreen
class BidderDoneScreen extends StatelessWidget {
  final String auctionId;
  final bool justPaid;
  const BidderDoneScreen({super.key, required this.auctionId, this.justPaid = false});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('BidderDoneScreen')));
  }
}
