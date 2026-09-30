import 'package:flutter/material.dart';

// TODO: Người C - làm màn hình AdminDisputesScreen
class AdminDisputesScreen extends StatelessWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminDisputesScreen')));
  }
}

// TODO: Người C - làm màn hình AdminDisputeDetailScreen
class AdminDisputeDetailScreen extends StatelessWidget {
  final String disputeId;
  const AdminDisputeDetailScreen({super.key, required this.disputeId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminDisputeDetailScreen')));
  }
}
