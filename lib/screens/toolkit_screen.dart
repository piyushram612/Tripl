import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/category_provider.dart';
import '../providers/source_provider.dart';
import '../services/platform_service.dart';
import '../services/notification_service.dart';
import '../services/csv_service.dart';
import '../services/transaction_service.dart';
import '../models/transaction_model.dart';
import 'calibration_screen.dart';
import 'sheets/manage_categories_sheet.dart';
import 'sheets/manage_sources_sheet.dart';
import 'sheets/manage_currency_sheet.dart';
import 'sheets/manage_profile_sheet.dart';
import 'recurring_transactions_list_screen.dart';
import 'tools/expense_splitter_screen.dart';
import 'tools/tip_calculator_screen.dart';
import 'tools/outstanding_ledger_screen.dart';
import '../providers/customization_provider.dart';
import 'sheets/snooze_duration_sheet.dart';
import '../providers/tutorial_provider.dart';
import '../services/tutorial_service.dart';
import '../providers/biometric_provider.dart';
import 'package:share_plus/share_plus.dart';


class ToolkitScreen extends ConsumerWidget {
  const ToolkitScreen({super.key});

  void _showManageCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManageCategoriesSheet(),
    );
  }

  void _showManageSourcesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageSourcesSheet(),
    );
  }

  void _showManageCurrencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageCurrencySheet(),
    );
  }

  void _showManageProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageProfileSheet(),
    );
  }

  void _showCalibrationScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CalibrationScreen(fromSettings: true),
      ),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
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
                    child: const Icon(Icons.bug_report_rounded, color: TallyTapTheme.primaryMint, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help & Feedback',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TallyTapTheme.textLight,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Report a bug or share your suggestions with us',
                          style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Piyush Contact Row
              const Text(
                'CONTACT PIYUSH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TallyTapTheme.primaryMint,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        PlatformService.sendEmail('piyushram.edu@gmail.com', 'TallyTap Feedback');
                      },
                      leading: const Icon(Icons.mail_rounded, color: TallyTapTheme.primaryMint, size: 18),
                      title: const Text('Email', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                      tileColor: const Color(0xFF141F1B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ListTile(
                      onTap: () async {
                        Navigator.pop(context);
                        await Clipboard.setData(const ClipboardData(text: 'piyushram.edu@gmail.com'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Piyush's email copied!"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: TallyTapTheme.primaryMint,
                            ),
                          );
                        }
                      },
                      leading: const Icon(Icons.copy_rounded, color: TallyTapTheme.primaryMint, size: 18),
                      title: const Text('Copy Address', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                      tileColor: const Color(0xFF141F1B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Sushanth Contact Row
              const Text(
                'CONTACT SUSHANTH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TallyTapTheme.primaryMint,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        PlatformService.sendEmail('aurus7900@gmail.com', 'TallyTap Feedback');
                      },
                      leading: const Icon(Icons.mail_rounded, color: TallyTapTheme.primaryMint, size: 18),
                      title: const Text('Email', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                      tileColor: const Color(0xFF141F1B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ListTile(
                      onTap: () async {
                        Navigator.pop(context);
                        await Clipboard.setData(const ClipboardData(text: 'aurus7900@gmail.com'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Sushanth's email copied!"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: TallyTapTheme.primaryMint,
                            ),
                          );
                        }
                      },
                      leading: const Icon(Icons.copy_rounded, color: TallyTapTheme.primaryMint, size: 18),
                      title: const Text('Copy Address', style: TextStyle(color: TallyTapTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                      tileColor: const Color(0xFF141F1B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1B17),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
        ),
        child: Icon(icon, color: TallyTapTheme.primaryMint, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: TallyTapTheme.textGray),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final transactions = ref.read(transactionListProvider);
      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions to export yet! Add some transactions first.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      // Show a loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: TallyTapTheme.primaryMint),
        ),
      );

      await CsvService.exportTransactions(transactions);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV backup generated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: TallyTapTheme.primaryMint,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    try {
      final rawData = await CsvService.pickAndParseRawCsv();

      if (rawData.rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The selected CSV file contains no data rows.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.amber,
            ),
          );
        }
        return;
      }

      // Check if it's already using Tripl's exact headers
      final headersLower = rawData.headers.map((h) => h.toLowerCase().trim()).toList();
      final bool hasExactRequired = headersLower.contains('amount') &&
                                    headersLower.contains('merchant') &&
                                    headersLower.contains('date');

      if (hasExactRequired) {
        final idIndex = headersLower.indexOf('id');
        final amountIndex = headersLower.indexOf('amount');
        final merchantIndex = headersLower.indexOf('merchant');
        final dateIndex = headersLower.indexOf('date');
        final paymentMethodIndex = headersLower.indexOf('paymentmethod');
        final categoryIndex = headersLower.indexOf('category');
        final notesIndex = headersLower.indexOf('notes');
        final paidToIndex = headersLower.indexOf('paidto');

        final Map<String, int> mapping = {
          'id': idIndex,
          'amount': amountIndex,
          'merchant': merchantIndex,
          'date': dateIndex,
          'category': categoryIndex,
          'paymentMethod': paymentMethodIndex,
          'notes': notesIndex,
          'paidTo': paidToIndex,
        };

        final parsedTransactions = CsvService.parseCsvWithMapping(rawData.rows, mapping);
        if (context.mounted) {
          _showAccountMapperSheet(context, ref, parsedTransactions);
        }
      } else {
        if (context.mounted) {
          _showColumnMapperSheet(context, ref, rawData);
        }
      }
    } catch (e) {
      if (context.mounted && e.toString() != 'Exception: No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString().replaceAll('Exception: ', '')}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showColumnMapperSheet(
    BuildContext context,
    WidgetRef ref,
    RawCsvData rawData,
  ) {
    int amountIdx = CsvService.findBestHeaderMatch(rawData.headers, ['amount', 'value', 'cost', 'sum', 'price', 'total', 'charge', 'spent', 'outflow']);
    int merchantIdx = CsvService.findBestHeaderMatch(rawData.headers, ['merchant', 'payee', 'store', 'description', 'title', 'name', 'vendor', 'narrative']);
    int dateIdx = CsvService.findBestHeaderMatch(rawData.headers, ['date', 'time', 'timestamp', 'created', 'created_at', 'transaction date']);
    int categoryIdx = CsvService.findBestHeaderMatch(rawData.headers, ['category', 'type', 'tag', 'group']);
    int paymentIdx = CsvService.findBestHeaderMatch(rawData.headers, ['paymentmethod', 'payment', 'method', 'source', 'account', 'card', 'wallet']);
    int notesIdx = CsvService.findBestHeaderMatch(rawData.headers, ['notes', 'note', 'comment', 'memo', 'remarks', 'reference']);
    int paidToIdx = CsvService.findBestHeaderMatch(rawData.headers, ['paid_to', 'paidto', 'recipient', 'to']);
    int isIncomeIdx = CsvService.findBestHeaderMatch(rawData.headers, ['is_income', 'isincome', 'income', 'type', 'transaction_type', 'transactiontype']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (stateCtx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(stateCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                          child: const Icon(Icons.splitscreen_rounded, color: TallyTapTheme.primaryMint, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Map CSV Columns',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: TallyTapTheme.textLight,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Align external app headers with Tripl fields',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Tripl has auto-detected closely matching columns from your file. Please verify and fill in the required mappings (*) to parse the transactions correctly.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    _buildMappingDropdown(
                      label: 'Amount Column',
                      subtitle: 'Total cost of the transaction',
                      currentValue: amountIdx,
                      headers: rawData.headers,
                      isRequired: true,
                      onChanged: (val) => setState(() => amountIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Merchant Column',
                      subtitle: 'Store, payee, or description of transaction',
                      currentValue: merchantIdx,
                      headers: rawData.headers,
                      isRequired: true,
                      onChanged: (val) => setState(() => merchantIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Date Column',
                      subtitle: 'When the transaction happened',
                      currentValue: dateIdx,
                      headers: rawData.headers,
                      isRequired: true,
                      onChanged: (val) => setState(() => dateIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Category Column',
                      subtitle: 'Groceries, entertainment, bills, etc.',
                      currentValue: categoryIdx,
                      headers: rawData.headers,
                      isRequired: false,
                      onChanged: (val) => setState(() => categoryIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Is Income Column (Optional)',
                      subtitle: 'Header indicating if transaction is income (true/false, inflow/outflow, etc.)',
                      currentValue: isIncomeIdx,
                      headers: rawData.headers,
                      isRequired: false,
                      onChanged: (val) => setState(() => isIncomeIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Payment Method Column',
                      subtitle: 'Cash, Credit Card, Bank, account name, etc.',
                      currentValue: paymentIdx,
                      headers: rawData.headers,
                      isRequired: false,
                      onChanged: (val) => setState(() => paymentIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Notes Column',
                      subtitle: 'Extra memo, description, or custom comments',
                      currentValue: notesIdx,
                      headers: rawData.headers,
                      isRequired: false,
                      onChanged: (val) => setState(() => notesIdx = val ?? -1),
                    ),
                    _buildMappingDropdown(
                      label: 'Paid To Column',
                      subtitle: 'Person or entity that received payment',
                      currentValue: paidToIdx,
                      headers: rawData.headers,
                      isRequired: false,
                      onChanged: (val) => setState(() => paidToIdx = val ?? -1),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () {
                        if (amountIdx == -1 || merchantIdx == -1 || dateIdx == -1) {
                          ScaffoldMessenger.of(stateCtx).showSnackBar(
                            const SnackBar(
                              content: Text('Please map all required columns (Amount, Merchant, Date)'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.amber,
                            ),
                          );
                          return;
                        }

                        final Map<String, int> mapping = {
                          'amount': amountIdx,
                          'merchant': merchantIdx,
                          'date': dateIdx,
                          'category': categoryIdx,
                          'paymentMethod': paymentIdx,
                          'notes': notesIdx,
                          'paidTo': paidToIdx,
                          'isIncome': isIncomeIdx,
                        };

                        final parsedTransactions = CsvService.parseCsvWithMapping(rawData.rows, mapping);

                        Navigator.pop(ctx);
                        _showAccountMapperSheet(context, ref, parsedTransactions);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TallyTapTheme.primaryMint,
                        foregroundColor: TallyTapTheme.obsidianBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Parse Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMappingDropdown({
    required String label,
    required String subtitle,
    required int currentValue,
    required List<String> headers,
    required bool isRequired,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: TallyTapTheme.textGray),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141F1B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TallyTapTheme.borderGreen.withOpacity(0.5), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentValue == -1 ? null : currentValue,
              hint: Text(
                isRequired ? 'Select Column (Required)' : 'None (Use Default)',
                style: TextStyle(fontSize: 13, color: isRequired ? Colors.amber.withOpacity(0.7) : TallyTapTheme.textGray),
              ),
              dropdownColor: TallyTapTheme.obsidianBg,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: TallyTapTheme.primaryMint),
              items: [
                if (!isRequired)
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('None (Use Default)', style: TextStyle(fontSize: 13, color: TallyTapTheme.textGray)),
                  ),
                ...List.generate(headers.length, (index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      'Column ${index + 1}: ${headers[index]}',
                      style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight),
                    ),
                  );
                }),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showAccountMapperSheet(
    BuildContext context,
    WidgetRef ref,
    List<ExpenseTransaction> parsedTransactions,
  ) {
    final csvPaymentMethods = parsedTransactions
        .map((tx) => tx.paymentMethod.trim())
        .where((method) => method.isNotEmpty)
        .toSet()
        .toList();

    // If there are no payment methods in the parsed transactions, go straight to options dialog
    if (csvPaymentMethods.isEmpty) {
      _showImportOptionsDialog(context, ref, parsedTransactions);
      return;
    }

    final existingSources = ref.read(sourcesListProvider);
    final Map<String, String> selectedMappings = {};
    for (final src in csvPaymentMethods) {
      final bestMatch = existingSources.firstWhere(
        (s) => s.toLowerCase().trim() == src.toLowerCase(),
        orElse: () => '',
      );
      if (bestMatch.isNotEmpty) {
        selectedMappings[src] = bestMatch;
      } else {
        selectedMappings[src] = '__CREATE_NEW__';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (stateCtx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(stateCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                          child: const Icon(Icons.account_balance_outlined, color: TallyTapTheme.primaryMint, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Map Payment Accounts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: TallyTapTheme.textLight,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Align CSV bank accounts with Tripl accounts',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Tripl detected these payment accounts in your CSV file. You can map them to existing accounts in the app, or create them freshly.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: csvPaymentMethods.length,
                        itemBuilder: (listCtx, idx) {
                          final src = csvPaymentMethods[idx];
                          final mappedVal = selectedMappings[src] ?? '__CREATE_NEW__';
                          final isNew = mappedVal == '__CREATE_NEW__';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141F1B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isNew 
                                    ? TallyTapTheme.primaryMint.withOpacity(0.2) 
                                    : TallyTapTheme.borderGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.credit_card_rounded, color: TallyTapTheme.textGray, size: 16),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              src,
                                              style: const TextStyle(
                                                fontSize: 14, 
                                                fontWeight: FontWeight.bold, 
                                                color: TallyTapTheme.textLight
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isNew 
                                            ? TallyTapTheme.primaryMint.withOpacity(0.1) 
                                            : const Color(0xFF0F1B17),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isNew ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        isNew ? 'CREATE FRESH' : 'EXISTING MATCH',
                                        style: TextStyle(
                                          fontSize: 8, 
                                          fontWeight: FontWeight.w800, 
                                          color: isNew ? TallyTapTheme.primaryMint : TallyTapTheme.textGray
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1B17),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: TallyTapTheme.borderGreen.withOpacity(0.5), width: 1),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: mappedVal,
                                      dropdownColor: TallyTapTheme.obsidianBg,
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, color: TallyTapTheme.primaryMint),
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: '__CREATE_NEW__',
                                          child: Text(
                                            'Create New Account: "$src"',
                                            style: const TextStyle(fontSize: 13, color: TallyTapTheme.primaryMint, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ...existingSources.map((ext) {
                                          return DropdownMenuItem<String>(
                                            value: ext,
                                            child: Text(
                                              'Map to Existing: $ext',
                                              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight),
                                            ),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            selectedMappings[src] = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    ElevatedButton(
                      onPressed: () {
                        final List<String> newSourcesToCreate = [];
                        final mappedTransactions = parsedTransactions.map((tx) {
                          final trimmedMethod = tx.paymentMethod.trim();
                          if (trimmedMethod.isEmpty) return tx;

                          final mappedVal = selectedMappings[trimmedMethod];
                          if (mappedVal != null && mappedVal != '__CREATE_NEW__') {
                            return tx.copyWith(paymentMethod: mappedVal);
                          } else if (mappedVal == '__CREATE_NEW__') {
                            if (!newSourcesToCreate.contains(trimmedMethod)) {
                              newSourcesToCreate.add(trimmedMethod);
                            }
                          }
                          return tx;
                        }).toList();

                        Navigator.pop(ctx);
                        _showImportOptionsDialog(
                          context, 
                          ref, 
                          mappedTransactions, 
                          newSourcesToCreate: newSourcesToCreate
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TallyTapTheme.primaryMint,
                        foregroundColor: TallyTapTheme.obsidianBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Confirm Mappings & Next', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImportOptionsDialog(
    BuildContext context,
    WidgetRef ref,
    List<ExpenseTransaction> importedTransactions, {
    List<String> newSourcesToCreate = const [],
  }) {
    final double totalAmount = importedTransactions.fold(0.0, (sum, item) => sum + item.amount);
    final dates = importedTransactions.map((t) => t.date).toList()..sort();
    final dateRangeStr = dates.isNotEmpty
        ? '${dates.first.day}/${dates.first.month}/${dates.first.year} - ${dates.last.day}/${dates.last.month}/${dates.last.year}'
        : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                    child: const Icon(Icons.file_download_rounded, color: TallyTapTheme.primaryMint, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm CSV Import',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TallyTapTheme.textLight,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select how you want to import this data',
                          style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Preview statistics card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141F1B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TallyTapTheme.borderGreen.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  children: [
                    _buildPreviewRow('Transactions Found', '${importedTransactions.length} items'),
                    const SizedBox(height: 8),
                    _buildPreviewRow('Total Value', '\$${totalAmount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildPreviewRow('Date Range', dateRangeStr),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Button 1: Merge
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  // Dynamic new sources registration
                  for (final source in newSourcesToCreate) {
                    await ref.read(sourcesListProvider.notifier).addSource(source);
                  }
                  // Dynamic new categories registration
                  final existingCategories = ref.read(categoriesListProvider);
                  final existingLower = existingCategories.map((c) => c.toLowerCase()).toSet();
                  for (final tx in importedTransactions) {
                    final normalizedCat = tx.category.trim();
                    if (normalizedCat.isNotEmpty && !existingLower.contains(normalizedCat.toLowerCase())) {
                      await ref.read(categoriesListProvider.notifier).addCategory(normalizedCat);
                      existingLower.add(normalizedCat.toLowerCase());
                    }
                  }
                  await ref.read(transactionListProvider.notifier).importTransactions(importedTransactions, overwrite: false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully merged ${importedTransactions.length} transactions!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: TallyTapTheme.primaryMint,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TallyTapTheme.primaryMint,
                  foregroundColor: TallyTapTheme.obsidianBg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Merge with Existing Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),

              // Button 2: Overwrite with Warning!
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Double confirmation for overwrite!
                  showDialog(
                    context: context,
                    builder: (doubleConfirmCtx) {
                      return AlertDialog(
                        backgroundColor: TallyTapTheme.obsidianBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Danger: Overwrite Database?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        content: const Text(
                          'This will permanently delete all your existing transactions and replace them with the CSV transactions. This action cannot be undone.\n\nAre you absolutely sure?',
                          style: TextStyle(color: TallyTapTheme.textLight, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(doubleConfirmCtx),
                            child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(doubleConfirmCtx);
                              // Dynamic new sources registration
                              for (final source in newSourcesToCreate) {
                                await ref.read(sourcesListProvider.notifier).addSource(source);
                              }
                              // Dynamic new categories registration
                              final existingCategories = ref.read(categoriesListProvider);
                              final existingLower = existingCategories.map((c) => c.toLowerCase()).toSet();
                              for (final tx in importedTransactions) {
                                final normalizedCat = tx.category.trim();
                                if (normalizedCat.isNotEmpty && !existingLower.contains(normalizedCat.toLowerCase())) {
                                  await ref.read(categoriesListProvider.notifier).addCategory(normalizedCat);
                                  existingLower.add(normalizedCat.toLowerCase());
                                }
                              }
                              await ref.read(transactionListProvider.notifier).importTransactions(importedTransactions, overwrite: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Successfully imported transactions (database overwritten)!'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Yes, Overwrite'),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Overwrite Existing Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleDeleteAllTransactions(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (confirmCtx) {
        return AlertDialog(
          backgroundColor: TallyTapTheme.obsidianBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          title: const Text(
            'Delete All Transactions?', 
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          content: const Text(
            'This will permanently erase all transaction records from your device. This action is irreversible.\n\nAre you sure you want to proceed?',
            style: TextStyle(color: TallyTapTheme.textLight, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(confirmCtx);
                showDialog(
                  context: context,
                  builder: (doubleConfirmCtx) {
                    return AlertDialog(
                      backgroundColor: TallyTapTheme.obsidianBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.redAccent, width: 2.0),
                      ),
                      title: const Text(
                        'WARNING: FINAL WARNING', 
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
                      ),
                      content: const Text(
                        'This is your absolute final warning. All transactions will be deleted forever.\n\nAre you sure you want to delete everything?',
                        style: TextStyle(color: TallyTapTheme.textLight, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(doubleConfirmCtx),
                          child: const Text('Cancel', style: TextStyle(color: TallyTapTheme.textGray)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(doubleConfirmCtx);
                            await ref.read(transactionListProvider.notifier).clearTransactions();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All transactions deleted successfully.'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Yes, Delete Everything'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: TallyTapTheme.textGray)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight)),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bottomPadding = 72.0 + MediaQuery.of(context).padding.bottom + (MediaQuery.of(context).padding.bottom > 0 ? 10.0 : 20.0) + 24.0;

    final backTapEnabled = ref.watch(backTapEnabledProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Toolkit',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: TallyTapTheme.textLight,
              ),
            ),
            const SizedBox(height: 24),

            // Double Back Tap Toggle Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HARDWARE INTERACTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1B17),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            color: TallyTapTheme.primaryMint,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Triple Back Tap',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Triple tap the back of your phone to trigger',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: backTapEnabled,
                          activeColor: TallyTapTheme.primaryMint,
                          onChanged: (val) {
                            ref.read(backTapEnabledProvider.notifier).toggle(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  val
                                      ? "Back Tap Listener Service Started!"
                                      : "Back Tap Listener Service Stopped.",
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 32),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1B17),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.vibration_rounded,
                            color: TallyTapTheme.primaryMint,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Haptic Feedback',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Vibrate when triple tap is detected',
                                style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: ref.watch(hapticsEnabledProvider),
                          activeColor: TallyTapTheme.primaryMint,
                          onChanged: (val) {
                            ref.read(hapticsEnabledProvider.notifier).toggle(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 32),
                    // Manual Test CTA Button
                    ElevatedButton(
                      onPressed: () => PlatformService.showPopup(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TallyTapTheme.primaryMint,
                        foregroundColor: TallyTapTheme.obsidianBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Test Quick Popup',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Re-calibrate button
                    OutlinedButton(
                      onPressed: () => _showCalibrationScreen(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TallyTapTheme.primaryMint,
                        side: BorderSide(
                          color: TallyTapTheme.primaryMint.withOpacity(0.5),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Re-calibrate Triple Tap',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card B: Data Configuration
            Card(
              key: TutorialService.toolkitDataConfigKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'DATA CONFIGURATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.person_rounded,
                      title: 'Customize Profile',
                      subtitle: 'Change your dashboard username',
                      onTap: () => _showManageProfileSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.category_rounded,
                      title: 'Manage Categories',
                      subtitle: 'Add or remove custom expense categories',
                      onTap: () => _showManageCategoriesSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Manage Payment Sources',
                      subtitle: 'Configure custom cash or bank accounts',
                      onTap: () => _showManageSourcesSheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.monetization_on_rounded,
                      title: 'Manage Currency',
                      subtitle: 'Select your preferred global currency',
                      onTap: () => _showManageCurrencySheet(context),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.autorenew_rounded,
                      title: 'Manage Recurring Payments',
                      subtitle: 'View and edit your automated transactions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RecurringTransactionsListScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card: Tools & Calculators
            Card(
              key: TutorialService.toolkitToolsKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'TOOLS & CALCULATORS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.splitscreen_rounded,
                      title: 'Expense Splitter',
                      subtitle: 'Split bills equally between friends',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ExpenseSplitterScreen()),
                        );
                      },
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.monetization_on_outlined,
                      title: 'Tip Calculator',
                      subtitle: 'Calculate tip percentages and splits',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TipCalculatorScreen()),
                        );
                      },
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.handshake_outlined,
                      title: 'Outstanding Ledger',
                      subtitle: 'Track who owes you money & who you owe',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OutstandingLedgerScreen()),
                        );
                      },
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    ],
                ),
              ),
            ),
            const SizedBox(height: 20),
                // Card: Help & Support (Share & Feedback)
                Card(
                  key: TutorialService.toolkitShareKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                          child: Text(
                            'HELP & SUPPORT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: TallyTapTheme.primaryMint,
                            ),
                          ),
                        ),
                        _buildSettingsTile(
                          icon: Icons.bug_report_rounded,
                          title: 'Report a Bug / Feedback',
                          subtitle: 'Provide feedback or report issues',
                          onTap: () => _showFeedbackSheet(context),
                        ),
                        const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                        _buildSettingsTile(
                          icon: Icons.share_rounded,
                          title: 'Share Tripl',
                          subtitle: 'Share the play store link of the app',
                          onTap: () {
                            Share.share(
                              'Check out this frictionless expense logging app! https://play.google.com/store/apps/details?id=com.waypointlattice.tripl',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

            // Card B2: Notifications
            Card(
              key: TutorialService.toolkitNotificationsKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'NOTIFICATIONS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.snooze_rounded,
                      title: 'Remind Later Duration',
                      subtitle: 'Current: ${ref.watch(snoozeDurationProvider)} minutes',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: TallyTapTheme.obsidianBg,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (context) => const SnoozeDurationSheet(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card B3: Security
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 12.0),
                      child: Text(
                        'SECURITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1B17),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                            ),
                            child: const Icon(
                              Icons.fingerprint_rounded,
                              color: TallyTapTheme.primaryMint,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'App Lock',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Biometric or passcode unlock on start',
                                  style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: ref.watch(biometricsEnabledProvider),
                            activeColor: TallyTapTheme.primaryMint,
                            onChanged: (val) async {
                              final success = await ref.read(biometricsEnabledProvider.notifier).toggle(val);
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to authenticate or device lock not setup.'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card C: Export & Backup
            Card(
              key: TutorialService.toolkitExportKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'EXPORT & BACKUP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.file_upload_rounded,
                      title: 'Export Data to CSV',
                      subtitle: 'Export your private transaction log to a CSV file',
                      onTap: () => _handleExport(context, ref),
                    ),
                    const Divider(color: TallyTapTheme.borderGreen, height: 1, indent: 20, endIndent: 20),
                    _buildSettingsTile(
                      icon: Icons.file_download_rounded,
                      title: 'Import Data from CSV',
                      subtitle: 'Restore or merge transactions from a CSV file',
                      onTap: () => _handleImport(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Shortcut Guide Card
            Card(
              key: TutorialService.toolkitShortcutKey,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SHORTCUT GUIDE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TallyTapTheme.primaryMint,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '1. Static Shortcuts',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Long press TallyTap icon on your phone launcher, select "Quick Add" to trigger instant overlays under 100ms.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.3),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '2. Quick Actions',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Long press the + floating action button on any screen to reveal more transaction options.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.3),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '3. Home Layout Editing',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Long press any widget on the Home page to enter Edit Mode. From there, you can drag and drop cards to reorder your personalized dashboard layout.',
                      style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card: App Guides
            Card(
              key: TutorialService.toolkitReplayKey,
              color: TallyTapTheme.obsidianCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: TallyTapTheme.borderGreen.withOpacity(0.5), width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'APP GUIDES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: TallyTapTheme.primaryMint,
                        ),
                      ),
                    ),
                    ListTile(
                      onTap: () {
                        ref.read(tutorialProvider.notifier).resetAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('App guides reset. Redirecting to tour...'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: TallyTapTheme.primaryMint,
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1B17),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: TallyTapTheme.primaryMint, size: 20),
                      ),
                      title: const Text(
                        'Reset All App Guides',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                      ),
                      subtitle: const Text(
                        'Reset the main tour and all contextual tutorials',
                        style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: TallyTapTheme.textGray),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card D: Danger Zone
            Card(
              key: TutorialService.toolkitDangerKey,
              color: const Color(0xFF1F1212),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        'DANGER ZONE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    ListTile(
                      onTap: () => _handleDeleteAllTransactions(context, ref),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C1616),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 0.5),
                        ),
                        child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                      ),
                      title: const Text(
                        'Delete All Transactions',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                      subtitle: const Text(
                        'Permanently erase all transaction data from this device',
                        style: TextStyle(fontSize: 12, color: TallyTapTheme.textGray),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }
}
