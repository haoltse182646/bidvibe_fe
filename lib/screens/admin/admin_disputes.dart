import 'package:flutter/material.dart';

class AdminDisputesScreen extends StatelessWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminDisputesScreen')));
  }
}

class AdminDisputeDetailScreen extends StatelessWidget {
  final String disputeId;
  const AdminDisputeDetailScreen({super.key, required this.disputeId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminDisputeDetailScreen')));
  }
}
