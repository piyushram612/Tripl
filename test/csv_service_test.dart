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
    });

    test('parseCsv throws FormatException on invalid headers', () {
      const invalidCsv = 'InvalidHeader1,InvalidHeader2\nvalue1,value2';
      expect(() => CsvService.parseCsv(invalidCsv), throwsA(isA<FormatException>()));
    });

    test('parseCsv handles empty/partially empty fields gracefully', () {
      const csv = 'ID,Amount,Merchant,Date,PaymentMethod,Category,Notes,PaidTo,NeedsVerification,ReminderDate,GroupId\n'
          'tx3,45.0,Walmart,2026-05-31T10:00:00.000,Cash,Groceries,,,,,\n';
      
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
    });
  });
}
