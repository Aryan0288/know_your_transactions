import '../model/model_pending_sms.dart';

class SmsParserService {
  /// Parses raw SMS body and extracts financial details if it matches debit/credit patterns.
  /// Returns [ModelPendingSms] if parsed successfully, or `null` if ignored/non-financial/OTP/spam.
  static ModelPendingSms? parseSms(String body, {String? sender, DateTime? messageTimestamp}) {
    if (body.isEmpty) return null;

    final lower = body.toLowerCase();

    // 1. Ignore OTPs, promotional, failed/declined transactions, requests
    if (_isSpamOrNonFinancial(lower)) {
      return null;
    }

    // 2. Determine if Debit (Expense) or Credit (Income)
    bool isCredit = _isCredit(lower);
    bool isExpense = _isDebit(lower);

    // Contextual Override 1: Telecom / Recharges take absolute priority over "credited"
    if (lower.contains('recharge') ||
        lower.contains('prepaid') ||
        lower.contains('postpaid')) {
      isExpense = true;
      isCredit = false;
    }

    // Contextual Override 2: APY / PRAN / NPS Pension Contributions take absolute priority over "credited to your PRAN"
    final bool isPensionContribution = (lower.contains('contribution') ||
            lower.contains('contributed') ||
            lower.contains('installment')) &&
        (lower.contains('pran') ||
            lower.contains('apy') ||
            lower.contains('nps') ||
            lower.contains('atal pension') ||
            lower.contains('protean') ||
            lower.contains('pfrda'));

    if (isPensionContribution) {
      isExpense = true;
      isCredit = false;
    }

    // Conflict Resolution: Inward credit markers take absolute priority over generic/ambiguous debit words
    if (isCredit && isExpense) {
      if (lower.contains('deposited') ||
          lower.contains('deposit of') ||
          lower.contains('rtgs cr') ||
          lower.contains('neft cr') ||
          lower.contains('imps cr') ||
          lower.contains('credited to') ||
          lower.contains('credit alert') ||
          lower.contains('received from') ||
          lower.contains('towards interest') ||
          lower.contains('interest credited') ||
          lower.contains('refund') ||
          lower.contains('cashback')) {
        isExpense = false;
      } else {
        isCredit = false;
      }
    }

    if (!isExpense && !isCredit) {
      return null; // Not a transaction SMS
    }

    // 3. Extract Amount (with balance isolation to prevent capturing remaining account balance)
    final double? amount = _extractAmount(body);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 4. Extract Vendor / Merchant / Payee Name using Multi-Pass Parsing
    final String vendorName = _extractVendor(body, lower, sender);

    // 5. Extract Date & Time from SMS body or fallback to message timestamp
    final dateTimeResult = _extractDateTime(body, fallbackDate: messageTimestamp);
    final DateTime smsDate = dateTimeResult['dateTime'] as DateTime;
    final String dateRaw = dateTimeResult['raw'] as String;

    // 6. Extract Reference / UPI Ref / Txn ID
    final String? refNo = extractReference(body);

    // 7. Extract Bank Account & Card Details
    final String? bankAccount = _extractBankAccount(body, sender);

    // 8. Generate Smart Title & Description
    final smartDetails = generateSmartDetails(vendorName, body, isExpense);

    // 9. Generate Unique Hash ID (based on Date/Time, Reference, Vendor, Amount, and Flow Direction)
    final String hashId = _generateSmsHash(vendorName, refNo, dateRaw, amount, body, isExpense: isExpense);

    return ModelPendingSms(
      id: hashId,
      amount: amount,
      vendorName: vendorName,
      date: smsDate,
      paymentMode: lower.contains('cash') ? 'cash' : 'online',
      isExpense: isExpense,
      rawSmsBody: body,
      status: 'pending',
      merchantName: vendorName,
      bankAccount: bankAccount,
      refNumber: refNo,
      smartTitle: smartDetails['title'],
    );
  }

