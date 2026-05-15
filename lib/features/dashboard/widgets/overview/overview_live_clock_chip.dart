import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class OverviewLiveClockChip extends StatefulWidget {
  const OverviewLiveClockChip({super.key});

  @override
  State<OverviewLiveClockChip> createState() => _OverviewLiveClockChipState();
}

class _OverviewLiveClockChipState extends State<OverviewLiveClockChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    final t =
        '${displayHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ora Aktuale',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.lightGreenText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
