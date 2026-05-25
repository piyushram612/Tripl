import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/source_provider.dart';

class ManageSourcesSheet extends ConsumerStatefulWidget {
  const ManageSourcesSheet({super.key});

  @override
  ConsumerState<ManageSourcesSheet> createState() => _ManageSourcesSheetState();
}

class _ManageSourcesSheetState extends ConsumerState<ManageSourcesSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage Payment Sources',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.primaryMint,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: TallyTapTheme.textGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'ACTIVE PAYMENT SOURCES (TAP TO DELETE)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No custom payment sources active. Add one below!',
                style: TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: sources.map((src) {
                    return InputChip(
                      label: Text(
                        src,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: TallyTapTheme.textLight,
                        ),
                      ),
                      backgroundColor: TallyTapTheme.obsidianCard,
                      selectedColor: TallyTapTheme.primaryMint,
                      checkmarkColor: TallyTapTheme.obsidianBg,
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        color: TallyTapTheme.primaryMint,
                        size: 14,
                      ),
                      onDeleted: () {
                        ref.read(sourcesListProvider.notifier).deleteSource(src);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted payment source: $src'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: TallyTapTheme.borderGreen, width: 0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'ADD NEW PAYMENT SOURCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Source name (e.g. Cash, Credit Card)',
                    hintStyle: const TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                    filled: true,
                    fillColor: TallyTapTheme.obsidianCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TallyTapTheme.primaryMint, width: 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(sourcesListProvider.notifier).addSource(text);
                    _controller.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added payment source: $text'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_circle_rounded, color: TallyTapTheme.primaryMint, size: 36),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
