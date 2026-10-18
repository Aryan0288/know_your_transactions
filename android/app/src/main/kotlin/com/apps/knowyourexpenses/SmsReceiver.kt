package com.apps.knowyourexpenses

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "auto_sms_channel"
        private const val CHANNEL_NAME = "Auto SMS Expenses"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_ENABLED = "flutter.auto_sms_enabled"
        private const val KEY_PENDING = "flutter.pending_auto_sms_items"
        private const val KEY_SYNCED = "flutter.synced_sms_hashes"
        private const val KEY_DISCARDED = "flutter.discarded_sms_hashes"

        private val DEBIT_KEYWORDS = listOf(
            "debited", "paid", "spent", "sent", "transferred", "transfer of", "withdrawn", "withdrawal",
            "charged", "purchase", "txn of", "transaction of", "dr-rs", "dr.", "dr ",
            "imps", "neft", "rtgs", "recharge", "bill payment", "autopay", "mandate",
            "sip", "mutual fund", "investment", "vpa", "upi/p2m", "upi/p2a", "used at",
            "swiped at", "pos txn", "atm wdl", "deducted", "auto-debit", "auto debit"
        )
        private val CREDIT_KEYWORDS = listOf(
            "credited", "received", "added to account", "added to your account",
            "deposited", "cr-rs", "cr.", "cr ", "refund", "cashback", "salary",
            "interest credited", "dividend", "reversed"
        )
        private val SPAM_KEYWORDS = listOf(
            "otp", "secret code", "verification code", "do not share", "one time password",
            "failed", "declined", "unsuccessful", "could not be processed",
            "pre-approved", "pre approved", "apply now", "click here", "avail loan", "loan approved",
            "credit limit is", "congratulations", "special offer", "exclusive offer",
            "request to pay", "requested money", "request received", "due date is", "bill generated",
            "payment due", "will be debited on", "bit.ly/", "tinyurl.com/", "cutt.ly/", "is.gd/",
            "rb.gy/", "shorturl.at/", "ct3.io/", "dearclient", "clientcode", "pleasecheck",
            "check account details", "regardsitisbl", "itisbl", "rummy", "ludo", "fantasy",
            "dream11", "my11circle", "winzo", "zupee", "poker", "teen patti", "teenpatti",
            "casino", "jackpot", "winnings", "welcome bonus", "joining bonus", "signup bonus",
            "sign up bonus", "wallet bonus", "bonus credited", "claim now", "withdraw now",
            "redeem now", "can be credited", "will be credited", "ready to be credited",
            "credited instantly", "get instant", "instant loan", "eligible for", "approved for",
            "use code", "coupon code", "promo code", "shop now", "buy now", "recharge now"
        )
        private val SELF_TRANSFER_KEYWORDS = listOf(
            "self transfer", "transfer to own a/c", "own account transfer"
        )

        private val BALANCE_STRIP_PATTERN = Pattern.compile(
            """(?:bal|balance|avail\s*bal|avbl\s*bal|avl\s*bal|limit)[\s:]*(?:rs\.?|inr\.?|₹)?\s*[\d,]+(?:\.\d+)?""",
            Pattern.CASE_INSENSITIVE
        )

        private val AMOUNT_ACTION_PATTERN = Pattern.compile(
            """(?:debited|credited|spent|transferred|withdrawn|charged|paid|sent|deposited|refunded)\s+(?:by|for|with|of)?\s*(?:rs\.?|inr\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)""",
            Pattern.CASE_INSENSITIVE
        )

        private val AMOUNT_CURRENCY_PATTERN = Pattern.compile(
            """(?:amt\.?\s*|amount\s*|txn\s*of\s*|sip\s*of\s*)?(?:rs\.?|inr\.?|₹)\s*[\:\-]?\s*([\d,]+(?:\.\d{1,2})?)""",
            Pattern.CASE_INSENSITIVE
        )

        private val AMOUNT_TRAILING_PATTERN = Pattern.compile(
            """([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr\.?|₹)\s*(?:debited|credited|spent|withdrawn|paid)?""",
            Pattern.CASE_INSENSITIVE
        )

        private val UPI_SLASH_REF_PATTERN = Pattern.compile(
            """upi\/(?:cr|dr)\/([a-zA-Z0-9]{6,25})""",
            Pattern.CASE_INSENSITIVE
        )

        private val RTGS_REF_PATTERN = Pattern.compile(
            """(?:rtgs|neft|imps)[\s_-]*cr[\s\S]*?[\:\-]([A-Za-z0-9]{12,25})\.?(?:\s|avl|bal|$)""",
            Pattern.CASE_INSENSITIVE
        )

        private val REF_PATTERN = Pattern.compile(
            """(?:transaction\s*id|txn\s*(?:id|#|no|ref)?|upi\s*(?:ref\s*(?:id|no|num)?|rrn|txn\s*(?:id|#|no)?|id|no)|rrn|ref\s*(?:id|no|num)?|imps(?:\s*ref)?|neft(?:\s*ref)?|utr)[\:\/\s\-#]+([a-zA-Z0-9]{6,25})""",
            Pattern.CASE_INSENSITIVE
        )

        private val UPI_DIRECT_REF_PATTERN = Pattern.compile(
            """\bupi[\:\/\s\-#]+(\d{6,25})""",
            Pattern.CASE_INSENSITIVE
        )

        private val FAKE_MOBILE_ACCOUNT_PATTERN = Pattern.compile(
            """\b(?:your\s+)?(?:a\/c|acct|account)\s*(?:no\.?)?[\s\:\-]*[6-9]\d{9}\b""",
            Pattern.CASE_INSENSITIVE
        )

        private val DATE_TEXT_PATTERN = Pattern.compile(
            """(\d{1,2})[\s\/\-]?([a-zA-Z]{3})[\s\/\-]?(\d{2,4})(?:\s+(\d{1,2}:\d{2}(?::\d{2})?(?:\s*(?:am|pm|AM|PM))?))?""",
            Pattern.CASE_INSENSITIVE
        )

        private val DATE_NUMERIC_PATTERN = Pattern.compile(
            """(?:dt|date|on)?\s*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)""",
            Pattern.CASE_INSENSITIVE
        )

        private val VENDOR_TO_PATTERN = Pattern.compile(
            """(?:to|paid to|sent to|transfer to|transferred to)\s+([A-Za-z0-9\s._-]+?)(?:\s+(?:thru|through|via|using|by|towards|on|ref|vpa|upi|avail|bal|a/c|dt|date|is|\:|\.|$))""",
            Pattern.CASE_INSENSITIVE
        )

        private val VENDOR_AT_PATTERN = Pattern.compile(
            """(?:at|towards|merchant|info|spent at|used at|for)\s+([A-Za-z0-9\s._-]+?)(?:\s+(?:thru|through|via|ref|vpa|upi|avail|bal|a/c|dt|date|is|\:|\.|$))""",
            Pattern.CASE_INSENSITIVE
        )

        private val VPA_PATTERN = Pattern.compile(
            """([A-Za-z0-9._-]+)@(?:upi|ybl|paytm|icici|axis|okicici|okhdfcbank|okaxis|sbi|ibl|idfcbank)""",
            Pattern.CASE_INSENSITIVE
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val pendingResult = goAsync()
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "KnowYourExpenses:SmsReceiverWakeLock")
        wakeLock?.acquire(10000) // 10 seconds timeout

        Thread {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean(KEY_ENABLED, false)
                if (isEnabled) {
                    val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    if (messages != null) {
                        val fullBody = messages.joinToString("") { it.messageBody ?: "" }
                        if (fullBody.isNotEmpty()) {
                            val sender = messages.firstOrNull()?.originatingAddress ?: ""
                            val parsed = parseSms(fullBody, sender)
                            if (parsed != null) {
                                saveToPending(prefs, parsed, context)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try {
                    if (wakeLock != null && wakeLock.isHeld) {
                        wakeLock.release()
                    }
                } catch (_: Exception) {}
                pendingResult.finish()
            }
        }.start()
    }

    private fun saveToPending(prefs: android.content.SharedPreferences, parsed: JSONObject, context: Context) {
        val hashId = parsed.optString("id")

        // 1. Check synced registry in SharedPreferences (stored as JSON array by Flutter)
        val syncedJson = prefs.getString(KEY_SYNCED, null)
        if (syncedJson != null && syncedJson.contains(hashId)) return

        // 2. Check discarded registry in SharedPreferences
        val discardedJson = prefs.getString(KEY_DISCARDED, null)
        if (discardedJson != null && discardedJson.contains(hashId)) return

        // 3. Check existing pending list
        val existingJson = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        val list = try { JSONArray(existingJson) } catch (e: Exception) { JSONArray() }

        for (i in 0 until list.length()) {
            if (list.optJSONObject(i)?.optString("id") == hashId) {
                return
            }
        }

        val newList = JSONArray()
        newList.put(parsed)
        for (i in 0 until list.length()) newList.put(list.get(i))
        prefs.edit().putString(KEY_PENDING, newList.toString()).apply()

        val amount = parsed.optDouble("amount", 0.0)
        val vendor = parsed.optString("vendorName", "Unknown")
        val isExpense = parsed.optBoolean("isExpense", true)
        val label = if (isExpense) "Expense" else "Income"
        showNotification(context,
            title = "New Auto-Detected $label",
            body = "₹${"%.2f".format(amount)} at $vendor"
        )
        notifyFlutterApp(context)
    }

    private fun notifyFlutterApp(context: Context) {
        val broadcastIntent = Intent("com.apps.knowyourexpenses.SMS_RECEIVED_EVENT").apply {
            setPackage(context.packageName)
        }
        context.sendBroadcast(broadcastIntent)
    }

    private fun isSpamSender(sender: String): Boolean {
        val s = sender.trim()
        if (s.isEmpty()) return false
        val upper = s.uppercase(Locale.getDefault())
        if (upper.endsWith("-P") || upper.endsWith("_P")) return true
        if (s.matches(Regex("^(?:\\+?91[\\-\\s]?)?[6-9]\\d{9}$"))) return true
        if (upper.contains("ITISBL") || upper.contains("RUMMY") || upper.contains("DREAM11") ||
            upper.contains("MY11") || upper.contains("WINZO") || upper.contains("ZUPEE") ||
            upper.contains("POKER") || upper.contains("CASINO") || upper.contains("TEENP")
        ) return true
        return false
    }

    private fun parseSms(body: String, sender: String = ""): JSONObject? {
        if (isSpamSender(sender)) return null
        val lower = body.lowercase(Locale.getDefault())
        if (SPAM_KEYWORDS.any { lower.contains(it) }) return null
        if (SELF_TRANSFER_KEYWORDS.any { lower.contains(it) }) return null
        if (FAKE_MOBILE_ACCOUNT_PATTERN.matcher(lower).find()) return null

        var isExpense = DEBIT_KEYWORDS.any { lower.contains(it) }
        var isCredit = CREDIT_KEYWORDS.any { lower.contains(it) }
        if (isCredit && isExpense) {
            if (lower.contains("deposited") || lower.contains("credited to") ||
                lower.contains("credit alert") || lower.contains("received from") ||
                lower.contains("towards interest") || lower.contains("interest credited") ||
                lower.contains("refund") || lower.contains("cashback")
            ) {
                isExpense = false
            } else {
                isCredit = false
            }
        }
        if (!isExpense && !isCredit) return null

        val amount = extractAmount(body) ?: return null
        if (amount <= 0) return null

        val vendor = extractVendor(body, sender)
        val refNo = extractRef(body)
        val bankAccount = extractBankAccount(body, sender)

        if (!isExpense) {
            val hasBankingAnchor = !bankAccount.isNullOrEmpty() ||
                !refNo.isNullOrEmpty() ||
                body.contains("@") ||
                lower.contains("salary") ||
                lower.contains("interest") ||
                lower.contains("dividend") ||
                lower.contains("refund") ||
                lower.contains("cashback") ||
                lower.contains("neft") ||
                lower.contains("rtgs") ||
                lower.contains("imps")
            if (!hasBankingAnchor) return null
        }
        val dateRaw = extractDateRaw(body)
        val date = extractDate(body)

        val cleanRef = refNo?.lowercase()?.replace(Regex("[^a-z0-9]"), "") ?: ""
        val cleanDate = dateRaw.replace(Regex("[^a-z0-9_]"), "")
        val cleanVendor = vendor.lowercase().replace(Regex("[^a-z0-9]"), "")
        val amountInt = (amount * 100).toInt()
        val typeSuffix = if (isExpense) "dr" else "cr"

        val hashId = when {
            cleanRef.isNotEmpty() -> "hash_ref_${cleanRef}_${amountInt}_$typeSuffix"
            cleanDate.isNotEmpty() -> "hash_${cleanDate}_${amountInt}_${cleanVendor}_$typeSuffix"
            else -> {
                val snippet = lower.replace(Regex("\\d+"), "").replace(Regex("[^a-z]"), "")
                "hash_${cleanVendor}_${snippet.take(20)}_${amountInt}_$typeSuffix"
            }
        }

        return JSONObject().apply {
            put("id", hashId)
            put("amount", amount)
            put("vendorName", vendor)
            put("date", date)
            put("paymentMode", if (lower.contains("cash")) "cash" else "online")
            put("isExpense", isExpense)
            put("rawSmsBody", body)
            put("status", "pending")
            if (!refNo.isNullOrEmpty()) put("refNumber", refNo)
            if (!bankAccount.isNullOrEmpty()) put("bankAccount", bankAccount)
            if (sender.isNotEmpty()) put("sender", sender)
        }
    }

    private fun extractAmount(body: String): Double? {
        val cleanBody = BALANCE_STRIP_PATTERN.matcher(body).replaceAll(" ")

        val m1 = AMOUNT_ACTION_PATTERN.matcher(cleanBody)
        if (m1.find()) {
            val v = m1.group(1)?.replace(",", "")?.toDoubleOrNull()
            if (v != null && v > 0) return v
        }

        val m2 = AMOUNT_CURRENCY_PATTERN.matcher(cleanBody)
        if (m2.find()) {
            val v = m2.group(1)?.replace(",", "")?.toDoubleOrNull()
            if (v != null && v > 0) return v
        }

        val m3 = AMOUNT_TRAILING_PATTERN.matcher(cleanBody)
        if (m3.find()) {
            val v = m3.group(1)?.replace(",", "")?.toDoubleOrNull()
            if (v != null && v > 0) return v
        }

        val mFallback = AMOUNT_CURRENCY_PATTERN.matcher(body)
        if (mFallback.find()) {
            return mFallback.group(1)?.replace(",", "")?.toDoubleOrNull()
        }

        return null
    }

    private fun extractRef(body: String): String? {
        val mSlash = UPI_SLASH_REF_PATTERN.matcher(body)
        if (mSlash.find()) {
            val v = mSlash.group(1)?.trim()
            if (v != null && v.any { it.isDigit() }) return v
        }

        val mRtgs = RTGS_REF_PATTERN.matcher(body)
        if (mRtgs.find()) {
            val v = mRtgs.group(1)?.trim()
            if (v != null && v.length >= 8 && v.any { it.isDigit() }) return v
        }

        val m = REF_PATTERN.matcher(body)
        if (m.find()) {
            val v = m.group(1)?.trim()
            if (v != null && v.any { it.isDigit() } &&
                !v.matches(Regex("^(?:amount|number|balance|account|trans|mandate|autopay|successful)$", RegexOption.IGNORE_CASE))
            ) {
                return v
            }
        }

        val mUpiDirect = UPI_DIRECT_REF_PATTERN.matcher(body)
        if (mUpiDirect.find()) {
            return mUpiDirect.group(1)?.trim()
        }

        return null
    }

    private fun extractDateRaw(body: String): String {
        val tm = DATE_TEXT_PATTERN.matcher(body)
        if (tm.find()) {
            val timeSuffix = if (tm.group(4) != null) "_${tm.group(4)?.replace(":", "")?.replace(" ", "")}" else ""
            return "${tm.group(1)}${tm.group(2)}${tm.group(3)}$timeSuffix"
        }
        val nm = DATE_NUMERIC_PATTERN.matcher(body)
        return if (nm.find()) nm.group(1)?.trim()?.replace(Regex("[^a-zA-Z0-9]"), "") ?: "" else ""
    }

    private fun extractDate(body: String): String {
        val tm = DATE_TEXT_PATTERN.matcher(body)
        if (tm.find()) {
            val day = tm.group(1)?.padStart(2, '0') ?: "01"
            val monthStr = tm.group(2)?.lowercase(Locale.US) ?: "jan"
            val month = monthNameToNumber(monthStr)
            var year = tm.group(3)?.toIntOrNull() ?: 2026
            if (year < 100) year += 2000
            val timeGroup = tm.group(4)
            val timeStr = if (timeGroup != null) {
                val cleanTime = timeGroup.lowercase(Locale.US).replace("am", "").replace("pm", "").trim()
                val tParts = cleanTime.split(":")
                val h = tParts.getOrNull(0)?.padStart(2, '0') ?: "00"
                val mi = tParts.getOrNull(1)?.padStart(2, '0') ?: "00"
                val s = tParts.getOrNull(2)?.padStart(2, '0') ?: "00"
                "${h}:${mi}:${s}"
            } else {
                "00:00:00"
            }
            return "${year}-${month}-${day}T${timeStr}.000"
        }

        val nm = DATE_NUMERIC_PATTERN.matcher(body)
        if (nm.find()) {
            val str = nm.group(1)?.trim() ?: return currentIso()
            val parts = str.split(Regex("\\s+"))
            val dateComponents = parts[0].split(Regex("[/\\-]"))
            if (dateComponents.size == 3) {
                val day = dateComponents[0].padStart(2, '0')
                val month = dateComponents[1].padStart(2, '0')
                var year = dateComponents[2].toIntOrNull() ?: return currentIso()
                if (year < 100) year += 2000
                val timeParts = (if (parts.size > 1) parts[1].lowercase(Locale.US).replace("am", "").replace("pm", "").trim() else "00:00:00").split(":")
                val h = timeParts.getOrNull(0)?.padStart(2, '0') ?: "00"
                val mi = timeParts.getOrNull(1)?.padStart(2, '0') ?: "00"
                val s = timeParts.getOrNull(2)?.padStart(2, '0') ?: "00"
                return "${year}-${month}-${day}T${h}:${mi}:${s}.000"
            }
        }
        return currentIso()
    }

    private fun monthNameToNumber(name: String): String {
        return when (name.lowercase(Locale.US)) {
            "jan" -> "01"; "feb" -> "02"; "mar" -> "03"; "apr" -> "04"
            "may" -> "05"; "jun" -> "06"; "jul" -> "07"; "aug" -> "08"
            "sep" -> "09"; "oct" -> "10"; "nov" -> "11"; "dec" -> "12"
            else -> "01"
        }
    }

    private fun currentIso(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())

    private fun extractVendor(body: String, sender: String): String {
        val m1 = VENDOR_TO_PATTERN.matcher(body)
        if (m1.find()) {
            val v = cleanVendor(m1.group(1) ?: "")
            if (v.isNotEmpty() && !isNoiseWord(v)) return capitalize(v)
        }

        val m2 = VENDOR_AT_PATTERN.matcher(body)
        if (m2.find()) {
            val v = cleanVendor(m2.group(1) ?: "")
            if (v.isNotEmpty() && !isNoiseWord(v)) return capitalize(v)
        }

        val m3 = VPA_PATTERN.matcher(body)
        if (m3.find()) {
            val handle = m3.group(1)?.replace(Regex("[._-]"), " ")?.trim() ?: ""
            val v = cleanVendor(handle)
            if (v.isNotEmpty() && !isNoiseWord(v)) return capitalize(v)
        }

        if (sender.isNotEmpty()) {
            val bank = detectBankFromSender(sender)
            if (bank != null) return bank
        }

        return "Bank Transfer (UPI)"
    }

    private fun detectBankFromSender(sender: String): String? {
        val s = sender.uppercase(Locale.getDefault())
        return when {
            s.contains("HDFCBK") -> "HDFC Bank"
            s.contains("SBIINB") || s.contains("SBIPSG") -> "State Bank of India"
            s.contains("ICICIB") -> "ICICI Bank"
            s.contains("AXISBK") -> "Axis Bank"
            s.contains("KOTAKB") -> "Kotak Bank"
            s.contains("PNBSMS") -> "PNB Bank"
            s.contains("BOBSMS") -> "Bank of Baroda"
            s.contains("CANBNK") -> "Canara Bank"
            s.contains("UNIONB") -> "Union Bank"
            s.contains("INDUSB") -> "IndusInd Bank"
            s.contains("YESBNK") -> "Yes Bank"
            s.contains("PAYTMB") -> "Paytm Bank"
            s.contains("FEDBNK") -> "Federal Bank"
            s.contains("IDFCFB") -> "IDFC First Bank"
            else -> null
        }
    }

    private fun extractBankAccount(body: String, sender: String): String? {
        var bankName = ""
        if (sender.isNotEmpty()) {
            bankName = detectBankFromSender(sender) ?: ""
        }
        if (bankName.isEmpty()) {
            val s = body.uppercase(Locale.getDefault())
            bankName = when {
                s.contains("PUNJAB&SIND") || s.contains("PUNJAB & SIND") || s.contains("PSB") -> "Punjab & Sind Bank"
                s.contains("PNB") || s.contains("PUNJAB NATIONAL") || s.contains("PUNB") -> "PNB Bank"
                s.contains("HDFC") -> "HDFC Bank"
                s.contains("SBI") || s.contains("STATE BANK") -> "State Bank of India"
                s.contains("ICICI") -> "ICICI Bank"
                s.contains("AXIS") -> "Axis Bank"
                s.contains("KOTAK") -> "Kotak Bank"
                s.contains("CANARA") || s.contains("CANRA") -> "Canara Bank"
                s.contains("BOB") || s.contains("BARODA") -> "Bank of Baroda"
                s.contains("UNION BANK") -> "Union Bank"
                s.contains("PAYTM") -> "Paytm Bank"
                s.contains("IDFC") -> "IDFC First Bank"
                else -> ""
            }
        }

        val accPattern = Pattern.compile("""(?:a\/c|acct|account|card)[\s\.\:\#\-]*(?:no\.?)?\s*([xX\*]+\d{3,6}|\d{3,6})(?!\d)""", Pattern.CASE_INSENSITIVE)
        val m = accPattern.matcher(body)
        var accDigits = ""
        if (m.find()) {
            val raw = m.group(1)?.trim() ?: ""
            val onlyDigits = raw.replace(Regex("[^0-9]"), "")
            if (onlyDigits.isNotEmpty()) {
                accDigits = "••$onlyDigits"
            }
        }

        return when {
            bankName.isNotEmpty() && accDigits.isNotEmpty() -> "$bankName (A/c $accDigits)"
            bankName.isNotEmpty() -> bankName
            accDigits.isNotEmpty() -> "A/c $accDigits"
            else -> null
        }
    }

    private fun cleanVendor(raw: String): String {
        var c = raw.trim()
        c = c.replace(Regex("""^(?:vpa|ref|txn|id|\:|\-)\s*""", RegexOption.IGNORE_CASE), "")
        c = c.replace(Regex("""\s+(?:thru|through|via|upi|vpa|ref|bal|a/c).*$""", RegexOption.IGNORE_CASE), "")
        if (c.length > 30) c = c.substring(0, 30)
        return c.trim()
    }

    private fun isNoiseWord(w: String): Boolean {
        val l = w.lowercase(Locale.getDefault())
        return l == "your" || l == "bank" || l == "account" || l == "upi" || l == "vpa" ||
                l == "a/c" || l == "rs" || l == "inr" || l.length < 2
    }

    private fun capitalize(text: String): String =
        text.trim().split(" ").joinToString(" ") {
            if (it.isEmpty()) "" else it[0].uppercaseChar() + it.substring(1).lowercase(Locale.getDefault())
        }

    private fun showNotification(context: Context, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Notifications for auto-detected SMS expenses"
                    enableLights(true); enableVibration(true)
                }
            )
        }
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pi = PendingIntent.getActivity(context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        nm.notify(System.currentTimeMillis().toInt(),
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .build()
        )
    }
}
