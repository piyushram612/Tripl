import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/filter_criteria.dart';
import '../../providers/category_provider.dart';
import '../../providers/source_provider.dart';

class TimelineFilterSheet extends ConsumerStatefulWidget {
  final FilterCriteria initialCriteria;
  final double maxTransactionAmount;

  const TimelineFilterSheet({
    super.key,
    required this.initialCriteria,
    required this.maxTransactionAmount,
  });

  @override
  ConsumerState<TimelineFilterSheet> createState() => _TimelineFilterSheetState();
}

class _TimelineFilterSheetState extends ConsumerState<TimelineFilterSheet> {
  late FilterCriteria _criteria;
  late TextEditingController _minController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _criteria = widget.initialCriteria;
    _minController = TextEditingController(text: (_criteria.minAmount ?? 0).toStringAsFixed(0));
    _maxController = TextEditingController(text: (_criteria.maxAmount ?? widget.maxTransactionAmount).toStringAsFixed(0));
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.of(context).pop(_criteria);
  }

  void _reset() {
    setState(() {
      _criteria = FilterCriteria();
      _minController.text = '0';
      _maxController.text = widget.maxTransactionAmount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final paymentMethods = ref.watch(sourcesListProvider);
    final maxAmount = widget.maxTransactionAmount > 0 ? widget.maxTransactionAmount : 10000.0;
    
    // Ensure min and max for slider are within valid bounds
    double currentMin = _criteria.minAmount ?? 0;
    double currentMax = _criteria.maxAmount ?? maxAmount;
    if (currentMin > maxAmount) currentMin = maxAmount;
    if (currentMax > maxAmount) currentMax = maxAmount;
    if (currentMin > currentMax) {
      final temp = currentMin;
      currentMin = currentMax;
      currentMax = temp;
    }

    return Container(
      decoration: const BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: TallyTapTheme.textLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: TallyTapTheme.textGray),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range
                  _buildSectionTitle('Date Range'),
                  _buildDateRangeSelector(),
                  const SizedBox(height: 24),
                  
                  // Amount Range
                  _buildSectionTitle('Amount Range'),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: RangeValues(currentMin, currentMax),
                    min: 0,
                    max: maxAmount,
                    divisions: maxAmount > 0 ? maxAmount.toInt() : 1,
                    activeColor: TallyTapTheme.primaryMint,
                    inactiveColor: TallyTapTheme.borderGreen,
                    labels: RangeLabels(
                      currentMin.toStringAsFixed(0),
                      currentMax.toStringAsFixed(0),
                    ),
                    onChanged: (RangeValues values) {
                      setState(() {
                        _criteria = _criteria.copyWith(
                          minAmount: values.start,
                          maxAmount: values.end,
                        );
                        _minController.text = values.start.toStringAsFixed(0);
                        _maxController.text = values.end.toStringAsFixed(0);
                      });
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Min',
                            labelStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 12),
                            filled: true,
                            fillColor: TallyTapTheme.obsidianCard,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (val) {
                            final parsed = double.tryParse(val) ?? 0;
                            setState(() {
                              _criteria = _criteria.copyWith(minAmount: parsed);
                              if (parsed > currentMax) {
                                _criteria = _criteria.copyWith(maxAmount: parsed);
                                _maxController.text = parsed.toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _maxController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Max',
                            labelStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 12),
                            filled: true,
                            fillColor: TallyTapTheme.obsidianCard,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (val) {
                            final parsed = double.tryParse(val) ?? maxAmount;
                            setState(() {
                              _criteria = _criteria.copyWith(maxAmount: parsed);
                              if (parsed < currentMin) {
                                _criteria = _criteria.copyWith(minAmount: parsed);
                                _minController.text = parsed.toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status
                  _buildSectionTitle('Verification Status'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('All', _criteria.needsVerification == null, () {
                        setState(() {
                          _criteria = _criteria.copyWith(clearNeedsVerification: true);
                        });
                      }),
                      _buildChip('Verified', _criteria.needsVerification == false, () {
                        setState(() {
                          _criteria = _criteria.copyWith(needsVerification: false);
                        });
                      }),
                      _buildChip('Needs Verification', _criteria.needsVerification == true, () {
                        setState(() {
                          _criteria = _criteria.copyWith(needsVerification: true);
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  _buildSectionTitle('Categories'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = _criteria.categories.contains(cat);
                      return _buildChip(cat, isSelected, () {
                        setState(() {
                          final newList = List<String>.from(_criteria.categories);
                          if (isSelected) {
                            newList.remove(cat);
                          } else {
                            newList.add(cat);
                          }
                          _criteria = _criteria.copyWith(categories: newList);
                        });
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Payment Methods
                  _buildSectionTitle('Payment Methods'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: paymentMethods.map((method) {
                      final isSelected = _criteria.paymentMethods.contains(method);
                      return _buildChip(method, isSelected, () {
                        setState(() {
                          final newList = List<String>.from(_criteria.paymentMethods);
                          if (isSelected) {
                            newList.remove(method);
                          } else {
                            newList.add(method);
                          }
                          _criteria = _criteria.copyWith(paymentMethods: newList);
                        });
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Actions
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: TallyTapTheme.borderGreen),
                    ),
                  ),
                  child: const Text('Reset', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TallyTapTheme.primaryMint,
                    foregroundColor: TallyTapTheme.obsidianBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: TallyTapTheme.textLight,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.15) : TallyTapTheme.obsidianCard,
          border: Border.all(
            color: isSelected ? TallyTapTheme.primaryMint.withOpacity(0.5) : TallyTapTheme.borderGreen,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textGray,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    final hasDate = _criteria.startDate != null && _criteria.endDate != null;
    String dateText = 'Select Date Range';
    if (hasDate) {
      dateText = '${_formatDate(_criteria.startDate!)} - ${_formatDate(_criteria.endDate!)}';
    }

    return GestureDetector(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: hasDate ? DateTimeRange(start: _criteria.startDate!, end: _criteria.endDate!) : null,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: TallyTapTheme.primaryMint,
                  onPrimary: TallyTapTheme.obsidianBg,
                  surface: TallyTapTheme.obsidianCard,
                  onSurface: TallyTapTheme.textLight,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _criteria = _criteria.copyWith(
              startDate: picked.start,
              endDate: picked.end,
            );
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TallyTapTheme.obsidianCard,
          border: Border.all(color: TallyTapTheme.borderGreen),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateText,
              style: TextStyle(
                color: hasDate ? TallyTapTheme.textLight : TallyTapTheme.textGray,
                fontSize: 14,
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _criteria = _criteria.copyWith(clearStartDate: true, clearEndDate: true);
                  });
                },
                child: const Icon(Icons.close, color: TallyTapTheme.textGray, size: 20),
              )
            else
              const Icon(Icons.calendar_today, color: TallyTapTheme.textGray, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
