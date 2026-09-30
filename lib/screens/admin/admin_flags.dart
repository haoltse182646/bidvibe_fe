import 'package:flutter/material.dart';

class AdminFlagsScreen extends StatelessWidget {
  const AdminFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminFlagsScreen')));
  }
}

class AdminFlagDetailScreen extends StatelessWidget {
  final String flagId;
  const AdminFlagDetailScreen({super.key, required this.flagId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('AdminFlagDetailScreen')));
  }
}
