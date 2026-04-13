import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosSystemApp());
}

class PosSystemApp extends StatelessWidget {
  const PosSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.beige,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          surface: AppColors.white,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: AppColors.darkGreenText,
          displayColor: AppColors.darkGreenText,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
