import 'package:uuid/uuid.dart';
import 'transaction_model.dart';

enum SmsTransactionType {
  debit,
  credit,
}

enum DuplicateStatus {
  none,
  exact,
  potential,
}

class SmsDuplicateMatch {
  final DuplicateStatus status;
  final ExpenseTransaction? matchedTransaction;
  final String reason;

  const SmsDuplicateMatch({
    required this.status,
    this.matchedTransaction,
    required this.reason,
  });

  bool get isDuplicate => status != DuplicateStatus.none;
  bool get isExact => status == DuplicateStatus.exact;
  bool get isPotential => status == DuplicateStatus.potential;
}

class ParsedSmsTransaction {
  final bool isFinancial;
  final double? amount; // In currency units (e.g., 500.00)
  final int? amountPaise; // In paise (e.g., 50000)
  final String? payee;
  final SmsTransactionType? type;
  final String? referenceId;
  final double? balance;
  final int? balancePaise;
  final double? availableLimit;
  final int? availableLimitPaise;
  final String? note;
  final String? bankName;
  final String? accountNumber; // Last 4 digits
  final String rawText;
  final String? sender;
  final String currency;
  final String accountType; // 'BANK' or 'CREDIT_CARD'
  final bool isTransfer;
  final bool excludeFromSpend;
  final double confidence;
  final String? rejectReason;
  final String category;
  final DateTime? date;

  // Smart source mapping and duplicate handling fields
  final String? selectedPaymentSource;
  final SmsDuplicateMatch? duplicateMatch;
  final bool isAccepted;
  final bool mergeWithExisting;

  ParsedSmsTransaction({
    required this.isFinancial,
    this.amount,
    this.amountPaise,
    this.payee,
    this.type,
    this.referenceId,
    this.balance,
    this.balancePaise,
    this.availableLimit,
    this.availableLimitPaise,
    this.note,
    this.bankName,
    this.accountNumber,
    required this.rawText,
    this.sender,
    this.currency = 'INR',
    this.accountType = 'BANK',
    this.isTransfer = false,
    this.excludeFromSpend = false,
    this.confidence = 1.0,
    this.rejectReason,
    this.category = 'Other',
    this.date,
    this.selectedPaymentSource,
    this.duplicateMatch,
    this.isAccepted = true,
    this.mergeWithExisting = false,
  });

  bool get isFullyParsed =>
      isFinancial &&
      amount != null &&
      amount! > 0 &&
      type != null &&
      bankName != null;

  bool get isIncome =>
      type == SmsTransactionType.credit && !excludeFromSpend && !isTransfer;

  ParsedSmsTransaction copyWith({
    bool? isFinancial,
    double? amount,
    int? amountPaise,
    String? payee,
    SmsTransactionType? type,
    String? referenceId,
    double? balance,
    int? balancePaise,
    double? availableLimit,
    int? availableLimitPaise,
    String? note,
    String? bankName,
    String? accountNumber,
    String? rawText,
    String? sender,
    String? currency,
    String? accountType,
    bool? isTransfer,
    bool? excludeFromSpend,
    double? confidence,
    String? rejectReason,
    String? category,
    DateTime? date,
    String? selectedPaymentSource,
    SmsDuplicateMatch? duplicateMatch,
    bool? isAccepted,
    bool? mergeWithExisting,
  }) {
    return ParsedSmsTransaction(
      isFinancial: isFinancial ?? this.isFinancial,
      amount: amount ?? this.amount,
      amountPaise: amountPaise ?? this.amountPaise,
      payee: payee ?? this.payee,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      balance: balance ?? this.balance,
      balancePaise: balancePaise ?? this.balancePaise,
      availableLimit: availableLimit ?? this.availableLimit,
      availableLimitPaise: availableLimitPaise ?? this.availableLimitPaise,
      note: note ?? this.note,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      rawText: rawText ?? this.rawText,
      sender: sender ?? this.sender,
      currency: currency ?? this.currency,
      accountType: accountType ?? this.accountType,
      isTransfer: isTransfer ?? this.isTransfer,
      excludeFromSpend: excludeFromSpend ?? this.excludeFromSpend,
      confidence: confidence ?? this.confidence,
      rejectReason: rejectReason ?? this.rejectReason,
      category: category ?? this.category,
      date: date ?? this.date,
      selectedPaymentSource: selectedPaymentSource ?? this.selectedPaymentSource,
      duplicateMatch: duplicateMatch ?? this.duplicateMatch,
      isAccepted: isAccepted ?? this.isAccepted,
      mergeWithExisting: mergeWithExisting ?? this.mergeWithExisting,
    );
  }

