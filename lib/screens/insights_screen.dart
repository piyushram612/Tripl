import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/currency_provider.dart';
import '../providers/insights_provider.dart';
import 'widgets/intent_ring_painter.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final insights = ref.watch(insightsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TallyTapTheme.obsidianCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TallyTapTheme.borderGreen),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: TallyTapTheme.primaryMint,
                      size: 20,
                    ),
                  ),
                  const Text(
                    'TallyTap',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 38), // To balance the left wallet icon container and keep TallyTap centered
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Monthly Intentionality',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'A high-level overview of where your resources flowed this period, categorized by intent.',
                style: TextStyle(
                  fontSize: 14,
                  color: TallyTapTheme.textGray,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      IntentRingGraph(
                        essential: insights.essential,
                        joyful: insights.joyful,
                        avoidable: insights.avoidable,
                        totalSpent: insights.totalSpent,
                        currency: currency,
                      ),
                      const SizedBox(height: 20),
                      _buildIntentLegendRow('Essential', insights.essentialPercent, TallyTapTheme.primaryMint),
                      const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                      _buildIntentLegendRow('Joyful', insights.joyfulPercent, const Color(0xFF4B5E55)),
                      const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                      _buildIntentLegendRow('Avoidable', insights.avoidablePercent, const Color(0xFFFFB5B5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: TallyTapTheme.primaryMint, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'INSIGHT OF THE DAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: TallyTapTheme.primaryMint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 13, color: TallyTapTheme.textLight, height: 1.5),
                          children: [
                            TextSpan(text: "Your "),
                            TextSpan(
                              text: "Joyful",
                              style: TextStyle(color: Color(0xFF9FB6DF), fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " spending increased by 12% this month, primarily driven by dining experiences. However, your "),
                            TextSpan(
                              text: "Avoidable",
                              style: TextStyle(color: Color(0xFFFFB5B5), fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " expenses remain low, indicating strong fundamental habits."),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category Breakdown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildCategoryProgressRow(
                        'Housing & Utilities',
                        insights.otherSpent + insights.utilitiesSpent,
                        (insights.otherLimit + insights.utilitiesLimit) > 0
                            ? ((insights.otherSpent + insights.utilitiesSpent) / (insights.otherLimit + insights.utilitiesLimit)).clamp(0.0, 1.0)
                            : 0.0,
                        currency,
                      ),
                      const SizedBox(height: 20),
                      _buildCategoryProgressRow(
                        'Food & Dining',
                        insights.diningSpent,
                        insights.diningLimit > 0 ? (insights.diningSpent / insights.diningLimit).clamp(0.0, 1.0) : 0.0,
                        currency,
                      ),
                      const SizedBox(height: 20),
                      _buildCategoryProgressRow(
                        'Transportation',
                        insights.commuteSpent,
                        insights.commuteLimit > 0 ? (insights.commuteSpent / insights.commuteLimit).clamp(0.0, 1.0) : 0.0,
                        currency,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntentLegendRow(String title, String percent, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textGray, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          percent,
          style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCategoryProgressRow(String title, double amount, double proportion, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.w500),
            ),
            Text(
              '$currency${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
              style: const TextStyle(fontSize: 13, color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF14241F),
            borderRadius: BorderRadius.circular(100),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: proportion,
            child: Container(
              decoration: BoxDecoration(
                color: TallyTapTheme.primaryMint,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
