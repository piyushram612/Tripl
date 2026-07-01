import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class CustomizeLayoutSheet extends ConsumerStatefulWidget {
  const CustomizeLayoutSheet({super.key});

  @override
  ConsumerState<CustomizeLayoutSheet> createState() => _CustomizeLayoutSheetState();
}

class _CustomizeLayoutSheetState extends ConsumerState<CustomizeLayoutSheet> {
  static const Map<String, String> _cardNames = {
    'accounts': 'Accounts & Balances',
    'summary': 'Weekly & Monthly Summary',
    'breakdown': 'Spending Breakdown',
    'recent': 'Recent Reflections',
  };

  static const Map<String, IconData> _cardIcons = {
    'accounts': Icons.account_balance_wallet_rounded,
    'summary': Icons.bar_chart_rounded,
    'breakdown': Icons.pie_chart_rounded,
    'recent': Icons.history_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final homeLayout = ref.watch(homeLayoutProvider);
    final cardVisibilities = ref.watch(homeCardVisibilityProvider);

    int visibleCount = 0;
    final Map<String, int> positionMapping = {};
    for (final key in homeLayout) {
      final isVisible = cardVisibilities[key] ?? true;
      if (isVisible) {
        visibleCount++;
        positionMapping[key] = visibleCount;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: TallyTapTheme.obsidianBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill at the top of the sheet
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TallyTapTheme.borderGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Customize Home Layout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.primaryMint,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'DRAG AND REORDER CARDS OR TOGGLE VISIBILITY FOR YOUR DASHBOARD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: TallyTapTheme.textGray,
              ),
            ),
            const SizedBox(height: 20),
            
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final layout = List<String>.from(homeLayout);
                final item = layout.removeAt(oldIndex);
                layout.insert(newIndex, item);
                ref.read(homeLayoutProvider.notifier).updateLayout(layout);
              },
              children: [
                for (int i = 0; i < homeLayout.length; i++)
                  if (_cardNames.containsKey(homeLayout[i]))
                    Padding(
                      key: ValueKey(homeLayout[i]),
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        tileColor: TallyTapTheme.obsidianCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_handle_rounded, color: TallyTapTheme.primaryMint, size: 20),
                            const SizedBox(width: 12),
                            Icon(_cardIcons[homeLayout[i]], color: TallyTapTheme.textLight, size: 18),
                          ],
                        ),
                        title: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _cardNames[homeLayout[i]]!,
                            style: const TextStyle(
                              color: TallyTapTheme.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  (cardVisibilities[homeLayout[i]] ?? true)
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: (cardVisibilities[homeLayout[i]] ?? true)
                                      ? TallyTapTheme.primaryMint
                                      : TallyTapTheme.textGray,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final isCurrentlyVisible = cardVisibilities[homeLayout[i]] ?? true;
                                  ref.read(homeCardVisibilityProvider.notifier).setVisible(homeLayout[i], !isCurrentlyVisible);
                                },
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1B17),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                                ),
                                child: Text(
                                  positionMapping.containsKey(homeLayout[i])
                                      ? 'Position ${positionMapping[homeLayout[i]]}'
                                      : 'Hidden',
                                  style: TextStyle(
                                    color: positionMapping.containsKey(homeLayout[i])
                                        ? TallyTapTheme.primaryMint
                                        : TallyTapTheme.textGray,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(homeLayoutProvider.notifier).resetLayout();
                      ref.read(homeCardVisibilityProvider.notifier).resetVisibility();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Layout and visibility reset to default'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: TallyTapTheme.primaryMint,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: TallyTapTheme.borderGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'RESET DEFAULT',
                      style: TextStyle(
                        color: TallyTapTheme.textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TallyTapTheme.primaryMint,
                      foregroundColor: TallyTapTheme.obsidianBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
