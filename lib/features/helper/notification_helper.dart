import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 0. Initialize local notifications for background isolate
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      );
      await flutterLocalNotificationsPlugin.initialize(settings: settings);

      // 1. Initialize Firebase in background isolate
      await Firebase.initializeApp();

      // Wait up to 2 seconds for Firebase Auth to load user session from persistent storage
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          user = FirebaseAuth.instance.currentUser;
          if (user != null) break;
        }
      }
      final userId = user?.uid;

      if (task == "morning-summary") {
        if (userId != null) {
          await _handleMorningSummary(userId);
        } else {
          debugPrint("Workmanager: morning-summary skipped because userId is null");
        }
      } else if (task == "evening-summary") {
        if (userId != null) {
          await NotificationHelper().handleEveningSummary(userId);
        } else {
          debugPrint("Workmanager: evening-summary skipped because userId is null");
        }
      }

      return true;
    } catch (e) {
      try {
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'daily_summary_channel',
          'Daily Summary',
          channelDescription: 'Daily spend and available balance summaries',
          importance: Importance.max,
          priority: Priority.high,
        );
        await flutterLocalNotificationsPlugin.show(
          id: 999,
          title: "Debug: Task Failed",
          body: e.toString(),
          notificationDetails: NotificationDetails(
            android: androidDetails,
            iOS: const DarwinNotificationDetails(),
          ),
        );
      } catch (_) {}
      return false;
    }
  });
}

// Mock helpers removed to prevent showing dummy data statements.

Future<void> _handleMorningSummary(String userId) async {
  final now = DateTime.now();
  final yesterdayStart = DateTime(now.year, now.month, now.day - 1, 0, 0, 0);
  final yesterdayEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);

  final personalSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('transactions')
      .get();

  final groupsSnapshot = await FirebaseFirestore.instance
      .collection('groups')
      .where('members', arrayContains: userId)
      .get();

  final List<Map<String, dynamic>> allTransactions = [];
  for (var doc in personalSnapshot.docs) {
    allTransactions.add(doc.data());
  }

  for (var groupDoc in groupsSnapshot.docs) {
    final groupTxsSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupDoc.id)
        .collection('transactions')
        .get();
    for (var txDoc in groupTxsSnapshot.docs) {
      allTransactions.add(txDoc.data());
    }
  }

  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double yesterdaySpent = 0.0;

  for (var data in allTransactions) {
    DateTime? date;
    final rawDate = data['date'];
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (rawDate is String) {
        date = DateTime.tryParse(rawDate);
      }
    }
    if (date == null) continue;
    double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final isShared = data['isShared'] as bool? ?? false;
    final splitWith = List<String>.from(data['splitWith'] ?? []);
    final splitAmounts = Map<String, dynamic>.from(data['splitAmounts'] ?? {});
    final isExpense = data['isExpense'] as bool? ?? true;

    if (isShared && splitWith.isNotEmpty) {
      if (splitWith.contains(userId)) {
        if (splitAmounts.containsKey(userId)) {
          amount = (splitAmounts[userId] as num?)?.toDouble() ?? 0.0;
        } else {
          amount = amount / splitWith.length;
        }
      } else {
        amount = 0.0;
      }
    }

    if (isExpense) {
      totalExpense += amount;
      if (date.isAfter(yesterdayStart) && date.isBefore(yesterdayEnd)) {
        yesterdaySpent += amount;
      }
    } else {
      totalIncome += amount;
    }
  }

  final balance = totalIncome - totalExpense;

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'morning_summary_channel',
    'Morning Summary',
    channelDescription: 'Yesterday spend and available balance summary',
    importance: Importance.max,
    priority: Priority.max,
  );

  final String bodyMessage = yesterdaySpent > 0
      ? "Yesterday you spent ₹${yesterdaySpent.toStringAsFixed(2)}. Available balance: ₹${balance.toStringAsFixed(2)}. Tap to add today's expenses!"
      : "You spent nothing yesterday! Available balance: ₹${balance.toStringAsFixed(2)}. Tap to add today's expenses!";

  await flutterLocalNotificationsPlugin.show(
    id: 10,
    title: "Yesterday's Summary 💸",
    body: bodyMessage,
    notificationDetails: const NotificationDetails(
      android: androidDetails
    ),
  );
}



