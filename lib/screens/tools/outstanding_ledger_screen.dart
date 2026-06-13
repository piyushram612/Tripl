import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/outstanding_model.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../../providers/outstanding_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/source_provider.dart';
import '../../services/notification_service.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/tutorial_service.dart';
import '../../providers/tutorial_provider.dart';

class OutstandingLedgerScreen extends ConsumerStatefulWidget {
  const OutstandingLedgerScreen({super.key});

  @override
  ConsumerState<OutstandingLedgerScreen> createState() => _OutstandingLedgerScreenState();
}

class _OutstandingLedgerScreenState extends ConsumerState<OutstandingLedgerScreen> {
  String _activeFilter = 'Active'; // 'Active', 'Settled', 'All'
  final Set<String> _expandedPersons = {};
  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorialStatus();
    });
  }

  void _togglePersonExpanded(String person) {
    setState(() {
      if (_expandedPersons.contains(person)) {
        _expandedPersons.remove(person);
      } else {
        _expandedPersons.add(person);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(combinedOutstandingProvider);
    final currency = ref.watch(currencyProvider);
    final sources = ref.watch(sourcesListProvider);

    // Calculate dynamic totals of ACTIVE outstanding entries
    double theyOweMe = 0.0;
    double iOweThem = 0.0;

    for (final r in records) {
      if (!r.isSettled) {
        if (r.isLent) {
          theyOweMe += r.amount;
        } else {
          iOweThem += r.amount;
        }
      }
    }

    final double netBalance = theyOweMe - iOweThem;

    // Filter records
    final List<OutstandingRecord> filteredRecords;
    if (_activeFilter == 'Active') {
      filteredRecords = records.where((r) => !r.isSettled).toList();
    } else if (_activeFilter == 'Settled') {
      filteredRecords = records.where((r) => r.isSettled).toList();
    } else {
      filteredRecords = records;
    }

    // Group records by Person Name
    final Map<String, List<OutstandingRecord>> personGroups = {};
    for (final r in filteredRecords) {
      personGroups.putIfAbsent(r.personName, () => []).add(r);
    }

    // Sort persons by net active balance
    final List<String> sortedPersons = personGroups.keys.toList()
      ..sort((a, b) {
        double netA = 0.0;
        for (final r in personGroups[a]!) {
          if (!r.isSettled) netA += r.isLent ? r.amount : -r.amount;
        }
        double netB = 0.0;
        for (final r in personGroups[b]!) {
          if (!r.isSettled) netB += r.isLent ? r.amount : -r.amount;
        }
        return netB.abs().compareTo(netA.abs()); // Sort by largest absolute outstanding debt
      });

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
          'Outstanding Ledger',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: TallyTapTheme.textLight,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Summary Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C1915), TallyTapTheme.obsidianCard],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          key: TutorialService.ledgerWhoOwesMeKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'THEY OWE ME',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: TallyTapTheme.textGray,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$currency${theyOweMe.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: TallyTapTheme.primaryMint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: TallyTapTheme.borderGreen,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          key: TutorialService.ledgerWhoIOweKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'I OWE THEM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: TallyTapTheme.textGray,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$currency${iOweThem.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NET OUTSTANDING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: TallyTapTheme.textGray,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          netBalance >= 0
                              ? '+ $currency${netBalance.toStringAsFixed(2)}'
                              : '- $currency${netBalance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: netBalance >= 0 ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Segmented Filters View
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF091210),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: Row(
                  children: ['Active', 'Settled', 'All'].map((tab) {
                    final isSel = _activeFilter == tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _activeFilter = tab;
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? TallyTapTheme.primaryMint : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tab.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isSel ? TallyTapTheme.obsidianBg : TallyTapTheme.textGray,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Main Ledger List View
            Expanded(
              child: sortedPersons.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: TallyTapTheme.textGray.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No $_activeFilter Records Found',
                            style: const TextStyle(
                              color: TallyTapTheme.textGray,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                      itemCount: sortedPersons.length,
                      itemBuilder: (context, index) {
                        final person = sortedPersons[index];
                        final items = personGroups[person]!;
                        final isExp = _expandedPersons.contains(person);

                        // Calculate net outstanding for this person
                        double netPerson = 0.0;
                        int activeCount = 0;
                        for (final r in items) {
                          if (!r.isSettled) {
                            activeCount++;
                            netPerson += r.isLent ? r.amount : -r.amount;
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              ListTile(
                                onTap: () => _togglePersonExpanded(person),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: netPerson >= 0
                                      ? TallyTapTheme.primaryMint.withOpacity(0.12)
                                      : const Color(0xFFF59E0B).withOpacity(0.12),
                                  child: Text(
                                    person.isNotEmpty ? person[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: netPerson >= 0 ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  person,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: TallyTapTheme.textLight,
                                  ),
                                ),
                                subtitle: Text(
                                  activeCount == 0
                                      ? 'All settled up'
                                      : '$activeCount active logs',
                                  style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          netPerson == 0
                                              ? 'Settled'
                                              : netPerson > 0
                                                  ? 'Owes you'
                                                  : 'You owe',
                                          style: const TextStyle(fontSize: 9, color: TallyTapTheme.textGray, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          netPerson == 0
                                              ? '${currency}0'
                                              : '$currency${netPerson.abs().toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: netPerson == 0
                                                ? TallyTapTheme.textGray
                                                : netPerson > 0
                                                    ? TallyTapTheme.primaryMint
                                                    : const Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isExp ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: TallyTapTheme.textGray,
                                    ),
                                  ],
                                ),
                              ),

                              // Expanded nested details log
                              if (isExp) ...[
                                const Divider(color: TallyTapTheme.borderGreen, height: 1),
                                Container(
                                  color: Colors.black.withOpacity(0.12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    children: [
                                      ...items.map((r) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                r.isSettled
                                                    ? Icons.check_circle_outline_rounded
                                                    : r.isLent
                                                        ? Icons.arrow_upward_rounded
                                                        : Icons.arrow_downward_rounded,
                                                color: r.isSettled
                                                    ? TallyTapTheme.textGray
                                                    : r.isLent
                                                        ? TallyTapTheme.primaryMint
                                                        : const Color(0xFFF59E0B),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      r.notes.isNotEmpty ? r.notes : (r.isLent ? 'Lent money' : 'Borrowed money'),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: r.isSettled ? TallyTapTheme.textGray : TallyTapTheme.textLight,
                                                        decoration: r.isSettled ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${r.date.day}/${r.date.month}/${r.date.year}',
                                                      style: const TextStyle(fontSize: 10, color: TallyTapTheme.textGray),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '$currency${r.amount.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w900,
                                                      color: r.isSettled
                                                          ? TallyTapTheme.textGray
                                                          : r.isLent
                                                              ? TallyTapTheme.primaryMint
                                                              : const Color(0xFFF59E0B),
                                                      decoration: r.isSettled ? TextDecoration.lineThrough : null,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (!r.isSettled)
                                                    IconButton(
                                                      icon: const Icon(Icons.check_rounded, color: TallyTapTheme.primaryMint, size: 18),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () {
                                                        HapticFeedback.lightImpact();
                                                        _showSettleDialog(context, r);
                                                      },
                                                    )
                                                  else
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () {
                                                        HapticFeedback.lightImpact();
                                                        final allTx = ref.read(transactionListProvider);
                                                        final isSynth = allTx.any((t) => t.id == r.id && t.wasFinishLater);
                                                        if (isSynth) {
                                                          final tx = allTx.firstWhere((t) => t.id == r.id);
                                                          final updatedTx = ExpenseTransaction(
                                                            id: tx.id,
                                                            amount: tx.amount,
                                                            merchant: tx.merchant,
                                                            date: tx.date,
                                                            paymentMethod: tx.paymentMethod,
                                                            category: tx.category,
                                                            notes: tx.notes,
                                                            paidTo: tx.paidTo,
                                                            needsVerification: tx.needsVerification,
                                                            reminderDate: tx.reminderDate,
                                                            wasFinishLater: tx.wasFinishLater,
                                                            hideFromLedger: true,
                                                            groupId: tx.groupId,
                                                          );
                                                          ref.read(transactionListProvider.notifier).updateTransaction(updatedTx);
                                                        } else {
                                                          ref.read(outstandingListProvider.notifier).deleteRecord(r.id);
                                                        }
                                                      },
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),

                                      // Settle Entire Balance CTA
                                      if (netPerson != 0) ...[
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: netPerson > 0 ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B),
                                            foregroundColor: TallyTapTheme.obsidianBg,
                                            minimumSize: const Size.fromHeight(40),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(Icons.handshake_rounded, size: 16),
                                          label: Text(
                                            'Settle Net Balance ($currency${netPerson.abs().toStringAsFixed(0)})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            // Settle all active transactions for this person
                                            _showSettleNetDialog(context, person, netPerson, items.where((r) => !r.isSettled).toList());
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: TallyTapTheme.primaryMint,
        foregroundColor: TallyTapTheme.obsidianBg,
        shape: const CircleBorder(),
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showAddIOUSheet(context, sources);
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  // Settle Single Debt Dialog
  void _showSettleDialog(BuildContext context, OutstandingRecord record) {
    bool recordTimelineTx = true;
    final allTx = ref.read(transactionListProvider);
    final isSynth = allTx.any((t) => t.id == record.id && t.wasFinishLater);
    ExpenseTransaction? synthTx;
    if (isSynth) {
      synthTx = allTx.firstWhere((t) => t.id == record.id);
    }

    String selectedSource = synthTx?.paymentMethod ?? 'Cash';
    final sources = ref.read(sourcesListProvider);
    if (synthTx != null && synthTx.paymentMethod.isNotEmpty && sources.contains(synthTx.paymentMethod)) {
      selectedSource = synthTx.paymentMethod;
    } else if (!sources.contains(selectedSource)) {
      selectedSource = sources.isNotEmpty ? sources.first : 'Cash';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: TallyTapTheme.obsidianCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
          ),
          title: Text(
            record.isLent ? 'Settle Lent Balance' : 'Settle Owed Balance',
            style: const TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                record.isLent
                    ? 'Confirm Rahul paid you back the amount of ${record.amount} INR.'
                        .replaceAll('Rahul', record.personName)
                        .replaceAll('1,200', record.amount.toStringAsFixed(0))
                    : 'Confirm you paid Rahul back the amount of ${record.amount} INR.'
                        .replaceAll('Rahul', record.personName)
                        .replaceAll('1,200', record.amount.toStringAsFixed(0)),
                style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: recordTimelineTx,
                    activeColor: TallyTapTheme.primaryMint,
                    onChanged: (val) {
                      setStateDialog(() {
                        recordTimelineTx = val ?? true;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      isSynth ? 'Complete transaction in timeline' : 'Record Settlement in Timeline',
                      style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (recordTimelineTx) ...[
                const SizedBox(height: 12),
                const Text(
                  'SELECT PAYMENT SOURCE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: TallyTapTheme.obsidianBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TallyTapTheme.borderGreen),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSource,
                      dropdownColor: TallyTapTheme.obsidianCard,
                      isExpanded: true,
                      style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                      items: ref.read(sourcesListProvider).map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedSource = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TallyTapTheme.primaryMint,
                foregroundColor: TallyTapTheme.obsidianBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final allTx = ref.read(transactionListProvider);
                final isSynth = allTx.any((t) => t.id == record.id && t.wasFinishLater);
                ExpenseTransaction? synthTx;
                if (isSynth) {
                  synthTx = allTx.firstWhere((t) => t.id == record.id);
                }

                if (isSynth && synthTx != null) {
                  if (recordTimelineTx) {
                    final updatedTx = ExpenseTransaction(
                      id: synthTx.id,
                      amount: synthTx.amount,
                      merchant: synthTx.merchant,
                      date: synthTx.date,
                      paymentMethod: selectedSource, // Set to selected source
                      category: synthTx.category,
                      notes: synthTx.notes,
                      paidTo: synthTx.paidTo,
                      needsVerification: false, // Mark completed
                      reminderDate: null,
                      wasFinishLater: synthTx.wasFinishLater,
                      hideFromLedger: synthTx.hideFromLedger,
                      groupId: synthTx.groupId,
                    );
                    await ref.read(transactionListProvider.notifier).updateTransaction(updatedTx);
                    NotificationService.cancelNotification(synthTx.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction completed successfully'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  } else {
                    final updatedTx = ExpenseTransaction(
                      id: synthTx.id,
                      amount: synthTx.amount,
                      merchant: synthTx.merchant,
                      date: synthTx.date,
                      paymentMethod: synthTx.paymentMethod,
                      category: synthTx.category,
                      notes: synthTx.notes,
                      paidTo: synthTx.paidTo,
                      needsVerification: synthTx.needsVerification, // remains true
                      reminderDate: synthTx.reminderDate,
                      wasFinishLater: synthTx.wasFinishLater,
                      hideFromLedger: true, // hide from ledger
                      groupId: synthTx.groupId,
                    );
                    await ref.read(transactionListProvider.notifier).updateTransaction(updatedTx);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction hidden from ledger'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                } else {
                  await ref.read(outstandingListProvider.notifier).settleRecord(
                        record.id,
                        recordTimelineTx: recordTimelineTx,
                        paymentMethod: recordTimelineTx ? selectedSource : null,
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Settled ${record.personName}\'s log!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Settle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Settle Net Balance Dialog
  void _showSettleNetDialog(BuildContext context, String person, double netAmount, List<OutstandingRecord> activeItems) {
    final allTx = ref.read(transactionListProvider);
    final synthesizedItems = activeItems.where((r) => allTx.any((t) => t.id == r.id && t.wasFinishLater)).toList();
    final manualItems = activeItems.where((r) => !allTx.any((t) => t.id == r.id && t.wasFinishLater)).toList();

    bool onlySynthesized = synthesizedItems.isNotEmpty && manualItems.isEmpty;
    bool mixed = synthesizedItems.isNotEmpty && manualItems.isNotEmpty;

    bool recordTimelineTx = true;
    String selectedSource = 'Cash';

    // Auto-fetch source if only one synthesized record is being settled
    if (onlySynthesized && synthesizedItems.length == 1) {
      final synthTx = allTx.firstWhere((t) => t.id == synthesizedItems.first.id);
      final sources = ref.read(sourcesListProvider);
      if (synthTx.paymentMethod.isNotEmpty && sources.contains(synthTx.paymentMethod)) {
        selectedSource = synthTx.paymentMethod;
      } else if (!sources.contains(selectedSource) && sources.isNotEmpty) {
        selectedSource = sources.first;
      }
    } else {
      final sources = ref.read(sourcesListProvider);
      if (!sources.contains(selectedSource) && sources.isNotEmpty) {
        selectedSource = sources.first;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: TallyTapTheme.obsidianCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: TallyTapTheme.borderGreen, width: 1.5),
          ),
          title: const Text(
            'Settle Net Account',
            style: TextStyle(color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                netAmount > 0
                    ? 'Confirm Rahul paid you the net outstanding balance of ${netAmount.abs().toStringAsFixed(0)} INR.'
                        .replaceAll('Rahul', person)
                    : 'Confirm you paid Rahul the net outstanding balance of ${netAmount.abs().toStringAsFixed(0)} INR.'
                        .replaceAll('Rahul', person),
                style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: recordTimelineTx,
                    activeColor: TallyTapTheme.primaryMint,
                    onChanged: (val) {
                      setStateDialog(() {
                        recordTimelineTx = val ?? true;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      onlySynthesized 
                          ? 'Complete transaction(s) in timeline' 
                          : mixed 
                              ? 'Record manual settlement & complete pending'
                              : 'Record Settlement in Timeline',
                      style: const TextStyle(color: TallyTapTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (recordTimelineTx) ...[
                const SizedBox(height: 12),
                const Text(
                  'SELECT PAYMENT SOURCE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: TallyTapTheme.obsidianBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TallyTapTheme.borderGreen),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSource,
                      dropdownColor: TallyTapTheme.obsidianCard,
                      isExpanded: true,
                      style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                      items: ref.read(sourcesListProvider).map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedSource = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TallyTapTheme.primaryMint,
                foregroundColor: TallyTapTheme.obsidianBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                // Settle synthesized logs for this person
                for (final record in synthesizedItems) {
                  final synthTx = allTx.firstWhere((t) => t.id == record.id);
                  if (recordTimelineTx) {
                    final updatedTx = ExpenseTransaction(
                      id: synthTx.id,
                      amount: synthTx.amount,
                      merchant: synthTx.merchant,
                      date: synthTx.date,
                      paymentMethod: selectedSource, // Update payment source
                      category: synthTx.category,
                      notes: synthTx.notes,
                      paidTo: synthTx.paidTo,
                      needsVerification: false,
                      reminderDate: null,
                      wasFinishLater: synthTx.wasFinishLater,
                      hideFromLedger: synthTx.hideFromLedger,
                      groupId: synthTx.groupId,
                    );
                    await ref.read(transactionListProvider.notifier).updateTransaction(updatedTx);
                    NotificationService.cancelNotification(synthTx.id);
                  } else {
                    final updatedTx = ExpenseTransaction(
                      id: synthTx.id,
                      amount: synthTx.amount,
                      merchant: synthTx.merchant,
                      date: synthTx.date,
                      paymentMethod: synthTx.paymentMethod,
                      category: synthTx.category,
                      notes: synthTx.notes,
                      paidTo: synthTx.paidTo,
                      needsVerification: synthTx.needsVerification,
                      reminderDate: synthTx.reminderDate,
                      wasFinishLater: synthTx.wasFinishLater,
                      hideFromLedger: true,
                      groupId: synthTx.groupId,
                    );
                    await ref.read(transactionListProvider.notifier).updateTransaction(updatedTx);
                  }
                }

                // Settle manual logs for this person
                for (final record in manualItems) {
                  await ref.read(outstandingListProvider.notifier).settleRecord(record.id, recordTimelineTx: false);
                }

                // If timeline tracking was requested and there are manual items, log the NET settlement as a single entry
                if (recordTimelineTx && manualItems.isNotEmpty) {
                  // Calculate net amount strictly for manual items to prevent double accounting
                  double manualNetAmount = 0;
                  for (final record in manualItems) {
                     manualNetAmount += record.isLent ? record.amount : -record.amount;
                  }
                  
                  if (manualNetAmount != 0) {
                    final isIncome = manualNetAmount > 0;
                    final txId = DateTime.now().millisecondsSinceEpoch.toString();
                    
                    final netTx = ExpenseTransaction(
                      id: txId,
                      amount: manualNetAmount.abs(),
                      merchant: person,
                      date: DateTime.now(),
                      paymentMethod: selectedSource,
                      category: isIncome ? 'Income' : 'Other',
                      notes: isIncome 
                          ? 'Settled net balance: $person paid back'
                          : 'Settled net balance: Paid back $person',
                      paidTo: !isIncome ? person : '',
                    );

                    await ref.read(transactionListProvider.notifier).addTransaction(netTx);
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Net outstanding for $person settled!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Settle Net', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Add Bottom Sheet
  void _showAddIOUSheet(BuildContext context, List<String> availableSources) {
    bool isLent = true;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    
    bool recordTimelineTx = false;
    String selectedSource = 'Cash';

    // Get predictive names suggestions
    final existingRecords = ref.read(outstandingListProvider);
    final suggestions = existingRecords.map((e) => e.personName).toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TallyTapTheme.borderGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Add IOU Record',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: TallyTapTheme.textLight, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 20),

                // Lent vs Borrowed Switcher
                Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF091210),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TallyTapTheme.borderGreen),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setSheetState(() {
                              isLent = true;
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isLent ? TallyTapTheme.primaryMint : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'THEY OWE ME (LENT)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isLent ? TallyTapTheme.obsidianBg : TallyTapTheme.textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setSheetState(() {
                              isLent = false;
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !isLent ? const Color(0xFFF59E0B) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'I OWE THEM (BORROWED)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: !isLent ? TallyTapTheme.obsidianBg : TallyTapTheme.textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Friend's Name Field
                const Text(
                  'FRIEND\'S NAME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return suggestions.where((name) {
                      return name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Sync autocomplete controller with our local controller
                    controller.addListener(() {
                      nameController.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Who is this with?',
                        hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                        filled: true,
                        fillColor: TallyTapTheme.obsidianCard,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isLent ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B)),
                        ),
                      ),
                    );
                  },
                  onSelected: (String selection) {
                    nameController.text = selection;
                  },
                ),
                const SizedBox(height: 16),

                // Amount and Notes Row
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AMOUNT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                              filled: true,
                              fillColor: TallyTapTheme.obsidianCard,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: isLent ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NOTES / DESCRIPTION',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: notesController,
                            style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'e.g. Dinner, Rent split...',
                              hintStyle: const TextStyle(color: TallyTapTheme.textGray),
                              filled: true,
                              fillColor: TallyTapTheme.obsidianCard,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: TallyTapTheme.borderGreen),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: isLent ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Direct Timeline Toggle
                Row(
                  children: [
                    Checkbox(
                      value: recordTimelineTx,
                      activeColor: isLent ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B),
                      onChanged: (val) {
                        setSheetState(() {
                          recordTimelineTx = val ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Record in Wallet Timeline',
                        style: TextStyle(color: TallyTapTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (recordTimelineTx) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'SELECT PAYMENT SOURCE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: TallyTapTheme.textGray, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TallyTapTheme.obsidianCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TallyTapTheme.borderGreen),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSource,
                        dropdownColor: TallyTapTheme.obsidianCard,
                        isExpanded: true,
                        style: const TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold),
                        items: availableSources.map((s) {
                          return DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              selectedSource = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Save Action Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLent ? TallyTapTheme.primaryMint : const Color(0xFFF59E0B),
                    foregroundColor: TallyTapTheme.obsidianBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final notes = notesController.text.trim();
                    final amt = double.tryParse(amountController.text) ?? 0.0;

                    if (name.isEmpty || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid name and amount.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final newRecord = OutstandingRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      personName: name,
                      amount: amt,
                      notes: notes,
                      date: DateTime.now(),
                      isLent: isLent,
                    );

                    await ref.read(outstandingListProvider.notifier).addRecord(
                          newRecord,
                          recordTimelineTx: recordTimelineTx,
                          paymentMethod: recordTimelineTx ? selectedSource : null,
                        );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isLent ? 'Lent log saved successfully!' : 'Borrowed log saved successfully!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Save Log',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(kPrefTutorialLedger) ?? false;
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
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialLedger);
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).markCompleted(kPrefTutorialLedger);
        return true;
      },
    );
    tutorialCoachMark?.show(context: context);
  }

  Widget _buildTutorialContent(TutorialCoachMarkController controller, String title, String description) {
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
            child: const Text("Next"),
          ),
        ),
      ],
    );
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    targets.add(TargetFocus(
      identify: "TargetWhoOwesMe",
      keyTarget: TutorialService.ledgerWhoOwesMeKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Pending Receivables", "This shows money others owe you. Note: Transactions marked as 'Finish later' (pending) are automatically logged in this ledger. You can finish them here or from the transaction itself."),
        ),
      ],
    ));

    targets.add(TargetFocus(
      identify: "TargetWhoIOwe",
      keyTarget: TutorialService.ledgerWhoIOweKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) => _buildTutorialContent(controller, "Your Debts", "This shows money you owe. Tap the (+) button below to manually log new IOUs, or tap an existing person's name to settle up balances."),
        ),
      ],
    ));

    return targets;
  }
}

