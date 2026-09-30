import 'package:flutter/material.dart';

// TODO: Người C - làm màn hình AdminFlagsScreen
class AdminFlagsScreen extends StatelessWidget {
  const AdminFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminFlagsScreen')));
  }
}

// TODO: Người C - làm màn hình AdminFlagDetailScreen
class AdminFlagDetailScreen extends StatelessWidget {
  final String flagId;
  const AdminFlagDetailScreen({super.key, required this.flagId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminFlagDetailScreen')));
  }
}
