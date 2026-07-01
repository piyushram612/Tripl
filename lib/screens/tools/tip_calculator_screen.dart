import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/tutorial_service.dart';
import '../../providers/tutorial_provider.dart';

class TipCalculatorScreen extends ConsumerStatefulWidget {
  const TipCalculatorScreen({super.key});

  @override
  ConsumerState<TipCalculatorScreen> createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends ConsumerState<TipCalculatorScreen> {
  final TextEditingController _billController = TextEditingController(text: "0.00");
  double _tipPercentage = 15.0;
  int _peopleCount = 1;
  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorialStatus();
    });
  }

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  double get _billAmount {
    return double.tryParse(_billController.text) ?? 0.0;
  }

  double get _totalTip {
    return _billAmount * (_tipPercentage / 100);
  }

  double get _totalAmount {
    return _billAmount + _totalTip;
  }

  double get _amountPerPerson {
    return _totalAmount / _peopleCount;
  }

  double get _tipPerPerson {
    return _totalTip / _peopleCount;
  }

  void _onChipSelected(double value) {
    HapticFeedback.lightImpact();
    setState(() {
      _tipPercentage = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TallyTapTheme.obsidianBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TallyTapTheme.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tip Calculator',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: TallyTapTheme.textLight,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display Card (Results)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TallyTapTheme.primaryMint.withOpacity(0.12),
                        TallyTapTheme.primaryMint.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: TallyTapTheme.primaryMint.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'EACH PERSON PAYS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: TallyTapTheme.primaryMint,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹', // Defaults to global rupee symbol or currency-agnostic symbol
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: TallyTapTheme.primaryMint,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            _amountPerPerson.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: TallyTapTheme.textLight,
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: TallyTapTheme.borderGreen, height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBreakdownItem('Total Bill', '₹${_totalAmount.toStringAsFixed(2)}'),
                          _buildBreakdownItem('Total Tip', '₹${_totalTip.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBreakdownItem('Tip / Person', '₹${_tipPerPerson.toStringAsFixed(2)}'),
                          _buildBreakdownItem('Total Split', '₹${_amountPerPerson.toStringAsFixed(2)} × $_peopleCount'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Section Title: Input details
                const Text(
                  'BILL DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: TallyTapTheme.textGray,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Bill Amount Card
                Card(
                  key: TutorialService.tipAmountKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Bill Amount',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: SizedBox(
                            width: 130,
                            child: TextField(
                              controller: _billController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: TallyTapTheme.primaryMint,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                setState(() {});
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tip Percentage Section
                Card(
                  key: TutorialService.tipSliderKey,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tip Percentage',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                            ),
                            Text(
                              '${_tipPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: TallyTapTheme.primaryMint,
                                ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: TallyTapTheme.primaryMint,
                            inactiveTrackColor: TallyTapTheme.borderGreen,
                            thumbColor: TallyTapTheme.primaryMint,
                            overlayColor: TallyTapTheme.primaryMint.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _tipPercentage,
                            min: 0,
                            max: 30,
                            divisions: 30,
                            onChanged: (val) {
                              setState(() {
                                _tipPercentage = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildTipChip(10),
                            _buildTipChip(15),
                            _buildTipChip(18),
                            _buildTipChip(20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // People Split Section
                Card(
                  key: TutorialService.tipSplitKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Split Between',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: TallyTapTheme.textGray),
                                onPressed: _peopleCount <= 1
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _peopleCount--;
                                        });
                                      },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$_peopleCount',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: TallyTapTheme.textLight,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: TallyTapTheme.primaryMint),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _peopleCount++;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: TallyTapTheme.textLight),
        ),
      ],
    );
  }

  Widget _buildTipChip(double pct) {
    final isSelected = _tipPercentage == pct;
    return GestureDetector(
      onTap: () => _onChipSelected(pct),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
            width: 1.0,
          ),
        ),
        child: Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight,
          ),
        ),
      ),
    );
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(kPrefTutorialTipCalc) ?? false;
    if (!hasSeen && mounted) {
      _initTutorial();
    }
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.6,
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      beforeFocus: (target) async {
        if (target.keyTarget?.currentContext != null) {
          Scrollable.ensureVisible(
            target.keyTarget!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          await Future.delayed(const Duration(milliseconds: 350));
        }
      },
      onClickOverlay: (target) {
        tutorialCoachMark?.next();
      },
      onFinish: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialTipCalc);
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialTipCalc);
        return true;
      },
    );
    tutorialCoachMark?.show(context: context);
  }

  Widget _buildTutorialContent(TutorialCoachMarkController controller, String title, String description, {String nextText = "Next"}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => controller.next(),
            style: ElevatedButton.styleFrom(
              backgroundColor: TallyTapTheme.primaryMint,
              foregroundColor: TallyTapTheme.obsidianBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(nextText),
          ),
        ),
      ],
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    targets.add(TargetFocus(
      identify: "TargetBillAmount",
      keyTarget: TutorialService.tipAmountKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Bill Amount", "Enter the total pre-tip bill amount here."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetTipSlider",
      keyTarget: TutorialService.tipSliderKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Tip Adjuster", "Use the slider or quick buttons to set the tip percentage."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetTipSplit",
      keyTarget: TutorialService.tipSplitKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) => _buildTutorialContent(controller, "Split Bill", "If sharing the bill, increase the people count to split the cost evenly.", nextText: "Finish"),
        ),
      ],
    ));

    return targets;
  }
}

