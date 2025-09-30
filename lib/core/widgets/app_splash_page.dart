import 'package:flutter/material.dart';

class AppSplashPage extends StatelessWidget {
  const AppSplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
