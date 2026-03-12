import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DonateNowScreen extends StatelessWidget {
  const DonateNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Donate Now",
          style: TextStyle(color: AppColors.primaryRed),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryRed),
      ),
      body: const Center(
        child: Text("Donate Now Page", style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
