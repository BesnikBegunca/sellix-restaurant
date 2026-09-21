import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/app_card.dart';
import '../../../../l10n/tr.dart';

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: tr.veprimeShpejta,
      subtitle: tr.shkoPunaDuhetTani,
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.schedule_outlined,
            label: tr.gjendjaTurnit,
            hint: tr.hapOseMbyllTurnin,
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.payments_outlined,
            label: tr.shtoShpenzim,
            hint: tr.regjistroKosto,
            onTap: () => onNavigate(3),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.menu_book_outlined,
            label: tr.ndryshoMenune,
            hint: tr.produkteCmime,
            onTap: () => onNavigate(7),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.history_outlined,
            label: tr.historikuShitjeve,
            hint: tr.faturaRimbursime,
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
            color: _hovered ? AppColors.lightGreenBg : AppColors.lightGreenBg.withValues(alpha: 0.45),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    Text(
                      widget.hint,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
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
