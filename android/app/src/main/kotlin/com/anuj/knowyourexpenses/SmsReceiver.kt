package com.anuj.knowyourexpenses

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
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

        private val DEBIT_KEYWORDS = listOf(
            "debited", "paid to", "spent", "sent to",
            "txn of rs", "transaction of rs", "vpa", "upi/p2m", "upi/p2a",
            "paid at", "payment of", "purchase of", "transferred", "withdrawn",
            "charged", "txn of inr"
        )
        private val CREDIT_KEYWORDS = listOf(
            "credited", "received rs", "added to account", "deposited"
        )
        private val SPAM_KEYWORDS = listOf("otp", "secret code", "verification code")
        private val SELF_TRANSFER_KEYWORDS = listOf(
            "self transfer", "transfer to own a/c", "own account transfer"
        )

        private val AMOUNT_PATTERN = Pattern.compile(
            """(?:rs\.?|inr\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)""", Pattern.CASE_INSENSITIVE
        )
        private val REF_PATTERN = Pattern.compile(
            """(?:upi|ref|ref\s*no|rrn|txn\s*id|info)[\:\/\s\-]*([a-zA-Z0-9]{6,25})""",
            Pattern.CASE_INSENSITIVE
        )
        private val DATE_PATTERN = Pattern.compile(
            """(?:dt|date|on)?\s*(\d{2}[\/\-]\d{2}[\/\-]\d{2,4}(?:\s+\d{2}:\d{2}(?::\d{2})?)?)""",
            Pattern.CASE_INSENSITIVE
        )
        private val VENDOR_TO_PATTERN = Pattern.compile(
            """(?:to|paid to|sent to)\s+([A-Za-z0-9\s._-]+?)(?:\s+(?:thru|through|via|using|by|towards|on|ref|vpa|upi|avail|bal|a/c|dt|date)|$)""",
            Pattern.CASE_INSENSITIVE
        )
        private val VENDOR_AT_PATTERN = Pattern.compile(
            """(?:at|for|towards|merchant)\s+([A-Za-z0-9\s._-]+?)(?:\s+(?:thru|through|via|ref|vpa|upi|avail|bal|a/c|dt|date)|$)""",
            Pattern.CASE_INSENSITIVE
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_ENABLED, false)
        if (!isEnabled) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        for (sms in messages) {
            val body = sms.messageBody ?: continue
            val parsed = parseSms(body) ?: continue

            val existingJson = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val list = try { JSONArray(existingJson) } catch (e: Exception) { JSONArray() }

            var duplicate = false
            for (i in 0 until list.length()) {
                if (list.optJSONObject(i)?.optString("id") == parsed.optString("id")) {
                    duplicate = true; break
                }
            }
            if (duplicate) continue

            val newList = JSONArray()
            newList.put(parsed)
            for (i in 0 until list.length()) newList.put(list.get(i))
            prefs.edit().putString(KEY_PENDING, newList.toString()).apply()

            val amount = parsed.optDouble("amount", 0.0)
            val vendor = parsed.optString("vendorName", "Unknown")
            showNotification(context,
                title = "New Auto-Detected Expense",
                body = "Rs.${"%.2f".format(amount)} at $vendor. Tap to assign Group."
            )

            val broadcastIntent = Intent("com.anuj.knowyourexpenses.SMS_RECEIVED_EVENT").apply {
                setPackage(context.packageName)
            }
            context.sendBroadcast(broadcastIntent)
        }
    }

    private fun parseSms(body: String): JSONObject? {
        val lower = body.lowercase(Locale.getDefault())
        if (SPAM_KEYWORDS.any { lower.contains(it) }) return null
        if (SELF_TRANSFER_KEYWORDS.any { lower.contains(it) }) return null

        val isExpense = DEBIT_KEYWORDS.any { lower.contains(it) }
        val isCredit = CREDIT_KEYWORDS.any { lower.contains(it) }
        if (!isExpense && !isCredit) return null

        val amount = extractAmount(body) ?: return null
        if (amount <= 0) return null

        val vendor = extractVendor(body)
        val refNo = extractRef(body)
        val dateRaw = extractDateRaw(body)
        val date = extractDate(body)

        val cleanRef = refNo?.lowercase()?.replace(Regex("[^a-z0-9]"), "") ?: ""
        val cleanDate = dateRaw.replace(Regex("[^a-z0-9]"), "")
        val cleanVendor = vendor.lowercase().replace(Regex("[^a-z0-9]"), "")
        val hashId = if (cleanRef.isNotEmpty() || cleanDate.isNotEmpty()) {
            "hash_${cleanRef}_${cleanDate}_$cleanVendor"
        } else {
            val snippet = lower.replace(Regex("\\d+"), "").replace(Regex("[^a-z]"), "")
            "hash_${cleanVendor}_${snippet.take(30)}"
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
        }
    }

    private fun extractAmount(body: String): Double? {
        val m = AMOUNT_PATTERN.matcher(body)
        return if (m.find()) m.group(1)?.replace(",", "")?.toDoubleOrNull() else null
    }

    private fun extractRef(body: String): String? {
        val m = REF_PATTERN.matcher(body)
        return if (m.find()) m.group(1)?.trim() else null
    }

    private fun extractDateRaw(body: String): String {
        val m = DATE_PATTERN.matcher(body)
        return if (m.find()) m.group(1)?.trim()?.replace(Regex("[^a-zA-Z0-9]"), "") ?: "" else ""
    }

    private fun extractDate(body: String): String {
        val m = DATE_PATTERN.matcher(body)
        if (m.find()) {
            val str = m.group(1)?.trim() ?: return currentIso()
            val parts = str.split(Regex("\\s+"))
            val dateComponents = parts[0].split(Regex("[/\\-]"))
            if (dateComponents.size == 3) {
                val day = dateComponents[0].padStart(2, '0')
                val month = dateComponents[1].padStart(2, '0')
                var year = dateComponents[2].toIntOrNull() ?: return currentIso()
                if (year < 100) year += 2000
                val timeParts = (if (parts.size > 1) parts[1] else "00:00:00").split(":")
                val h = timeParts.getOrNull(0)?.padStart(2, '0') ?: "00"
                val mi = timeParts.getOrNull(1)?.padStart(2, '0') ?: "00"
                val s = timeParts.getOrNull(2)?.padStart(2, '0') ?: "00"
                return "${year}-${month}-${day}T${h}:${mi}:${s}.000"
            }
        }
        return currentIso()
    }

    private fun currentIso(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault()).format(Date())

    private fun extractVendor(body: String): String {
        val m1 = VENDOR_TO_PATTERN.matcher(body)
        if (m1.find()) { val v = m1.group(1)?.trim() ?: ""; if (v.length > 1) return capitalize(v.take(30)) }
        val m2 = VENDOR_AT_PATTERN.matcher(body)
        if (m2.find()) { val v = m2.group(1)?.trim() ?: ""; if (v.length > 1) return capitalize(v.take(30)) }
        return "Bank Transfer (UPI)"
    }

    private fun capitalize(text: String): String =
        text.trim().split(" ").joinToString(" ") {
            if (it.isEmpty()) "" else it[0].uppercaseChar() + it.substring(1).lowercase()
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