  /// Converts this parsed transaction into a TallyTap [ExpenseTransaction].
  ExpenseTransaction toExpenseTransaction({
    String? customCategory,
    String? customPaymentMethod,
    DateTime? customDate,
  }) {
    final effectiveDate = customDate ?? date ?? DateTime.now();
    final effectivePayee = (payee != null && payee!.trim().isNotEmpty)
        ? payee!.trim()
        : (bankName ?? 'Unknown Merchant');

    String effectivePaymentMethod;
    if (customPaymentMethod != null && customPaymentMethod.isNotEmpty) {
      effectivePaymentMethod = customPaymentMethod;
    } else if (selectedPaymentSource != null && selectedPaymentSource!.isNotEmpty) {
      effectivePaymentMethod = selectedPaymentSource!;
    } else if (accountType == 'CREDIT_CARD') {
      effectivePaymentMethod = 'Credit Card';
    } else {
      effectivePaymentMethod = 'Bank Account';
    }

    final effectiveCategory = customCategory ??
        (isIncome ? 'Salary' : (category.isNotEmpty ? category : 'Other'));

    final notesParts = <String>[];
    if (bankName != null) {
      final acct = accountNumber != null ? ' (A/c **$accountNumber)' : '';
      notesParts.add('$bankName$acct');
    }
    if (referenceId != null && referenceId!.isNotEmpty) {
      notesParts.add('Ref: $referenceId');
    }
    if (balance != null) {
      notesParts.add('Bal: ₹${balance!.toStringAsFixed(2)}');
    }
    if (availableLimit != null) {
      notesParts.add('Avl Lmt: ₹${availableLimit!.toStringAsFixed(2)}');
    }
    if (note != null && note!.isNotEmpty) {
      notesParts.add('Note: $note');
    }

    return ExpenseTransaction(
      id: const Uuid().v4(),
      amount: amount ?? 0.0,
      merchant: effectivePayee,
      date: effectiveDate,
      paymentMethod: effectivePaymentMethod,
      category: effectiveCategory,
      notes: notesParts.join(' | '),
      paidTo: effectivePayee,
      needsVerification: payee == null || payee!.isEmpty || type == null,
      wasFinishLater: false,
      hideFromLedger: excludeFromSpend,
      isIncome: isIncome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isFinancial': isFinancial,
      'amount': amount,
      'amountPaise': amountPaise,
      'payee': payee,
      'type': type?.name,
      'referenceId': referenceId,
      'balance': balance,
      'balancePaise': balancePaise,
      'availableLimit': availableLimit,
      'availableLimitPaise': availableLimitPaise,
      'note': note,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'rawText': rawText,
      'sender': sender,
      'currency': currency,
      'accountType': accountType,
      'isTransfer': isTransfer,
      'excludeFromSpend': excludeFromSpend,
      'confidence': confidence,
      'rejectReason': rejectReason,
      'category': category,
      'date': date?.toIso8601String(),
      'selectedPaymentSource': selectedPaymentSource,
      'isAccepted': isAccepted,
      'mergeWithExisting': mergeWithExisting,
    };
  }

  factory ParsedSmsTransaction.fromMap(Map<String, dynamic> map) {
    SmsTransactionType? type;
    if (map['type'] == 'debit') {
      type = SmsTransactionType.debit;
    } else if (map['type'] == 'credit') {
      type = SmsTransactionType.credit;
    }

    return ParsedSmsTransaction(
      isFinancial: map['isFinancial'] == true,
      amount: (map['amount'] as num?)?.toDouble(),
      amountPaise: (map['amountPaise'] as num?)?.toInt(),
      payee: map['payee'] as String?,
      type: type,
      referenceId: map['referenceId'] as String?,
      balance: (map['balance'] as num?)?.toDouble(),
      balancePaise: (map['balancePaise'] as num?)?.toInt(),
      availableLimit: (map['availableLimit'] as num?)?.toDouble(),
      availableLimitPaise: (map['availableLimitPaise'] as num?)?.toInt(),
      note: map['note'] as String?,
      bankName: map['bankName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      rawText: (map['rawText'] as String?) ?? '',
      sender: map['sender'] as String?,
      currency: (map['currency'] as String?) ?? 'INR',
      accountType: (map['accountType'] as String?) ?? 'BANK',
      isTransfer: map['isTransfer'] == true,
      excludeFromSpend: map['excludeFromSpend'] == true,
      confidence: ((map['confidence'] as num?) ?? 1.0).toDouble(),
      rejectReason: map['rejectReason'] as String?,
      category: (map['category'] as String?) ?? 'Other',
      date: map['date'] != null ? DateTime.tryParse(map['date'] as String) : null,
      selectedPaymentSource: map['selectedPaymentSource'] as String?,
      isAccepted: map['isAccepted'] != false,
      mergeWithExisting: map['mergeWithExisting'] == true,
    );
  }
}
