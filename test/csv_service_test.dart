import 'package:flutter_test/flutter_test.dart';
import 'package:tripl/models/transaction_model.dart';
import 'package:tripl/services/csv_service.dart';

void main() {
  group('CsvService Tests', () {
    test('generateCsv and parseCsv are perfectly symmetric', () {
      final transactions = [
        ExpenseTransaction(
          id: 'tx1',
          amount: 150.50,
          merchant: 'Google Store',
          date: DateTime(2026, 5, 31, 12, 0, 0),
          paymentMethod: 'Credit Card',
          category: 'Electronics',
          notes: 'Pixel 9 Pro purchase, "premium" glass',
          paidTo: 'Google LLC',
          needsVerification: false,
          reminderDate: null,
          groupId: 'group123',
          isIncome: true,
        ),
        ExpenseTransaction(
          id: 'tx2',
          amount: 12.00,
          merchant: 'Starbucks, Seattle',
          date: DateTime(2026, 5, 30, 8, 30, 0),
          paymentMethod: 'Apple Pay',
          category: 'Food & Drinks',
          notes: 'Coffee & croissant\nDouble line note',
          paidTo: '',
          needsVerification: true,
          reminderDate: DateTime(2026, 6, 1, 9, 0, 0),
          groupId: null,
          isIncome: false,
        ),
      ];

      // Generate CSV
      final csvText = CsvService.generateCsv(transactions);

      // Parse CSV back
      final parsed = CsvService.parseCsv(csvText);

      expect(parsed.length, equals(2));

      // Assert tx1 values
      final t1 = parsed.firstWhere((t) => t.id == 'tx1');
      expect(t1.amount, equals(150.50));
      expect(t1.merchant, equals('Google Store'));
      expect(t1.date, equals(DateTime(2026, 5, 31, 12, 0, 0)));
      expect(t1.paymentMethod, equals('Credit Card'));
      expect(t1.category, equals('Electronics'));
      expect(t1.notes, equals('Pixel 9 Pro purchase, "premium" glass'));
      expect(t1.paidTo, equals('Google LLC'));
      expect(t1.needsVerification, isFalse);
      expect(t1.reminderDate, isNull);
      expect(t1.groupId, equals('group123'));
      expect(t1.isIncome, isTrue);

      // Assert tx2 values
      final t2 = parsed.firstWhere((t) => t.id == 'tx2');
      expect(t2.amount, equals(12.00));
      expect(t2.merchant, equals('Starbucks, Seattle'));
      expect(t2.date, equals(DateTime(2026, 5, 30, 8, 30, 0)));
      expect(t2.paymentMethod, equals('Apple Pay'));
      expect(t2.category, equals('Food & Drinks'));
      expect(t2.notes, equals('Coffee & croissant\nDouble line note'));
      expect(t2.paidTo, equals(''));
      expect(t2.needsVerification, isTrue);
      expect(t2.reminderDate, equals(DateTime(2026, 6, 1, 9, 0, 0)));
      expect(t2.groupId, isNull);
      expect(t2.isIncome, isFalse);
    });

    test('parseCsv throws FormatException on invalid headers', () {
      const invalidCsv = 'InvalidHeader1,InvalidHeader2\nvalue1,value2';
      expect(() => CsvService.parseCsv(invalidCsv), throwsA(isA<FormatException>()));
    });

    test('parseCsv handles empty/partially empty fields gracefully', () {
      const csv = 'ID,Amount,Merchant,Date,PaymentMethod,Category,Notes,PaidTo,NeedsVerification,ReminderDate,GroupId,IsIncome\n'
          'tx3,45.0,Walmart,2026-05-31T10:00:00.000,Cash,Groceries,,,,,,\n';
      
      final parsed = CsvService.parseCsv(csv);
      expect(parsed.length, equals(1));
      
      final tx = parsed.first;
      expect(tx.id, equals('tx3'));
      expect(tx.amount, equals(45.0));
      expect(tx.merchant, equals('Walmart'));
      expect(tx.paymentMethod, equals('Cash'));
      expect(tx.category, equals('Groceries'));
      expect(tx.notes, equals(''));
      expect(tx.paidTo, equals(''));
      expect(tx.needsVerification, isFalse);
      expect(tx.reminderDate, isNull);
      expect(tx.groupId, isNull);
      expect(tx.isIncome, isFalse);
    });

    test('parseCsv detects isIncome using heuristics (signs and keywords)', () {
      const csv = 'Amount,Merchant,Date,Category\n'
          '100.0,Store A,2026-05-31,Food\n' // no sign -> expense (no negative numbers in CSV)
          '+250.0,Salary,2026-05-31,Other\n'  // explicit plus -> income
          '50.0,Refund,2026-05-31,Refund\n'   // positive + keyword -> income
          '75.0,Store B,2026-05-31,Shopping\n'; // positive + no keyword -> expense
      
      final parsed = CsvService.parseCsv(csv);
      expect(parsed.length, equals(4));
      expect(parsed[0].isIncome, isFalse);
      expect(parsed[0].amount, equals(100.0));
      expect(parsed[1].isIncome, isTrue);
      expect(parsed[1].amount, equals(250.0));
      expect(parsed[2].isIncome, isTrue);
      expect(parsed[2].amount, equals(50.0));
      expect(parsed[3].isIncome, isFalse);
      expect(parsed[3].amount, equals(75.0));
    });

    test('parseCsv detects isIncome when CSV contains negative amounts', () {
      const csv = 'Amount,Merchant,Date,Category\n'
          '-50.0,Store A,2026-05-31,Food\n' // negative -> expense
          '2000.0,Employer,2026-05-31,Other\n'; // positive + negative present -> income
      
      final parsed = CsvService.parseCsv(csv);
      expect(parsed.length, equals(2));
      expect(parsed[0].isIncome, isFalse);
      expect(parsed[1].isIncome, isTrue);
    });

    test('parseCsv detects isIncome when CSV uses negative-is-income convention', () {
      const csv = 'Amount,Merchant,Date,Category\n'
          '-1000.0,Employer,2026-05-31,Salary\n' // negative + Salary -> negative is income!
          '50.0,Store A,2026-05-31,Food\n'      // positive + Food -> positive is expense!
          '75.0,Store B,2026-05-31,Other\n'     // positive + neutral -> positive is expense!
          '-200.0,Refund,2026-05-31,Other\n';   // negative + neutral -> negative is income!
      
      final parsed = CsvService.parseCsv(csv);
      expect(parsed.length, equals(4));
      expect(parsed[0].isIncome, isTrue);
      expect(parsed[0].amount, equals(1000.0));
      expect(parsed[1].isIncome, isFalse);
      expect(parsed[1].amount, equals(50.0));
      expect(parsed[2].isIncome, isFalse);
      expect(parsed[2].amount, equals(75.0));
      expect(parsed[3].isIncome, isTrue);
      expect(parsed[3].amount, equals(200.0));
    });
  });
}