class NotificationHelper {
  static Future<void> initialize() async {
    try {
      // 1. Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings
      );

      await flutterLocalNotificationsPlugin.initialize(
        settings: settings
      );

      // Initialize timezone database
      tz.initializeTimeZones();
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Fallback
      }

      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      // 2. Initialize WorkManager
      await Workmanager().initialize(
        callbackDispatcher,
      );

      // Schedule static 9:00 AM notification
      await _schedule9AMReminder();

      // Schedule 8:30 AM & 7:30 PM one-off tasks with initial delays
      final now = DateTime.now();

      var target830 = DateTime(now.year, now.month, now.day, 8, 30);
      if (target830.isBefore(now)) {
        target830 = target830.add(const Duration(days: 1));
      }
      final delay830 = target830.difference(now);

      await Workmanager().registerPeriodicTask(
        "morning-summary-periodic-task",
        "morning-summary",
        frequency: const Duration(hours: 24),
        initialDelay: delay830,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );

      var target1930 = DateTime(now.year, now.month, now.day, 19, 30);
      if (target1930.isBefore(now)) {
        target1930 = target1930.add(const Duration(days: 1));
      }
      final delay1930 = target1930.difference(now);

      await Workmanager().registerPeriodicTask(
        "evening-summary-periodic-task",
        "evening-summary",
        frequency: const Duration(hours: 24),
        initialDelay: delay1930,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (e) {
      // Prevent blocking app initialization
      debugPrint("NotificationHelper.initialize error: $e");
    }
  }

  Future<void> handleEveningSummary(String userId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final personalSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .get();

    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: userId)
        .get();

    final List<Map<String, dynamic>> allTransactions = [];
    for (var doc in personalSnapshot.docs) {
      allTransactions.add(doc.data());
    }

    final List<Map<String, dynamic>> groupTransactionsTodayOther = [];

    for (var groupDoc in groupsSnapshot.docs) {
      final groupData = groupDoc.data();
      final groupName = groupData['name'] ?? 'Unknown Group';
      final groupType = groupData['type'] ?? 'split';

      DateTime? createdDate;
      final rawCreatedAt = groupData['createdAt'];
      if (rawCreatedAt != null) {
        if (rawCreatedAt is Timestamp) {
          createdDate = rawCreatedAt.toDate();
        } else if (rawCreatedAt is String) {
          createdDate = DateTime.tryParse(rawCreatedAt);
        }
      }
      if (createdDate != null) {
        if (createdDate.isAfter(todayStart) && createdDate.isBefore(todayEnd)) {
          final adminId = groupData['adminId'] ?? '';
          String creatorName = 'Someone';
          if (adminId.isNotEmpty) {
            final adminDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(adminId)
                .get();
            creatorName = adminDoc.data()?['name'] ?? 'Someone';
          }

          const AndroidNotificationDetails groupCreatedDetails = AndroidNotificationDetails(
            'group_creation_channel',
            'Group Creation',
            channelDescription: 'Notifications when new groups are created',
            importance: Importance.max,
            priority: Priority.max,
          );
          await flutterLocalNotificationsPlugin.show(
            id: groupDoc.id.hashCode,
            title: "New Group Created! 👥",
            body: "$creatorName created group '$groupName'. Tap to view.",
            notificationDetails: const NotificationDetails(
              android: groupCreatedDetails,
              iOS: DarwinNotificationDetails(),
            ),
          );
        }
      }

      final groupTxsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupDoc.id)
          .collection('transactions')
          .get();

