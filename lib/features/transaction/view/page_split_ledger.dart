import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view/dialog_transaction_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:know_your_expenses/features/transaction/view/widgets/widget_group_ledger_card.dart';
import 'package:know_your_expenses/features/common_widgets/closable_banner_ad.dart';
import 'package:know_your_expenses/features/transaction/view/widgets/widget_export_bottom_sheet.dart';
import 'package:know_your_expenses/features/transaction/view/page_add_expenses.dart';

final selectedGroupFilterProvider = StateProvider<String?>((ref) => null);
final selectedMemberIdProvider = StateProvider<String?>((ref) => null);
final lastBackPressedProvider = StateProvider<DateTime?>((ref) => null);
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
                      final selectedMemberId = ref.read(selectedMemberIdProvider);
                      final selectedGroupId = ref.read(selectedGroupFilterProvider);
                      if (selectedMemberId != null) {
                        ref.read(selectedMemberIdProvider.notifier).state = null;
                      } else if (selectedGroupId != null) {
                        ref.read(selectedGroupFilterProvider.notifier).state = null;
                      } else {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          ref.read(bottomNavIndexProvider.notifier).state = 0;
                        }
                      }
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
                  Consumer(
                    builder: (context, ref, _) {
                      final selectedGroupId = ref.watch(selectedGroupFilterProvider);
                      if (selectedGroupId != null) {
                        return IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ExportBottomSheet(
                                initialGroupId: selectedGroupId,
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox(width: 48);
                    },
                  ),
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
    final memberNames = ref.watch(allGroupsMembersProvider).value ?? {};
    final selectedGroupId = ref.watch(selectedGroupFilterProvider);
    final selectedMemberId = ref.watch(selectedMemberIdProvider);
    final currentTab = ref.watch(groupsHubTabProvider);

    return PopScope(
      canPop: selectedGroupId == null && selectedMemberId == null && Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final sGroupId = ref.read(selectedGroupFilterProvider);
        final sMemberId = ref.read(selectedMemberIdProvider);

        if (sMemberId != null) {
          ref.read(selectedMemberIdProvider.notifier).state = null;
        } else if (sGroupId != null) {
          ref.read(selectedGroupFilterProvider.notifier).state = null;
        } else {
          final now = DateTime.now();
          final lastPressed = ref.read(lastBackPressedProvider);
          if (lastPressed == null || now.difference(lastPressed) > const Duration(seconds: 2)) {
            ref.read(lastBackPressedProvider.notifier).state = now;
            toastification.show(
              context: context,
              type: ToastificationType.info,
              style: ToastificationStyle.fillColored,
              backgroundColor: const Color(0xFF2E8B57),
              autoCloseDuration: const Duration(seconds: 2),
              alignment: Alignment.bottomCenter,
              title: Text(
                'Press back again to exit',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              showProgressBar: false,
              closeButtonShowType: CloseButtonShowType.none,
            );
          } else {
            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        bottomNavigationBar: const ClosableBannerAd(),
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

                final selectedGroup = selectedGroupId != null
                    ? groups.firstWhere((g) => g.id == selectedGroupId, orElse: () => groups.first)
                    : null;
                final isAdmin = selectedGroup?.adminId == currentUserId || (selectedGroup?.admins.contains(currentUserId) ?? false);
                final isWages = selectedGroup?.type == 'wages';
                final transactions = selectedGroupId != null
                    ? ref.watch(groupTransactionsStreamByIdProvider(selectedGroupId)).value ?? []
                    : [];
                final balances = selectedGroupId != null
                    ? ref.watch(groupSplitBalancesProvider(selectedGroupId))
                    : <SplitBalance>[];

                String tab0Text = 'Expenses';
                if (selectedGroupId == null) {
                  tab0Text = 'Spaces';
                } else if (selectedMemberId == null) {
                  tab0Text = isWages ? 'Employees' : 'Members';
                } else {
                  tab0Text = isWages ? 'Income' : 'Expenses';
                }

                // Filter groups for rendering
                final filteredGroups = selectedGroupId == null
                    ? groups
                    : groups.where((g) => g.id == selectedGroupId).toList();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(child: _buildHeader(context, ref)),

                    if (selectedGroupId != null)
                      SliverToBoxAdapter(
                        child: Consumer(
                          builder: (context, ref, child) {
                             if (selectedMemberId == null) {
                              if (isWages && !isAdmin) return const SizedBox();

                              if (selectedGroup?.type == 'business') {
                                return const SizedBox();
                              }

                              double groupWagesTotal = 0.0;
                              double netBalance = 0.0;
                              
                              if (isWages) {
                                final wagesTransactions = transactions.where((t) => t.isShared && t.categoryId == 'cat_wages');
                                for (var t in wagesTransactions) {
                                  groupWagesTotal += t.amount;
                                }
                              } else {
                                for (var b in balances) {
                                  if (b.debtorId == currentUserId) {
                                    netBalance -= b.amount;
                                  } else if (b.creditorId == currentUserId) {
                                    netBalance += b.amount;
                                  }
                                }
                              }

                              final double displayAmount = isWages ? groupWagesTotal : netBalance;
                              final String cardTitle = isWages 
                                  ? 'Total Wages Paid' 
                                  : (displayAmount > 0.01 
                                      ? 'Owed to You' 
                                      : (displayAmount < -0.01 ? 'You Owe' : 'Settled'));
                              
                              final List<Color> gradientColors = isWages
                                  ? [const Color(0xFF2E7D79), const Color(0xFF429690)]
                                  : (displayAmount > 0.01
                                      ? [const Color(0xFF2E7D79), const Color(0xFF429690)]
                                      : (displayAmount < -0.01
                                          ? [const Color(0xFFB71C1C), const Color(0xFFE57373)]
                                          : [const Color(0xFF616161), const Color(0xFF9E9E9E)]));

                              final IconData cardIcon = isWages
                                  ? Icons.payments_rounded
                                  : (displayAmount > 0.01
                                      ? Icons.arrow_downward_rounded
                                      : (displayAmount < -0.01
                                          ? Icons.arrow_upward_rounded
                                          : Icons.check_circle_rounded));

                              return Container(
                                margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: gradientColors[0].withOpacity(0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        cardIcon,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cardTitle,
                                            style: GoogleFonts.manrope(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            isWages 
                                                ? 'All paid wages to employees' 
                                                : (displayAmount > 0.01 
                                                    ? 'Net amount you are owed' 
                                                    : (displayAmount < -0.01 ? 'Net amount you owe' : 'Group is fully settled')),
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${displayAmount.abs().toStringAsFixed(2)}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              final membersAsync = ref.watch(groupMembersDetailsByIdProvider(selectedGroupId));
                              return membersAsync.when(
                                data: (members) {
                                  final member = members.firstWhere((m) => m['uid'] == selectedMemberId, orElse: () => {});
                                  if (member.isEmpty) return const SizedBox();

                                  final mUid = member['uid'] as String;
                                  final disambiguatedNames = Utils.getDisambiguatedNames(members);
                                  final baseName = disambiguatedNames[mUid] ?? (member['name'] as String? ?? 'Member');
                                  final mName = mUid == currentUserId ? '$baseName (You)' : baseName;
                                  final mPhoto = member['photoUrl'] as String?;

                                  final isWagesGroup = selectedGroup?.type == 'wages';
                                  final isBusinessGroup = selectedGroup?.type == 'business';

                                  double displayAmount = 0.0;
                                  String summaryTitle = '';
                                  if (isWagesGroup) {
                                    final mTransactions = transactions.where((t) => t.isShared && t.categoryId == 'cat_wages' && t.splitWith != null && t.splitWith!.contains(mUid));
                                    for (var t in mTransactions) {
                                      displayAmount += t.amount;
                                    }
                                    final isCurrentUserAdmin = selectedGroup?.adminId == currentUserId || (selectedGroup?.admins.contains(currentUserId) ?? false);
                                    summaryTitle = isCurrentUserAdmin
                                        ? 'Total Wages Paid'
                                        : 'Total Wages Received';
                                  } else if (isBusinessGroup) {
                                    final mTransactions = transactions.where((t) => t.userId == mUid);
                                    double mIncome = 0.0;
                                    double mExpense = 0.0;
                                    for (var t in mTransactions) {
                                      if (t.isExpense) {
                                        mExpense += t.amount;
                                      } else {
                                        mIncome += t.amount;
                                      }
                                    }
                                    displayAmount = mIncome - mExpense;
                                    summaryTitle = displayAmount >= 0 ? 'Net Income' : 'Net Deficit';
                                  } else {
                                    double bal = 0.0;
                                    for (var b in balances) {
                                      if (b.debtorId == mUid && b.creditorId == currentUserId) {
                                        bal += b.amount;
                                      } else if (b.creditorId == mUid && b.debtorId == currentUserId) {
                                        bal -= b.amount;
                                      }
                                    }
                                    displayAmount = bal;
                                    summaryTitle = bal > 0.01 ? 'Owes You' : (bal < -0.01 ? 'You Owe' : 'Net Balance');
                                  }

                                  final List<Color> gradientColors = isWagesGroup
                                      ? [const Color(0xFF2E7D79), const Color(0xFF429690)]
                                      : (displayAmount > 0.01
                                          ? [const Color(0xFF2E7D79), const Color(0xFF429690)]
                                          : (displayAmount < -0.01
                                              ? [const Color(0xFFB71C1C), const Color(0xFFE57373)]
                                              : [const Color(0xFF616161), const Color(0xFF9E9E9E)]));

                                  return Container(
                                    margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gradientColors[0].withOpacity(0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: Colors.white.withOpacity(0.2),
                                          backgroundImage: mPhoto != null ? NetworkImage(mPhoto) : null,
                                          child: mPhoto == null
                                              ? Text(
                                                  mName[0].toUpperCase(),
                                                  style: GoogleFonts.manrope(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                mName,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                summaryTitle,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹${displayAmount.abs().toStringAsFixed(2)}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              );
                            }
                          },
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
                                        tab0Text,
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
                      if (selectedGroupId == null) ...[
                        // 2. Groups Section
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                            child: Text(
                              'Your spaces',
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
                              child: GestureDetector(
                                onTap: () {
                                  ref.read(selectedGroupFilterProvider.notifier).state = group.id;
                                  ref.read(selectedMemberIdProvider.notifier).state = null;
                                },
                                child: GroupLedgerCard(
                                  group: group,
                                  currentUserId: currentUserId,
                                  onSettle: (balance) =>
                                      _onSettleUp(context, ref, balance, group.id),
                                ),
                              ),
                            );
                          }, childCount: filteredGroups.length),
                        ),
                      ] else ...[
                        // 3. Group Detail: Directory or Member Transaction List
                        if (selectedMemberId == null) ...[
                          // Member Directory View
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Space Members 👥',
                                    style: GoogleFonts.manrope(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E232A),
                                    ),
                                  ),
                                  if (selectedGroup?.type == 'wages' && isAdmin)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                      label: Text(
                                        'Pay Wages',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E8B57),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddExpensePage(
                                              initialGroupId: selectedGroupId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),

                          ref.watch(groupMembersDetailsByIdProvider(selectedGroupId)).when(
                            data: (members) {
                              final isWages = selectedGroup?.type == 'wages';
                              final displayMembers = members;

                              if (displayMembers.isEmpty) {
                                return SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey[200]!),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[400]),
                                          const SizedBox(height: 16),
                                          Text(
                                            isWages ? 'No Employees Added' : 'No Space Members',
                                            style: GoogleFonts.manrope(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E232A),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isWages
                                                ? 'Go to space settings to add employee members.'
                                                : 'Go to space settings to add members.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.manrope(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final disambiguatedNames = Utils.getDisambiguatedNames(displayMembers);

                              return SliverList(
                                delegate: SliverChildBuilderDelegate((context, index) {
                                  final member = displayMembers[index];
                                  final mUid = member['uid'] as String;
                                  final baseName = disambiguatedNames[mUid] ?? (member['name'] as String? ?? 'Member');
                                  final mName = mUid == currentUserId ? '$baseName (You)' : baseName;
                                  final mPhoto = member['photoUrl'] as String?;
                                  
                                  final isGroupAdmin = selectedGroup?.adminId == mUid || (selectedGroup?.admins.contains(mUid) ?? false);
                                  final isWagesGroup = selectedGroup?.type == 'wages';
                                  final isBusinessGroup = selectedGroup?.type == 'business';

                                  // Calculate specific member balance/stats
                                  double displayAmount = 0.0;
                                  String labelText = '';
                                  if (isWagesGroup) {
                                    final mTransactions = transactions.where((t) => t.isShared && t.categoryId == 'cat_wages' && t.splitWith != null && t.splitWith!.contains(mUid));
                                    for (var t in mTransactions) {
                                      displayAmount += t.amount;
                                    }
                                    final isCurrentUserAdmin = selectedGroup?.adminId == currentUserId || (selectedGroup?.admins.contains(currentUserId) ?? false);
                                    if (isCurrentUserAdmin) {
                                      labelText = 'Wages Paid: ₹${displayAmount.toStringAsFixed(2)}';
                                    } else if (mUid == currentUserId) {
                                      labelText = 'Wages Received: ₹${displayAmount.toStringAsFixed(2)}';
                                    } else {
                                      labelText = '';
                                    }
                                  } else if (isBusinessGroup) {
                                    final mTransactions = transactions.where((t) => t.userId == mUid);
                                    double mIncome = 0.0;
                                    double mExpense = 0.0;
                                    for (var t in mTransactions) {
                                      if (t.isExpense) {
                                        mExpense += t.amount;
                                      } else {
                                        mIncome += t.amount;
                                      }
                                    }
                                    final net = mIncome - mExpense;
                                    labelText = 'Net: ${net >= 0 ? "+" : "-"}₹${net.abs().toStringAsFixed(2)} (In: ₹${mIncome.toStringAsFixed(0)}, Out: ₹${mExpense.toStringAsFixed(0)})';
                                  } else {
                                    double bal = 0.0;
                                    for (var b in balances) {
                                      if (b.debtorId == mUid && b.creditorId == currentUserId) {
                                        bal += b.amount;
                                      } else if (b.creditorId == mUid && b.debtorId == currentUserId) {
                                        bal -= b.amount;
                                      }
                                    }
                                    if (bal > 0.01) {
                                      labelText = 'Owes you: ₹${bal.toStringAsFixed(2)}';
                                    } else if (bal < -0.01) {
                                      labelText = 'You owe: ₹${bal.abs().toStringAsFixed(2)}';
                                    } else {
                                      labelText = 'Settled';
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                    child: Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.grey[200]!),
                                      ),
                                      color: Colors.white,
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: CircleAvatar(
                                          radius: 22,
                                          backgroundColor: const Color(0xFF2E8B57).withOpacity(0.1),
                                          backgroundImage: mPhoto != null ? NetworkImage(mPhoto) : null,
                                          child: mPhoto == null
                                              ? Text(
                                                  mName[0].toUpperCase(),
                                                  style: GoogleFonts.manrope(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF2E8B57),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                mName,
                                                style: GoogleFonts.manrope(
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF1E232A),
                                                ),
                                              ),
                                            ),
                                            if (isGroupAdmin)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.amber.shade200),
                                                ),
                                                child: Text(
                                                  'Admin',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber.shade800,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: labelText.isNotEmpty
                                            ? Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  labelText,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: labelText.contains('owes') || labelText.contains('Wages')
                                                        ? const Color(0xFF2E8B57)
                                                        : labelText.contains('owe')
                                                            ? Colors.red[700]
                                                            : Colors.grey[600],
                                                  ),
                                                ),
                                              )
                                            : null,
                                        trailing: isWagesGroup && !isAdmin && mUid != currentUserId
                                            ? const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20)
                                            : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                                        onTap: () {
                                          if (isWagesGroup && !isAdmin && mUid != currentUserId) {
                                            Utils.showErrorToast(
                                              context,
                                              alignment: Alignment.bottomCenter,
                                              title: "Privacy Restricted",
                                              description: "You are only allowed to view your own wages transactions.",
                                            );
                                            return;
                                          }
                                          ref.read(selectedMemberIdProvider.notifier).state = mUid;
                                        },
                                      ),
                                    ),
                                  );
                                }, childCount: displayMembers.length),
                              );
                            },
                            loading: () => const SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(color: Color(0xFF2E8B57)),
                                ),
                              ),
                            ),
                            error: (err, stack) => SliverToBoxAdapter(
                              child: Center(
                                child: Text('Error loading directory: $err'),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Member Detail & Transaction List View
SliverToBoxAdapter(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final membersAsync = ref.watch(groupMembersDetailsByIdProvider(selectedGroupId));
                                return membersAsync.when(
                                  data: (members) {
                                    final member = members.firstWhere((m) => m['uid'] == selectedMemberId, orElse: () => {});
                                    if (member.isEmpty) return const SizedBox();
                                    
                                    final mUid = member['uid'] as String;
                                    final disambiguatedNames = Utils.getDisambiguatedNames(members);
                                    final baseName = disambiguatedNames[mUid] ?? (member['name'] as String? ?? 'Member');
                                    final mName = mUid == currentUserId ? '$baseName (You)' : baseName;
                                    final mPhoto = member['photoUrl'] as String?;
                                    
                                    final mEmail = member['email'] as String? ?? '';

                                    return Container(
                                      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF2E7D79), Color(0xFF429690)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2E7D79).withOpacity(0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 26,
                                                backgroundColor: Colors.white.withOpacity(0.2),
                                                backgroundImage: mPhoto != null ? NetworkImage(mPhoto) : null,
                                                child: mPhoto == null
                                                    ? Text(
                                                        mName[0].toUpperCase(),
                                                        style: GoogleFonts.manrope(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 20,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      mName,
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (mEmail.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Text(
                                                          mEmail,
                                                          style: GoogleFonts.manrope(
                                                            fontSize: 12,
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isWages && isAdmin) ...[
                                             const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2E7D79)),
                                              label: Text(
                                                'Record Wages Payment',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF2E7D79),
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                minimumSize: const Size(double.infinity, 44),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AddExpensePage(
                                                      initialGroupId: selectedGroupId,
                                                      initialRecipientId: selectedMemberId,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                  loading: () => const SizedBox(),
                                  error: (_, __) => const SizedBox(),
                                );
                              },
                            ),
                          ),

                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                              child: Text(
                                'Transactions Ledger',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E232A),
                                ),
                              ),
                            ),
                          ),

                          Consumer(
                            builder: (context, ref, child) {
                              final isWagesGroup = selectedGroup?.type == 'wages';
                              final isBusinessGroup = selectedGroup?.type == 'business';

                              final memberTransactions = transactions.where((t) {
                                if (isWagesGroup) {
                                  return t.isShared && t.categoryId == 'cat_wages' && t.splitWith != null && t.splitWith!.contains(selectedMemberId);
                                } else if (isBusinessGroup) {
                                  return t.userId == selectedMemberId;
                                } else {
                                  return t.userId == selectedMemberId || (t.isShared && t.splitWith != null && t.splitWith!.contains(selectedMemberId));
                                }
                              }).toList();

                              if (memberTransactions.isEmpty) {
                                return const SliverToBoxAdapter(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text(
                                        'No transactions found.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return SliverList(
                                delegate: SliverChildBuilderDelegate((context, index) {
                                  final t = memberTransactions[index];
                                  final isExpense = isWagesGroup ? false : t.isExpense;
                                  final dateStr = DateFormat('MMM dd, yyyy').format(t.date);

                                  Widget? paymentBadge;
                                  if (isWagesGroup && t.paymentMode != null) {
                                    final isCash = t.paymentMode!.toLowerCase() == 'cash';
                                    paymentBadge = Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCash ? Colors.amber.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isCash ? Colors.amber.shade200 : Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        isCash ? '💵 Cash' : '💳 Online',
                                        style: GoogleFonts.manrope(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isCash ? Colors.amber.shade800 : Colors.blue.shade800,
                                        ),
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.02),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => TransactionDetailDialog(transaction: t),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: Color(t.colorValue).withOpacity(0.12),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    IconData(t.iconCodePoint, fontFamily: 'MaterialIcons'),
                                                    color: Color(t.colorValue),
                                                    size: 20,
                                                  ),
                                                ),
                                                 const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        isWagesGroup
                                                            ? '💸 ${t.description.isNotEmpty ? t.description : t.categoryName}'
                                                            : (t.description.isNotEmpty ? t.description : t.categoryName),
                                                        style: GoogleFonts.manrope(
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFF1E232A),
                                                        ),
                                                      ),
                                                      Text(
                                                        '$dateStr  •  By ${t.userId == currentUserId ? "You" : (memberNames[t.userId] ?? "Member")}',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 11,
                                                          color: Colors.grey[500],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      if (paymentBadge != null) paymentBadge,
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${isExpense ? "-" : "+"} ₹${t.amount.toStringAsFixed(2)}',
                                                      style: GoogleFonts.manrope(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 15,
                                                        color: isExpense ? Colors.red[700] : Colors.green[700],
                                                      ),
                                                    ),
                                                    if (isWagesGroup && isAdmin) ...[
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.replay_circle_filled_rounded, color: Colors.blue, size: 20),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            tooltip: 'Repeat Payment',
                                                            onPressed: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (_) => AddExpensePage(
                                                                    initialGroupId: selectedGroupId,
                                                                    initialRecipientId: selectedMemberId,
                                                                    initialAmount: t.amount,
                                                                    initialDescription: t.description,
                                                                    initialPaymentMode: t.paymentMode,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(Icons.edit_rounded, color: Colors.amber, size: 20),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            tooltip: 'Edit',
                                                            onPressed: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (_) => AddExpensePage(
                                                                    editTransaction: t,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            tooltip: 'Delete',
                                                            onPressed: () async {
                                                              final confirm = await showDialog<bool>(
                                                                context: context,
                                                                builder: (context) => AlertDialog(
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                  title: Text('Delete Transaction', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                                                                  content: Text('Are you sure you want to delete this wages payment?', style: GoogleFonts.manrope()),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () => Navigator.pop(context, false),
                                                                      child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
                                                                    ),
                                                                    ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                                      onPressed: () => Navigator.pop(context, true),
                                                                      child: Text('Delete', style: GoogleFonts.manrope(color: Colors.white)),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                              if (confirm == true) {
                                                                await ref.read(transactionViewModelProvider.notifier).deleteTransaction(t);
                                                              }
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }, childCount: memberTransactions.length),
                              );
                            },
                          ),
                        ]
                      ]
                    ],
                    // ─── ACTIVITY LOG TAB ───
                    if (currentTab == 1) ...[
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

  Widget _buildBusinessGroupSummaryCard(
    BuildContext context,
    double income,
    double expense,
    double net,
  ) {
    final isPositive = net >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF1A5C3A), const Color(0xFF2E8B57)]
              : [const Color(0xFFB71C1C), const Color(0xFFE57373)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? const Color(0xFF2E8B57) : const Color(0xFFE57373)).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Balance',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${isPositive ? "+" : "-"}₹${net.abs().toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded, color: Colors.lightGreenAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Income: ₹${income.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: Colors.white24),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Expense: ₹${expense.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

