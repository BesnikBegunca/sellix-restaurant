import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/activation_key_form.dart';

/// First-run screen: enter the SelliX business key, preview data, continue.
class ActivationScreen extends StatelessWidget {
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const Card(
              margin: EdgeInsets.all(24),
              child: Padding(
                padding: EdgeInsets.all(40),
                child: ActivationKeyForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