      for (var txDoc in groupTxsSnapshot.docs) {
        final txData = txDoc.data();
        allTransactions.add(txData);

        DateTime? txDate;
        final rawTxDate = txData['date'];
        if (rawTxDate != null) {
          if (rawTxDate is Timestamp) {
            txDate = rawTxDate.toDate();
          } else if (rawTxDate is String) {
            txDate = DateTime.tryParse(rawTxDate);
          }
        }
        if (txDate != null) {
          final txUserId = txData['userId'] as String? ?? '';
          if (txDate.isAfter(todayStart) &&
              txDate.isBefore(todayEnd) &&
              txUserId != userId) {
            groupTransactionsTodayOther.add({
              ...txData,
              'groupName': groupName,
              'groupType': groupType,
            });
          }
        }
      }
    }

    for (var tx in groupTransactionsTodayOther) {
      final groupType = tx['groupType'] as String;
      if (groupType == 'business') {
        final txUserId = tx['userId'] as String;
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final description = tx['description'] ?? 'Expense';
        final groupName = tx['groupName'] ?? 'Group';

        String memberName = 'Someone';
        if (txUserId.isNotEmpty) {
          final memberDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(txUserId)
              .get();
          memberName = memberDoc.data()?['name'] ?? 'Someone';
        }

        const AndroidNotificationDetails txDetails = AndroidNotificationDetails(
          'group_transactions_channel',
          'Group Transactions',
          channelDescription: 'Notifications for transactions added by other members',
          importance: Importance.max,
          priority: Priority.high,
        );

        await flutterLocalNotificationsPlugin.show(
          id: tx['id']?.hashCode ?? now.hashCode,
          title: "New Shared Expense 💸",
          body: "$memberName added ₹${amount.toStringAsFixed(2)} for '$description' in '$groupName'.",
          notificationDetails: const NotificationDetails(
            android: txDetails
          ),
        );
      }
    }

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    double todaySpent = 0.0;

    for (var data in allTransactions) {
      DateTime? date;
      final rawDate = data['date'];
      if (rawDate != null) {
        if (rawDate is Timestamp) {
          date = rawDate.toDate();
        } else if (rawDate is String) {
          date = DateTime.tryParse(rawDate);
        }
      }
      if (date == null) continue;
      double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final isShared = data['isShared'] as bool? ?? false;
      final splitWith = List<String>.from(data['splitWith'] ?? []);
      final splitAmounts = Map<String, dynamic>.from(data['splitAmounts'] ?? {});
      final isExpense = data['isExpense'] as bool? ?? true;

      if (isShared && splitWith.isNotEmpty) {
        if (splitWith.contains(userId)) {
          if (splitAmounts.containsKey(userId)) {
            amount = (splitAmounts[userId] as num?)?.toDouble() ?? 0.0;
          } else {
            amount = amount / splitWith.length;
          }
        } else {
          amount = 0.0;
        }
      }

      if (isExpense) {
        totalExpense += amount;
        if (date.isAfter(todayStart) && date.isBefore(todayEnd)) {
          todaySpent += amount;
        }
      } else {
        totalIncome += amount;
      }
    }

    final balance = totalIncome - totalExpense;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'evening_summary_channel',
      'Evening Summary',
      channelDescription: 'Today spend and available balance summary',
      importance: Importance.max,
      priority: Priority.high,
    );

    final String bodyMessage = todaySpent > 0
        ? "Today's Summary 📊 Today you spent ₹${todaySpent.toStringAsFixed(2)}. Available balance: ₹${balance.toStringAsFixed(2)}."
        : "You spent ₹0 today! Great job saving money. 💰";

    await flutterLocalNotificationsPlugin.show(
      id: 20,
      title: "Today's Summary",
      body: bodyMessage,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }


  static Future<void> _schedule9AMReminder() async {
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(9, 0);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 1,
      title: "Start Your Day! 🌅",
      body: "Remember to track your expenses today to stay on budget.",
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminder_channel',
          'Morning Reminder',
          channelDescription: 'Daily morning motivational reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
