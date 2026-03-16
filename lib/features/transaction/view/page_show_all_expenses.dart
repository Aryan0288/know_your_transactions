// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
// import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
// import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
// import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
// import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';

// class ShowAllExpensesPage extends ConsumerWidget {
//   const ShowAllExpensesPage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return CommonScaffold(
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           // Fixed Header Section
//           Stack(
//             children: [
//               Container(
//                 height: 280,
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [Color(0xFF429690), Color(0xFF2E7D79)],
//                   ),
//                   borderRadius: BorderRadius.only(
//                     bottomLeft: Radius.circular(40),
//                     bottomRight: Radius.circular(40),
//                   ),
//                 ),
//               ),
//               SafeArea(
//                 bottom: false,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 24,
//                     vertical: 16,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 _getGreeting(),
//                                 style: GoogleFonts.manrope(
//                                   fontSize: 14,
//                                   color: Colors.white70,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Consumer(
//                                 builder: (context, ref, child) {
//                                   final user = ref
//                                       .watch(firebaseAuthProvider)
//                                       .currentUser;
//                                   user?.reload();
//                                   final userData = ref
//                                       .watch(userDataProvider)
//                                       .value;
//                                   final userName =
//                                       userData?['name'] ??
//                                       (user != null ? 'User' : 'Guest');
//                                   return Text(
//                                     userName,
//                                     style: GoogleFonts.manrope(
//                                       fontSize: 22,
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                           Container(
//                             padding: const EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.15),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: const Icon(
//                               Icons.notifications_none_rounded,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 32),
//                       // Balance Card
//                       Consumer(
//                         builder: (context, ref, child) {
//                           final stats = ref.watch(transactionStatsProvider);
//                           return _BalanceCard(stats: stats);
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // Scrollable Transactions Section
//           Expanded(
//             child: CustomScrollView(
//               slivers: [
//                 // Transactions List Header
//                 SliverToBoxAdapter(
//                   child: Padding(
//                     padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Transactions History',
//                           style: GoogleFonts.manrope(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: const Color(0xFF1E1E1E),
//                           ),
//                         ),
//                         Text(
//                           'See all',
//                           style: GoogleFonts.manrope(
//                             fontSize: 14,
//                             color: textColor_55555A,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//                 // Transactions List
//                 Consumer(
//                   builder: (context, ref, child) {
//                     final transactionsAsync = ref.watch(
//                       transactionsStreamProvider,
//                     );
//                     return transactionsAsync.when(
//                       data: (transactions) {
//                         final user = ref
//                             .watch(firebaseAuthProvider)
//                             .currentUser;
//                         if (user == null) {
//                           return SliverFillRemaining(
//                             hasScrollBody: false,
//                             child: Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.lock_outline,
//                                     size: 64,
//                                     color: Colors.grey[400],
//                                   ),
//                                   const SizedBox(height: 16),
//                                   Text(
//                                     'Sign in to see your transactions',
//                                     style: GoogleFonts.manrope(
//                                       fontSize: 16,
//                                       color: Colors.grey[600],
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         }
//                         if (transactions.isEmpty) {
//                           return const SliverFillRemaining(
//                             child: Center(child: Text('No transactions yet')),
//                           );
//                         }
//                         return SliverList(
//                           delegate: SliverChildBuilderDelegate((
//                             context,
//                             index,
//                           ) {
//                             final transaction = transactions[index];
//                             return _TransactionTile(transaction: transaction);
//                           }, childCount: transactions.length),
//                         );
//                       },
//                       loading: () => const SliverToBoxAdapter(
//                         child: Center(child: CircularProgressIndicator()),
//                       ),
//                       error: (e, r) => SliverToBoxAdapter(
//                         child: Center(child: Text('Error: $e')),
//                       ),
//                     );
//                   },
//                 ),
//                 const SliverToBoxAdapter(child: SizedBox(height: 100)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getGreeting() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return 'Good morning,';
//     if (hour < 17) return 'Good afternoon,';
//     return 'Good evening,';
//   }
// }

