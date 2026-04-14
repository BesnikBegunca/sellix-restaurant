import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../theme/app_colors.dart';

class GgLogoBox extends StatelessWidget {
  const GgLogoBox({super.key, this.size = 48, this.radius = 12});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final logo = ManagerData.instance.companyLogoBytes;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: logo == null ? AppColors.primaryGreen : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: logo != null ? Clip.hardEdge : Clip.none,
      alignment: Alignment.center,
      child: logo != null
          ? Image.memory(logo, width: size, height: size, fit: BoxFit.contain)
          : Icon(
              Icons.local_cafe,
              color: AppColors.white,
              size: size * (28 / 48),
            ),
    );
  }
}

/// Header i përbashkët për ekranet pas login-it.
class GgAppHeader extends StatelessWidget {
  const GgAppHeader({
    super.key,
    this.showBack = false,
    this.onBack,
    this.title,
    this.logoSize = 40,
    this.showLogo = true,
    this.userName,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final String? title;
  final double logoSize;
  final bool showLogo;
  final String? userName;

  static String formattedDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle(0.1))),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            _BackButton(onPressed: onBack),
            const SizedBox(width: 16),
          ],
          if (showLogo) ...[
            GgLogoBox(size: logoSize, radius: 12),
            const SizedBox(width: 12),
          ],
          Text(
            title ?? ManagerData.instance.companyName ?? 'POS System',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: AppColors.darkGreenText,
            ),
          ),
          const Expanded(child: Center(child: _DateLabel())),
          _UserSection(userName: userName),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      GgAppHeader.formattedDate(DateTime.now()),
      style: const TextStyle(fontSize: 16, color: AppColors.mediumGreenText),
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.lightGreenBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.primaryGreen,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          userName ?? 'Cashier',
          style: const TextStyle(fontSize: 16, color: AppColors.darkGreenText),
        ),
      ],
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: _hover ? AppColors.lightGreenBg : AppColors.beige,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onPressed,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
