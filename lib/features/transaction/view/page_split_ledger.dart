import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view/dialog_transaction_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final selectedGroupFilterProvider = StateProvider<String?>((ref) => null);
final groupsHubTabProvider = StateProvider<int>(
  (ref) => 0,
); // 0 = Expenses, 1 = Activity Log

final overallNetBalanceProvider = Provider<double>((ref) {
  final groups = ref.watch(userGroupsStreamProvider).value ?? [];
  final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (groups.isEmpty || currentUserId == null) return 0.0;

  double overall = 0.0;
  for (var group in groups) {
    if (group.type == 'business')
      continue; // Business groups have no debt splitting

    final balances = ref.watch(groupSplitBalancesProvider(group.id));
    for (var b in balances) {
      if (b.debtorId == currentUserId) {
        overall -= b.amount;
      } else if (b.creditorId == currentUserId) {
        overall += b.amount;
      }
    }
  }
  return overall;
});

final allGroupsMembersProvider = StreamProvider<Map<String, String>>((ref) {
  final groups = ref.watch(userGroupsStreamProvider).value ?? [];
  if (groups.isEmpty) return Stream.value({});

  final allUids = groups.expand((g) => g.members).toSet().toList();
  if (allUids.isEmpty) return Stream.value({});

  final chunked = allUids.take(10).toList();

  return FirebaseFirestore.instance
      .collection('users')
      .where(FieldPath.documentId, whereIn: chunked)
      .snapshots()
      .map((snapshot) {
        return {
          for (var doc in snapshot.docs)
            doc.id: doc.data()['name'] as String? ?? 'Group Member',
        };
      });
});

