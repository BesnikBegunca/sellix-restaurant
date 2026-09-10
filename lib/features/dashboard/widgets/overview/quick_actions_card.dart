import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/app_card.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Veprime të shpejta',
      subtitle: 'Shko te puna që të duhet tani.',
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.schedule_outlined,
            label: 'Gjendja e turnit',
            hint: 'Hap ose mbyll turnin',
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.payments_outlined,
            label: 'Shto shpenzim',
            hint: 'Regjistro një kosto',
            onTap: () => onNavigate(4),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.menu_book_outlined,
            label: 'Ndrysho menunë',
            hint: 'Produkte dhe çmime',
            onTap: () => onNavigate(8),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.history_outlined,
            label: 'Historiku i shitjeve',
            hint: 'Fatura dhe rimbursime',
            onTap: () => onNavigate(13),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.lightGreenBg : const Color(0xFFF4F7F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? AppColors.primaryGreen.withValues(alpha: 0.25)
                  : AppColors.lightGreenBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    Text(
                      widget.hint,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.lightGreenText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
