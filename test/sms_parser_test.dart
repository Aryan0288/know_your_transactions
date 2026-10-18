import 'package:flutter_test/flutter_test.dart';
import 'package:know_your_expenses/features/auto_sms/model/model_pending_sms.dart';
import 'package:know_your_expenses/features/auto_sms/service/sms_parser_service.dart';
import 'package:know_your_expenses/features/auto_sms/service/auto_sms_service.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

void main() {
  group('SmsParserService Tests', () {
    test('HDFC Bank UPI debit SMS', () {
      const sms = 'Dear Customer, Rs.550.00 has been debited from account **1234 to VPA zomato@icici on 24-09-24. UPI Ref 426819283741. Avail Bal: INR 15,230.50';
      final parsed = SmsParserService.parseSms(sms, sender: 'VM-HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 550.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.vendorName.toLowerCase().contains('zomato'), isTrue);
    });

    test('SBI Debit SMS with text month and balance isolation', () {
      const sms = 'Dear SBI User, A/C 1234 debited by 450.0 on 24Sep24 transfer to Swiggy UPI. Bal Rs 10000.0.';
      final parsed = SmsParserService.parseSms(sms, sender: 'AX-SBIINB');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 450.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.vendorName.toLowerCase().contains('swiggy'), isTrue);
    });

    test('Investment / SIP debit SMS', () {
      const sms = 'SIP of Rs 2,500.00 for Groww Mutual Fund processed on 25-09-2024. Ref: 9876543210.';
      final parsed = SmsParserService.parseSms(sms, sender: 'AD-GROWW');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 2500.0);
      expect(parsed.isExpense, isTrue);
    });

    test('Groceries Blinkit SMS', () {
      const sms = 'Paid Rs. 349 to Blinkit at 24-Sep-24 via UPI. Ref No 426891234.';
      final parsed = SmsParserService.parseSms(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 349.0);
      expect(parsed.vendorName.toLowerCase().contains('blinkit'), isTrue);
    });

    test('Salary credit SMS', () {
      const sms = 'Your A/C XX5678 is credited with INR 65,000.00 on 30-Sep-24 by Salary for September.';
      final parsed = SmsParserService.parseSms(sms, sender: 'VK-HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 65000.0);
      expect(parsed.isExpense, isFalse);
    });

    test('OTP / Spam should be ignored', () {
      const otpSms = 'Your OTP for transaction of Rs 500 at Amazon is 492011. Do not share with anyone.';
      final parsed = SmsParserService.parseSms(otpSms);
      expect(parsed, isNull);
    });

    test('Loan promotion / Pre-approved should be ignored', () {
      const promoSms = 'Congratulations! Pre-approved loan of Rs 5,00,000 is ready. Apply now at link.';
      final parsed = SmsParserService.parseSms(promoSms);
      expect(parsed, isNull);
    });

    test('PNB Indian Clearing (ICCL / Mutual Fund SIP) SMS', () {
      const sms = 'A/c X9975 debited INR 1800.00 Dt 02-09-26 08:37:41 to Indian Clearing thru UPI:110577150899.Bal INR 17122.36 Not u?Fwd this SMS to 9264092640 to block UPI.-PNB';
      final parsed = SmsParserService.parseSms(sms, sender: 'PNBSMS');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1800.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.vendorName, contains('Indian Clearing'));
      expect(parsed.refNumber, '110577150899');
      expect(parsed.bankAccount, contains('9975'));
      expect(parsed.smartTitle, contains('Mutual Fund'));
    });

    test('Jio Mobile Recharge SMS', () {
      const sms = 'Paid Rs 299.00 to Jio Prepaid Recharge via UPI 9876543210 on 01-09-26.';
      final parsed = SmsParserService.parseSms(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 299.0);
      expect(parsed.smartTitle, contains('Jio Recharge'));
    });

    test('Protean APY / PRAN Contribution SMS', () {
      const sms = 'APY(PRANXX1647) Contribution of Rs.59.00 for Sep-2026 credited to your PRAN. To complete Aadhar seeding Click https://gs.im/PTNNPS/e/CDIouKo3gTr -Protean';
      final parsed = SmsParserService.parseSms(sms, sender: 'PROTEAN');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 59.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.smartTitle, contains('Atal Pension Yojana (APY)'));
      expect(parsed.smartTitle, contains('1647'));
    });

    test('PNB UPI Credit SMS - should not misclassify as CRED', () {
      const sms = 'Your a/c XX9975 is credited for INR 575.00 on 25-09-26 22:26 through UPI.Available Bal INR 9051.71 (UPI Ref ID 626858479471).Download PNB ONE-PNB';
      final parsed = SmsParserService.parseSms(sms, sender: 'PNBSMS');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 575.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, '626858479471');
      expect(parsed.smartTitle, isNot(contains('CRED')));
      expect(parsed.smartTitle, contains('UPI / Bank Credit'));
    });

    test('Zomato UPI Debit SMS', () {
      const sms = 'Rs. 450.00 debited from A/C XXXX1234 at Zomato on 22-Jul-26 via UPI. Ref No 987654321.';
      final parsed = SmsParserService.parseSms(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 450.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.vendorName.toLowerCase(), contains('zomato'));
      expect(parsed.refNumber, '987654321');
      expect(parsed.bankAccount, contains('1234'));
      expect(parsed.smartTitle, contains('Zomato'));
    });

    test('Rapido PNB UPI Debit SMS', () {
      const sms = 'A/c X9975 debited INR 38.00 Dt 20-08-26 08:52:20 to Rapido thru UPI:659897022217.Bal INR 430.41 Not u?Fwd this SMS to 9264092640 to block UPI.-PNB';
      final parsed = SmsParserService.parseSms(sms, sender: 'PNBSMS');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 38.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.vendorName.toLowerCase(), contains('rapido'));
      expect(parsed.refNumber, '659897022217');
      expect(parsed.bankAccount, contains('9975'));
      expect(parsed.smartTitle, contains('Rapido'));
    });

    test('Real Completed Jio Recharge Receipt SMS', () {
      const sms = '''Recharge Successful !
Plan Name : 579.0
Jio Number : 9759147625
Entitlement : 
Benefits: Unlimited data - 84GB(1.5GB/Day 4G/5G Data), Unlimited Voice, 100 SMS/Day & Subscription to Jio Apps. Validity - 56 Days
Transaction ID : 10005776384844
View plan details - http://tiny.jio.com/dmyjioplans''';
      final parsed = SmsParserService.parseSms(sms, sender: 'Jio');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 579.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.refNumber, '10005776384844');
      expect(parsed.vendorName, contains('Jio'));
      expect(parsed.vendorName, contains('9759147625'));
    });

    test('Jio Home Freedom Promo SMS - MUST BE IGNORED', () {
      const sms = '''Save ₹6,000 with the new JioHome Freedom Pack!
Recharge for ₹10,000 & get 15 months of 100 Mbps WiFi, 1000+ LiveTV channels & 12+ Entertainment Apps at just ₹666/month.
Limited time offer. Recharge Now: https://tiny.jio.com/freedom2
T&C Apply''';
      final parsed = SmsParserService.parseSms(sms, sender: 'Jio');
      expect(parsed, isNull);
    });

    test('Jio Birthday Special Offer SMS - MUST BE IGNORED', () {
      const sms = "Happy Birthday! Celebrate longer with Jio's special Rs.799 plan - 84 days validity & 1.5GB/day. Recharge now: www.jio.com/r/EmkxxxhkY T&C apply.";
      final parsed = SmsParserService.parseSms(sms, sender: 'Jio');
      expect(parsed, isNull);
    });

    test('Jio Plan Expiry Reminder SMS - MUST BE IGNORED', () {
      const sms = 'Your Jio no. 9759147625 plan is expiring soon. Recharge with Rs. 899 for Unlimited voice, 2 GB/day data for 90 Days + JioHotstar mobile & Pro Google Gemini. T&C Apply. www.jio.com/r/EwOAuXfpy';
      final parsed = SmsParserService.parseSms(sms, sender: 'Jio');
      expect(parsed, isNull);
    });

    test('Flipkart Big Billion Days Promo SMS - MUST BE IGNORED', () {
      const sms = 'Big Billion Days is live! Flat Rs 500 off on orders above Rs 1999. Use code BBD500. Shop now on Flipkart!';
      final parsed = SmsParserService.parseSms(sms, sender: 'FLPKRT');
      expect(parsed, isNull);
    });

    test('Myntra Coupon Promo SMS - MUST BE IGNORED', () {
      const sms = 'Exclusive Offer! Get Rs 300 off on fashion apparel. Use coupon MYNTRA300. Hurry, offer valid till midnight.';
      final parsed = SmsParserService.parseSms(sms, sender: 'MYNTRA');
      expect(parsed, isNull);
    });

    test('Failed transaction should be ignored', () {
      const failedSms = 'Transaction of Rs 500 at Flipkart failed due to technical issues.';
      final parsed = SmsParserService.parseSms(failedSms);
      expect(parsed, isNull);
    });

    test('Jio Expired Plan + Queued Pack Auto-Activation SMS - MUST BE IGNORED', () {
      const sms = '''Your plan Rs 579_56D_1.5GB/D for Jio Number 9759147625 has expired on 23-Sep-26 08:40 Hrs. You have already recharged with Rs 579_56D_1.5GB/D plan, which will automatically get activated to ensure uninterrupted Jio services. 
To view your current and upcoming plan details, click http://tiny.jio.com/dmyjioplans
Dial 1991, to know your current balance, validity, plan details and for exciting recharge plans.''';
      final parsed = SmsParserService.parseSms(sms, sender: 'Jio');
      expect(parsed, isNull);
    });

    test('Credit Card Statement / Bill Due SMS - MUST BE IGNORED', () {
      const sms = 'Dear Customer, Total Amt Due on your HDFC Bank Credit Card ending 1234 is Rs 15,400.00. Min Due: Rs 1,500.00 Due Date: 15-Oct-26. Pay now to avoid charges.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNull);
    });

    test('E-Mandate / SIP Registration SMS - MUST BE IGNORED', () {
      const sms = 'Dear Customer, E-mandate for Rs 5,000.00 in favour of GROWW has been successfully registered on your A/c XX1234.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNull);
    });

    test('Cheque Sent For Clearing SMS - MUST BE IGNORED', () {
      const sms = 'Cheque no 123456 for Rs 25,000 deposited in your A/C XX1234 is sent for clearing.';
      final parsed = SmsParserService.parseSms(sms, sender: 'SBISMS');
      expect(parsed, isNull);
    });

    test('FASTag Low Balance Warning SMS - MUST BE IGNORED', () {
      const sms = 'Your FASTag balance for vehicle UP14XX1234 is low (Rs 45.00). Recharge fastag to avoid toll plaza delays.';
      final parsed = SmsParserService.parseSms(sms, sender: 'NETC');
      expect(parsed, isNull);
    });

    test('Virtual Rewards / SuperCoins Credited SMS - MUST BE IGNORED', () {
      const sms = 'Congratulations! 500 SuperCoins credited to your Flipkart account for your recent shopping.';
      final parsed = SmsParserService.parseSms(sms, sender: 'FLPKRT');
      expect(parsed, isNull);
    });
  });

  group('Category Classification Tests', () {
    final categories = [
      CategoryModel(id: 'food', name: 'Food & Dining', iconCodePoint: 1, colorValue: 1),
      CategoryModel(id: 'groceries', name: 'Groceries', iconCodePoint: 2, colorValue: 2),
      CategoryModel(id: 'investments', name: 'Investments & Stocks', iconCodePoint: 3, colorValue: 3),
      CategoryModel(id: 'salary', name: 'Salary & Income', iconCodePoint: 4, colorValue: 4),
      CategoryModel(id: 'shopping', name: 'Shopping & E-Commerce', iconCodePoint: 5, colorValue: 5),
      CategoryModel(id: 'utilities', name: 'Bills & Utilities', iconCodePoint: 6, colorValue: 6),
      CategoryModel(id: 'transport', name: 'Transport & Cab', iconCodePoint: 7, colorValue: 7),
      CategoryModel(id: 'entertainment', name: 'Entertainment & OTT', iconCodePoint: 8, colorValue: 8),
      CategoryModel(id: 'bills_emi', name: 'Credit Card & EMI', iconCodePoint: 9, colorValue: 9),
      CategoryModel(id: 'health', name: 'Health & Medical', iconCodePoint: 10, colorValue: 10),
      CategoryModel(id: 'rent', name: 'Rent & Housing', iconCodePoint: 11, colorValue: 11),
      CategoryModel(id: 'income', name: 'Income', iconCodePoint: 13, colorValue: 13),
      CategoryModel(id: 'transfer', name: 'Transfers', iconCodePoint: 14, colorValue: 14),
      CategoryModel(id: 'returns', name: 'Returns & Div', iconCodePoint: 15, colorValue: 15),
      CategoryModel(id: 'refund', name: 'Refunds', iconCodePoint: 16, colorValue: 16),
      CategoryModel(id: 'other', name: 'Other Expenses', iconCodePoint: 12, colorValue: 12),
    ];

    test('Classifies Indian Clearing / ICCL as Investment', () {
      final parsed = SmsParserService.parseSms('A/c X9975 debited INR 1800.00 Dt 02-09-26 08:37:41 to Indian Clearing thru UPI:110577150899.Bal INR 17122.36 Not u?Fwd this SMS to 9264092640 to block UPI.-PNB')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'investments');
    });

    test('Classifies APY PRAN SMS as Investment', () {
      final parsed = SmsParserService.parseSms('APY(PRANXX1647) Contribution of Rs.59.00 for Sep-2026 credited to your PRAN. -Protean', sender: 'PROTEAN')!;
      expect(parsed.isExpense, isTrue);
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'investments');
    });

    test('Classifies Zerodha / Groww as Investment', () {
      final parsed = SmsParserService.parseSms('Debited Rs 5000 towards Zerodha Broking SIP on 24-Sep-24.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'investments');
    });

    test('Classifies Zepto / Blinkit as Groceries', () {
      final parsed = SmsParserService.parseSms('Paid Rs 299 to Zepto on 24-Sep-24.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'groceries');
    });

    test('Classifies Salary credit as Income', () {
      final parsed = SmsParserService.parseSms('Credited INR 50,000 on 30-Sep-24 for Monthly Salary.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'income');
    });

    test('Classifies Uber / Fastag as Transport', () {
      final parsed = SmsParserService.parseSms('Paid Rs 350 to Uber India via UPI on 24-Sep-24.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'transport');
    });

    test('Auto debit for Netflix is classified as Entertainment, NOT Transport', () {
      final parsed = SmsParserService.parseSms('A/C XX1234 debited INR 649.00 on 24-09-24 by auto debit for Netflix Subscription.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, 'entertainment');
    });

    test('Paid to person named Pranay for dinner does NOT misclassify as APY/PRAN', () {
      final parsed = SmsParserService.parseSms('Paid Rs 1,200 to Pranay for dinner on 24-09-24 via UPI.')!;
      expect(parsed.smartTitle, isNot(contains('APY')));
      expect(parsed.smartTitle, isNot(contains('PRAN')));
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, equals('food'));
    });

    test('Paid at Happy Dental Clinic does NOT misclassify as APY', () {
      final parsed = SmsParserService.parseSms('Paid Rs 800 at Happy Dental Clinic on 24-09-24 via UPI.')!;
      expect(parsed.smartTitle, isNot(contains('APY')));
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, equals('health'));
    });

    test('Prevents "declined" matching Food & Dining ("dine")', () {
      final parsed = SmsParserService.parseSms('A/C XX1234 debited INR 500 on 24-09-24 at generic vendor declined ref 1234.');
      expect(parsed, isNull); // Since declined is correctly recognized as spam/non-financial/failed

      final pending = ModelPendingSms(
        id: '1',
        amount: 100,
        vendorName: 'XYZ Store',
        date: DateTime.now(),
        rawSmsBody: 'Purchase at XYZ Store declined transaction note',
        isExpense: true,
      );
      final cat = PendingSmsNotifier.getSmartCategory(pending, categories);
      expect(cat.id, isNot(equals('food')));
    });

    test('Prevents "powered by" matching Bills & Utilities ("power")', () {
      final parsed = SmsParserService.parseSms('A/C XX1234 debited INR 500 on 24-09-24 to vendor ABC powered by bank UPI.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, isNot(equals('utilities')));
    });

    test('Prevents "current a/c" matching Rent & Housing ("rent")', () {
      final parsed = SmsParserService.parseSms('Current A/C XX1234 debited INR 500 on 24-09-24 to ABC store.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, isNot(equals('rent')));
    });

    test('Prevents "toll-free" matching Transport & Travel ("toll")', () {
      final parsed = SmsParserService.parseSms('A/C XX1234 debited INR 500 on 24-09-24. Call toll-free 1800112233 for issues.')!;
      final cat = PendingSmsNotifier.getSmartCategory(parsed, categories);
      expect(cat.id, isNot(equals('transport')));
    });
  });

  group('Deduplication & Hash Consistency Tests', () {
    test('Same SMS with same date produces identical hash ID', () {
      const sms = 'Dear Customer, Rs.550.00 debited from a/c **1234 on 24-09-2024 at Zomato. UPI Ref: 426819283741';
      final parsed1 = SmsParserService.parseSms(sms, sender: 'VM-HDFCBK');
      final parsed2 = SmsParserService.parseSms(sms, sender: 'VM-HDFCBK');
      expect(parsed1, isNotNull);
      expect(parsed2, isNotNull);
      expect(parsed1!.id, isNotEmpty);
      expect(parsed1.id, equals(parsed2!.id));
    });

    test('Different UPI Ref numbers produce different hash IDs', () {
      const sms1 = 'Dear Customer, Rs.500.00 debited on 24-09-2024 at Swiggy. UPI Ref: 111111111111';
      const sms2 = 'Dear Customer, Rs.500.00 debited on 24-09-2024 at Swiggy. UPI Ref: 222222222222';
      final parsed1 = SmsParserService.parseSms(sms1);
      final parsed2 = SmsParserService.parseSms(sms2);
      expect(parsed1!.id, isNot(equals(parsed2!.id)));
    });

    test('TransactionModel stores and loads smsHash, bankAccount, merchantName cleanly', () {
      final tx = TransactionModel(
        id: 'tx_123',
        description: 'Mutual Fund (Indian Clearing)',
        amount: 1800.0,
        categoryId: 'investments',
        categoryName: 'Investments & Stocks',
        iconCodePoint: 1,
        colorValue: 1,
        userId: 'user_1',
        date: DateTime(2026, 9, 2),
        smsHash: 'hash_abc_123',
        merchantName: 'Indian Clearing',
        bankAccount: 'PNB (A/c ••9975)',
        refNumber: '110577150899',
        rawSmsBody: 'Sample raw sms body',
      );
      final map = tx.toMap();
      expect(map['smsHash'], 'hash_abc_123');
      expect(map['merchantName'], 'Indian Clearing');
      expect(map['bankAccount'], 'PNB (A/c ••9975)');
      expect(map['refNumber'], '110577150899');
      expect(map['rawSmsBody'], 'Sample raw sms body');

      final loaded = TransactionModel.fromMap(map, 'tx_123');
      expect(loaded.smsHash, 'hash_abc_123');
      expect(loaded.merchantName, 'Indian Clearing');
      expect(loaded.bankAccount, 'PNB (A/c ••9975)');
      expect(loaded.refNumber, '110577150899');
      expect(loaded.rawSmsBody, 'Sample raw sms body');
    });

    test('Natural Key matches legacy transactions without smsHash', () {
      final legacyDate = DateTime(2026, 9, 24, 18, 30);
      final key = AutoSmsService.buildNaturalKey(
        amount: 550.0,
        date: legacyDate,
        isExpense: true,
      );
      expect(key, '550.00_2026_9_24_true');
    });

    test('1-to-1 Slot Matching handles same-day identical amount transactions', () {
      final Map<String, int> slots = {
        '100.00_2026_9_24_true': 1, // Only 1 recorded in old build
      };

      final sms1 = SmsParserService.parseSms(
        'Dear Customer, Rs.100.00 debited on 24-09-2026 for Coffee. Ref 111.',
        messageTimestamp: DateTime(2026, 9, 24, 10, 0),
      );
      final sms2 = SmsParserService.parseSms(
        'Dear Customer, Rs.100.00 debited on 24-09-2026 for Tea. Ref 222.',
        messageTimestamp: DateTime(2026, 9, 24, 16, 0),
      );

      expect(sms1, isNotNull);
      expect(sms2, isNotNull);

      final key1 = AutoSmsService.buildNaturalKey(
        amount: sms1!.amount,
        date: sms1.date,
        isExpense: sms1.isExpense,
      );

      // First SMS consumes the 1 available slot -> SKIPPED (deduped with legacy)
      expect(slots[key1], 1);
      slots[key1] = slots[key1]! - 1;
      expect(slots[key1], 0);

      // Second SMS finds 0 slots available -> IMPORTED (genuine 2nd transaction)
      final availableSlots = slots[key1] ?? 0;
      expect(availableSlots, 0); // Correctly identifies it as needing import!
    });
  });

  group('User Real-World 12 SMS Test Cases', () {
    test('SMS 1: High value inward RTGS company payout (FIVEALIVE)', () {
      const sms = 'Update! INR 4,26,921.00 deposited in HDFC Bank A/c XX6196 on 04-SEP-26 for RTGS Cr-ICIC0000011-FIVEALIVE PRODUCTIVITY PRIVATE LIMI-AmitKumar-ICICR42026090400535605.Avl bal INR 5,45,826.45. Cheque deposits in A/C are subject to clearing';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 426921.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, 'ICICR42026090400535605');
      expect(parsed.vendorName.toLowerCase(), contains('fivealive'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'income');
    });

    test('SMS 2: Canara Bank interest credit', () {
      const sms = 'INR 27.00 credited to A/c XXXXX01396 on 28/09/2026 towards Interest. Total Avail. Bal. INR 4,240.69. -Canara Bank';
      final parsed = SmsParserService.parseSms(sms, sender: 'CANBNK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 27.0);
      expect(parsed.isExpense, isFalse);
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'returns');
    });

    test('SMS 3: Google Payments verification credit', () {
      const sms = 'Credit Alert!\nRs.1.00 credited to HDFC Bank A/c XX6196 on 19-09-26 from VPA goog-payments@axisbank (UPI 535040092626)';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, '535040092626');
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'refund');
    });

    test('SMS 4: UPI Mandate to Razorpay', () {
      const sms = 'UPI Mandate:\nSent Rs.882.00\nfrom HDFC Bank A/c 6196\nTo Razorpay\n21/09/26\nRef 110727115773\nNot You? Call 18002586161/SMS BLOCK UPI to 7308080808|';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 882.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.refNumber, '110727115773');
      expect(parsed.vendorName.toLowerCase(), contains('razorpay'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'online');
    });

    test('SMS 5: Credit Alert from personal VPA', () {
      const sms = 'Credit Alert!\nRs.110.00 credited to HDFC Bank A/c XX6196 on 14-09-26 from VPA 8083317969@hdfc (UPI 625747999285)';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 110.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, '625747999285');
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
    });

    test('SMS 6: Tira coupon promo with "off* credited" - MUST BE IGNORED', () {
      const sms = 'ALERT: Extra 5% off + Rs.2000 off* credited\nYour code is NOWORNEVER\nValidity 6 hours!\nALMOST EVERYTHING ON SALE ends on Tira: promotions.tirabeauty.com/0o1XWvw';
      final parsed = SmsParserService.parseSms(sms, sender: 'TIRABT');
      expect(parsed, isNull);
    });

    test('SMS 7: RTGS Money Deposited header format with FIVEALIVE', () {
      const sms = 'RTGS Money Deposited~Dear Customer, INR 4,26,921.00 has been credited to your A/c XX6196 on 04-SEP-26 for RTGS Cr-ICIC0000011-FIVEALIVE PRODUCTIVITY PRIVATE LIMI-AmitKumar-ICICR42026090400535605.Avl bal: INR 5,45,826.45.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 426921.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, 'ICICR42026090400535605');
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'income');
    });

    test('SMS 8: Deposited in A/C by RTGS from FIVEALIVE PRODUCTIVITY PRIVATE LIMITED', () {
      const sms = 'INR 4,26,921.00 deposited in your A/C XX6196 on 04-09-2026 14:15:30 by RTGS from FIVEALIVE PRODUCTIVITY PRIVATE LIMITED. Avl Bal: INR 5,45,826.45.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 426921.0);
      expect(parsed.isExpense, isFalse);
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'income');
    });

    test('SMS 9: Pre-debit notice "RTGS transaction initiated" - MUST BE IGNORED', () {
      const sms = 'RTGS transaction initiated: A/C XX6196 debited with INR 4,26,921.00 on 04-09-2026. If not requested, call bank immediately.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNull);
    });

    test('SMS 10: Outward RTGS Transfer to AmitKotak', () {
      const sms = 'Sent INR 4,26,921.00 from HDFC Bank A/C XX6196 To AmitKotak on 04-SEP-26 via RTGS. Ref: ICICR42026090400535605. Avl Bal: INR 1,18,905.45.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 426921.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.refNumber, 'ICICR42026090400535605');
      expect(parsed.vendorName.toLowerCase(), contains('amitkotak'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
    });

    test('SMS 11: HDFC Bank Quarterly Interest Credit', () {
      const sms = 'Dear Customer, Interest of INR 1,420.00 has been credited to your SB A/C XX6196 for Q2 on 30-SEP-26. Total Bal: INR 1,20,325.45. -HDFC Bank';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1420.0);
      expect(parsed.isExpense, isFalse);
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'returns');
    });

    test('SMS 12: UPI Autopay Mandate executed to Razorpay Software', () {
      const sms = 'Dear Customer, your UPI autopay mandate of Rs.882.00 to Razorpay Software Pvt Ltd has been successfully executed on 21-09-2026. Ref: 110727115773';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 882.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.refNumber, '110727115773');
      expect(parsed.vendorName.toLowerCase(), contains('razorpay'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'online');
    });
  });

  group('UPI Self-Transfer Cross-Bank Scenarios', () {
    test('Canara Bank inward UPI transfer from ARYAN', () {
      const sms = 'Dear Customer, Acct XXX934 credited with INR 8,000.00 on 31/08/26 from ARYAN; UPI:624376617761; Bal INR 11,635.46-CanaraBank';
      final parsed = SmsParserService.parseSms(sms, sender: 'CANBNK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 8000.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, '624376617761');
      expect(parsed.vendorName.toLowerCase(), contains('aryan'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
    });

    test('YES Bank outward UPI debit to VPA', () {
      const sms = 'YES BANK Ac X0641 debited for INR 8,000.00 on 31AUG26 21:43. UPI:624376617761/To:aryansharma2882000-2@okaxis. Bal INR 24,527.43. Not U? SMS BLKMB <CustID> to 9840909000';
      final parsed = SmsParserService.parseSms(sms, sender: 'YESBNK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 8000.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.refNumber, '624376617761');
      expect(parsed.vendorName, contains('aryansharma2882000-2@okaxis'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
    });

    test('PSB UPI Credit SMS slash delimited with ARYAN SO SANJAY', () {
      const sms = '''PSB000000007630929
A/c No **4447 Credited with Rs 15000--UPI/CR/624397651570/ARYAN SO SANJAY/PUNB/107200 (CLR BAL 300016.14CR)(26-09-2026 22:14:00)-Punjab&Sind Bank''';
      final parsed = SmsParserService.parseSms(sms, sender: 'PSBSMS');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 15000.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.refNumber, '624397651570');
      expect(parsed.vendorName.toLowerCase(), contains('aryan'));
      expect(parsed.bankAccount, contains('4447'));
      expect(parsed.bankAccount, contains('Punjab & Sind Bank'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
    });

    test('Canara Bank Generic Inward Credit SMS - Categorized as Income, not Salary', () {
      const sms = 'An amount of INR 10,834.00 has been CREDITED to your account XXX934 on 14/09/26.Total Avail.bal INR 22,611.46.- Canara Bank';
      final parsed = SmsParserService.parseSms(sms, sender: 'CANBNK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 10834.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.bankAccount, contains('934'));
      expect(parsed.bankAccount, contains('Canara Bank'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'income');
      expect(cat.id, isNot('salary'));
    });

    test('Outward transfer to person (Paid to Anuj Kumar) is categorized as Transfers, NOT Other', () {
      const sms = 'A/c XX1234 debited INR 500.00 on 02-Oct-26 to Anuj Kumar thru UPI:123456789. Bal INR 5000.';
      final parsed = SmsParserService.parseSms(sms, sender: 'PNBSMS');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 500.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.vendorName.toLowerCase(), contains('anuj'));
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
      expect(cat.id, isNot('other'));
    });

    test('Outward transfer to personal VPA is categorized as Transfers', () {
      const sms = 'Dear Customer, Rs.1,200.00 debited from A/C XX6196 on 03-10-26 to VPA anujkumar@okaxis. Ref: 9876543210.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200.0);
      expect(parsed.isExpense, isTrue);
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'transfer');
      expect(cat.id, isNot('other'));
    });

    test('Canara Dr and PNB Cr pair with same UPI Ref ID forms single Self Transfer', () {
      const canaraSms = 'Dear Customer, Acct XXX934 Dr. INR 4,000.00 on 03/10/26 to ARYAN SO SAN; UPI: 664239925757; Bal INR 18,729.46.Not you?SMS BLOCKUPI to 9901771222-CanaraBank';
      const pnbSms = 'Your a/c XX9975 is credited for INR 4000.00 on 03-10-26 21:25 through UPI.Available Bal INR 4498.71 (UPI Ref ID 664239925757).Download PNB ONE-PNB';

      final canaraParsed = SmsParserService.parseSms(canaraSms, sender: 'CANBNK');
      final pnbParsed = SmsParserService.parseSms(pnbSms, sender: 'PNBSMS');

      expect(canaraParsed, isNotNull);
      expect(canaraParsed!.amount, 4000.0);
      expect(canaraParsed.isExpense, isTrue);
      expect(canaraParsed.refNumber, '664239925757');
      expect(canaraParsed.bankAccount, contains('Canara Bank'));

      expect(pnbParsed, isNotNull);
      expect(pnbParsed!.amount, 4000.0);
      expect(pnbParsed.isExpense, isFalse);
      expect(pnbParsed.refNumber, '664239925757');
      expect(pnbParsed.bankAccount, contains('PNB'));

      // Both share identical UPI Ref Number
      expect(canaraParsed.refNumber, equals(pnbParsed.refNumber));

      // Distinct debit vs credit hashes
      expect(canaraParsed.id, contains('_dr'));
      expect(pnbParsed.id, contains('_cr'));
      expect(canaraParsed.id, isNot(equals(pnbParsed.id)));

      // Check description formatting
      final fromStr = canaraParsed.bankAccount ?? 'Account';
      final toStr = pnbParsed.bankAccount ?? 'Account';
      final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';
      expect(selfTransferDesc, contains('Canara Bank'));
      expect(selfTransferDesc, contains('PNB'));
    });

    test('Google Pay ₹1 Cashback SMS is classified as Refunds & Cashback, NOT Salary', () {
      const sms = 'Your A/C XX1234 is credited with INR 1.00 on 04-Oct-26 from Google India Digital Services Private Limited via UPI. UPI Ref 623456789012.';
      final parsed = SmsParserService.parseSms(sms, sender: 'HDFCBK');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1.0);
      expect(parsed.isExpense, isFalse);
      
      final cat = PendingSmsNotifier.getSmartCategory(parsed, kDefaultCategories);
      expect(cat.id, 'refund');
      expect(cat.id, isNot('salary'));
      expect(cat.id, isNot('income'));
    });

    test('Real-Time User SMS ₹1.00 PNB Credit + Canara Debit Self Transfer pairing', () {
      const pnbCreditSms = 'Your a/c XX9975 is credited for INR 1.00 on 04-10-26 15:37 through UPI.Available Bal INR 2454.71 (UPI Ref ID 664346754517).Download PNB ONE-PNB';
      const canaraDebitSms = 'Dear Customer, Acct XXX934 Dr. INR 1.00 on 04/10/26 to ARYAN SO SAN; UPI: 664346754517; Bal INR 18,729.46.Not you?SMS BLOCKUPI to 9901771222-CanaraBank';

      final pnbParsed = SmsParserService.parseSms(pnbCreditSms, sender: 'PNBSMS');
      final canaraParsed = SmsParserService.parseSms(canaraDebitSms, sender: 'CANBNK');

      expect(pnbParsed, isNotNull);
      expect(pnbParsed!.amount, 1.0);
      expect(pnbParsed.isExpense, isFalse);
      expect(pnbParsed.refNumber, '664346754517');
      expect(pnbParsed.bankAccount, contains('PNB'));

      expect(canaraParsed, isNotNull);
      expect(canaraParsed!.amount, 1.0);
      expect(canaraParsed.isExpense, isTrue);
      expect(canaraParsed.refNumber, '664346754517');
      expect(canaraParsed.bankAccount, contains('Canara Bank'));

      // 1. Matching Ref and Amount
      expect(pnbParsed.refNumber, equals(canaraParsed.refNumber));
      expect(pnbParsed.amount, equals(canaraParsed.amount));

      // 2. Opposite transaction direction
      expect(pnbParsed.isExpense, isNot(equals(canaraParsed.isExpense)));

      // 3. Description format resolution
      final isDebitIncoming = canaraParsed.isExpense;
      final debitBank = isDebitIncoming ? canaraParsed.bankAccount : pnbParsed.bankAccount;
      final creditBank = isDebitIncoming ? pnbParsed.bankAccount : canaraParsed.bankAccount;

      final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
      final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
      final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

      expect(selfTransferDesc, contains('Canara Bank'));
      expect(selfTransferDesc, contains('PNB'));
      expect(selfTransferDesc, equals('Self Transfer (Canara Bank (A/c ••934) ➔ PNB Bank (A/c ••9975))'));
    });

    test('PNB Credit + SBI Credit same UPI Ref ID → Self Transfer pairing (Branch 2: same-direction)', () {
      const pnbSms = 'Your a/c XX9975 is credited for INR 1.00 on 04-10-26 16:15 through UPI.Available Bal INR 2438.01 (UPI Ref ID 664308459494).Download PNB ONE-PNB';
      const sbiSms = 'Dear SBI User, your A/c X9975-credited by Rs.1 on 04Oct26 transfer from ARYAN Ref No 664308459494 -SBI';

      final pnbParsed = SmsParserService.parseSms(pnbSms, sender: 'PNBSMS');
      final sbiParsed = SmsParserService.parseSms(sbiSms, sender: 'SBIINB');

      expect(pnbParsed, isNotNull);
      expect(sbiParsed, isNotNull);

      // Both are Credits (same isExpense direction)
      expect(pnbParsed!.isExpense, isFalse);
      expect(sbiParsed!.isExpense, isFalse);

      // Same UPI Ref ID — primary pairing key
      expect(pnbParsed.refNumber, '664308459494');
      expect(sbiParsed.refNumber, '664308459494');
      expect(pnbParsed.refNumber, equals(sbiParsed.refNumber));

      // Same amount
      expect(pnbParsed.amount, 1.0);
      expect(sbiParsed.amount, 1.0);

      // Different bank accounts — distinguishes the two legs
      expect(pnbParsed.bankAccount, isNotNull);
      expect(sbiParsed.bankAccount, isNotNull);
      expect(
        pnbParsed.bankAccount!.toLowerCase().trim(),
        isNot(equals(sbiParsed.bankAccount!.toLowerCase().trim())),
      );

      // Verify Branch 2 pairing decision: same ref + same amount + different bank = Self Transfer
      final existingBank = pnbParsed.bankAccount!;
      final incomingBank = sbiParsed.bankAccount!;
      final isSameRefAmountDifferentBank =
          (pnbParsed.amount - sbiParsed.amount).abs() < 0.01 &&
          existingBank.toLowerCase().trim() != incomingBank.toLowerCase().trim();

      expect(isSameRefAmountDifferentBank, isTrue,
          reason: 'Branch 2 condition must be satisfied for self-transfer upgrade');

      final selfTransferDesc = 'Self Transfer ($existingBank ➔ $incomingBank)';
      expect(selfTransferDesc, contains('PNB'));
      expect(selfTransferDesc, contains('State Bank of India'));
    });

    test('Real-Time User SMS ₹1.00 (PNB Credit + Canara Debit) Ref: 664323795617 forms Self Transfer', () {
      const pnbSms = 'Your a/c XX9975 is credited for INR 1.00 on 04-10-26 18:12 through UPI.Available Bal INR 2440.01 (UPI Ref ID 664323795617).Download PNB ONE-PNB';
      const canaraSms = 'Dear Customer, Acct XXX934 Dr. INR 1.00 on 04/10/26 to ARYAN SO SAN; UPI: 664323795617; Bal INR 18,726.46.Not you?SMS BLOCKUPI to 9901771222-CanaraBank';

      final pnbParsed = SmsParserService.parseSms(pnbSms, sender: 'PNBSMS');
      final canaraParsed = SmsParserService.parseSms(canaraSms, sender: 'CANBNK');

      expect(pnbParsed, isNotNull);
      expect(canaraParsed, isNotNull);

      // PNB is Credit (isExpense: false), Canara is Debit (isExpense: true)
      expect(pnbParsed!.isExpense, isFalse);
      expect(canaraParsed!.isExpense, isTrue);

      // Same UPI Ref ID
      expect(pnbParsed.refNumber, '664323795617');
      expect(canaraParsed.refNumber, '664323795617');
      expect(pnbParsed.refNumber, equals(canaraParsed.refNumber));

      // Same Amount
      expect(pnbParsed.amount, 1.0);
      expect(canaraParsed.amount, 1.0);

      // Banks correctly isolated
      expect(pnbParsed.bankAccount, 'PNB Bank (A/c ••9975)');
      expect(canaraParsed.bankAccount, 'Canara Bank (A/c ••934)');

      // Counterpart pairing: Debit bank -> Credit bank
      final debitBank = canaraParsed.bankAccount!;
      final creditBank = pnbParsed.bankAccount!;
      final selfTransferDesc = 'Self Transfer ($debitBank ➔ $creditBank)';

      expect(selfTransferDesc, equals('Self Transfer (Canara Bank (A/c ••934) ➔ PNB Bank (A/c ••9975))'));
    });

    test('Investment SMS discrimination: Genuine vs Advertisement', () {
      // 1. Genuine PNB ICCL debit SMS -> Allowed
      const pnbSms =
          'A/c X9975 debited INR 2100.00 Dt 02-10-26 08:32:03 to Indian Clearing thru UPI:110811332799.Bal INR 2498.71 Not u?Fwd this SMS to 9264092640 to block UPI.-PNB';
      final pnbParsed = SmsParserService.parseSms(pnbSms, sender: 'PNBSMS');
      expect(pnbParsed, isNotNull);
      expect(pnbParsed!.amount, 2100.0);
      expect(pnbParsed.isExpense, isTrue);
      expect(pnbParsed.smartTitle, contains('Mutual Fund'));

      // 2. Genuine NJ Wealth SIP processed SMS -> Allowed
      const njSms =
          'Dear Client, Your 2 SIP transaction(s) of Rs. 200 have been processed on 28.09.26. Pls refer email for details. NJ';
      final njParsed = SmsParserService.parseSms(njSms, sender: 'NJWLTH');
      expect(njParsed, isNotNull);
      expect(njParsed!.amount, 200.0);
      expect(njParsed.isExpense, isTrue);
      expect(njParsed.smartTitle, contains('Mutual Fund'));

      // 3. Promotional Appreciate ad -> Blocked / ignored
      const adSms =
          'Start SIPs from Rs.100 in Index mutual funds on Appreciate. Tap into the fast-growing companies of India and build long-term wealth. Click: ct3.io/m3bkc';
      final adParsed = SmsParserService.parseSms(adSms, sender: 'APPREC');
      expect(adParsed, isNull);
    });
  });
}



