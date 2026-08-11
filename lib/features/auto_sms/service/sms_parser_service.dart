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

    // 6. Extract Date & Time from SMS body
    final dateTimeResult = _extractDateTime(body);
    final DateTime smsDate = dateTimeResult['dateTime'] as DateTime;
    final String dateRaw = dateTimeResult['raw'] as String;

    // 7. Extract Reference / UPI Ref / Txn ID
    final String? refNo = _extractReference(body);

    // 8. Generate Unique Hash ID (based on Date/Time & UPI Ref, excluding amount)
    final String hashId = _generateSmsHash(vendorName, refNo, dateRaw, body);

    return ModelPendingSms(
      id: hashId,
      amount: amount,
      vendorName: vendorName,
      date: smsDate,
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

  static String? _extractReference(String body) {
    // Matches UPI:62139832749516, UPI/62139832749516, Ref 62139832749516, RRN 62139832749516, Txn ID 62139832749516
    final RegExp refRegExp = RegExp(
      r'(?:upi|ref|ref\s*no|rrn|txn\s*id|info)[\:\/\s\-]*([a-zA-Z0-9]{6,25})',
      caseSensitive: false,
    );
    final match = refRegExp.firstMatch(body);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return null;
  }

  static Map<String, dynamic> _extractDateTime(String body) {
    final RegExp dateTimeRegExp = RegExp(
      r'(?:dt|date|on)?\s*(\d{2}[\/\-]\d{2}[\/\-]\d{2,4}(?:\s+\d{2}:\d{2}(?::\d{2})?)?)',
      caseSensitive: false,
    );

    final match = dateTimeRegExp.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final str = match.group(1)!.trim();
      final parsedDate = _parseDateString(str);
      return {
        'raw': str.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
        'dateTime': parsedDate ?? DateTime.now(),
      };
    }

    return {
      'raw': '',
      'dateTime': DateTime.now(),
    };
  }

  static DateTime? _parseDateString(String str) {
    try {
      final parts = str.trim().split(RegExp(r'\s+'));
      final datePart = parts[0];
      final timePart = parts.length > 1 ? parts[1] : '00:00:00';

      final dateComponents = datePart.split(RegExp(r'[\/\-]'));
      if (dateComponents.length == 3) {
        int day = int.parse(dateComponents[0]);
        int month = int.parse(dateComponents[1]);
        int year = int.parse(dateComponents[2]);
        if (year < 100) year += 2000;

        final timeComponents = timePart.split(':');
        int hour = timeComponents.isNotEmpty ? int.parse(timeComponents[0]) : 0;
        int minute = timeComponents.length > 1 ? int.parse(timeComponents[1]) : 0;
        int second = timeComponents.length > 2 ? int.parse(timeComponents[2]) : 0;

        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (_) {}
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

  static String _generateSmsHash(
    String vendor,
    String? refNo,
    String dateRaw,
    String body,
  ) {
    final String cleanVendor = vendor.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String cleanRef = (refNo ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String cleanDate = dateRaw.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (cleanRef.isNotEmpty || cleanDate.isNotEmpty) {
      return 'hash_${cleanRef}_${cleanDate}_$cleanVendor';
    }

    // Fallback if neither ref nor date string found: body text fingerprint without digits
    final String bodyNoNumbers = body.replaceAll(RegExp(r'\d+'), '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final String fallbackSnippet = bodyNoNumbers.length > 30 ? bodyNoNumbers.substring(0, 30) : bodyNoNumbers;
    return 'hash_${cleanVendor}_$fallbackSnippet';
  }
}