// class _BalanceCard extends StatelessWidget {
//   final TransactionStats stats;

//   const _BalanceCard({required this.stats});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2F7E79),
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.15),
//             blurRadius: 20,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Text(
//                 'Total Balance',
//                 style: GoogleFonts.manrope(
//                   fontSize: 16,
//                   color: Colors.white,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Icon(
//                 Icons.keyboard_arrow_up_rounded,
//                 color: Colors.white70,
//                 size: 20,
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: Text(
//               '₹ ${stats.totalBalance.toStringAsFixed(2)}',
//               style: GoogleFonts.manrope(
//                 fontSize: 32,
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           const SizedBox(height: 32),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _IncomeExpense(
//                 title: 'Income',
//                 amount: stats.totalIncome,
//                 iconPath: Icons.arrow_downward_rounded,
//                 color: Colors.white70,
//               ),
//               _IncomeExpense(
//                 title: 'Expenses',
//                 amount: stats.totalExpense,
//                 iconPath: Icons.arrow_upward_rounded,
//                 color: Colors.white70,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _IncomeExpense extends StatelessWidget {
//   final String title;
//   final double amount;
//   final IconData iconPath;
//   final Color color;

//   const _IncomeExpense({
//     required this.title,
//     required this.amount,
//     required this.iconPath,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(6),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(iconPath, color: Colors.white, size: 16),
//         ),
//         const SizedBox(width: 8),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: GoogleFonts.manrope(
//                 fontSize: 14,
//                 color: Colors.white70,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             Text(
//               '₹ ${amount.toStringAsFixed(2)}',
//               style: GoogleFonts.manrope(
//                 fontSize: 16,
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// class _TransactionTile extends StatelessWidget {
//   final TransactionModel transaction;

//   const _TransactionTile({required this.transaction});

//   String limitChars(String text, int maxChars) {
//     if (text.length <= maxChars) return text;
//     return text.substring(0, maxChars) + '...';
//   }

//   void _showTransactionDetail(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
//         child: Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(28),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 70,
//                 height: 70,
//                 decoration: BoxDecoration(
//                   color: transaction.color.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   transaction.icon,
//                   color: transaction.color,
//                   size: 35,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: transaction.isExpense
//                       ? Colors.red.withOpacity(0.1)
//                       : Colors.green.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   transaction.isExpense ? 'Expense' : 'Income',
//                   style: GoogleFonts.manrope(
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                     color: transaction.isExpense ? Colors.red : Colors.green,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 '₹ ${transaction.amount.toStringAsFixed(2)}',
//                 style: GoogleFonts.manrope(
//                   fontSize: 32,
//                   fontWeight: FontWeight.bold,
//                   color: const Color(0xFF1E1E1E),
//                 ),
//               ),
//               const SizedBox(height: 24),
//               _DetailRow(label: 'Category', value: transaction.categoryName),
//               const Divider(height: 32),
//               _DetailRow(
//                 label: 'Date',
//                 value: DateFormat(
//                   'MMM dd, yyyy - hh:mm a',
//                 ).format(transaction.date),
//               ),
//               if (transaction.description.isNotEmpty) ...[
//                 const Divider(height: 32),
//                 _DetailRow(
//                   label: 'Description',
//                   value: transaction.description,
//                 ),
//               ],
//               const SizedBox(height: 32),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2E7D79),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     elevation: 0,
//                   ),
//                   onPressed: () => Navigator.pop(context),
//                   child: Text(
//                     'Close',
//                     style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: () => _showTransactionDetail(context),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//         child: Row(
//           children: [
//             Container(
//               width: 50,
//               height: 50,
//               decoration: BoxDecoration(
//                 color: transaction.color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Icon(transaction.icon, color: transaction.color, size: 24),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     transaction.categoryName,
//                     style: GoogleFonts.manrope(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: const Color(0xFF1E1E1E),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     _formatDate(transaction.date),
//                     style: GoogleFonts.manrope(
//                       fontSize: 13,
//                       color: textColor_181636,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Text(
//                   '${transaction.isExpense ? '-' : '+'} ₹ ${transaction.amount.toStringAsFixed(2)}',
//                   style: GoogleFonts.manrope(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: transaction.isExpense
//                         ? const Color(0xFFE57373)
//                         : const Color(0xFF66BB6A),
//                   ),
//                 ),
//                 if (transaction.description.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 2),
//                     child: Text(
//                       limitChars(transaction.description, 20),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: GoogleFonts.manrope(
//                         fontSize: 11,
//                         color: textColor_55555A,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _formatDate(DateTime date) {
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final yesterday = today.subtract(const Duration(days: 1));
//     final transactionDate = DateTime(date.year, date.month, date.day);

//     if (transactionDate == today) return 'Today';
//     if (transactionDate == yesterday) return 'Yesterday';
//     return DateFormat('MMM dd, yyyy').format(date);
//   }
// }

// class _DetailRow extends StatelessWidget {
//   final String label;
//   final String value;

//   const _DetailRow({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: GoogleFonts.manrope(color: Colors.grey[600], fontSize: 14),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: Text(
//             value,
//             textAlign: TextAlign.end,
//             style: GoogleFonts.manrope(
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//               color: const Color(0xFF1E1E1E),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }











import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';

class ShowAllExpensesPage extends ConsumerWidget {
  const ShowAllExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Fixed Header Section
          Stack(
            children: [
              Container(
                height: 280,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF429690), Color(0xFF2E7D79)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Consumer(
                                builder: (context, ref, child) {
                                  final user = ref
                                      .watch(firebaseAuthProvider)
                                      .currentUser;
                                  user?.reload();
                                  final userData = ref
                                      .watch(userDataProvider)
                                      .value;
                                  final userName =
                                      userData?['name'] ??
                                      (user != null ? 'User' : 'Guest');
                                  return Text(
                                    userName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Balance Card
                      Consumer(
                        builder: (context, ref, child) {
                          final stats = ref.watch(transactionStatsProvider);
                          return _BalanceCard(stats: stats);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scrollable Transactions Section
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Transactions List Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transactions History',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                        Text(
                          'See all',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: textColor_55555A,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transactions List
                Consumer(
                  builder: (context, ref, child) {
                    final transactionsAsync = ref.watch(
                      transactionsStreamProvider,
                    );
                    return transactionsAsync.when(
                      data: (transactions) {
                        final user = ref
                            .watch(firebaseAuthProvider)
                            .currentUser;
                        if (user == null) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Sign in to see your transactions',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (transactions.isEmpty) {
                          return const SliverFillRemaining(
                            child: Center(child: Text('No transactions yet')),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final transaction = transactions[index];
                            return _TransactionTile(transaction: transaction);
                          }, childCount: transactions.length),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, r) => SliverToBoxAdapter(
                        child: Center(child: Text('Error: $e')),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _BalanceCard extends StatefulWidget {
  final TransactionStats stats;

  const _BalanceCard({required this.stats});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AccelerometerEvent>? _subscription;

  // Current smoothed tilt values (range roughly -1 to 1)
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // Max rotation angle in radians (~10°)
  static const double _maxAngle = 0.3;
  // Smoothing factor (0 = no change, 1 = instant)
  static const double _smoothing = 0.15;
  // Max accelerometer value we care about (m/s²)
  static const double _maxAccel = 1.0;

  // Shake detection
  late final AnimationController _shakeController;
  static const double _shakeThreshold = 12.0; // m/s² spike to count as shake
  double _lastMagnitude = 9.8;
  DateTime _lastShakeTime = DateTime(2000);
  static const Duration _shakeCooldown = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _subscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 16),
    ).listen((event) {
      if (!mounted) return;

      // --- Shake detection (spike-based) ---
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final delta = (magnitude - _lastMagnitude).abs();
      _lastMagnitude = magnitude;
      final now = DateTime.now();
      // Detect a sudden spike in acceleration (delta > 5 means a jolt)
      if ((delta > 5.0 || magnitude > _shakeThreshold) &&
          now.difference(_lastShakeTime) > _shakeCooldown) {
        _lastShakeTime = now;
        _shakeController.forward(from: 0.0);
      }

      // --- Tilt smoothing ---
      final targetX = (event.x / _maxAccel).clamp(-1.0, 1.0);
      final targetY = (event.y / _maxAccel).clamp(-1.0, 1.0);
      setState(() {
        _tiltX = lerpDouble(_tiltX, targetX, _smoothing)!;
        _tiltY = lerpDouble(_tiltY, targetY, _smoothing)!;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Glow center follows the tilt direction
    final glowAlignX = _tiltX.clamp(-1.0, 1.0);
    final glowAlignY = (-_tiltY + 1).clamp(-1.0, 1.0); // invert Y for visual
    final glowIntensity = (_tiltX.abs() + _tiltY.abs()).clamp(0.0, 1.0);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateY(_tiltX * _maxAngle)
        ..rotateX(_tiltY * _maxAngle),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF2F7E79),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(_tiltX * 8, -_tiltY * 8 + 10),
            ),
          ],
          gradient: RadialGradient(
            center: Alignment(glowAlignX, glowAlignY),
            radius: 1.2,
            colors: [
              Color.lerp(
                const Color(0xFF2F7E79),
                const Color(0xFF5EEAD4),
                0.45 * glowIntensity,
              )!,
              const Color(0xFF2F7E79),
            ],
            stops: const [0.0, 0.75],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Total Balance',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, _) {

                final amountText =
                    '₹ ${widget.stats.totalBalance.toStringAsFixed(2)}';
                final progress = _shakeController.value;
                final decay = 1.0 - progress; // amplitude fades out

                return Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(amountText.length, (index) {
                      // Each character gets a different phase offset
                      final phase = index * 0.4;

                      final offsetX =
                          sin((progress * pi * 20) + phase) * 1.0 * decay;
                      final offsetY =
                          cos((progress * pi * 20) + phase) * 3 * decay;
                      return Transform.translate(
                        offset: Offset(offsetX, offsetY),
                        child: Text(
                          amountText[index],
                          style: GoogleFonts.manrope(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IncomeExpense(
                  title: 'Income',
                  amount: widget.stats.totalIncome,
                  iconPath: Icons.arrow_downward_rounded,
                  color: Colors.white70,
                ),
                _IncomeExpense(
                  title: 'Expenses',
                  amount: widget.stats.totalExpense,
                  iconPath: Icons.arrow_upward_rounded,
                  color: Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeExpense extends StatelessWidget {
  final String title;
  final double amount;
  final IconData iconPath;
  final Color color;

  const _IncomeExpense({
    required this.title,
    required this.amount,
    required this.iconPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(iconPath, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionTile({required this.transaction});

  String limitChars(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars) + '...';
  }

  void _showTransactionDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: transaction.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.icon,
                  color: transaction.color,
                  size: 35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: transaction.isExpense
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  transaction.isExpense ? 'Expense' : 'Income',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: transaction.isExpense ? Colors.red : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '₹ ${transaction.amount.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 24),
              _DetailRow(label: 'Category', value: transaction.categoryName),
              const Divider(height: 32),
              _DetailRow(
                label: 'Date',
                value: DateFormat(
                  'MMM dd, yyyy - hh:mm a',
                ).format(transaction.date),
              ),
              if (transaction.description.isNotEmpty) ...[
                const Divider(height: 32),
                _DetailRow(
                  label: 'Description',
                  value: transaction.description,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D79),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showTransactionDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: transaction.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(transaction.icon, color: transaction.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.categoryName,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.date),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: textColor_181636,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.isExpense ? '-' : '+'} ₹ ${transaction.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: transaction.isExpense
                        ? const Color(0xFFE57373)
                        : const Color(0xFF66BB6A),
                  ),
                ),
                if (transaction.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      limitChars(transaction.description, 20),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: textColor_55555A,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) return 'Today';
    if (transactionDate == yesterday) return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(date);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: const Color(0xFF1E1E1E),
            ),
          ),
        ),
      ],
    );
  }
}