  static bool _isSpamOrNonFinancial(String lower) {
    // 0. Receipt Exemption: If this is an explicit completed recharge/payment receipt with a Txn ID or Ref, do not flag as spam!
    final bool isCompletedReceipt = (lower.contains('recharge successful') ||
            lower.contains('payment successful') ||
            lower.contains('transaction successful') ||
            lower.contains('recharge done') ||
            lower.contains('recharge processed')) &&
        (lower.contains('transaction id') ||
            lower.contains('txn id') ||
            lower.contains('ref no') ||
            lower.contains('ref id') ||
            lower.contains('ref:') ||
            lower.contains('rrn'));

    if (isCompletedReceipt) {
      return false;
    }

    // 1. Security & OTP codes
    if (lower.contains('otp') ||
        lower.contains('secret code') ||
        lower.contains('verification code') ||
        lower.contains('do not share') ||
        lower.contains('one time password')) {
      return true;
    }

    // 2. Failed or declined transactions
    if (lower.contains('failed') ||
        lower.contains('declined') ||
        lower.contains('unsuccessful') ||
        lower.contains('could not be processed')) {
      return true;
    }

    // 3. Marketing, Discounts, Sales & Promotional Ads (Flipkart, Myntra, Amazon, Tira Beauty, Swiggy, Zomato, etc.)
    if (lower.contains('save ₹') ||
        lower.contains('save rs') ||
        lower.contains('save inr') ||
        lower.contains('limited time offer') ||
        lower.contains('offer valid') ||
        lower.contains('celebrate with') ||
        lower.contains('happy birthday') ||
        lower.contains('freedom pack') ||
        lower.contains('exclusive offer') ||
        lower.contains('special offer') ||
        lower.contains('congratulations') ||
        lower.contains('use code') ||
        lower.contains('coupon code') ||
        lower.contains('promo code') ||
        lower.contains('use coupon') ||
        lower.contains('your code') ||
        lower.contains('discount up to') ||
        lower.contains('discount of') ||
        lower.contains('sale is live') ||
        lower.contains('big billion') ||
        lower.contains('mega sale') ||
        lower.contains('festive sale') ||
        lower.contains('shop now') ||
        lower.contains('buy now') ||
        lower.contains('order now') ||
        lower.contains('book now') ||
        lower.contains('hurry') ||
        lower.contains('free delivery on') ||
        lower.contains('cashback up to') ||
        lower.contains('cashback of up to') ||
        lower.contains('at checkout') ||
        lower.contains('sale ends on') ||
        lower.contains('ends on tira') ||
        lower.contains('promotions.') ||
        RegExp(r'validity\s*\d+\s*(?:hours?|days?|hrs?)', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'(?:rs\.?|inr\.?|₹)?\s*[\d,]+\s*(?:off|\*|\%)\s*credited', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'credited\s+with\s+(?:rs\.?|inr\.?|₹)?\s*[\d,]+\*?\s*off', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'extra\s*\d+%\s*off', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'flat\s*(?:rs\.?|inr\.?|₹|\d+%)', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'get\s*(?:rs\.?|inr\.?|₹|\d+%)\s*off', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // 4. Telecom Plan Expiry, Queued Pack Alerts & Recharge Reminders
    if (lower.contains('recharge now') ||
        lower.contains('recharge with') ||
        lower.contains('recharge for') ||
        lower.contains('plan is expiring') ||
        lower.contains('plan expiring') ||
        lower.contains('pack expiring') ||
        lower.contains('plan expired') ||
        lower.contains('has expired on') ||
        lower.contains('plan has expired') ||
        lower.contains('already recharged with') ||
        lower.contains('will automatically get activated') ||
        lower.contains('upcoming plan') ||
        lower.contains('dial 1991') ||
        lower.contains('data quota exhausted') ||
        lower.contains('daily data limit') ||
        lower.contains('data booster at') ||
        lower.contains('t&c apply') ||
        lower.contains('t&c') ||
        lower.contains('tiny.jio.com/freedom') ||
        lower.contains('jio.com/r/') ||
        lower.contains('upgrade your plan') ||
        lower.contains('switch to')) {
      return true;
    }

    // 5. Loan & Investment Marketing / Pre-approved offers
    if (lower.contains('pre-approved') ||
        lower.contains('pre approved') ||
        lower.contains('apply now') ||
        lower.contains('click here') ||
        lower.contains('avail loan') ||
        lower.contains('loan approved') ||
        lower.contains('credit limit is') ||
        lower.contains('credit limit increase') ||
        lower.contains('zero processing fee') ||
        // Investment Marketing & Broker Promos
        lower.contains('start sip') ||
        lower.contains('start sips') ||
        lower.contains('start investing') ||
        lower.contains('invest from') ||
        lower.contains('build wealth') ||
        lower.contains('grow wealth') ||
        lower.contains('open demat') ||
        lower.contains('open trading account')) {
      return true;
    }

    // 6. Credit Card Statements & Bill Due Alerts (Not yet paid / Prevents double counting)
    if (lower.contains('total amt due') ||
        lower.contains('total amount due') ||
        lower.contains('min amt due') ||
        lower.contains('minimum amount due') ||
        lower.contains('min due:') ||
        lower.contains('min due rs') ||
        lower.contains('statement generated') ||
        lower.contains('e-statement') ||
        lower.contains('bill due on') ||
        lower.contains('e-bill generated') ||
        lower.contains('e-bill for')) {
      return true;
    }

    // 7. E-Mandate / SIP / Autopay Registrations & Banking In-Clearing (Zero money moved)
    if (((lower.contains('mandate') ||
                lower.contains('autopay') ||
                lower.contains('auto-pay') ||
                lower.contains('sip')) &&
            (lower.contains('registered') ||
                lower.contains('created') ||
                lower.contains('approved') ||
                lower.contains('setup') ||
                lower.contains('set up') ||
                lower.contains('modified') ||
                lower.contains('cancelled'))) ||
        lower.contains('sent for clearing') ||
        lower.contains('inward clearing') ||
        lower.contains('cheque deposited for clearing') ||
        lower.contains('cheque returned') ||
        lower.contains('average monthly balance') ||
        lower.contains('min required rs') ||
        lower.contains('maintain balance')) {
      return true;
    }

    // 8. FASTag Low Balance & Blacklist Warnings
    if (lower.contains('low balance in fastag') ||
        lower.contains('fastag balance is low') ||
        lower.contains('low fastag balance') ||
        lower.contains('recharge fastag to avoid')) {
      return true;
    }

    // 9. Delivery & COD Order Updates
    if (lower.contains('out for delivery') ||
        lower.contains('keep exact cash') ||
        lower.contains('order delivered') ||
        lower.contains('track your order')) {
      return true;
    }

    // 10. Virtual Rewards & Game Coins (Fake Incomes)
    if (lower.contains('supercoins') ||
        lower.contains('neucoins') ||
        lower.contains('reward points') ||
        lower.contains('points credited') ||
        lower.contains('coins credited') ||
        lower.contains('scratch card')) {
      return true;
    }

    // 11. Payment collect requests, pre-debit notices / Reminders (not yet completed / non-settled)
    if (lower.contains('request to pay') ||
        lower.contains('requested money') ||
        lower.contains('request received') ||
        lower.contains('due date is') ||
        lower.contains('is due on') ||
        lower.contains('due on') ||
        lower.contains('ensure availability of fund') ||
        lower.contains('ensure availability of funds') ||
        lower.contains('mandate debit') ||
        lower.contains('nach mandate') ||
        lower.contains('bill generated') ||
        lower.contains('payment due') ||
        lower.contains('will be debited on') ||
        lower.contains('scheduled for debit') ||
        RegExp(r'\b(?:rtgs|neft|imps|upi|transaction|payment|transfer)\s+(?:transaction\s+)?initiated\b', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'\binitiated\s*:\s*(?:of\s*)?(?:rs\.?|inr\.?|₹)', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    return false;
  }

  static bool _isDebit(String lower) {
    return lower.contains('debited') ||
        lower.contains('paid to') ||
        lower.contains('paid rs') ||
        lower.contains('paid inr') ||
        lower.contains('paid ₹') ||
        lower.contains('spent on') ||
        lower.contains('spent at') ||
        lower.contains('spent inr') ||
        lower.contains('spent rs') ||
        lower.contains('transferred to') ||
        lower.contains('transferred rs') ||
        lower.contains('transferred inr') ||
        lower.contains('transfer of') ||
        lower.contains('withdrawn') ||
        lower.contains('withdrawal') ||
        lower.contains('charged') ||
        lower.contains('txn of') ||
        lower.contains('transaction of') ||
        lower.contains('dr-rs') ||
        lower.contains('dr.') ||
        lower.contains('dr ') ||
        lower.contains('rtgs dr') ||
        lower.contains('neft dr') ||
        lower.contains('imps dr') ||
        lower.contains('sent rs') ||
        lower.contains('sent inr') ||
        lower.contains('sent ₹') ||
        lower.contains('recharge successful') ||
        lower.contains('recharge done') ||
        lower.contains('recharge processed') ||
        lower.contains('recharge of') ||
        lower.contains('bill payment') ||
        lower.contains('autopay') ||
        lower.contains('mandate') ||
        RegExp(r'\bsip\b').hasMatch(lower) ||
        lower.contains('mutual fund') ||
        lower.contains('vpa') ||
        lower.contains('upi/p2m') ||
        lower.contains('upi/p2a') ||
        lower.contains('used at') ||
        lower.contains('swiped at') ||
        lower.contains('pos txn') ||
        lower.contains('atm wdl') ||
        lower.contains('deducted') ||
        lower.contains('auto-debit') ||
        lower.contains('auto debit');
  }

  static bool _isCredit(String lower) {
    return lower.contains('credited') ||
        lower.contains('received from') ||
        lower.contains('received rs') ||
        lower.contains('received inr') ||
        lower.contains('received ₹') ||
        lower.contains('added to account') ||
        lower.contains('added to your account') ||
        lower.contains('deposited') ||
        lower.contains('deposit of') ||
        lower.contains('rtgs cr') ||
        lower.contains('neft cr') ||
        lower.contains('imps cr') ||
        lower.contains('cr-rs') ||
        lower.contains('cr.') ||
        lower.contains('cr ') ||
        lower.contains('refund') ||
        lower.contains('cashback') ||
        lower.contains('salary') ||
        lower.contains('towards interest') ||
        lower.contains('interest credited') ||
        lower.contains('dividend') ||
        lower.contains('reversed') ||
        lower.contains('credit alert');
  }

  static double? _extractAmount(String body) {
    // 1. Isolate and strip out Balance phrases so balance number is never confused as amount
    String cleanBody = body;
    cleanBody = cleanBody.replaceAll(
      RegExp(r'(?:bal|balance|avail\s*bal|avbl\s*bal|avl\s*bal|limit)[\s:]*(?:rs\.?|inr\.?|₹)?\s*[\d,]+(?:\.\d+)?', caseSensitive: false),
      ' ',
    );

    // Pattern 1: Action verb + Amount e.g. "debited by Rs 500", "spent INR 1,200.50", "paid 450 to"
    final RegExp actionPattern = RegExp(
      r'(?:debited|credited|spent|transferred|withdrawn|charged|paid|sent|deposited|refunded)\s+(?:by|for|with|of)?\s*(?:rs\.?|inr\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final match1 = actionPattern.firstMatch(cleanBody);
    if (match1 != null && match1.group(1) != null) {
      final parsed = _parseNumericAmount(match1.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }

    // Pattern 2: Standard Currency Prefix e.g. "Rs. 450.00", "INR 1,250.50", "₹500", "Amt Rs 500"
    final RegExp currencyPattern = RegExp(
      r'(?:amt\.?\s*|amount\s*|txn\s*of\s*|sip\s*of\s*)?(?:rs\.?|inr\.?|₹)\s*[\:\-]?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final match2 = currencyPattern.firstMatch(cleanBody);
    if (match2 != null && match2.group(1) != null) {
      final parsed = _parseNumericAmount(match2.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }

    // Pattern 3: Telecom Plan / Receipt Amount e.g. "Plan Name : 579.0", "Plan : 299.00", "MRP : 719", "Amount : 579"
    final RegExp planAmountPattern = RegExp(
      r'(?:plan\s*name|plan|mrp|recharge\s*amt|recharge\s*amount)\s*[\:\-]\s*(?:rs\.?|inr\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final matchPlan = planAmountPattern.firstMatch(cleanBody);
    if (matchPlan != null && matchPlan.group(1) != null) {
      final parsed = _parseNumericAmount(matchPlan.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }

    // Pattern 4: Trailing currency e.g. "450.00 INR debited", "500 Rs credited"
    final RegExp trailingPattern = RegExp(
      r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr\.?|₹)\s*(?:debited|credited|spent|withdrawn|paid)?',
      caseSensitive: false,
    );
    final match3 = trailingPattern.firstMatch(cleanBody);
    if (match3 != null && match3.group(1) != null) {
      final parsed = _parseNumericAmount(match3.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }

    // Pattern 5: Fallback on original body in case isolation removed too much
    final matchFallback = currencyPattern.firstMatch(body);
    if (matchFallback != null && matchFallback.group(1) != null) {
      return _parseNumericAmount(matchFallback.group(1)!);
    }

    return null;
  }

  static double? _parseNumericAmount(String str) {
    final clean = str.replaceAll(',', '').trim();
    return double.tryParse(clean);
  }

  static String? extractReference(String body) {
    // 0. Slash Delimited UPI Ref (e.g. "UPI/CR/624397651570/ARYAN SO SANJAY/PUNB/107200", "UPI/DR/624397651570/...")
    final RegExp upiSlashRef = RegExp(
      r'upi\/(?:cr|dr)\/([a-zA-Z0-9]{6,25})',
      caseSensitive: false,
    );
    final matchSlashRef = upiSlashRef.firstMatch(body);
    if (matchSlashRef != null && matchSlashRef.group(1) != null) {
      final val = matchSlashRef.group(1)!.trim();
      if (RegExp(r'\d').hasMatch(val)) return val;
    }

    // 1. RTGS / NEFT / IMPS hyphenated UTR / Ref (e.g. "RTGS Cr-ICIC0000011-FIVEALIVE...-ICICR42026090400535605")
    final RegExp rtgsCrPattern = RegExp(
      r'(?:rtgs|neft|imps)[\s_-]*cr[\s\S]*?[\:\-]([A-Za-z0-9]{12,25})\.?(?:\s|avl|bal|$)',
      caseSensitive: false,
    );
    final matchRtgs = rtgsCrPattern.firstMatch(body);
    if (matchRtgs != null && matchRtgs.group(1) != null) {
      final val = matchRtgs.group(1)!.trim();
      if (RegExp(r'\d').hasMatch(val) && val.length >= 8) {
        return val;
      }
    }

    // 2. Standard ref/rrn/txn/mandate patterns (e.g. "Ref 110727115773", "Ref: ICICR42026090400535605", "UPI Ref ID 626858479471")
    final RegExp refRegExp = RegExp(
      r'(?:transaction\s*id|txn\s*(?:id|#|no|ref)?|upi\s*(?:ref\s*(?:id|no|num)?|rrn|txn\s*(?:id|#|no)?|id|no)|rrn|ref\s*(?:id|no|num)?|imps(?:\s*ref)?|neft(?:\s*ref)?|utr)[\:\/\s\-#]+([a-zA-Z0-9]{6,25})',
      caseSensitive: false,
    );
    final match = refRegExp.firstMatch(body);
    if (match != null && match.group(1) != null) {
      final val = match.group(1)!.trim();
      // Ensure it contains digits and is not generic English noise
      if (RegExp(r'\d').hasMatch(val) &&
          !RegExp(r'^(?:amount|number|balance|account|trans|mandate|autopay|successful)$', caseSensitive: false).hasMatch(val)) {
        return val;
      }
    }

    // 3. Direct UPI reference (e.g. "UPI:624376617761/To:", "UPI 535040092626", "(UPI 625747999285)")
    final RegExp upiDirectRegExp = RegExp(
      r'\bupi[\:\/\s\-#]+(\d{6,25})',
      caseSensitive: false,
    );
    final matchUpiDirect = upiDirectRegExp.firstMatch(body);
    if (matchUpiDirect != null && matchUpiDirect.group(1) != null) {
      return matchUpiDirect.group(1)!.trim();
    }

    return null;
  }

  static Map<String, dynamic> _extractDateTime(String body, {DateTime? fallbackDate}) {
    final fallback = fallbackDate ?? DateTime.now();

    // Try text month pattern e.g. "24-Sep-24", "24Sep2024", "24 Sep 2024", "24/Sep/24 14:30:00"
    final RegExp textMonthRegExp = RegExp(
      r'\b(\d{1,2})[\s\/\-]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s\/\-]?(\d{2,4})\b(?:\s+(\d{1,2}:\d{2}(?::\d{2})?(?:\s*(?:am|pm|AM|PM))?))?',
      caseSensitive: false,
    );
    final textMatch = textMonthRegExp.firstMatch(body);
    if (textMatch != null) {
      final dayStr = textMatch.group(1);
      final monthStr = textMatch.group(2)?.toLowerCase();
      final yearStr = textMatch.group(3);
      final timeStr = textMatch.group(4);

      if (dayStr != null && monthStr != null && yearStr != null) {
        final month = _monthNameToNumber(monthStr);
        if (month != null) {
          int day = int.tryParse(dayStr) ?? fallback.day;
          int year = int.tryParse(yearStr) ?? fallback.year;
          if (year < 100) year += 2000;

          int hour = 0;
          int minute = 0;
          int second = 0;

          if (timeStr != null && timeStr.isNotEmpty) {
            final parsedTime = _parseTimeString(timeStr);
            hour = parsedTime['hour'] ?? 0;
            minute = parsedTime['minute'] ?? 0;
            second = parsedTime['second'] ?? 0;
          }

          final String rawTimeStr = (hour > 0 || minute > 0)
              ? '_${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}'
              : '';
          final parsedDate = DateTime(year, month, day, hour, minute, second);
          return {
            'raw': '$day$monthStr$year$rawTimeStr',
            'dateTime': parsedDate,
          };
        }
      }
    }

    // Try numeric date pattern e.g. "24/09/2024", "24-09-24 18:30"
    final RegExp numericDateRegExp = RegExp(
      r'(?:dt|date|on)?\s*\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?',
      caseSensitive: false,
    );
    final numMatch = numericDateRegExp.firstMatch(body);
    if (numMatch != null && numMatch.group(1) != null) {
      final str = numMatch.group(1)!.trim();
      final parsedDate = _parseNumericDateString(str);
      if (parsedDate != null) {
        final timeSuffix = (parsedDate.hour > 0 || parsedDate.minute > 0)
            ? '_${parsedDate.hour.toString().padLeft(2, '0')}${parsedDate.minute.toString().padLeft(2, '0')}'
            : '';
        return {
          'raw': '${str.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}$timeSuffix',
          'dateTime': parsedDate,
        };
      }
    }

    return {
      'raw': '',
      'dateTime': fallback,
    };
  }

  static int? _monthNameToNumber(String name) {
    switch (name) {
      case 'jan': return 1;
      case 'feb': return 2;
      case 'mar': return 3;
      case 'apr': return 4;
      case 'may': return 5;
      case 'jun': return 6;
      case 'jul': return 7;
      case 'aug': return 8;
      case 'sep': return 9;
      case 'oct': return 10;
      case 'nov': return 11;
      case 'dec': return 12;
      default: return null;
    }
  }

  static Map<String, int> _parseTimeString(String timeStr) {
    try {
      final isPm = timeStr.toLowerCase().contains('pm');
      final isAm = timeStr.toLowerCase().contains('am');
      final cleanTime = timeStr.replaceAll(RegExp(r'[a-zA-Z\s]'), '');
      final parts = cleanTime.split(':');
      int hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
      int minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      int second = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return {'hour': hour, 'minute': minute, 'second': second};
    } catch (_) {
      return {'hour': 0, 'minute': 0, 'second': 0};
    }
  }

  static DateTime? _parseNumericDateString(String str) {
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

  static String _extractVendor(String body, String lower, String? sender) {
    // Pass 0A: Telecom receipt numbers (e.g. "Jio Number : 9759147625", "Airtel Mobile : 9876543210")
    final RegExp telecomRegExp = RegExp(
      r'(jio|airtel|vi|vodafone|bsnl)\s*(?:number|no|mobile|mob)?\s*[\:\-]\s*([6-9]\d{9})',
      caseSensitive: false,
    );
    final matchTelecom = telecomRegExp.firstMatch(body);
    if (matchTelecom != null && matchTelecom.group(1) != null) {
      final op = _capitalize(matchTelecom.group(1)!);
      final num = matchTelecom.group(2);
      return (num != null && num.isNotEmpty) ? '$op Recharge ($num)' : '$op Recharge';
    }

    // Pass 0B: Bank Interest
    if (lower.contains('towards interest') || lower.contains('interest credited') || lower.contains('sb int') || lower.contains('interest of')) {
      return 'Bank Interest';
    }

    // Pass 0C: Google Payments
    if (lower.contains('goog-payments') || lower.contains('google payment')) {
      return 'Google Payments';
    }

    // Pass 0D: RTGS Cr / NEFT Cr / IMPS Cr Company Payouts
    final RegExp rtgsCrRegExp = RegExp(
      r'(?:rtgs|neft|imps)\s*cr[\:\-][A-Za-z0-9]+[\:\-]([A-Za-z0-9\s._-]+?)[\:\-]',
      caseSensitive: false,
    );
    final matchRtgsCr = rtgsCrRegExp.firstMatch(body);
    if (matchRtgsCr != null && matchRtgsCr.group(1) != null) {
      final v = _cleanVendorString(matchRtgsCr.group(1)!);
      if (v.isNotEmpty && !_isGenericNoiseWord(v)) return _capitalize(v);
    }

    // Pass 0D2: Slash Delimited UPI string (e.g. "UPI/CR/624397651570/ARYAN SO SANJAY/PUNB/107200")
    final RegExp slashUpiRegExp = RegExp(
      r'upi\/(?:cr|dr)\/[0-9]+\/([A-Za-z0-9\s._-]+?)\/(?:[A-Za-z0-9]+)',
      caseSensitive: false,
    );
    final matchSlashUpi = slashUpiRegExp.firstMatch(body);
    if (matchSlashUpi != null && matchSlashUpi.group(1) != null) {
      final v = _cleanVendorString(matchSlashUpi.group(1)!);
      if (v.isNotEmpty && !_isGenericNoiseWord(v)) return _capitalize(v);
    }

    // Pass 0E: Beneficiary Name
    final RegExp beneficiaryRegExp = RegExp(
      r'(?:from\s+beneficiary|beneficiary|to\s+beneficiary)\s+([A-Za-z0-9\s._-]+?)(?:[\.\;\~]|via|utr|ref|$)',
      caseSensitive: false,
    );
    final matchBene = beneficiaryRegExp.firstMatch(body);
    if (matchBene != null && matchBene.group(1) != null) {
      final v = _cleanVendorString(matchBene.group(1)!);
      if (v.isNotEmpty && !_isGenericNoiseWord(v)) return _capitalize(v);
    }

    // Pass 0F: Slash To VPA e.g. "UPI:624376617761/To:aryansharma2882000-2@okaxis"
    final RegExp toVpaRegExp = RegExp(
      r'[\/\s]to:\s*([A-Za-z0-9._-]+@[A-Za-z0-9._-]+|[A-Za-z0-9._-]+)',
      caseSensitive: false,
    );
    final matchToVpa = toVpaRegExp.firstMatch(body);
    if (matchToVpa != null && matchToVpa.group(1) != null) {
      final fullHandle = matchToVpa.group(1)!.trim();
      if (fullHandle.isNotEmpty && !_isGenericNoiseWord(fullHandle)) {
        return fullHandle;
      }
    }

    // Pass 0G: Tilde delimited To recipient (e.g. "RTGS Money Deposited~INR 5,00,000~To AmitKotak~Txn No:")
    final RegExp tildeToRegExp = RegExp(
      r'(?:~|^)To\s*([A-Za-z0-9\s._-]+?)(?:~|\;|$)',
      caseSensitive: false,
    );
    final matchTilde = tildeToRegExp.firstMatch(body);
    if (matchTilde != null && matchTilde.group(1) != null) {
      final v = _cleanVendorString(matchTilde.group(1)!);
      if (v.isNotEmpty && !_isGenericNoiseWord(v)) return _capitalize(v);
    }

    final String delimiters = r'(?:\r|\n|\s+(?:thru|through|via|using|by|towards|on|ref|vpa|upi|avail|bal|a/c|dt|date|is|\:|\.|$))';

    // Pass 1: Direct Payee transfers ("To AmitKotak on", "To Razorpay", "to Bhanu thru UPI", "paid to Ramesh ref", "Paid Rs 349 to Blinkit at")
    final RegExp pass1RegExp = RegExp(
      r'\b(?:to|paid to|sent to|transfer to|transferred to)\s+([A-Za-z0-9\s._-]+?)' + delimiters,
      caseSensitive: false,
    );
    final match1 = pass1RegExp.firstMatch(body);
    if (match1 != null && match1.group(1) != null) {
      final vendor = _cleanVendorString(match1.group(1)!);
      if (vendor.isNotEmpty && !_isGenericNoiseWord(vendor)) {
        return _capitalize(vendor);
      }
    }

    // Pass 1B: Inward Sender Name (excluding debiting banks/accounts) e.g. "from ARYAN;", "by RTGS from FIVEALIVE PRODUCTIVITY PRIVATE LIMITED"
    final RegExp fromRegExp = RegExp(
      r'\bfrom\s+(?!hdfc|sbi|icici|axis|pnb|canara|kotak|bank|account|a\/c|your\s+a\/c)([A-Za-z0-9\s._-]+?)(?:\;|\~|\.|\r|\n|\s+thru|\s+through|\s+via|\s+using|\s+vpa|\s+upi|\s+ref|\s+bal|\s+a\/c|$)',
      caseSensitive: false,
    );
    final matchFrom = fromRegExp.firstMatch(body);
    if (matchFrom != null && matchFrom.group(1) != null) {
      final v = _cleanVendorString(matchFrom.group(1)!);
      if (v.isNotEmpty && !_isGenericNoiseWord(v) && !v.toLowerCase().contains('vpa')) {
        return _capitalize(v);
      }
    }

    // Pass 2: Merchant & Store debits ("at Zomato on", "for Starbucks ref", "towards BESCOM", "for Groww Mutual Fund")
    final RegExp pass2RegExp = RegExp(
      r'\b(?:at|towards|merchant|info|spent at|used at|for)\s+([A-Za-z0-9\s._-]+?)' + delimiters,
      caseSensitive: false,
    );
    final match2 = pass2RegExp.firstMatch(body);
    if (match2 != null && match2.group(1) != null) {
      final vendor = _cleanVendorString(match2.group(1)!);
      if (vendor.isNotEmpty && !_isGenericNoiseWord(vendor)) {
        return _capitalize(vendor);
      }
    }

    // Pass 3: VPA handle extraction ("swiggy@icici", "zomato@upi", "user@okhdfcbank")
    final RegExp pass3RegExp = RegExp(
      r'([A-Za-z0-9._-]+)@(?:upi|ybl|paytm|icici|axis|okicici|okhdfcbank|okaxis|sbi|ibl|idfcbank)',
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

    // Pass 4: Bank Name Extraction from Sender ID if available (e.g. "HDFCBK" -> "HDFC Bank")
    if (sender != null && sender.isNotEmpty) {
      final bankName = _detectBankFromSender(sender);
      if (bankName != null) {
        return bankName;
      }
    }

    return 'Bank Transfer (UPI)';
  }

  static String? _detectBankFromSender(String sender) {
    final s = sender.toUpperCase();
    if (s.contains('HDFCBK')) return 'HDFC Bank';
    if (s.contains('SBIINB') || s.contains('SBIPSG')) return 'State Bank of India';
    if (s.contains('ICICIB')) return 'ICICI Bank';
    if (s.contains('AXISBK')) return 'Axis Bank';
    if (s.contains('KOTAKB')) return 'Kotak Bank';
    if (s.contains('PNBSMS') || s.contains('PUNB')) return 'PNB Bank';
    if (s.contains('PSB') || s.contains('PSBANK') || s.contains('PUNJABSIND')) return 'Punjab & Sind Bank';
    if (s.contains('BOBSMS')) return 'Bank of Baroda';
    if (s.contains('CANBNK') || s.contains('CANRA') || s.contains('CNRBK')) return 'Canara Bank';
    if (s.contains('UNIONB')) return 'Union Bank';
    if (s.contains('INDUSB')) return 'IndusInd Bank';
    if (s.contains('YESBNK')) return 'Yes Bank';
    if (s.contains('PAYTMB')) return 'Paytm Bank';
    if (s.contains('FEDBNK')) return 'Federal Bank';
    if (s.contains('IDFCFB')) return 'IDFC First Bank';
    if (s.contains('PROTEAN') || s.contains('NSDL') || s.contains('PFRDA')) return 'Protean (NPS/APY)';
    if (s.contains('CAMS')) return 'CAMS (Mutual Funds)';
    if (s.contains('KFINTECH')) return 'KFintech (Mutual Funds)';
    return null;
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
    final lower = word.toLowerCase().trim();
    // Ignore currency amounts (e.g. "INR 575.00", "Rs 500", "575.00")
    if (RegExp(r'^(?:inr|rs\.?|₹)?\s*[\d,]+(?:\.\d+)?$').hasMatch(lower)) return true;
    if (RegExp(r'^(?:inr|rs\.?|₹)$').hasMatch(lower)) return true;
    return lower == 'your' ||
        lower == 'bank' ||
        lower == 'account' ||
        lower == 'upi' ||
        lower == 'vpa' ||
        lower == 'a/c' ||
        lower == 'rs' ||
        lower == 'inr' ||
        lower == 'credited' ||
        lower == 'debited' ||
        lower == 'credit' ||
        lower == 'debit' ||
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
    double amount,
    String body, {
    bool isExpense = true,
  }) {
    final String cleanVendor = vendor.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String cleanRef = (refNo ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String cleanDate = dateRaw.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final int amountInt = (amount * 100).toInt();
    final String typeSuffix = isExpense ? 'dr' : 'cr';

    if (cleanRef.isNotEmpty) {
      return 'hash_ref_${cleanRef}_${amountInt}_$typeSuffix';
    }

    if (cleanDate.isNotEmpty) {
      return 'hash_${cleanDate}_${amountInt}_${cleanVendor}_$typeSuffix';
    }

    // Fallback: body text fingerprint with amount
    final String bodyNoNumbers = body.replaceAll(RegExp(r'\d+'), '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final String fallbackSnippet = bodyNoNumbers.length > 20 ? bodyNoNumbers.substring(0, 20) : bodyNoNumbers;
    return 'hash_${cleanVendor}_${fallbackSnippet}_${amountInt}_$typeSuffix';
  }

  static String? _extractBankAccount(String body, String? sender) {
    // 1. Detect Bank Name
    String bankName = '';
    if (sender != null && sender.isNotEmpty) {
      bankName = _detectBankFromSender(sender) ?? '';
    }
    if (bankName.isEmpty) {
      final s = body.toUpperCase();
      if (s.contains('PUNJAB&SIND') || s.contains('PUNJAB & SIND') || s.contains('PSB')) {
        bankName = 'Punjab & Sind Bank';
      } else if (s.contains('PNB') || s.contains('PUNJAB NATIONAL') || s.contains('PUNB')) {
        bankName = 'PNB';
      } else if (s.contains('HDFC')) {
        bankName = 'HDFC Bank';
      } else if (s.contains('SBI') || s.contains('STATE BANK')) {
        bankName = 'SBI';
      } else if (s.contains('ICICI')) {
        bankName = 'ICICI Bank';
      } else if (s.contains('AXIS')) {
        bankName = 'Axis Bank';
      } else if (s.contains('KOTAK')) {
        bankName = 'Kotak Bank';
      } else if (s.contains('CANARA') || s.contains('CANRA')) {
        bankName = 'Canara Bank';
      } else if (s.contains('BOB') || s.contains('BARODA')) {
        bankName = 'Bank of Baroda';
      } else if (s.contains('UNION BANK')) {
        bankName = 'Union Bank';
      } else if (s.contains('PAYTM')) {
        bankName = 'Paytm Bank';
      } else if (s.contains('IDFC')) {
        bankName = 'IDFC First Bank';
      }
    }

    // 2. Extract Account / Card digits
    final RegExp accRegex = RegExp(
      r'(?:a\/c|acct|account|card)[\s\.\:\#\-]*(?:no\.?)?\s*([xX\*]*\d{3,6})',
      caseSensitive: false,
    );
    final match = accRegex.firstMatch(body);
    String accDigits = '';
    if (match != null && match.group(1) != null) {
      final raw = match.group(1)!.trim();
      final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (onlyDigits.isNotEmpty) {
        accDigits = '••$onlyDigits';
      }
    }

    if (bankName.isNotEmpty && accDigits.isNotEmpty) {
      return '$bankName (A/c $accDigits)';
    } else if (bankName.isNotEmpty) {
      return bankName;
    } else if (accDigits.isNotEmpty) {
      return 'A/c $accDigits';
    }
    return null;
  }

  static Map<String, String> generateSmartDetails(String vendor, String body, bool isExpense) {
    final lower = body.toLowerCase();
    final vLower = vendor.toLowerCase();

    // =========================================================================
    // 1. APY / PRAN / NPS Pension Contribution (can be debit or credit alert)
    // =========================================================================
    final bool isPranOrApy = RegExp(r'\bpran\b|pran[\s\:\#\-xX\*]*\d+', caseSensitive: false).hasMatch(body) ||
        RegExp(r'\bapy\b|atal pension', caseSensitive: false).hasMatch(body) ||
        RegExp(r'\bnps\b|national pension', caseSensitive: false).hasMatch(body) ||
        vLower.contains('protean') ||
        vLower.contains('pfrda') ||
        lower.contains('protean') ||
        lower.contains('pfrda');

    if (isPranOrApy) {
      final pranMatch = RegExp(r'pran[\s\:\#\-xX\*]*([0-9]{4,12})', caseSensitive: false).firstMatch(body);
      String pranSuffix = '';
      if (pranMatch != null && pranMatch.group(1) != null) {
        final digits = pranMatch.group(1)!.trim();
        if (digits.isNotEmpty) {
          pranSuffix = ' (PRAN ••$digits)';
        }
      }
      final isApy = RegExp(r'\bapy\b|atal pension', caseSensitive: false).hasMatch(lower);
      final schemeName = isApy ? 'Atal Pension Yojana (APY)' : 'NPS Pension';
      return {
        'title': '$schemeName$pranSuffix',
        'description': '$schemeName Contribution',
      };
    }

    // =========================================================================
    // 2. Income / Credit Transactions (!isExpense)
    // =========================================================================
    if (!isExpense) {
      if (lower.contains('refund') || lower.contains('reversal') || lower.contains('reversed') || lower.contains('chargeback')) {
        return {'title': 'Refund / Reversal', 'description': 'Transaction Refund or Reversal'};
      }
      if (lower.contains('cashback') || lower.contains('reward') || lower.contains('scratch') || vLower.contains('google payment') || vLower.contains('google india') || vLower.contains('goog-payment')) {
        return {'title': 'Cashback & Rewards', 'description': 'Cashback or Promotional Reward'};
      }
      if (lower.contains('salary') || lower.contains('payroll') || lower.contains('stipend') || lower.contains('wages')) {
        return {'title': 'Salary / Income Credit', 'description': 'Salary / Payroll Income'};
      }
      if (lower.contains('interest') || lower.contains('sb int') || lower.contains('term deposit') || lower.contains('fd int')) {
        return {'title': 'Bank Interest Credit', 'description': 'Savings / Deposit Interest Credit'};
      }
      if (lower.contains('dividend')) {
        return {'title': 'Dividend Income', 'description': 'Stock / Mutual Fund Dividend Credit'};
      }
      if (vendor.isNotEmpty &&
          vendor != 'Bank Transfer (UPI)' &&
          !vendor.toLowerCase().contains('bank') &&
          !RegExp(r'^(?:inr|rs\.?|₹)?\s*[\d,]+(?:\.\d+)?$', caseSensitive: false).hasMatch(vendor)) {
        return {'title': 'Received from $vendor', 'description': 'UPI / Account Credit from $vendor'};
      }
      return {'title': 'UPI / Bank Credit', 'description': 'Account Credit Transfer'};
    }

    // =========================================================================
    // 3. Investments & Clearing (ICCL, NSE Clearing, CAMS, KFintech, Demat, SIP)
    // =========================================================================
    if (vLower.contains('indian clearing') ||
        vLower.contains('iccl') ||
        lower.contains('indian clearing') ||
        lower.contains('iccl') ||
        lower.contains('nse clearing') ||
        lower.contains('ncl') ||
        lower.contains('cams') ||
        lower.contains('kfintech') ||
        lower.contains('mf central') ||
        vLower.contains('groww') ||
        vLower.contains('zerodha') ||
        vLower.contains('upstox') ||
        vLower.contains('angel') ||
        lower.contains('mutual fund') ||
        RegExp(r'\bsip\b').hasMatch(lower) ||
        lower.contains('demat') ||
        RegExp(r'\bppf\b').hasMatch(lower) ||
        lower.contains('sukanya')) {
      final name = vendor.isNotEmpty && vendor != 'Bank Transfer (UPI)' ? vendor : 'Indian Clearing (ICCL)';
      return {
        'title': 'Mutual Fund ($name)',
        'description': 'Mutual Fund / Stock SIP via $name',
      };
    }

    // =========================================================================
    // 4. Telecom & Recharges
    // =========================================================================
    final RegExp phoneRegex = RegExp(
      r'(?:recharge\s*(?:for|of|to)?|mob(?:ile)?|num(?:ber)?|dth)\s*[:\-]?\s*([6-9]\d{9})',
      caseSensitive: false,
    );
    final phoneMatch = phoneRegex.firstMatch(body);
    final phoneStr = phoneMatch != null ? ' (${phoneMatch.group(1)})' : '';

    if (vLower.contains('jio') || lower.contains('jio')) {
      return {
        'title': 'Jio Recharge$phoneStr',
        'description': 'Jio Mobile / Fiber Recharge$phoneStr',
      };
    }
    if (vLower.contains('airtel') || lower.contains('airtel')) {
      return {
        'title': 'Airtel Recharge$phoneStr',
        'description': 'Airtel Mobile / DTH Recharge$phoneStr',
      };
    }
    if (vLower.contains('vodafone') || lower.contains('vodafone') || RegExp(r'\bvi\b').hasMatch(vLower) || RegExp(r'\bvi\s+recharge\b').hasMatch(lower)) {
      return {
        'title': 'Vi Recharge$phoneStr',
        'description': 'Vodafone Idea Mobile Recharge$phoneStr',
      };
    }

    // =========================================================================
    // 5. Groceries & Quick Commerce
    // =========================================================================
    if (vLower.contains('blinkit') || lower.contains('blinkit')) {
      return {'title': 'Blinkit Groceries', 'description': 'Quick Commerce Grocery Order'};
    }
    if (vLower.contains('zepto') || lower.contains('zepto')) {
      return {'title': 'Zepto Groceries', 'description': 'Quick Commerce Grocery Order'};
    }
    if (vLower.contains('instamart') || lower.contains('instamart')) {
      return {'title': 'Swiggy Instamart', 'description': 'Instant Grocery Order'};
    }
    if (vLower.contains('bigbasket') || lower.contains('bigbasket')) {
      return {'title': 'BigBasket Groceries', 'description': 'Supermarket Grocery Order'};
    }
    if (vLower.contains('dmart') || lower.contains('dmart')) {
      return {'title': 'DMart Supermarket', 'description': 'Supermarket Shopping'};
    }

    // =========================================================================
    // 6. Food & Dining
    // =========================================================================
    if (vLower.contains('zomato') || lower.contains('zomato')) {
      return {'title': 'Zomato Food Order', 'description': 'Food Delivery via Zomato'};
    }
    if (vLower.contains('swiggy') || lower.contains('swiggy')) {
      return {'title': 'Swiggy Food Order', 'description': 'Food Delivery via Swiggy'};
    }
    if (vLower.contains('starbucks') || lower.contains('starbucks')) {
      return {'title': 'Starbucks Coffee', 'description': 'Dining & Beverages'};
    }
    if (vLower.contains('domino') || lower.contains('domino')) {
      return {'title': "Domino's Pizza", 'description': 'Pizza & Dining Order'};
    }
    if (vLower.contains('mcdonald') || lower.contains('mcdonald')) {
      return {'title': "McDonald's", 'description': 'Fast Food Order'};
    }

    // =========================================================================
    // 7. Transport & Fuel
    // =========================================================================
    if (vLower.contains('uber') || lower.contains('uber')) {
      return {'title': 'Uber Ride', 'description': 'Cab / Auto Ride via Uber'};
    }
    if (vLower.contains('ola') || lower.contains('ola')) {
      return {'title': 'Ola Ride', 'description': 'Cab / Auto Ride via Ola'};
    }
    if (vLower.contains('rapido') || lower.contains('rapido')) {
      return {'title': 'Rapido Ride', 'description': 'Bike / Auto Ride via Rapido'};
    }
    if (vLower.contains('fastag') || lower.contains('fastag') || (lower.contains('toll') && !lower.contains('toll free') && !lower.contains('tollfree'))) {
      return {'title': 'FASTag Toll Debit', 'description': 'National Highway Toll Debit'};
    }
    if (vLower.contains('irctc') || lower.contains('irctc')) {
      return {'title': 'IRCTC Train Ticket', 'description': 'Railway Ticket Booking'};
    }
    if (vLower.contains('hpcl') || lower.contains('hpcl')) {
      return {'title': 'HPCL Petrol Pump', 'description': 'Fuel & Petrol Expense'};
    }
    if (vLower.contains('bpcl') || lower.contains('bpcl')) {
      return {'title': 'BPCL Petrol Pump', 'description': 'Fuel & Petrol Expense'};
    }
    if (vLower.contains('iocl') || lower.contains('iocl') || lower.contains('indian oil')) {
      return {'title': 'Indian Oil Petrol Pump', 'description': 'Fuel & Petrol Expense'};
    }
    if (vLower.contains('shell') || lower.contains('shell')) {
      return {'title': 'Shell Fuel Station', 'description': 'Fuel & Petrol Expense'};
    }

    // =========================================================================
    // 8. Shopping & Retail
    // =========================================================================
    if (vLower.contains('reliance digital') || lower.contains('reliance digital')) {
      return {'title': 'Reliance Digital', 'description': 'Electronics & Appliances Purchase'};
    }
    if (vLower.contains('croma') || lower.contains('croma')) {
      return {'title': 'Croma Electronics', 'description': 'Electronics & Retail Purchase'};
    }
    if (vLower.contains('amazon') || lower.contains('amazon')) {
      return {'title': 'Amazon Shopping', 'description': 'E-Commerce Online Order'};
    }
    if (vLower.contains('flipkart') || lower.contains('flipkart')) {
      return {'title': 'Flipkart Shopping', 'description': 'E-Commerce Online Order'};
    }
    if (vLower.contains('myntra') || lower.contains('myntra')) {
      return {'title': 'Myntra Fashion', 'description': 'Clothing & Fashion Order'};
    }
    if (vLower.contains('ajio') || lower.contains('ajio')) {
      return {'title': 'AJIO Fashion', 'description': 'Clothing & Fashion Order'};
    }

    // =========================================================================
    // 9. Credit Card / EMI (strictly bounded, expense only)
    // =========================================================================
    if (vLower == 'cred' || vLower.startsWith('cred ') || RegExp(r'\bcred\b').hasMatch(vLower) || RegExp(r'\bcred\b').hasMatch(lower)) {
      return {'title': 'CRED Card Payment', 'description': 'Credit Card Bill Payment via CRED'};
    }
    if (lower.contains('credit card') || lower.contains('card bill') || RegExp(r'\bemi\b').hasMatch(lower)) {
      return {'title': 'Credit Card / EMI Payment', 'description': 'Credit Card Bill / EMI Payment'};
    }

    // =========================================================================
    // 10. Generic Person P2P or Vendor
    // =========================================================================
    if (vendor.isNotEmpty && vendor != 'Bank Transfer (UPI)') {
      return {'title': 'Paid to $vendor', 'description': 'UPI Transfer to $vendor'};
    }

    return {'title': 'UPI Debit', 'description': 'Bank Online Transfer'};
  }
}