class SplitLedgerPage extends ConsumerWidget {
  const SplitLedgerPage({super.key});

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalHeaderHeight = 148;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(36),
            bottomRight: Radius.circular(36),
          ),
          child: Container(
            height: totalHeaderHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A5C3A),
                  Color(0xFF2E8B57),
                  Color(0xFF3EAF78),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -25,
                  left: 20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: totalHeaderHeight - statusBarHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(bottomNavIndexProvider.notifier).state = 0;
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Groups Hub',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onSettleUp(
    BuildContext context,
    WidgetRef ref,
    SplitBalance balance,
    String groupId,
  ) async {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Settle Up',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Record a payment of ₹${balance.amount.toStringAsFixed(2)} from ${balance.debtorName} to ${balance.creditorName}?',
          style: GoogleFonts.manrope(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E8B57),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);

              final categories = ref.read(categoriesProvider).value ?? [];
              final otherCategory = categories.firstWhere(
                (c) => c.id == 'other',
                orElse: () => CategoryModel(
                  id: 'other',
                  name: 'Other',
                  iconCodePoint: Icons.more_horiz.codePoint,
                  colorValue: Colors.grey.value,
                ),
              );

              // Correct settlement payer: Pass overrideUserId as debtorId
              final success = await ref
                  .read(transactionViewModelProvider.notifier)
                  .addTransaction(
                    amount: balance.amount,
                    description:
                        'Settle: ${balance.debtorName} to ${balance.creditorName}',
                    category: otherCategory,
                    date: DateTime.now(),
                    isExpense: true,
                    isShared: true,
                    splitWith: [balance.creditorId],
                    targetGroupId: groupId,
                    overrideUserId: balance.debtorId,
                  );

              if (success && context.mounted) {
                Utils.showSuccessToast(context, title: "Settle Up Successful!");
              }
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsStreamProvider);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final allTransactionsAsync = ref.watch(allGroupsTransactionsProvider);
    final memberNames = ref.watch(allGroupsMembersProvider).value ?? {};
    final selectedGroupId = ref.watch(selectedGroupFilterProvider);
    final currentTab = ref.watch(groupsHubTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: currentUserId == null
          ? _buildNoGroupView(
              context,
              "Sign In Required",
              "Please sign in to view your groups.",
            )
          : groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return _buildNoGroupView(
                    context,
                    "No Active Groups",
                    "You are not a member of any groups yet. Create or join a group in Settings.",
                  );
                }

                final groupNames = {for (var g in groups) g.id: g.name};

                // Filter groups for rendering
                final filteredGroups = selectedGroupId == null
                    ? groups
                    : groups.where((g) => g.id == selectedGroupId).toList();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(child: _buildHeader(context, ref)),
                    // 1. Overall Balance Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          24.0,
                          16.0,
                          24.0,
                          16.0,
                        ),
                        child: _OverallBalanceCard(ref: ref),
                      ),
                    ),

                    // 1.5 Tab Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      ref
                                              .read(
                                                groupsHubTabProvider.notifier,
                                              )
                                              .state =
                                          0,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: currentTab == 0
                                          ? const Color(0xFF2E8B57)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Expenses',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: currentTab == 0
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      ref
                                              .read(
                                                groupsHubTabProvider.notifier,
                                              )
                                              .state =
                                          1,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: currentTab == 1
                                          ? const Color(0xFF2E8B57)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Activity Log',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: currentTab == 1
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (currentTab == 0) ...[
                      // ─── EXPENSES TAB ───
                      // 2. Groups Section
                      if (selectedGroupId != null) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                            child: Text(
                              'Selected Group',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E232A),
                              ),
                            ),
                          ),
                        ),

                        SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final group = filteredGroups[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 6,
                              ),
                              child: _GroupLedgerCard(
                                group: group,
                                currentUserId: currentUserId,
                                onSettle: (balance) =>
                                    _onSettleUp(context, ref, balance, group.id),
                              ),
                            );
                          }, childCount: filteredGroups.length),
                        ),
                      ],

                      // 3. Transactions Section Header with Dropdown Filter
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Group Expenses',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E232A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: selectedGroupId,
                                    hint: Text(
                                      'All Groups',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: const Color(0xFF1E232A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          'All Groups',
                                          style: GoogleFonts.manrope(),
                                        ),
                                      ),
                                      ...groups.map((g) {
                                        return DropdownMenuItem<String?>(
                                          value: g.id,
                                          child: Text(
                                            g.name,
                                            style: GoogleFonts.manrope(),
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      ref
                                              .read(
                                                selectedGroupFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          val;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      allTransactionsAsync.when(
                        data: (transactions) {
                          // Filter list
                          final filteredTransactions = selectedGroupId == null
                              ? transactions
                              : transactions
                                    .where((t) => t.groupId == selectedGroupId)
                                    .toList();

                          if (filteredTransactions.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    'No transactions recorded yet.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final t = filteredTransactions[index];
                              final isMePayer = t.userId == currentUserId;
                              final payerName = isMePayer
                                  ? 'You'
                                  : (memberNames[t.userId] ?? 'Group Member');
                              final groupName =
                                  groupNames[t.groupId] ?? 'Group';

                              final inSplit =
                                  t.splitWith != null &&
                                  t.splitWith!.contains(currentUserId);

                              double myShare = 0.0;
                              if (t.splitAmounts != null &&
                                  t.splitAmounts!.containsKey(currentUserId)) {
                                myShare = t.splitAmounts![currentUserId]!;
                              } else if (t.splitWith != null &&
                                  t.splitWith!.isNotEmpty) {
                                myShare = t.amount / t.splitWith!.length;
                              }

                              String splitStatus = '';
                              Color statusColor = Colors.grey[600]!;

                              if (t.splitWith != null &&
                                  t.splitWith!.isNotEmpty) {
                                if (isMePayer) {
                                  final lent = t.amount - myShare;
                                  splitStatus =
                                      'You lent ₹${lent.toStringAsFixed(2)}';
                                  statusColor = Colors.green[700]!;
                                } else {
                                  if (inSplit) {
                                    splitStatus =
                                        'You owe ₹${myShare.toStringAsFixed(2)}';
                                    statusColor = Colors.red[700]!;
                                  } else {
                                    splitStatus = 'Not involved';
                                    statusColor = Colors.grey[600]!;
                                  }
                                }
                              } else {
                                // Non-shared group expense (e.g. recorded under business group)
                                if (isMePayer) {
                                  splitStatus = t.isExpense
                                      ? 'You paid'
                                      : 'You received';
                                  statusColor = t.isExpense
                                      ? Colors.red[700]!
                                      : Colors.green[700]!;
                                } else {
                                  splitStatus = t.isExpense
                                      ? 'Employee paid'
                                      : 'Employee received';
                                  statusColor = Colors.grey[600]!;
                                }
                              }

                              final splitMembersNames =
                                  t.splitWith?.map((uid) {
                                    return uid == currentUserId
                                        ? 'You'
                                        : (memberNames[uid] ?? 'Group Member');
                                  }).toList() ??
                                  [];

                              String splitDesc = '';
                              if (splitMembersNames.isNotEmpty) {
                                splitDesc =
                                    ' • Split with ${splitMembersNames.join(', ')}';
                              }

                              final dateStr = DateFormat(
                                'MMM dd, yyyy',
                              ).format(t.date);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      showGeneralDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        barrierLabel: '',
                                        barrierColor: Colors.black54,
                                        transitionDuration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        pageBuilder: (_, __, ___) =>
                                            TransactionDetailDialog(
                                              transaction: t,
                                            ),
                                        transitionBuilder:
                                            (_, animation, __, child) {
                                              return ScaleTransition(
                                                scale: CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutBack,
                                                ),
                                                child: FadeTransition(
                                                  opacity: CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeIn,
                                                  ),
                                                  child: child,
                                                ),
                                              );
                                            },
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.02,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: t.color
                                                .withOpacity(0.12),
                                            child: Icon(
                                              t.icon,
                                              color: t.color,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        t.description.isNotEmpty
                                                            ? t.description
                                                            : t.categoryName,
                                                        style:
                                                            GoogleFonts.manrope(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                              color:
                                                                  const Color(
                                                                    0xFF1E232A,
                                                                  ),
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE6F3F2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        groupName,
                                                        style:
                                                            GoogleFonts.manrope(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color:
                                                                  const Color(
                                                                    0xFF2E7D79,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Paid by $payerName$splitDesc • $dateStr',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₹${t.amount.toStringAsFixed(2)}',
                                                style: GoogleFonts.manrope(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: const Color(
                                                    0xFF1E232A,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                splitStatus,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: filteredTransactions.length),
                          );
                        },
                        loading: () => const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF2E8B57),
                              ),
                            ),
                          ),
                        ),
                        error: (err, stack) => SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              'Error: $err',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // ─── ACTIVITY LOG TAB ───
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Activity History',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E232A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: selectedGroupId,
                                    hint: Text(
                                      'Select Group',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: const Color(0xFF1E232A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: groups.map((g) {
                                      return DropdownMenuItem<String?>(
                                        value: g.id,
                                        child: Text(
                                          g.name,
                                          style: GoogleFonts.manrope(),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      ref
                                              .read(
                                                selectedGroupFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          val;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (selectedGroupId == null)
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 64,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.filter_list_rounded,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Please select a specific group from the dropdown filter to view its Activity Log.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ref
                            .watch(groupLogsStreamProvider(selectedGroupId))
                            .when(
                              data: (logs) {
                                if (logs.isEmpty) {
                                  return const SliverToBoxAdapter(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(48.0),
                                        child: Text(
                                          'No log records found for this group.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final log = logs[index];
                                    final authorName =
                                        log['userName'] as String? ?? 'Member';
                                    final role =
                                        log['userRole'] as String? ?? 'member';
                                    final action =
                                        log['action'] as String? ?? 'action';
                                    final details =
                                        log['details'] as String? ?? '';

                                    // Parse timestamp
                                    DateTime time = DateTime.now();
                                    if (log['timestamp'] != null) {
                                      time = (log['timestamp'] as Timestamp)
                                          .toDate();
                                    }
                                    final timeStr = DateFormat(
                                      'MMM dd, hh:mm a',
                                    ).format(time);

                                    IconData iconData = Icons.info_outline;
                                    Color iconColor = Colors.grey;
                                    String actionPhrase = ' performed an action.';
                                    Color actionColor = Colors.grey[700]!;

                                    if (action == 'add') {
                                      iconData = Icons.add_circle_rounded;
                                      iconColor = const Color(0xFF2E8B57);
                                      actionPhrase = ' added a transaction.';
                                      actionColor = const Color(0xFF2E8B57);
                                    } else if (action == 'edit') {
                                      iconData = Icons.edit_rounded;
                                      iconColor = Colors.orange[800]!;
                                      actionPhrase = ' edited a transaction.';
                                      actionColor = Colors.orange[800]!;
                                    } else if (action == 'delete') {
                                      iconData = Icons.delete_forever_rounded;
                                      iconColor = Colors.red[700]!;
                                      actionPhrase = ' deleted a transaction.';
                                      actionColor = Colors.red[700]!;
                                    } else if (action == 'toggle_type') {
                                      iconData = Icons.swap_horiz_rounded;
                                      iconColor = Colors.blue[700]!;
                                      actionPhrase = ' changed transaction type.';
                                      actionColor = Colors.blue[700]!;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 6,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.01,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: iconColor
                                                  .withOpacity(0.1),
                                              radius: 18,
                                              child: Icon(
                                                iconData,
                                                color: iconColor,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      style:
                                                          GoogleFonts.manrope(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: 13,
                                                          ),
                                                      children: [
                                                        TextSpan(
                                                          text: '$authorName ',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        TextSpan(
                                                           text:
                                                               '(${role.toUpperCase()})',
                                                           style: TextStyle(
                                                             color:
                                                                 role == 'admin'
                                                                 ? Colors
                                                                       .red[800]
                                                                 : Colors
                                                                       .blue[800],
                                                             fontSize: 10,
                                                             fontWeight:
                                                                 FontWeight.bold,
                                                           ),
                                                         ),
                                                         TextSpan(
                                                           text: actionPhrase,
                                                           style: TextStyle(
                                                             color: actionColor,
                                                             fontWeight: FontWeight.bold,
                                                           ),
                                                         ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (details.isNotEmpty) ...[
                                                     const SizedBox(height: 6),
                                                     if (action == 'edit') () {
                                                       final firstColon = details.indexOf(': ');
                                                       final mainText = firstColon != -1 ? details.substring(0, firstColon) : details;
                                                       final changesText = firstColon != -1 ? details.substring(firstColon + 2) : '';
                                                       final changeItems = changesText.isNotEmpty
                                                           ? (changesText.contains('; ')
                                                               ? changesText.split('; ')
                                                               : changesText.split(', '))
                                                           : <String>[];
                                                       
                                                       return Column(
                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                         children: [
                                                           Text(
                                                             mainText,
                                                             style: GoogleFonts.manrope(
                                                               color: Colors.grey[700],
                                                               fontSize: 12,
                                                               fontWeight: FontWeight.bold,
                                                             ),
                                                           ),
                                                           if (changeItems.isNotEmpty)
                                                             Padding(
                                                               padding: const EdgeInsets.only(top: 4),
                                                               child: Column(
                                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                                 children: changeItems.map((item) {
                                                                   return Padding(
                                                                     padding: const EdgeInsets.only(top: 2, left: 4),
                                                                     child: Row(
                                                                       children: [
                                                                         const Icon(Icons.arrow_right_rounded, size: 16, color: Colors.orange),
                                                                         const SizedBox(width: 4),
                                                                         Expanded(
                                                                           child: Text(
                                                                             item,
                                                                             style: GoogleFonts.manrope(
                                                                               fontSize: 11,
                                                                               color: Colors.grey[600],
                                                                               fontWeight: FontWeight.w600,
                                                                             ),
                                                                           ),
                                                                         ),
                                                                       ],
                                                                     ),
                                                                   );
                                                                 }).toList(),
                                                               ),
                                                             ),
                                                         ],
                                                       );
                                                     }() else if (action == 'delete') ...[
                                                       Text(
                                                         details,
                                                         style: GoogleFonts.manrope(
                                                           color: Colors.red[700],
                                                           fontSize: 12,
                                                           fontWeight: FontWeight.bold,
                                                         ),
                                                       ),
                                                     ] else ...[
                                                       Text(
                                                         details,
                                                         style: GoogleFonts.manrope(
                                                           color: Colors.grey[600],
                                                           fontSize: 12,
                                                           fontWeight: FontWeight.w500,
                                                         ),
                                                       ),
                                                     ],
                                                   ],
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    timeStr,
                                                    style: GoogleFonts.manrope(
                                                      color: Colors.grey[400],
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }, childCount: logs.length),
                                );
                              },
                              loading: () => const SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF2E8B57),
                                    ),
                                  ),
                                ),
                              ),
                              error: (e, s) => SliverToBoxAdapter(
                                child: Center(
                                  child: Text(
                                    'Error: $e',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E8B57)),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error loading groups: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
    );
  }

  Widget _buildNoGroupView(
    BuildContext context,
    String title,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E232A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallBalanceCard extends ConsumerWidget {
  final WidgetRef ref;
  const _OverallBalanceCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupId = ref.watch(selectedGroupFilterProvider);
    
    if (selectedGroupId != null) {
      final group = ref.watch(groupByIdStreamProvider(selectedGroupId)).value;
      if (group == null || group.type == 'business') {
        return const SizedBox.shrink();
      }
    }

    final overallBalance = selectedGroupId == null
        ? ref.watch(overallNetBalanceProvider)
        : () {
            final currentUserId = ref
                .watch(firebaseAuthProvider)
                .currentUser
                ?.uid;
            if (currentUserId == null) return 0.0;

            final balances = ref.watch(
              groupSplitBalancesProvider(selectedGroupId),
            );
            double groupNet = 0.0;
            for (var b in balances) {
              if (b.debtorId == currentUserId) {
                groupNet -= b.amount;
              } else if (b.creditorId == currentUserId) {
                groupNet += b.amount;
              }
            }
            return groupNet;
          }();

    final isMeCreditor = overallBalance > 0.01;
    final isMeDebtor = overallBalance < -0.01;

    Color cardColor = const Color(0xFFF1F3F4);
    Color textColor = const Color(0xFF1E232A);
    String titleText = selectedGroupId == null ? "All Settled Up" : "All Settled Up in this Group";
    String descriptionText = "You don't owe anything.";

    if (isMeCreditor) {
      cardColor = const Color(0xFFE6F4EA);
      textColor = Colors.green[800]!;
      titleText = selectedGroupId == null ? "Overall Owed To You" : "Owed To You in this Group";
      descriptionText = selectedGroupId == null
          ? "You are owed a net total of ₹${overallBalance.abs().toStringAsFixed(2)} across groups."
          : "You are owed a net total of ₹${overallBalance.abs().toStringAsFixed(2)} in this group.";
    } else if (isMeDebtor) {
      cardColor = const Color(0xFFFFEBEE);
      textColor = Colors.red[800]!;
      titleText = selectedGroupId == null ? "Overall You Owe" : "You Owe in this Group";
      descriptionText = selectedGroupId == null
          ? "You owe a net total of ₹${overallBalance.abs().toStringAsFixed(2)} across groups."
          : "You owe a net total of ₹${overallBalance.abs().toStringAsFixed(2)} in this group.";
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${overallBalance.abs().toStringAsFixed(2)}',
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descriptionText,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLedgerCard extends ConsumerWidget {
  final GroupModel group;
  final String currentUserId;
  final Function(SplitBalance) onSettle;

  const _GroupLedgerCard({
    required this.group,
    required this.currentUserId,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(groupSplitBalancesProvider(group.id));
    final transactions =
        ref.watch(groupTransactionsStreamByIdProvider(group.id)).value ?? [];

    final groupType = group.toMap()['type'] as String? ?? 'split';
    final isBusiness = groupType == 'business';

    final userBalances = isBusiness
        ? <SplitBalance>[]
        : balances
            .where((b) =>
                b.debtorId == currentUserId || b.creditorId == currentUserId)
            .toList();

    double groupNetBalance = 0.0;
    if (!isBusiness) {
      for (var b in balances) {
        if (b.debtorId == currentUserId) {
          groupNetBalance -= b.amount;
        } else if (b.creditorId == currentUserId) {
          groupNetBalance += b.amount;
        }
      }
    }

    double totalUserSpending = 0.0;
    for (var t in transactions) {
      if (isBusiness) {
        if (t.userId == currentUserId) {
          totalUserSpending += t.amount;
        }
      } else {
        if (t.isShared &&
            t.splitWith != null &&
            t.splitWith!.contains(currentUserId)) {
          if (t.splitAmounts != null &&
              t.splitAmounts!.containsKey(currentUserId)) {
            totalUserSpending += t.splitAmounts![currentUserId]!;
          } else {
            totalUserSpending += t.amount / t.splitWith!.length;
          }
        }
      }
    }

    final isMeCreditor = groupNetBalance > 0.01;
    final isMeDebtor = groupNetBalance < -0.01;

    Color statusColor = Colors.grey[600]!;
    if (isMeCreditor) {
      statusColor = Colors.green[700]!;
    } else if (isMeDebtor) {
      statusColor = Colors.red[700]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBusiness
                      ? const Color(0xFFE3F2FD)
                      : const Color(0xFFE6F3F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBusiness
                      ? Icons.business_center_rounded
                      : Icons.group_rounded,
                  color: isBusiness
                      ? Colors.blue[800]
                      : const Color(0xFF2E7D79),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          group.name,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E232A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isBusiness
                                ? Colors.blue[50]
                                : const Color(0xFFE6F3F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isBusiness
                                  ? Colors.blue[100]!
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            isBusiness ? 'Business' : 'Split',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isBusiness
                                  ? Colors.blue[800]
                                  : const Color(0xFF2E7D79),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBusiness
                          ? 'Your total spending: ₹${totalUserSpending.toStringAsFixed(2)}'
                          : 'Your total spending here: ₹${totalUserSpending.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isBusiness)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isMeCreditor
                        ? 'Owed ₹${groupNetBalance.abs().toStringAsFixed(2)}'
                        : isMeDebtor
                        ? 'Owe ₹${groupNetBalance.abs().toStringAsFixed(2)}'
                        : 'Settled',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),

          if (!isBusiness && userBalances.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF0F2F5)),
            ),
            ...userBalances.asMap().entries.map((entry) {
              final index = entry.key;
              final balance = entry.value;
              final isMeDebtorForThis = currentUserId == balance.debtorId;

              return Padding(
                padding: EdgeInsets.only(top: index > 0 ? 8.0 : 0.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isMeDebtorForThis
                            ? 'You owe ${balance.creditorName}'
                            : '${balance.debtorName} owes you',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E232A),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '₹${balance.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isMeDebtorForThis
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => onSettle(balance),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B57),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Settle',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
