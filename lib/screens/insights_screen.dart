import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../providers/currency_provider.dart';
import '../providers/insights_provider.dart';
import '../providers/category_provider.dart';
import 'widgets/intent_ring_painter.dart';
import '../services/tutorial_service.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bottomPadding = 72.0 + MediaQuery.of(context).padding.bottom + (MediaQuery.of(context).padding.bottom > 0 ? 10.0 : 20.0) + 24.0;

    final currency = ref.watch(currencyProvider);
    final insights = ref.watch(insightsProvider);
    final splitTargets = ref.watch(budgetSplitProvider);
    final filter = ref.watch(insightsPeriodFilterProvider);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Spend Intentionality',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: TallyTapTheme.primaryMint,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPeriodSelectorChip(context, ref, filter),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Overview of resources from ${_formatDateRange(filter)}, categorized by intent.',
                style: const TextStyle(
                  fontSize: 14,
                  color: TallyTapTheme.textGray,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // ── Intent Ring Card ──────────────────────────────────────────────
              Card(
                key: TutorialService.insightsDonutKey,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      IntentRingGraph(
                        essential: insights.essential,
                        joyful: insights.joyful,
                        avoidable: insights.avoidable,
                        investments: insights.investments,
                        totalSpent: insights.totalSpent,
                        currency: currency,
                      ),
                      const SizedBox(height: 20),
                      _buildIntentLegendRow('Essential', insights.essentialPercent, TallyTapTheme.primaryMint, TutorialService.insightsPillEssentialKey),
                      const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                      _buildIntentLegendRow('Joyful', insights.joyfulPercent, const Color(0xFF9FB6DF), TutorialService.insightsPillJoyfulKey),
                      const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                      _buildIntentLegendRow('Avoidable', insights.avoidablePercent, const Color(0xFFFFB5B5), TutorialService.insightsPillAvoidableKey),
                      const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                      _buildIntentLegendRow('Investments', insights.investmentsPercent, const Color(0xFF8B5CF6), TutorialService.insightsPillInvestKey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Budget Split Card ─────────────────────────────────────────────
              _BudgetSplitCard(key: TutorialService.insightsBudgetSplitKey, insights: insights, splitTargets: splitTargets, currency: currency),
              const SizedBox(height: 16),

              // ── Insight of the Day ────────────────────────────────────────────
              Card(
                key: TutorialService.insightsDailyKey,
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
                      _buildDynamicInsight(insights, currency),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Category Breakdown ────────────────────────────────────────────
              Card(
                key: TutorialService.insightsCategoryBreakdownKey,
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
                      if (insights.categoryBreakdowns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Center(
                            child: Text(
                              'No category breakdown data available for this period.',
                              style: TextStyle(
                                fontSize: 13,
                                color: TallyTapTheme.textGray,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: insights.categoryBreakdowns.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 20),
                          itemBuilder: (context, index) {
                            final entry = insights.categoryBreakdowns[index];
                            return _buildCategoryProgressRow(
                              entry.category,
                              entry.spent,
                              entry.proportion,
                              currency,
                              entry.percentOfTotal,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateRange(InsightsPeriodFilter filter) {
    if (filter.start == null || filter.end == null) {
      return 'all-time history';
    }
    final df = DateFormat('MMM d, yyyy');
    return '${df.format(filter.start!)} to ${df.format(filter.end!)}';
  }

  Widget _buildPeriodSelectorChip(BuildContext context, WidgetRef ref, InsightsPeriodFilter filter) {
    return InkWell(
      onTap: () => _showPeriodSelectorSheet(context, ref),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TallyTapTheme.borderGreen),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, color: TallyTapTheme.primaryMint, size: 12),
            const SizedBox(width: 6),
            Text(
              filter.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: TallyTapTheme.textLight,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: TallyTapTheme.textGray, size: 14),
          ],
        ),
      ),
    );
  }

  void _showPeriodSelectorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: TallyTapTheme.borderGreen, width: 1.0),
      ),
      builder: (context) {
        return const _PeriodSelectorSheet();
      },
    );
  }

  Widget _buildIntentLegendRow(String title, String percent, Color color, [GlobalKey? key]) {
    return Row(
      key: key,
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

  Widget _buildCategoryProgressRow(String title, double amount, double proportion, String currency, String percentOfTotal) {
    final color = TallyTapTheme.getColorForCategory(title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                Text(
                  '($percentOfTotal)',
                  style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            Text(
              '$currency${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(100),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: proportion,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicInsight(InsightsState insights, String currency) {
    if (insights.totalSpent == 0) {
      return const Text(
        "You haven't logged any expenses this period. Start tracking your transactions to unlock personalized, value-based intentionality insights!",
        style: TextStyle(fontSize: 13, color: TallyTapTheme.textLight, height: 1.5),
      );
    }

    final double essential = insights.essential;
    final double joyful = insights.joyful;
    final double avoidable = insights.avoidable;
    final double invest = insights.investments;

    final String essentialPct = insights.essentialPercent;
    final String joyfulPct = insights.joyfulPercent;
    final String avoidablePct = insights.avoidablePercent;
    final String investPct = insights.investmentsPercent;

    List<InlineSpan> spans = [];

    spans.add(const TextSpan(text: "Your spending is currently "));

    final double maxVal = [essential, joyful, avoidable, invest].reduce((a, b) => a > b ? a : b);

    if (essential == maxVal) {
      spans.add(const TextSpan(text: "primarily focused on "));
      spans.add(const TextSpan(text: "Essential", style: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " needs ($essentialPct of total), showing disciplined baseline habits. "));
    } else if (joyful == maxVal) {
      spans.add(const TextSpan(text: "largely driven by "));
      spans.add(const TextSpan(text: "Joyful", style: TextStyle(color: Color(0xFF9FB6DF), fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " experiences ($joyfulPct of total), highlighting your focus on values-based spending. "));
    } else if (invest == maxVal) {
      spans.add(const TextSpan(text: "notably directed towards "));
      spans.add(const TextSpan(text: "Investments", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " ($investPct of total) — fantastic discipline in building your future. "));
    } else {
      spans.add(const TextSpan(text: "highly allocated towards "));
      spans.add(const TextSpan(text: "Avoidable", style: TextStyle(color: Color(0xFFFFB5B5), fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " expenses ($avoidablePct of total), primarily driven by entertainment or subscriptions. "));
    }

    if (avoidable / insights.totalSpent > 0.25) {
      spans.add(const TextSpan(text: "With "));
      spans.add(const TextSpan(text: "Avoidable", style: TextStyle(color: Color(0xFFFFB5B5), fontWeight: FontWeight.bold)));
      spans.add(const TextSpan(text: " costs exceeding 25%, reviewing recurring subscriptions could easily unlock savings. "));
    } else if (avoidable > 0) {
      spans.add(const TextSpan(text: "Your "));
      spans.add(const TextSpan(text: "Avoidable", style: TextStyle(color: Color(0xFFFFB5B5), fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " expenses remain very low ($avoidablePct), indicating strong fundamental budget control. "));
    }

    if (invest > 0 && invest / insights.totalSpent >= 0.20) {
      spans.add(const TextSpan(text: "Your "));
      spans.add(const TextSpan(text: "Investment", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " rate ($investPct) meets or exceeds the 20% savings benchmark — excellent financial health."));
    } else if (invest == 0) {
      spans.add(const TextSpan(text: "Consider logging "));
      spans.add(const TextSpan(text: "Investment", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)));
      spans.add(const TextSpan(text: " transactions (e.g. SIP, stocks, savings deposits) to track your wealth-building progress."));
    } else {
      spans.add(const TextSpan(text: "Your "));
      spans.add(const TextSpan(text: "Investment", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)));
      spans.add(TextSpan(text: " rate is $investPct. Aim to grow this towards your savings target for stronger long-term wealth."));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, height: 1.5),
        children: spans,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Split Card — configurable Needs / Wants / Savings targets
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetSplitCard extends ConsumerStatefulWidget {
  final InsightsState insights;
  final BudgetSplitTargets splitTargets;
  final String currency;

  const _BudgetSplitCard({
    super.key,
    required this.insights,
    required this.splitTargets,
    required this.currency,
  });

  @override
  ConsumerState<_BudgetSplitCard> createState() => _BudgetSplitCardState();
}

class _BudgetSplitCardState extends ConsumerState<_BudgetSplitCard> {
  bool _isEditing = false;

  // Local slider state (only active while editing)
  late double _needsTarget;
  late double _wantsTarget;
  late double _savingsTarget;

  @override
  void initState() {
    super.initState();
    _resetLocal();
  }

  void _resetLocal() {
    _needsTarget   = widget.splitTargets.needsTarget;
    _wantsTarget   = widget.splitTargets.wantsTarget;
    _savingsTarget = widget.splitTargets.savingsTarget;
  }

  // When user drags one slider, redistribute the remainder equally among others.
  void _onNeedsChanged(double val) {
    final rem = (100 - val).clamp(0.0, 100.0);
    setState(() {
      _needsTarget = val;
      final ratio = _wantsTarget + _savingsTarget > 0 ? _wantsTarget / (_wantsTarget + _savingsTarget) : 0.5;
      _wantsTarget   = (rem * ratio).clamp(0, rem);
      _savingsTarget = (rem - _wantsTarget).clamp(0, rem);
    });
  }

  void _onWantsChanged(double val) {
    final rem = (100 - val).clamp(0.0, 100.0);
    setState(() {
      _wantsTarget = val;
      final ratio = _needsTarget + _savingsTarget > 0 ? _needsTarget / (_needsTarget + _savingsTarget) : 0.5;
      _needsTarget   = (rem * ratio).clamp(0, rem);
      _savingsTarget = (rem - _needsTarget).clamp(0, rem);
    });
  }

  void _onSavingsChanged(double val) {
    final rem = (100 - val).clamp(0.0, 100.0);
    setState(() {
      _savingsTarget = val;
      final ratio = _needsTarget + _wantsTarget > 0 ? _needsTarget / (_needsTarget + _wantsTarget) : 0.5;
      _needsTarget = (rem * ratio).clamp(0, rem);
      _wantsTarget = (rem - _needsTarget).clamp(0, rem);
    });
  }

  Future<void> _saveTargets() async {
    await ref.read(budgetSplitProvider.notifier).updateTargets(
      needs: _needsTarget,
      wants: _wantsTarget,
      savings: _savingsTarget,
    );
    if (mounted) setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final ins = widget.insights;
    final targets = widget.splitTargets;

    final double needsActual   = ins.needsActual;
    final double wantsActual   = ins.wantsActual;
    final double savingsActual = ins.savingsActual;

    // Determine the biggest deviation to generate a tip
    final double needsDelta   = needsActual   - targets.needsTarget;
    final double wantsDelta   = wantsActual   - targets.wantsTarget;
    final double savingsDelta = savingsActual - targets.savingsTarget;

    String tipText;
    Color tipColor;
    if (ins.totalSpent == 0) {
      tipText = 'Log your first transaction to see how your spending compares to your targets.';
      tipColor = TallyTapTheme.textGray;
    } else if (needsDelta.abs() >= wantsDelta.abs() && needsDelta.abs() >= savingsDelta.abs()) {
      if (needsDelta > 5) {
        tipText = 'Your Needs are ${needsDelta.toStringAsFixed(0)}% above target. Look for areas to trim essential fixed costs.';
        tipColor = const Color(0xFFF59E0B);
      } else {
        tipText = 'Your Needs spending is right on track. Great foundational discipline!';
        tipColor = TallyTapTheme.primaryMint;
      }
    } else if (wantsDelta.abs() >= savingsDelta.abs()) {
      if (wantsDelta > 5) {
        tipText = 'Your Wants are ${wantsDelta.toStringAsFixed(0)}% above target. Consider trimming avoidable subscriptions or entertainment.';
        tipColor = const Color(0xFFFFB5B5);
      } else {
        tipText = 'Wants spending is well controlled — you\'re staying within your lifestyle budget.';
        tipColor = const Color(0xFF9FB6DF);
      }
    } else {
      if (savingsDelta < -5) {
        tipText = 'Your Savings/Investments are ${(-savingsDelta).toStringAsFixed(0)}% below target. Try routing more to your SIP or savings account.';
        tipColor = const Color(0xFF8B5CF6);
      } else {
        tipText = 'You\'re hitting your savings target — excellent long-term wealth building!';
        tipColor = const Color(0xFF8B5CF6);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1040),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF8B5CF6), size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'BUDGET SPLIT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (_isEditing) {
                        _saveTargets();
                      } else {
                        setState(() {
                          _resetLocal();
                          _isEditing = true;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isEditing ? const Color(0xFF8B5CF6) : TallyTapTheme.obsidianCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isEditing ? const Color(0xFF8B5CF6) : TallyTapTheme.borderGreen,
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'SAVE' : 'EDIT TARGETS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: _isEditing ? Colors.white : TallyTapTheme.textGray,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isEditing) ...[
              // ── Target Editor ────────────────────────────────────────────────
              const Text(
                'ADJUST YOUR TARGETS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: TallyTapTheme.textGray),
              ),
              const SizedBox(height: 4),
              const Text(
                'Drag the sliders to set how you want to distribute your spending. Values auto-balance to 100%.',
                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildTargetSlider('Needs', _needsTarget, TallyTapTheme.primaryMint, _onNeedsChanged),
              const SizedBox(height: 12),
              _buildTargetSlider('Wants', _wantsTarget, const Color(0xFF9FB6DF), _onWantsChanged),
              const SizedBox(height: 12),
              _buildTargetSlider('Savings', _savingsTarget, const Color(0xFF8B5CF6), _onSavingsChanged),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: ${(_needsTarget + _wantsTarget + _savingsTarget).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ] else ...[
              // ── Split Rows ───────────────────────────────────────────────────
              _buildSplitRow(
                label: 'Needs',
                subtitle: 'Essential expenses',
                actual: needsActual,
                target: targets.needsTarget,
                actualColor: TallyTapTheme.primaryMint,
                targetColor: TallyTapTheme.primaryMint.withOpacity(0.25),
              ),
              const SizedBox(height: 16),
              _buildSplitRow(
                label: 'Wants',
                subtitle: 'Joyful + Avoidable',
                actual: wantsActual,
                target: targets.wantsTarget,
                actualColor: const Color(0xFF9FB6DF),
                targetColor: const Color(0xFF9FB6DF).withOpacity(0.25),
              ),
              const SizedBox(height: 16),
              _buildSplitRow(
                label: 'Savings',
                subtitle: 'Investments & growth',
                actual: savingsActual,
                target: targets.savingsTarget,
                actualColor: const Color(0xFF8B5CF6),
                targetColor: const Color(0xFF8B5CF6).withOpacity(0.25),
              ),
              const SizedBox(height: 20),

              // ── Dynamic Tip ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tipColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tipColor.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_outlined, color: tipColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tipText,
                        style: TextStyle(fontSize: 12, color: tipColor, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSplitRow({
    required String label,
    required String subtitle,
    required double actual,
    required double target,
    required Color actualColor,
    required Color targetColor,
  }) {
    final bool overTarget = actual > target + 2;
    final bool underTarget = actual < target - 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text(
                    '${actual.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 15, color: actualColor, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: overTarget
                          ? const Color(0xFFFFB5B5).withOpacity(0.15)
                          : underTarget
                              ? const Color(0xFFF59E0B).withOpacity(0.12)
                              : TallyTapTheme.primaryMint.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'target ${target.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: overTarget
                            ? const Color(0xFFFFB5B5)
                            : underTarget
                                ? const Color(0xFFF59E0B)
                                : TallyTapTheme.primaryMint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Target track (full width marker)
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF14241F),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            // Target marker line
            FractionallySizedBox(
              widthFactor: (target / 100).clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: targetColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            // Actual bar
            FractionallySizedBox(
              widthFactor: (actual / 100).clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: actualColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetSlider(String label, double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label, style: const TextStyle(fontSize: 12, color: TallyTapTheme.textLight, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PeriodSelectorSheet extends ConsumerWidget {
  const _PeriodSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(insightsPeriodFilterProvider);
    final availableMonths = ref.watch(availableMonthsProvider);
    final notifier = ref.read(insightsPeriodFilterProvider.notifier);

    // List of standard presets:
    final presets = [
      _PeriodPresetItem(
        label: 'This Month',
        icon: Icons.calendar_today_rounded,
        isSelected: activeFilter.label == 'This Month',
        onTap: () {
          notifier.setThisMonth();
          Navigator.pop(context);
        },
      ),
      _PeriodPresetItem(
        label: 'Last Month',
        icon: Icons.history_rounded,
        isSelected: activeFilter.label == 'Last Month',
        onTap: () {
          notifier.setLastMonth();
          Navigator.pop(context);
        },
      ),
      _PeriodPresetItem(
        label: 'Last 30 Days',
        icon: Icons.date_range_rounded,
        isSelected: activeFilter.label == 'Last 30 Days',
        onTap: () {
          notifier.setLast30Days();
          Navigator.pop(context);
        },
      ),
      _PeriodPresetItem(
        label: 'Last 90 Days',
        icon: Icons.date_range_outlined,
        isSelected: activeFilter.label == 'Last 90 Days',
        onTap: () {
          notifier.setLast90Days();
          Navigator.pop(context);
        },
      ),
      _PeriodPresetItem(
        label: 'All Time',
        icon: Icons.all_inclusive_rounded,
        isSelected: activeFilter.label == 'All Time',
        onTap: () {
          notifier.setAllTime();
          Navigator.pop(context);
        },
      ),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TallyTapTheme.textGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TallyTapTheme.primaryMint,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: TallyTapTheme.borderGreen.withOpacity(0.3),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Date Range Option
          InkWell(
            onTap: () async {
              Navigator.pop(context);
              final initialRange = activeFilter.start != null && activeFilter.end != null
                  ? DateTimeRange(start: activeFilter.start!, end: activeFilter.end!)
                  : null;
              final pickedRange = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: initialRange,
              );
              if (pickedRange != null) {
                notifier.setCustomRange(pickedRange.start, pickedRange.end);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF14241F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TallyTapTheme.primaryMint.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.date_range_rounded, color: TallyTapTheme.primaryMint, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose Custom Range...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: TallyTapTheme.primaryMint, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Presets
          const Text(
            'PRESETS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 8),
          ...presets.map((preset) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildPeriodTile(context, preset),
              )),

          if (availableMonths.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'MONTHLY ARCHIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableMonths.length,
                itemBuilder: (context, index) {
                  final monthDate = availableMonths[index];
                  final label = DateFormat('MMMM yyyy').format(monthDate);
                  final isSelected = activeFilter.label == label;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildPeriodTile(
                      context,
                      _PeriodPresetItem(
                        label: label,
                        icon: Icons.calendar_month_rounded,
                        isSelected: isSelected,
                        onTap: () {
                          notifier.setCustomMonth(monthDate);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodTile(BuildContext context, _PeriodPresetItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: item.isSelected ? TallyTapTheme.primaryMint.withOpacity(0.15) : TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isSelected ? TallyTapTheme.primaryMint.withOpacity(0.5) : TallyTapTheme.borderGreen,
            width: item.isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: item.isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: item.isSelected ? FontWeight.bold : FontWeight.w500,
                  color: item.isSelected ? TallyTapTheme.textLight : TallyTapTheme.textGray,
                ),
              ),
            ),
            if (item.isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: TallyTapTheme.primaryMint,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodPresetItem {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  _PeriodPresetItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
}
