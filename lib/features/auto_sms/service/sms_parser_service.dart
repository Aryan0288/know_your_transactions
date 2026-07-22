import '../model/model_pending_sms.dart';

class SmsParserService {
  /// Parses raw SMS body and extracts financial details if it matches debit/credit patterns.
  /// Returns [ModelPendingSms] if parsed successfully, or `null` if ignored/non-financial/OTP/spam.
  static ModelPendingSms? parseSms(String body) {
    if (body.isEmpty) return null;

    final lower = body.toLowerCase();

    // 1. Ignore OTPs, promotional, security codes
    if (lower.contains('otp') ||
        lower.contains('secret code') ||
        lower.contains('verification code') ||
        lower.contains('do not share')) {
      return null;
    }

    // 2. Check explicit self-transfers (optional ignore)
    if (lower.contains('self transfer') ||
        lower.contains('transfer to own a/c') ||
        lower.contains('own account transfer')) {
      return null;
    }

    // 3. Determine if Debit (Expense) or Credit (Income)
    final bool isExpense = _isDebit(lower);
    final bool isCredit = _isCredit(lower);

    if (!isExpense && !isCredit) {
      return null; // Not a transaction SMS
    }

    // 4. Extract Amount
    final double? amount = _extractAmount(body);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 5. Extract Vendor / Merchant / Payee Name using Multi-Pass Parsing
    final String vendorName = _extractVendor(body, lower);

    // 6. Generate Unique Hash ID to prevent duplicates
    final String hashId = _generateSmsHash(amount, vendorName, body);

    return ModelPendingSms(
      id: hashId,
      amount: amount,
      vendorName: vendorName,
      date: DateTime.now(),
      paymentMode: lower.contains('cash') ? 'cash' : 'online',
      isExpense: isExpense,
      rawSmsBody: body,
      status: 'pending',
    );
  }

  static bool _isDebit(String lower) {
    return lower.contains('debited') ||
        lower.contains('paid to') ||
        lower.contains('spent') ||
        lower.contains('sent to') ||
        lower.contains('txn of rs') ||
        lower.contains('transaction of rs') ||
        lower.contains('vpa') ||
        lower.contains('upi/p2m') ||
        lower.contains('upi/p2a');
  }

  static bool _isCredit(String lower) {
    return lower.contains('credited') ||
        lower.contains('received rs') ||
        lower.contains('added to account') ||
        lower.contains('deposited');
  }

  static double? _extractAmount(String body) {
    // Regex matches formats: Rs. 450.00, Rs 450, INR 1,250.50, INR 500, etc.
    final RegExp amountRegExp = RegExp(
      r'(?:rs\.?|inr\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    final match = amountRegExp.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final cleanAmount = match.group(1)!.replaceAll(',', '');
      return double.tryParse(cleanAmount);
    }
    return null;
  }

  static String _extractVendor(String body, String lower) {
    final String delimiters = r'(?:\s+(?:thru|through|via|using|by|towards|on|ref|vpa|upi|avail|bal|a/c|dt|date|is|\:|\.|$))';

    // Pass 1: Direct Payee transfers ("to Bhanu thru UPI", "paid to Ramesh ref")
    final RegExp pass1RegExp = RegExp(
      r'(?:to|paid to|sent to)\s+([A-Za-z0-9\s._-]+?)' + delimiters,
      caseSensitive: false,
    );
    final match1 = pass1RegExp.firstMatch(body);
    if (match1 != null && match1.group(1) != null) {
      final vendor = _cleanVendorString(match1.group(1)!);
      if (vendor.isNotEmpty && !_isGenericNoiseWord(vendor)) {
        return _capitalize(vendor);
      }
    }

    // Pass 2: Merchant & Store debits ("at Zomato on", "for Starbucks ref")
    final RegExp pass2RegExp = RegExp(
      r'(?:at|vpa|info|for|towards|merchant)\s+([A-Za-z0-9\s._-]+?)' + delimiters,
      caseSensitive: false,
    );
    final match2 = pass2RegExp.firstMatch(body);
    if (match2 != null && match2.group(1) != null) {
      final vendor = _cleanVendorString(match2.group(1)!);
      if (vendor.isNotEmpty && !_isGenericNoiseWord(vendor)) {
        return _capitalize(vendor);
      }
    }

    // Pass 3: VPA handle extraction ("swiggy@icici", "zomato@upi")
    final RegExp pass3RegExp = RegExp(
      r'([A-Za-z0-9._-]+)@(?:upi|ybl|paytm|icici|axis|okicici|okhdfcbank|okaxis|sbi)',
      caseSensitive: false,
    );
    final match3 = pass3RegExp.firstMatch(body);
    if (match3 != null && match3.group(1) != null) {
      String handle = match3.group(1)!.replaceAll(RegExp(r'[._-]'), ' ').trim();
      final vendor = _cleanVendorString(handle);
      if (vendor.isNotEmpty && !_isGenericNoiseWord(vendor)) {
        return _capitalize(vendor);
      }
    }

    return 'Bank Transfer (UPI)';
  }

  static String _cleanVendorString(String raw) {
    String cleaned = raw.trim();
    // Remove unwanted leading/trailing numbers or symbols if attached
    cleaned = cleaned.replaceAll(RegExp(r'^(?:vpa|ref|txn|id|\:|\-)\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+(?:thru|through|via|upi|vpa|ref|bal|a/c).*$'), '');
    
    if (cleaned.length > 30) {
      cleaned = cleaned.substring(0, 30);
    }
    return cleaned.trim();
  }

  static bool _isGenericNoiseWord(String word) {
    final lower = word.toLowerCase();
    return lower == 'your' ||
        lower == 'bank' ||
        lower == 'account' ||
        lower == 'upi' ||
        lower == 'vpa' ||
        lower == 'a/c' ||
        lower.length < 2;
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _generateSmsHash(double amount, String vendor, String body) {
    final raw = '${amount.toStringAsFixed(2)}_${vendor.toLowerCase()}_${body.length}';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }
}
