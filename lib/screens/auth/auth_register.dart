import 'package:flutter/material.dart';

import 'auth_form.dart';

class AuthRegisterScreen extends StatelessWidget {
  const AuthRegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const AuthForm(register: true);
}
