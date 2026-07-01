import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: TallyTapTheme.textGray,
        ),
      );
}

class TypeToggle extends StatelessWidget {
  const TypeToggle({super.key, required this.isIncome, required this.onChanged});
  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return Container(
      height: 34 * textScale,
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TallyTapTheme.borderGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pill('Expense', !isIncome, TallyTapTheme.primaryMint,
              () => onChanged(false)),
          _pill('Income', isIncome, const Color(0xFF10B981),
              () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(
      String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(color: color.withOpacity(0.6), width: 1.0)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? color : TallyTapTheme.textGray,
            ),
          ),
        ),
      ),
    );
  }
}

class AmountCard extends StatelessWidget {
  const AmountCard({
    super.key,
    required this.currency,
    required this.controller,
    required this.activeColor,
    required this.catColor,
  });

  final String currency;
  final TextEditingController controller;
  final Color activeColor;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: TallyTapTheme.obsidianCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TallyTapTheme.borderGreen),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'TRANSACTION AMOUNT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currency,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: activeColor,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: IntrinsicWidth(
                  child: TextFormField(
                    controller: controller,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                      fontFamily: 'Outfit',
                      letterSpacing: -2,
                    ),
                    textAlign: TextAlign.left,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: TallyTapTheme.textGray.withOpacity(0.25),
                        fontFamily: 'Outfit',
                        letterSpacing: -2,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(val) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
