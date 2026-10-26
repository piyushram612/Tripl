import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/parsed_sms_transaction.dart';
import '../../providers/currency_provider.dart';
import '../../providers/source_provider.dart';
import '../../services/sms_parser_service.dart';
import '../../services/transaction_service.dart';

class ImportSmsSheet extends ConsumerStatefulWidget {
  const ImportSmsSheet({super.key});

  @override
  ConsumerState<ImportSmsSheet> createState() => _ImportSmsSheetState();
}

class _ImportSmsSheetState extends ConsumerState<ImportSmsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();

  bool _isLoading = false;
  String? _statusMessage;
  List<ParsedSmsTransaction> _parsedTransactions = [];
  String _activeFilter = 'all'; // 'all', 'new', 'duplicates'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  Future<void> _scanDeviceInbox() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting SMS permissions...';
    });

    try {
      final hasPermission = await SmsParserService.hasSmsPermission();
      if (!hasPermission) {
        final granted = await SmsParserService.requestSmsPermission();
        if (!granted) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _statusMessage = 'READ_SMS permission was denied. You can still paste SMS text in the "Paste Text" tab.';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS permission not granted. Please allow SMS permission in settings or paste text manually.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }

      setState(() {
        _statusMessage = 'Scanning inbox for bank & card messages...';
      });

      final availableSources = ref.read(sourcesListProvider);
      final existingTransactions = ref.read(transactionListProvider);

      final results = await SmsParserService.scanAndParseInbox(
        limit: 250,
        availableSources: availableSources,
        existingTransactions: existingTransactions,
      );

      if (mounted) {
        final dupCount = results.where((t) => t.duplicateMatch?.isDuplicate == true).length;
        final newCount = results.length - dupCount;

        setState(() {
          _parsedTransactions = results;
          _isLoading = false;
          _statusMessage = results.isEmpty
              ? 'No financial bank/card transactions found in recent messages.'
              : 'Found ${results.length} transaction(s): $newCount new, $dupCount potential duplicate(s).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error scanning SMS: $e';
        });
      }
    }
  }

  Future<void> _parsePastedText() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste some SMS text to parse.')),
      );
      return;
    }

    final sender = _senderController.text.trim().isNotEmpty ? _senderController.text.trim() : null;
    final availableSources = ref.read(sourcesListProvider);
    final existingTransactions = ref.read(transactionListProvider);
    final savedPrefs = await SmsParserService.loadSourcePreferences();

    final parsed = SmsParserService.parse(text, sender: sender);

    if (parsed.isFinancial && parsed.amount != null && parsed.amount! > 0) {
      final mappedSource = SmsParserService.mapToPaymentSource(
        parsed,
        availableSources,
        savedPreferences: savedPrefs,
      );

      final duplicateMatch = SmsParserService.findDuplicateMatch(parsed, existingTransactions);
      final isAccepted = !duplicateMatch.isExact;
      final mergeWithExisting = duplicateMatch.isPotential;

      final prepared = parsed.copyWith(
        selectedPaymentSource: mappedSource,
        duplicateMatch: duplicateMatch,
        isAccepted: isAccepted,
        mergeWithExisting: mergeWithExisting,
      );

      setState(() {
        _parsedTransactions = [prepared];
        _statusMessage = duplicateMatch.isDuplicate
            ? 'Parsed 1 transaction (${duplicateMatch.reason})'
            : 'Successfully parsed 1 new transaction!';
      });
    } else {
      setState(() {
        _parsedTransactions = [];
        _statusMessage = parsed.rejectReason ?? 'The text does not look like a financial debit/credit transaction.';
      });
    }
  }

  void _updateTransaction(int index, ParsedSmsTransaction updated) {
    setState(() {
      _parsedTransactions[index] = updated;
    });
  }

  void _showSourcePicker(BuildContext context, int index, ParsedSmsTransaction item) {
    final sources = ref.read(sourcesListProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: TriplTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, color: TriplTheme.primaryMint, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Map to Payment Source',
                        style: TextStyle(
                          color: TriplTheme.primaryMint,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Select which bank account or card in TallyTap this SMS belongs to. Your choice will be remembered.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
                const Divider(color: Colors.white12, height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sources.length,
                    itemBuilder: (ctx, i) {
                      final src = sources[i];
                      final isSelected = item.selectedPaymentSource == src;
                      return ListTile(
                        leading: Icon(
                          src.toLowerCase().contains('card') || src.toLowerCase().contains('cc')
                              ? Icons.credit_card_rounded
                              : (src.toLowerCase() == 'cash'
                                  ? Icons.payments_rounded
                                  : Icons.account_balance_rounded),
                          color: isSelected ? TriplTheme.primaryMint : Colors.white70,
                        ),
                        title: Text(
                          src,
                          style: TextStyle(
                            color: isSelected ? TriplTheme.primaryMint : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected ? Icon(Icons.check_rounded, color: TriplTheme.primaryMint) : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          _updateTransaction(index, item.copyWith(selectedPaymentSource: src));

                          // Persist preference for this bank
                          if (item.bankName != null && item.bankName!.isNotEmpty) {
                            await SmsParserService.saveSourcePreference(
                              item.bankName!,
                              item.accountNumber,
                              src,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _autoResolveDuplicates() {
    setState(() {
      for (int i = 0; i < _parsedTransactions.length; i++) {
        final t = _parsedTransactions[i];
        if (t.duplicateMatch?.isExact == true) {
          // Reject exact duplicates
          _parsedTransactions[i] = t.copyWith(isAccepted: false, mergeWithExisting: false);
        } else if (t.duplicateMatch?.isPotential == true) {
          // Merge potential duplicates into the manual entry
          _parsedTransactions[i] = t.copyWith(isAccepted: true, mergeWithExisting: true);
        } else {
          // Accept new items
          _parsedTransactions[i] = t.copyWith(isAccepted: true, mergeWithExisting: false);
        }
      }
      _statusMessage = 'Duplicates auto-resolved: Potential duplicates set to Merge & Enrich; exact duplicates skipped.';
    });
  }

  Future<void> _importSelected() async {
    final toProcess = _parsedTransactions.where((t) => t.isAccepted).toList();
    if (toProcess.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions are currently accepted for import.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final notifier = ref.read(transactionListProvider.notifier);
    final count = await SmsParserService.importTransactions(toProcess, notifier);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      final mergeCount = toProcess.where((t) => t.mergeWithExisting).length;
      final newCount = toProcess.length - mergeCount;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Processed $count transaction(s) ($newCount added, $mergeCount enriched)!',
          ),
          backgroundColor: TriplTheme.primaryMint,
        ),
      );
    }
  }

  List<int> get _filteredIndices {
    final list = <int>[];
    for (int i = 0; i < _parsedTransactions.length; i++) {
      final t = _parsedTransactions[i];
      if (_activeFilter == 'all') {
        list.add(i);
      } else if (_activeFilter == 'new' && (t.duplicateMatch == null || !t.duplicateMatch!.isDuplicate)) {
        list.add(i);
      } else if (_activeFilter == 'duplicates' && t.duplicateMatch?.isDuplicate == true) {
        list.add(i);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);

    final totalCount = _parsedTransactions.length;
    final dupCount = _parsedTransactions.where((t) => t.duplicateMatch?.isDuplicate == true).length;
    final newCount = totalCount - dupCount;

    final acceptedList = _parsedTransactions.where((t) => t.isAccepted).toList();
    final acceptedNewCount = acceptedList.where((t) => !t.mergeWithExisting).length;
    final acceptedMergeCount = acceptedList.where((t) => t.mergeWithExisting).length;

    final filteredIndices = _filteredIndices;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: TriplTheme.obsidianBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: TriplTheme.borderGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TriplTheme.primaryMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sms_rounded, color: TriplTheme.primaryMint, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SMS Transaction Reader',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Smart source mapping & duplicate reconciliation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          // Tabs: Device Inbox vs Paste Text
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: TriplTheme.primaryMint.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TriplTheme.primaryMint.withValues(alpha: 0.5)),
              ),
              labelColor: TriplTheme.primaryMint,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.mark_email_read_rounded, size: 18), text: 'Device Inbox'),
                Tab(icon: Icon(Icons.content_paste_rounded, size: 18), text: 'Paste SMS Text'),
              ],
            ),
          ),

          // Tab content (Scan or Paste)
          SizedBox(
            height: 140,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Device Inbox
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Auto-scan inbox for bank/card alerts. Mapped to your accounts & cross-referenced against your entries.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _scanDeviceInbox,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.sync_rounded, color: Colors.black, size: 18),
                        label: Text(
                          _isLoading ? 'Scanning...' : 'Scan Device Inbox',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TriplTheme.primaryMint,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Paste SMS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pasteController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Paste SMS: "Rs.500 debited from A/c XX1234 to Zomato UPI Ref 1234..."',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _senderController,
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              decoration: InputDecoration(
                                hintText: 'Optional Sender (e.g. HDFCBK)',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _parsePastedText,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TriplTheme.primaryMint,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Parse', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filters and resolution banner (when items exist)
          if (_parsedTransactions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All ($totalCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('new', 'New ($newCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('duplicates', 'Duplicates ($dupCount)'),
                  const Spacer(),
                  if (dupCount > 0)
                    TextButton.icon(
                      onPressed: _autoResolveDuplicates,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFFFFB74D)),
                      label: const Text(
                        'Auto-Resolve',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFFB74D), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Status message
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: _parsedTransactions.isNotEmpty ? TriplTheme.primaryMint : Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const Divider(color: Colors.white12, height: 8),

          // Transactions Preview List
          Expanded(
            child: _parsedTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        Text(
                          'No parsed transactions to show',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: filteredIndices.length,
                    itemBuilder: (context, i) {
                      final originalIndex = filteredIndices[i];
                      final item = _parsedTransactions[originalIndex];
                      return _buildTransactionCard(originalIndex, item, currency);
                    },
                  ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: TriplTheme.obsidianBg,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (acceptedList.isEmpty || _isLoading) ? null : _importSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TriplTheme.primaryMint,
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            acceptedMergeCount > 0
                                ? 'Import ($acceptedNewCount New, $acceptedMergeCount Merge)'
                                : 'Import ${acceptedList.length} Accepted Transaction${acceptedList.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? TriplTheme.primaryMint.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? TriplTheme.primaryMint : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? TriplTheme.primaryMint : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(int index, ParsedSmsTransaction item, String currency) {
    final isDebit = item.type == SmsTransactionType.debit;
    final dateFormatted = item.date != null
        ? DateFormat('dd MMM, hh:mm a').format(item.date!)
        : 'Recent';

    final isExact = item.duplicateMatch?.isExact == true;
    final isPotential = item.duplicateMatch?.isPotential == true;

    Color cardBorderColor;
    if (!item.isAccepted) {
      cardBorderColor = Colors.white10;
    } else if (item.mergeWithExisting) {
      cardBorderColor = const Color(0xFFFFB74D).withValues(alpha: 0.6);
    } else if (isExact) {
      cardBorderColor = Colors.blueAccent.withValues(alpha: 0.4);
    } else {
      cardBorderColor = TriplTheme.primaryMint.withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: !item.isAccepted
            ? Colors.white.withValues(alpha: 0.02)
            : (item.mergeWithExisting
                ? const Color(0xFFFFB74D).withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Duplicate / Reconciliation Banner (if match found)
          if (isExact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.duplicateMatch!.reason,
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    item.isAccepted ? 'Will Add Again' : 'Skipped',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.isAccepted ? Colors.orangeAccent : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

          if (isPotential)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.14),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFFB74D)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.duplicateMatch!.reason,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFFB74D), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Main Card Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Merchant & Amount & Accept/Reject
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.payee ?? item.bankName ?? 'Unknown Merchant',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.isAccepted ? Colors.white : Colors.white38,
                          fontSize: 14,
                          decoration: !item.isAccepted ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isDebit ? '-' : '+'}$currency${item.amount?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: !item.isAccepted
                            ? Colors.white38
                            : (isDebit ? const Color(0xFFFF6B6B) : TriplTheme.primaryMint),
                        decoration: !item.isAccepted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Accept / Reject button
                    IconButton(
                      icon: Icon(
                        item.isAccepted ? Icons.check_circle_rounded : Icons.cancel_outlined,
                        color: item.isAccepted ? TriplTheme.primaryMint : Colors.white38,
                        size: 20,
                      ),
                      onPressed: () {
                        _updateTransaction(index, item.copyWith(isAccepted: !item.isAccepted));
                      },
                      tooltip: item.isAccepted ? 'Reject / Ignore' : 'Accept Transaction',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 2: Badges (Category, Date, Ref)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormatted,
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    if (item.referenceId != null && item.referenceId!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ref: ${item.referenceId}',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Row 3: Mapped Payment Source Selector
                Row(
                  children: [
                    Text(
                      'Payment Source: ',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    GestureDetector(
                      onTap: () => _showSourcePicker(context, index, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: TriplTheme.primaryMint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TriplTheme.primaryMint.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.selectedPaymentSource ?? 'Bank Account',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: TriplTheme.primaryMint,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down_rounded, size: 14, color: TriplTheme.primaryMint),
                          ],
                        ),
                      ),
                    ),
                    if (item.accountNumber != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(**${item.accountNumber})',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ],
                ),

                // Row 4: Duplicate Resolution Action Toggles (for potential duplicates)
                if (isPotential && item.isAccepted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _updateTransaction(index, item.copyWith(mergeWithExisting: true));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: item.mergeWithExisting
                                    ? const Color(0xFFFFB74D).withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: item.mergeWithExisting ? const Color(0xFFFFB74D) : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.merge_type_rounded,
                                    size: 13,
                                    color: item.mergeWithExisting ? const Color(0xFFFFB74D) : Colors.white60,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Merge & Enrich',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.mergeWithExisting ? const Color(0xFFFFB74D) : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _updateTransaction(index, item.copyWith(mergeWithExisting: false));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: !item.mergeWithExisting
                                    ? TriplTheme.primaryMint.withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: !item.mergeWithExisting ? TriplTheme.primaryMint : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 13,
                                    color: !item.mergeWithExisting ? TriplTheme.primaryMint : Colors.white60,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Keep as New',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !item.mergeWithExisting ? TriplTheme.primaryMint : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
