import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class TipCalculatorScreen extends StatefulWidget {
  const TipCalculatorScreen({super.key});

  @override
  State<TipCalculatorScreen> createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends State<TipCalculatorScreen> {
  final TextEditingController _billController = TextEditingController(text: "0.00");
  double _tipPercentage = 15.0;
  int _peopleCount = 1;

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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bill Amount',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                        ),
                        SizedBox(
                          width: 150,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tip Percentage Section
                Card(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Split Between',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                        ),
                        Row(
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
}
