import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/customization_provider.dart';

class SnoozeDurationSheet extends ConsumerStatefulWidget {
  const SnoozeDurationSheet({super.key});

  @override
  ConsumerState<SnoozeDurationSheet> createState() => _SnoozeDurationSheetState();
}

class _SnoozeDurationSheetState extends ConsumerState<SnoozeDurationSheet> {
  final Map<String, int> _options = {
    '15 mins': 15,
    '30 mins': 30,
    '45 mins': 45,
    '1 hr': 60,
    '4 hrs': 240,
    '12 hrs': 720,
    '1 day': 1440,
  };

  void _showCustomTimeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TallyTapTheme.obsidianBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1),
          ),
          title: const Text('Custom Snooze Time', style: TextStyle(color: TallyTapTheme.textLight)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: TallyTapTheme.textLight),
            decoration: const InputDecoration(
              hintText: 'Enter duration in minutes',
              hintStyle: TextStyle(color: TallyTapTheme.textGray),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TallyTapTheme.borderGreen)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TallyTapTheme.primaryMint)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null && val > 0) {
                  ref.read(snoozeDurationProvider.notifier).setDuration(val);
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Close the sheet as well
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: TallyTapTheme.primaryMint, foregroundColor: TallyTapTheme.obsidianBg),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDuration = ref.watch(snoozeDurationProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1B17),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                ),
                child: const Icon(Icons.snooze_rounded, color: TallyTapTheme.primaryMint, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remind Later Duration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TallyTapTheme.textLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select how long to snooze notifications',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._options.entries.map((entry) {
            final isSelected = currentDuration == entry.value;
            return ListTile(
              title: Text(entry.key, style: TextStyle(color: isSelected ? TallyTapTheme.primaryMint : TallyTapTheme.textLight)),
              trailing: isSelected ? const Icon(Icons.check, color: TallyTapTheme.primaryMint) : null,
              onTap: () {
                ref.read(snoozeDurationProvider.notifier).setDuration(entry.value);
                Navigator.pop(context);
              },
            );
          }),
          const Divider(color: TallyTapTheme.borderGreen),
          ListTile(
            title: const Text('Custom Time...', style: TextStyle(color: TallyTapTheme.textLight)),
            trailing: const Icon(Icons.keyboard_arrow_right, color: TallyTapTheme.textGray),
            onTap: _showCustomTimeDialog,
          ),
        ],
      ),
    ),
  );
}
}
