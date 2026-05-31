import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

class RawCsvData {
  final List<String> headers;
  final List<List<String>> rows;

  RawCsvData({required this.headers, required this.rows});
}

class CsvService {
  /// Generate CSV string from a list of transactions
  static String generateCsv(List<ExpenseTransaction> transactions) {
    final List<String> headers = [
      'ID',
      'Amount',
      'Merchant',
      'Date',
      'PaymentMethod',
      'Category',
      'Notes',
      'PaidTo',
      'NeedsVerification',
      'ReminderDate',
      'GroupId'
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final tx in transactions) {
      final List<String> fields = [
        tx.id,
        tx.amount.toString(),
        tx.merchant,
        tx.date.toIso8601String(),
        tx.paymentMethod,
        tx.category,
        tx.notes,
        tx.paidTo,
        tx.needsVerification ? 'true' : 'false',
        tx.reminderDate?.toIso8601String() ?? '',
        tx.groupId ?? '',
      ];

      final escapedFields = fields.map((field) {
        if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }).toList();

      buffer.writeln(escapedFields.join(','));
    }

    return buffer.toString();
  }

  /// Best-guess preselection for column header mapping based on keywords
  static int findBestHeaderMatch(List<String> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase().trim();
      for (final keyword in keywords) {
        if (header == keyword || header.contains(keyword)) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Parse a CSV string into a list of ExpenseTransaction (using standard headers)
  static List<ExpenseTransaction> parseCsv(String csvText) {
    final List<List<String>> parsedRows = parseRawLines(csvText);
    if (parsedRows.isEmpty) return [];

    final headersLower = parsedRows[0].map((h) => h.toLowerCase().trim()).toList();
    
    final idIndex = headersLower.indexOf('id');
    final amountIndex = headersLower.indexOf('amount');
    final merchantIndex = headersLower.indexOf('merchant');
    final dateIndex = headersLower.indexOf('date');
    final paymentMethodIndex = headersLower.indexOf('paymentmethod');
    final categoryIndex = headersLower.indexOf('category');
    final notesIndex = headersLower.indexOf('notes');
    final paidToIndex = headersLower.indexOf('paidto');
    final needsVerificationIndex = headersLower.indexOf('needsverification');
    final reminderDateIndex = headersLower.indexOf('reminderdate');
    final groupIdIndex = headersLower.indexOf('groupid');

    if (amountIndex == -1 || merchantIndex == -1 || dateIndex == -1) {
      throw const FormatException('CSV is missing required headers (Amount, Merchant, Date)');
    }

    final Map<String, int> mapping = {
      'id': idIndex,
      'amount': amountIndex,
      'merchant': merchantIndex,
      'date': dateIndex,
      'category': categoryIndex,
      'paymentMethod': paymentMethodIndex,
      'notes': notesIndex,
      'paidTo': paidToIndex,
      'needsVerification': needsVerificationIndex,
      'reminderDate': reminderDateIndex,
      'groupId': groupIdIndex,
    };

    final dataRows = parsedRows.skip(1).toList();
    return parseCsvWithMapping(dataRows, mapping);
  }

  /// Pick and parse a CSV file, returning the parsed transactions (using standard headers for compatibility)
  static Future<List<ExpenseTransaction>> pickAndParseTransactions() async {
    final rawData = await pickAndParseRawCsv();
    
    final headersLower = rawData.headers.map((h) => h.toLowerCase().trim()).toList();
    
    final idIndex = headersLower.indexOf('id');
    final amountIndex = headersLower.indexOf('amount');
    final merchantIndex = headersLower.indexOf('merchant');
    final dateIndex = headersLower.indexOf('date');
    final paymentMethodIndex = headersLower.indexOf('paymentmethod');
    final categoryIndex = headersLower.indexOf('category');
    final notesIndex = headersLower.indexOf('notes');
    final paidToIndex = headersLower.indexOf('paidto');
    final needsVerificationIndex = headersLower.indexOf('needsverification');
    final reminderDateIndex = headersLower.indexOf('reminderdate');
    final groupIdIndex = headersLower.indexOf('groupid');

    if (amountIndex == -1 || merchantIndex == -1 || dateIndex == -1) {
      throw const FormatException('CSV is missing required headers (Amount, Merchant, Date)');
    }

    final Map<String, int> mapping = {
      'id': idIndex,
      'amount': amountIndex,
      'merchant': merchantIndex,
      'date': dateIndex,
      'category': categoryIndex,
      'paymentMethod': paymentMethodIndex,
      'notes': notesIndex,
      'paidTo': paidToIndex,
      'needsVerification': needsVerificationIndex,
      'reminderDate': reminderDateIndex,
      'groupId': groupIdIndex,
    };

    return parseCsvWithMapping(rawData.rows, mapping);
  }

  /// Pick and parse a CSV file into raw headers and rows for mapper UI
  static Future<RawCsvData> pickAndParseRawCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final pickedFile = result.files.first;
    String content;
    if (pickedFile.path != null) {
      final file = File(pickedFile.path!);
      content = await file.readAsString();
    } else if (pickedFile.bytes != null) {
      content = utf8.decode(pickedFile.bytes!);
    } else {
      throw Exception('Could not read the picked file content');
    }

    final List<List<String>> parsedRows = parseRawLines(content);
    if (parsedRows.isEmpty) {
      throw Exception('The CSV file is empty.');
    }

    final headers = parsedRows[0].map((h) => h.trim()).toList();
    final dataRows = parsedRows.skip(1).toList();

    return RawCsvData(headers: headers, rows: dataRows);
  }

  /// Parses a raw CSV string into rows of fields, handling quotes and escaping correctly
  static List<List<String>> parseRawLines(String csvText) {
    final List<List<String>> rows = [];
    final List<String> currentRow = [];
    final StringBuffer buffer = StringBuffer();
    bool inQuotes = false;
    int i = 0;

    while (i < csvText.length) {
      final String char = csvText[i];
      final String? nextChar = (i + 1 < csvText.length) ? csvText[i + 1] : null;

      if (inQuotes) {
        if (char == '"') {
          if (nextChar == '"') {
            buffer.write('"');
            i++; // Skip the second quote
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(buffer.toString());
          buffer.clear();
        } else if (char == '\r' || char == '\n') {
          currentRow.add(buffer.toString());
          buffer.clear();
          if (currentRow.isNotEmpty) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
          if (char == '\r' && nextChar == '\n') {
            i++; // Skip LF if we have CRLF
          }
        } else {
          buffer.write(char);
        }
      }
      i++;
    }

    if (buffer.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(buffer.toString());
      rows.add(currentRow);
    }

    return rows.where((row) => row.isNotEmpty && row.any((field) => field.trim().isNotEmpty)).toList();
  }

  /// Parse raw CSV data rows using a specific column index mapping
  static List<ExpenseTransaction> parseCsvWithMapping(
    List<List<String>> rows,
    Map<String, int> mapping,
  ) {
    final List<ExpenseTransaction> transactions = [];

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty || (row.length == 1 && row[0].trim().isEmpty)) continue;

      String getValue(int idx, String defaultValue) {
        if (idx >= 0 && idx < row.length) {
          return row[idx].trim();
        }
        return defaultValue;
      }

      final int idIdx = mapping['id'] ?? -1;
      final String rawId = getValue(idIdx, '');
      final String id = rawId.isNotEmpty ? rawId : '${DateTime.now().microsecondsSinceEpoch}_$r';

      final int amountIdx = mapping['amount'] ?? -1;
      final String amountStr = getValue(amountIdx, '0.0');
      
      // Strip currency symbols (e.g. $, €, £) and commas from amount to parse double safely
      final cleanAmountStr = amountStr.replaceAll(RegExp(r'[^\d\.\-]'), '');
      final double amount = double.tryParse(cleanAmountStr) ?? 0.0;

      final int merchantIdx = mapping['merchant'] ?? -1;
      final String merchant = getValue(merchantIdx, 'Unknown');

      final int dateIdx = mapping['date'] ?? -1;
      final String dateStr = getValue(dateIdx, '');
      DateTime date;
      try {
        date = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
      } catch (_) {
        // Fallback for custom date formats like DD/MM/YYYY or MM/DD/YYYY
        date = _tryParseCustomDate(dateStr) ?? DateTime.now();
      }

      final int paymentIdx = mapping['paymentMethod'] ?? -1;
      final String paymentMethod = paymentIdx != -1 ? getValue(paymentIdx, 'Cash') : 'Cash';

      final int categoryIdx = mapping['category'] ?? -1;
      final String category = categoryIdx != -1 ? getValue(categoryIdx, 'Other') : 'Other';

      final int notesIdx = mapping['notes'] ?? -1;
      final String notes = notesIdx != -1 ? getValue(notesIdx, '') : '';

      final int paidToIdx = mapping['paidTo'] ?? -1;
      final String paidTo = paidToIdx != -1 ? getValue(paidToIdx, '') : '';

      final int needsVerificationIdx = mapping['needsVerification'] ?? -1;
      final String needsVerificationStr = needsVerificationIdx != -1 ? getValue(needsVerificationIdx, 'false') : 'false';
      final bool needsVerification = needsVerificationStr.toLowerCase() == 'true';

      final int reminderDateIdx = mapping['reminderDate'] ?? -1;
      final String reminderDateStr = reminderDateIdx != -1 ? getValue(reminderDateIdx, '') : '';
      DateTime? reminderDate;
      if (reminderDateStr.isNotEmpty) {
        try {
          reminderDate = DateTime.parse(reminderDateStr);
        } catch (_) {}
      }

      final int groupIdIdx = mapping['groupId'] ?? -1;
      final String groupId = groupIdIdx != -1 ? getValue(groupIdIdx, '') : '';

      transactions.add(ExpenseTransaction(
        id: id,
        amount: amount,
        merchant: merchant,
        date: date,
        paymentMethod: paymentMethod,
        category: category,
        notes: notes,
        paidTo: paidTo,
        needsVerification: needsVerification,
        reminderDate: reminderDate,
        groupId: groupId.isNotEmpty ? groupId : null,
      ));
    }

    return transactions;
  }

