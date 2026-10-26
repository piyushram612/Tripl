import 'package:flutter_test/flutter_test.dart';
import 'package:tripl/models/parsed_sms_transaction.dart';
import 'package:tripl/models/transaction_model.dart';
import 'package:tripl/services/sms_parser_service.dart';

void main() {
  group('SmsParserService - Sender Filtering', () {
    test('phone numbers are rejected as personal chats', () {
      expect(SmsParserService.isAllowedSmsSender('+919876543210'), isFalse);
      expect(SmsParserService.isAllowedSmsSender('9876543210'), isFalse);
      expect(SmsParserService.isAllowedSmsSender('+1 (555) 234-5678'), isFalse);
    });

    test('promotional -P suffixes are rejected', () {
      expect(SmsParserService.isAllowedSmsSender('VM-HDFCBK-P'), isFalse);
      expect(SmsParserService.isAllowedSmsSender('AX-SBIINB-p'), isFalse);
    });

    test('valid bank and transactional headers are allowed', () {
      expect(SmsParserService.isAllowedSmsSender('HDFCBK'), isTrue);
      expect(SmsParserService.isAllowedSmsSender('SBIINB'), isTrue);
      expect(SmsParserService.isAllowedSmsSender('AX-HDFCBK'), isTrue);
      expect(SmsParserService.isAllowedSmsSender('VM-HDFCBK-S'), isTrue);
      expect(SmsParserService.isAllowedSmsSender('AX-SBIINB-T'), isTrue);
    });
  });

  group('SmsParserService - Bank SMS Parsing', () {
    test('plain UPI debit reads everything', () {
      final p = SmsParserService.parse(
        'Rs.500.00 debited from A/c XX1234 on 05-10-26 to VPA zomato@icici UPI Ref 123456789012. Avl Bal Rs 15,000.00',
        sender: 'HDFCBK',
      );
      expect(p.isFinancial, isTrue);
      expect(p.type, equals(SmsTransactionType.debit));
      expect(p.amount, equals(500.00));
      expect(p.amountPaise, equals(50000));
      expect(p.payee, equals('Zomato'));
      expect(p.bankName, equals('HDFC Bank'));
      expect(p.accountNumber, equals('1234'));
      expect(p.balance, equals(15000.00));
      expect(p.referenceId, equals('123456789012'));
      expect(p.category, equals('Dining'));
    });

    test('Indian lakh format is read correctly', () {
      final p = SmsParserService.parse(
        'INR 1,25,000.00 debited from A/c XX1234. Avl bal INR 2,00,000.00',
        sender: 'AX-HDFCBK',
      );
      expect(p.amount, equals(125000.00));
      expect(p.amountPaise, equals(12500000));
      expect(p.balance, equals(200000.00));
      expect(p.balancePaise, equals(20000000));
    });

    test('balance is never mistaken for the amount', () {
      final p = SmsParserService.parse(
        'Avl Bal Rs 5,000.00. Rs 100 spent on card ending 4321 at SWIGGY',
        sender: 'ICICIB',
      );
      expect(p.amount, equals(100.00));
      expect(p.balance, equals(5000.00));
      expect(p.type, equals(SmsTransactionType.debit));
      expect(p.payee, equals('Swiggy'));
      expect(p.category, equals('Dining'));
    });

    test('salary credit is marked as income', () {
      final p = SmsParserService.parse(
        'Rs 45000.00 credited to A/c XX1234 on 01-10-26. Avl Bal Rs 60,000.00',
        sender: 'SBIINB',
      );
      expect(p.type, equals(SmsTransactionType.credit));
      expect(p.amount, equals(45000.00));
      expect(p.bankName, equals('SBI'));
      expect(p.isIncome, isTrue);
    });

    test('refund is credit and excluded from spend', () {
      final p = SmsParserService.parse(
        'Rs 300 refunded to your A/c XX1234 for order 77',
        sender: 'AX-HDFCBK',
      );
      expect(p.type, equals(SmsTransactionType.credit));
      expect(p.excludeFromSpend, isTrue);
      expect(p.note, equals('order 77'));
    });

    test('credit card bill payment is excluded from spend', () {
      final p = SmsParserService.parse(
        'Rs 12000 debited from A/c XX1234 towards credit card bill XX4321',
        sender: 'HDFCBK',
      );
      expect(p.type, equals(SmsTransactionType.debit));
      expect(p.excludeFromSpend, isTrue);
      expect(p.isTransfer, isTrue);
      expect(p.payee, equals('Credit Card Bill'));
    });

    test('credit card purchase counts as spend', () {
      final p = SmsParserService.parse(
        'Rs 2500 spent on HDFC Credit Card XX4321 at AMAZON on 04-10-26',
        sender: 'HDFCBK',
      );
      expect(p.type, equals(SmsTransactionType.debit));
      expect(p.excludeFromSpend, isFalse);
      expect(p.payee, equals('Amazon'));
      expect(p.accountType, equals('CREDIT_CARD'));
      expect(p.category, equals('Shopping'));
    });

    test('otp, failed, and future mandate are rejected', () {
      expect(
        SmsParserService.parse(
          '123456 is your OTP for txn of Rs 500 at Amazon. Do not share.',
          sender: 'AX-HDFCBK',
        ).isFinancial,
        isFalse,
      );
      expect(
        SmsParserService.parse(
          'Your payment of Rs 500 failed. Amount will be refunded',
          sender: 'PhonePe',
        ).isFinancial,
        isFalse,
      );
      expect(
        SmsParserService.parse(
          'Rs 999 will be debited from your A/c XX1234 on 10-10-26 for Netflix',
          sender: 'HDFCBK',
        ).isFinancial,
        isFalse,
      );
    });

    test('promo and balance enquiry are rejected', () {
      expect(
        SmsParserService.parse(
          'Recharge now Rs 299 plan 28 days validity unlimited data',
          sender: 'JIOINF',
        ).isFinancial,
        isFalse,
      );
      expect(
        SmsParserService.parse(
          'Your A/c XX1234 balance is Rs 15000.00 as on 05-10-26',
          sender: 'HDFCBK',
        ).isFinancial,
        isFalse,
      );
    });

    test('reversal is kept as money back (credit)', () {
      final p = SmsParserService.parse(
        'Rs 300 reversed to your A/c XX1234',
        sender: 'AX-HDFCBK',
      );
      expect(p.isFinancial, isTrue);
      expect(p.type, equals(SmsTransactionType.credit));
      expect(p.amount, equals(300.00));
    });

    test('failed payment that was reversed is still rejected', () {
      expect(
        SmsParserService.parse(
          'Your payment of Rs 500 failed. The amount has been reversed to your A/c XX1234',
          sender: 'AX-HDFCBK',
        ).isFinancial,
        isFalse,
      );
    });

    test('paid you notification / SMS is credit from that person', () {
      final p = SmsParserService.parse(
        'Ravi paid you Rs 200.00 via UPI',
        sender: 'Google Pay',
      );
      expect(p.type, equals(SmsTransactionType.credit));
      expect(p.amount, equals(200.00));
      expect(p.payee, equals('Ravi'));
    });
  });

  group('SmsParserService - Credit Card SMS Formats', () {
    test('HDFC spend with Avl Lmt is captured', () {
      final r = SmsParserService.parse(
        'Spent Rs.1250.00 On HDFC Bank Card x1234 At SWIGGY On 2025-01-10:12:30:11. Avl Lmt: Rs.85000.00. Not You? Call 18002586161',
        sender: 'HDFCBK',
      );
      expect(r.isFinancial, isTrue);
      expect(r.amount, equals(1250.00));
      expect(r.amountPaise, equals(125000));
      expect(r.type, equals(SmsTransactionType.debit));
      expect(r.accountType, equals('CREDIT_CARD'));
      expect(r.availableLimit, equals(85000.00));
      expect(r.availableLimitPaise, equals(8500000));
      expect(r.payee, equals('Swiggy'));
    });

    test('bank account never gets an available limit', () {
      final r = SmsParserService.parse(
        'Rs 200.00 debited from A/c XX1111 on 10-Jan-25 trf to RAJESH UPI Ref 123456789012. Avl bal Rs 5000',
        sender: 'SBIINB',
      );
      expect(r.availableLimit, isNull);
      expect(r.accountType, equals('BANK'));
      expect(r.balance, equals(5000.00));
      expect(r.payee, equals('Rajesh'));
    });

    test('UPI on credit card stays credit card', () {
      final r = SmsParserService.parse(
        'Rs 499.00 debited from your HDFC Bank Credit Card XX1234 via UPI to NETFLIX on 10-01-25. Avl Lmt Rs 90000',
        sender: 'HDFCBK',
      );
      expect(r.accountType, equals('CREDIT_CARD'));
      expect(r.excludeFromSpend, isFalse);
      expect(r.payee, equals('Netflix'));
      expect(r.category, equals('Subscriptions'));
    });

    test('ICICI used for transaction is debit', () {
      final r = SmsParserService.parse(
        'ICICI Bank Credit Card XX1234 has been used for a transaction of INR 2,450.00 on 10-Jan-25 at AMAZON. Avl Limit: INR 70,000.00.',
        sender: 'ICICIB',
      );
      expect(r.type, equals(SmsTransactionType.debit));
      expect(r.amount, equals(2450.00));
      expect(r.payee, equals('Amazon'));
      expect(r.category, equals('Shopping'));
    });

    test('card payment received is excluded transfer', () {
      final r = SmsParserService.parse(
        'Payment of Rs. 5000.00 received towards your HDFC Bank Credit Card XX1234 on 12-Jan-25. Thank you.',
        sender: 'HDFCBK',
      );
      expect(r.isTransfer, isTrue);
      expect(r.excludeFromSpend, isTrue);
      expect(r.payee, equals('Credit Card Bill'));
    });

    test('bank side card bill payment is excluded', () {
      final r = SmsParserService.parse(
        'Rs.5000.00 debited from A/c XX9876 on 12-Jan-25 towards Credit Card XX1234 payment. Avl bal Rs.12000',
        sender: 'HDFCBK',
      );
      expect(r.isTransfer, isTrue);
      expect(r.accountType, equals('BANK'));
      expect(r.excludeFromSpend, isTrue);
    });

    test('statement alert is rejected', () {
      expect(
        SmsParserService.parse(
          'Your ICICI Bank Credit Card XX1234 statement: Total Due Rs 5,000.00, Min Due Rs 500',
          sender: 'ICICIB',
        ).isFinancial,
        isFalse,
      );
    });

    test('refund on card keeps merchant payee', () {
      final r = SmsParserService.parse(
        'Refund of Rs 300.00 credited to your HDFC Bank Credit Card XX1234 from AMAZON on 12-Jan-25',
        sender: 'HDFCBK',
      );
      expect(r.payee, equals('Amazon'));
      expect(r.excludeFromSpend, isTrue);
    });
  });

  group('SmsParserService - Conversion to ExpenseTransaction', () {
    test('successfully maps to ExpenseTransaction with all fields populated', () {
      final parsed = SmsParserService.parse(
        'Rs 350.00 debited from your A/c XX5678 to Uber India UPI Ref 987654321012. Avl Bal Rs 12,400.00',
        sender: 'AX-AXISBK',
      );

      final expenseTx = parsed.toExpenseTransaction();
      expect(expenseTx.amount, equals(350.00));
      expect(expenseTx.merchant, equals('Uber India'));
      expect(expenseTx.category, equals('Commute'));
      expect(expenseTx.paymentMethod, equals('Bank Account'));
      expect(expenseTx.notes, contains('Axis Bank (A/c **5678)'));
      expect(expenseTx.notes, contains('Ref: 987654321012'));
      expect(expenseTx.notes, contains('Bal: ₹12400.00'));
      expect(expenseTx.isIncome, isFalse);
    });

    test('credit card spend sets paymentMethod to Credit Card', () {
      final parsed = SmsParserService.parse(
        'Spent Rs. 1499.00 on your Axis Bank Credit Card XX9999 at Blinkit on 20-Oct-26. Avl Lmt Rs 45000',
        sender: 'AXISBK',
      );

      final expenseTx = parsed.toExpenseTransaction();
      expect(expenseTx.amount, equals(1499.00));
      expect(expenseTx.merchant, equals('Blinkit'));
      expect(expenseTx.category, equals('Groceries'));
      expect(expenseTx.paymentMethod, equals('Credit Card'));
      expect(expenseTx.notes, contains('Avl Lmt: ₹45000.00'));
    });
  });

  group('SmsParserService - Smart Payment Source Mapping', () {
    final userSources = ['Cash', 'HDFC Salary', 'SBI Savings 1234', 'ICICI Amazon CC'];

    test('maps by account number when source contains matching digits', () {
      final parsed = SmsParserService.parse(
        'Rs 2500 debited from A/c XX1234 on 26-10-26 to SWIGGY',
        sender: 'SBIINB',
      );
      final mapped = SmsParserService.mapToPaymentSource(parsed, userSources);
      expect(mapped, equals('SBI Savings 1234'));
    });

    test('maps credit card SMS to user credit card source', () {
      final parsed = SmsParserService.parse(
        'Spent Rs. 4500 on ICICI Bank Credit Card x9999 at AMAZON',
        sender: 'ICICIB',
      );
      final mapped = SmsParserService.mapToPaymentSource(parsed, userSources);
      expect(mapped, equals('ICICI Amazon CC'));
    });

    test('maps bank name to bank account source', () {
      final parsed = SmsParserService.parse(
        'Rs 500.00 debited from HDFC Bank A/c XX5678 to Zomato',
        sender: 'HDFCBK',
      );
      final mapped = SmsParserService.mapToPaymentSource(parsed, userSources);
      expect(mapped, equals('HDFC Salary'));
    });

    test('respects saved user preferences', () {
      final parsed = SmsParserService.parse(
        'Rs 300 debited from Axis Bank A/c XX9999 to Zomato',
        sender: 'AXISBK',
      );
      final preferences = {'Axis Bank': 'HDFC Salary'};
      final mapped = SmsParserService.mapToPaymentSource(
        parsed,
        userSources,
        savedPreferences: preferences,
      );
      expect(mapped, equals('HDFC Salary'));
    });
  });

  group('SmsParserService - Intelligent Duplicate Detection & Merge', () {
    final now = DateTime.now();

    final manualTransaction = ExpenseTransaction(
      id: 'manual-uuid-1',
      amount: 450.00,
      merchant: 'Starbucks',
      date: now.subtract(const Duration(minutes: 15)),
      paymentMethod: 'Credit Card',
      category: 'Dining',
      notes: 'Coffee with team',
      needsVerification: true,
    );

    final alreadyImportedTransaction = ExpenseTransaction(
      id: 'sms-uuid-2',
      amount: 1200.00,
      merchant: 'Amazon',
      date: now.subtract(const Duration(hours: 1)),
      paymentMethod: 'Bank Account',
      category: 'Shopping',
      notes: 'HDFC Bank | Ref: 554433221100',
    );

    test('detects exact duplicate when reference ID matches', () {
      final incomingSms = SmsParserService.parse(
        'Rs 1200.00 debited from A/c XX1234 to Amazon UPI Ref 554433221100',
        sender: 'HDFCBK',
      );

      final match = SmsParserService.findDuplicateMatch(
        incomingSms,
        [manualTransaction, alreadyImportedTransaction],
      );

      expect(match.status, equals(DuplicateStatus.exact));
      expect(match.isExact, isTrue);
      expect(match.matchedTransaction?.id, equals('sms-uuid-2'));
    });

    test('detects potential duplicate for manual entry with matching amount and close time', () {
      final incomingSms = SmsParserService.parse(
        'Rs 450.00 debited from your HDFC Bank Card x1234 at STARBUCKS on 26-10-26 UPI Ref 998877665544',
        sender: 'HDFCBK',
      );

      final match = SmsParserService.findDuplicateMatch(
        incomingSms,
        [manualTransaction, alreadyImportedTransaction],
      );

      expect(match.status, equals(DuplicateStatus.potential));
      expect(match.isPotential, isTrue);
      expect(match.matchedTransaction?.id, equals('manual-uuid-1'));
    });

    test('returns none when amount or date does not match', () {
      final incomingSms = SmsParserService.parse(
        'Rs 890.00 debited from A/c XX1234 to Netflix',
        sender: 'HDFCBK',
      );

      final match = SmsParserService.findDuplicateMatch(
        incomingSms,
        [manualTransaction, alreadyImportedTransaction],
      );

      expect(match.status, equals(DuplicateStatus.none));
      expect(match.isDuplicate, isFalse);
    });

    test('mergeTransaction enriches manual transaction without duplicating row', () {
      final incomingSms = SmsParserService.parse(
        'Rs 450.00 debited from your HDFC Bank Card x1234 at STARBUCKS. Avl Bal Rs 20000. Ref 998877665544',
        sender: 'HDFCBK',
      );

      final merged = SmsParserService.mergeTransaction(manualTransaction, incomingSms);

      // Preserves original manual transaction ID
      expect(merged.id, equals('manual-uuid-1'));
      expect(merged.amount, equals(450.00));
      // Preserves user's manual category
      expect(merged.category, equals('Dining'));
      // Enriches notes with official bank Ref and account number
      expect(merged.notes, contains('Coffee with team'));
      expect(merged.notes, contains('HDFC Bank'));
      expect(merged.notes, contains('Ref: 998877665544'));
      expect(merged.notes, contains('Bal: ₹20000.00'));
      // Verified by bank!
      expect(merged.needsVerification, isFalse);
    });
  });
}
