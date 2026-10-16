import 'package:flutter/material.dart';
import 'appraiser_ops_screen.dart';

class AppraiserShell extends StatefulWidget {
  const AppraiserShell({super.key});

  @override
  State<AppraiserShell> createState() => _AppraiserShellState();
}

class _AppraiserShellState extends State<AppraiserShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return const AppraiserOpsScreen();
  }
}