  /// Try to parse custom date formats like 31/05/2026 or 05/31/2026
  static DateTime? _tryParseCustomDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split(RegExp(r'[\/\-\.]'));
      if (parts.length >= 3) {
        final part1 = int.tryParse(parts[0]) ?? 1;
        final part2 = int.tryParse(parts[1]) ?? 1;
        final part3 = int.tryParse(parts[2]) ?? 2026;

        if (part1 > 1000) {
          // YYYY-MM-DD
          return DateTime(part1, part2, part3);
        } else if (part3 > 1000) {
          // DD-MM-YYYY or MM-DD-YYYY
          if (part1 > 12) {
            return DateTime(part3, part2, part1);
          } else if (part2 > 12) {
            return DateTime(part3, part1, part2);
          } else {
            // Default to MM-DD-YYYY
            return DateTime(part3, part1, part2);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Export transactions to CSV and trigger standard sharing dialog
  static Future<void> exportTransactions(List<ExpenseTransaction> transactions) async {
    if (transactions.isEmpty) {
      throw Exception('No transactions to export');
    }

    final csvText = generateCsv(transactions);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/tallytap_backup_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvText);

    // Share the file
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'TallyTap Transactions Backup',
      text: 'Here is your privacy-focused TallyTap data backup as a CSV file.',
    );
  }
}
