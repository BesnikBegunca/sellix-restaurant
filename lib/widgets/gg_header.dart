import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../manager/manager_data.dart';
import '../theme/app_colors.dart';

/// Shared Sellix brand mark used throughout the application.
class GgLogoBox extends StatelessWidget {
  const GgLogoBox({
    super.key,
    this.size = 48,
    this.radius = 12,
    this.horizontal = true,
  });

  static const String sellixLogoAsset = 'assets/images/sellix_logo.svg';

  final double size;
  final double radius;

  /// Logoja është horizontale — jep më shumë gjerësi se lartësi.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final height = size;
    final width = horizontal ? size * 3.23 : size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SvgPicture.asset(
        sellixLogoAsset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        colorFilter: isDark
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null,
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
      'E hënë',
      'E martë',
      'E mërkurë',
      'E enjte',
      'E premte',
      'E shtunë',
      'E diel',
    ];
    const months = [
      'Janar',
      'Shkurt',
      'Mars',
      'Prill',
      'Maj',
      'Qershor',
      'Korrik',
      'Gusht',
      'Shtator',
      'Tetor',
      'Nëntor',
      'Dhjetor',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
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
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Text(
      GgAppHeader.formattedDate(DateTime.now()),
      style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline, color: scheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          userName ?? 'Cashier',
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
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
