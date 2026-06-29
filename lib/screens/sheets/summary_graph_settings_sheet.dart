import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class SummaryGraphSettingsSheet extends ConsumerWidget {
  const SummaryGraphSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(homeSummaryMetricProvider);
    final style = ref.watch(homeSummaryStyleProvider);
    final gridVisible = ref.watch(homeSummaryGridVisibleProvider);
    final labelsVisible = ref.watch(homeSummaryLabelsVisibleProvider);
    final gradientVisible = ref.watch(homeSummaryGradientVisibleProvider);
    final glowVisible = ref.watch(homeSummaryGlowVisibleProvider);
    final tooltipsVisible = ref.watch(homeSummaryTooltipsVisibleProvider);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TallyTapTheme.textGray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Summary Graph Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                title: 'Metric Mode',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'Spent (Cumulative)', metric == 'spent', () => ref.read(homeSummaryMetricProvider.notifier).updateVal('spent')),
                    _buildChoiceChip(context, 'Income (Cumulative)', metric == 'income', () => ref.read(homeSummaryMetricProvider.notifier).updateVal('income')),
                    _buildChoiceChip(context, 'Net Balance', metric == 'net', () => ref.read(homeSummaryMetricProvider.notifier).updateVal('net')),
                    _buildChoiceChip(context, 'Daily Spikes', metric == 'daily', () => ref.read(homeSummaryMetricProvider.notifier).updateVal('daily')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Curve Style',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'Smooth Curve', style == 'bezier', () => ref.read(homeSummaryStyleProvider.notifier).updateVal('bezier')),
                    _buildChoiceChip(context, 'Straight Line', style == 'straight', () => ref.read(homeSummaryStyleProvider.notifier).updateVal('straight')),
                    _buildChoiceChip(context, 'Bar Chart', style == 'bar', () => ref.read(homeSummaryStyleProvider.notifier).updateVal('bar')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Visual Enhancements',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'Gridlines: ${gridVisible ? 'On' : 'Off'}', gridVisible, () => ref.read(homeSummaryGridVisibleProvider.notifier).updateVal(!gridVisible)),
                    _buildChoiceChip(context, 'Y-Axis Labels: ${labelsVisible ? 'On' : 'Off'}', labelsVisible, () => ref.read(homeSummaryLabelsVisibleProvider.notifier).updateVal(!labelsVisible)),
                    _buildChoiceChip(context, 'Gradient Fill: ${gradientVisible ? 'On' : 'Off'}', gradientVisible, () => ref.read(homeSummaryGradientVisibleProvider.notifier).updateVal(!gradientVisible)),
                    _buildChoiceChip(context, 'Glow Effect: ${glowVisible ? 'On' : 'Off'}', glowVisible, () => ref.read(homeSummaryGlowVisibleProvider.notifier).updateVal(!glowVisible)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSection(
                title: 'Interactivity',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(context, 'Touch Tooltips: ${tooltipsVisible ? 'On' : 'Off'}', tooltipsVisible, () => ref.read(homeSummaryTooltipsVisibleProvider.notifier).updateVal(!tooltipsVisible)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: TallyTapTheme.textGray,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildChoiceChip(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TallyTapTheme.primaryMint.withValues(alpha: 0.15) : TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? TallyTapTheme.primaryMint.withValues(alpha: 0.5) : TallyTapTheme.borderGreen,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight,
          ),
        ),
      ),
    );
  }
}
