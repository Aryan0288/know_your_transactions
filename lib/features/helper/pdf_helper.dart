import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';

class PdfHelper {
  static const _appGreen = PdfColor.fromInt(0xFF2E8B57);
  static const _darkText = PdfColor.fromInt(0xFF1E232A);
  static const _lightBg = PdfColor.fromInt(0xFFF4F7F6);

  // Draws a vector upward arrow inside a circle (Income)
  static pw.Widget _buildIncomeVectorIcon() {
    return pw.CustomPaint(
      size: const PdfPoint(16, 16),
      painter: (canvas, size) {
        // Draw green circle
        canvas.setColor(PdfColor.fromInt(0xFF2E8B57));
        canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
        canvas.fillPath();

        // Draw upward arrow
        canvas.setColor(PdfColors.white);
        canvas.setLineWidth(1.5);
        canvas.moveTo(size.x / 2, size.y * 0.25);
        canvas.lineTo(size.x / 2, size.y * 0.75);
        canvas.moveTo(size.x * 0.3, size.y * 0.55);
        canvas.lineTo(size.x / 2, size.y * 0.75);
        canvas.lineTo(size.x * 0.7, size.y * 0.55);
        canvas.strokePath();
      },
    );
  }

  // Draws a vector downward arrow inside a circle (Expense)
  static pw.Widget _buildExpenseVectorIcon() {
    return pw.CustomPaint(
      size: const PdfPoint(16, 16),
      painter: (canvas, size) {
        // Draw red circle
        canvas.setColor(PdfColor.fromInt(0xFFD32F2F));
        canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
        canvas.fillPath();

        // Draw downward arrow
        canvas.setColor(PdfColors.white);
        canvas.setLineWidth(1.5);
        canvas.moveTo(size.x / 2, size.y * 0.75);
        canvas.lineTo(size.x / 2, size.y * 0.25);
        canvas.moveTo(size.x * 0.3, size.y * 0.45);
        canvas.lineTo(size.x / 2, size.y * 0.25);
        canvas.lineTo(size.x * 0.7, size.y * 0.45);
        canvas.strokePath();
      },
    );
  }

  // Draws a vector wallet outline (Net Balance)
  static pw.Widget _buildBalanceVectorIcon() {
    return pw.CustomPaint(
      size: const PdfPoint(16, 16),
      painter: (canvas, size) {
        // Draw teal circle
        canvas.setColor(PdfColor.fromInt(0xFF1E88E5));
        canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
        canvas.fillPath();

        // Draw wallet outline
        canvas.setColor(PdfColors.white);
        canvas.setLineWidth(1.2);
        
        // Main wallet body
        canvas.drawRect(size.x * 0.2, size.y * 0.25, size.x * 0.6, size.y * 0.5);
        canvas.strokePath();
        
        // Wallet clasp/flap
        canvas.drawRect(size.x * 0.55, size.y * 0.4, size.x * 0.25, size.y * 0.2);
        canvas.strokePath();
      },
    );
  }

  // Generates PDF bytes for Personal Statement
  static Future<Uint8List> generatePersonalStatementBytes({
    required List<TransactionModel> transactions,
    required String title,
  }) async {
    final pdf = pw.Document();

    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var t in transactions) {
      if (t.isExpense) {
        totalExpense += t.amount;
      } else {
        totalIncome += t.amount;
      }
    }
    final balance = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} • Powered by Know Your Expenses',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Personal Transaction Statement',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _appGreen,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: $title',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Know Your Expenses',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _appGreen,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: _appGreen, thickness: 1.5),
            pw.SizedBox(height: 16),

            // Summary Section with Vector Icons
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                  'Total Income', 
                  '${totalIncome.toStringAsFixed(2)}', 
                  PdfColors.green800,
                  _buildIncomeVectorIcon(),
                ),
                _buildSummaryCard(
                  'Total Expense', 
                  '${totalExpense.toStringAsFixed(2)}', 
                  PdfColors.red800,
                  _buildExpenseVectorIcon(),
                ),
                _buildSummaryCard(
                  'Net Balance', 
                  '${balance.toStringAsFixed(2)}', 
                  balance >= 0 ? PdfColors.green800 : PdfColors.red800,
                  _buildBalanceVectorIcon(),
                ),
              ],
            ),
            pw.SizedBox(height: 28),

            // Table Header
            pw.Text(
              'Transactions Details',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _darkText,
              ),
            ),
            pw.SizedBox(height: 8),

            // Table
            pw.TableHelper.fromTextArray(
              border: null,
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: const {
                0: pw.FixedColumnWidth(80),
                1: pw.FixedColumnWidth(50),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FixedColumnWidth(65),
                4: pw.FixedColumnWidth(80),
              },
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: _appGreen,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.8),
                ),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              headers: ['Date', 'Category', 'Description/Note', 'Type', 'Amount'],
              data: transactions.map((t) {
                final desc = t.description.isNotEmpty ? t.description : '-';
                // final truncatedDesc = desc.length > 25 ? '${desc.substring(0, 22)}...' : desc;
                return [
                  DateFormat('dd MMM yyyy').format(t.date),
                  t.categoryName.isNotEmpty ? t.categoryName : 'No Category',
                  // truncatedDesc,
                  desc,
                  t.isExpense ? 'Expense' : 'Income',
                  '${t.amount.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Generates PDF bytes for Group Statement
  static Future<Uint8List> generateGroupStatementBytes({
    required GroupModel group,
    required List<TransactionModel> transactions,
    required String title,
    required Map<String, String> memberNames,
    required String currentUserId,
  }) async {
    final pdf = pw.Document();

    final groupType = group.toMap()['type'] as String? ?? 'split';
    final isBusiness = groupType == 'business';

    double totalGroupSpending = 0.0;
    double totalUserSpending = 0.0;

    for (var t in transactions) {
      if (t.isExpense) {
        totalGroupSpending += t.amount;
      }
      
      if (isBusiness) {
        if (t.userId == currentUserId) {
          totalUserSpending += t.amount;
        }
      } else {
        if (t.isShared && t.splitWith != null && t.splitWith!.contains(currentUserId)) {
          if (t.splitAmounts != null && t.splitAmounts!.containsKey(currentUserId)) {
            totalUserSpending += t.splitAmounts![currentUserId]!;
          } else {
            totalUserSpending += t.amount / t.splitWith!.length;
          }
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} • Powered by Know Your Expenses',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Group Transaction Statement',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _appGreen,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Group: ${group.name} (${isBusiness ? "Business" : "Split Space"})',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Period: $title',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Know Your Expenses',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _appGreen,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: _appGreen, thickness: 1.5),
            pw.SizedBox(height: 16),

            // Summary Section with Vector Icons
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                  'Group Spend', 
                  '₹ ${totalGroupSpending.toStringAsFixed(2)}', 
                  _darkText,
                  _buildExpenseVectorIcon(),
                ),
                _buildSummaryCard(
                  'Your Spend Share', 
                  '₹ ${totalUserSpending.toStringAsFixed(2)}', 
                  _appGreen,
                  _buildBalanceVectorIcon(),
                ),
                _buildSummaryCard(
                  'Members Count', 
                  '${group.members.length} Members', 
                  PdfColors.blueGrey800,
                  pw.CustomPaint(
                    size: const PdfPoint(16, 16),
                    painter: (canvas, size) {
                      canvas.setColor(PdfColor.fromInt(0xFF555555));
                      canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
                      canvas.fillPath();
                    },
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 28),

            // Table Header
            pw.Text(
              'Group Transactions History',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _darkText,
              ),
            ),
            pw.SizedBox(height: 8),

            // Table
            pw.TableHelper.fromTextArray(
              border: null,
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: const {
                0: pw.FixedColumnWidth(80),
                1: pw.FixedColumnWidth(90),
                2: pw.FixedColumnWidth(90),
                3: pw.FlexColumnWidth(2.0),
                4: pw.FixedColumnWidth(80),
                5: pw.FixedColumnWidth(80),
              },
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: _appGreen,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.8),
                ),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              headers: ['Date', 'Paid By', 'Category', 'Description/Note', 'Total Amount', 'Your Share'],
              data: transactions.map((t) {
                final payerName = t.userId == currentUserId
                    ? 'You'
                    : (memberNames[t.userId] ?? 'Group Member');

                double userShare = 0.0;
                if (isBusiness) {
                  userShare = t.userId == currentUserId ? t.amount : 0.0;
                } else {
                  if (t.isShared && t.splitWith != null && t.splitWith!.contains(currentUserId)) {
                    if (t.splitAmounts != null && t.splitAmounts!.containsKey(currentUserId)) {
                      userShare = t.splitAmounts![currentUserId]!;
                    } else {
                      userShare = t.amount / t.splitWith!.length;
                    }
                  }
                }

                final desc = t.description.isNotEmpty ? t.description : '-';
                final truncatedDesc = desc.length > 25 ? '${desc.substring(0, 22)}...' : desc;

                return [
                  DateFormat('dd MMM yyyy').format(t.date),
                  payerName,
                  t.categoryName.isNotEmpty ? t.categoryName : 'No Category',
                  truncatedDesc,
                  '₹ ${t.amount.toStringAsFixed(2)}',
                  '₹ ${userShare.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helper to build a clean card with a vector icon
  static pw.Widget _buildSummaryCard(String label, String value, PdfColor textColor, pw.Widget vectorIcon) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: _lightBg,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, right: 8),
            child: vectorIcon,
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  value,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CSV Exporter
  static Future<void> exportToCsv({
    required List<TransactionModel> transactions,
    required String title,
    required String currentUserId,
    required Map<String, String> memberNames,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("Transaction Statement - $title");
    buffer.writeln("Generated on: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}");
    buffer.writeln();
    buffer.writeln("Date,Type,Category,Description,Paid By,Total Amount,Your Share");

    for (var t in transactions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
      final typeStr = t.isExpense ? "Expense" : "Income";
      final catStr = t.categoryName.isNotEmpty ? t.categoryName : "No Category";
      final descStr = t.description.replaceAll(',', ' ');
      final payerName = t.userId == currentUserId ? "You" : (memberNames[t.userId] ?? "Member");

      double userShare = t.amount;
      if (t.isShared && t.splitWith != null && t.splitWith!.isNotEmpty) {
        if (t.splitWith!.contains(currentUserId)) {
          if (t.splitAmounts != null && t.splitAmounts!.containsKey(currentUserId)) {
            userShare = t.splitAmounts![currentUserId]!;
          } else {
            userShare = t.amount / t.splitWith!.length;
          }
        } else {
          userShare = 0.0;
        }
      }

      buffer.writeln("$dateStr,$typeStr,$catStr,$descStr,$payerName,${t.amount.toStringAsFixed(2)},${userShare.toStringAsFixed(2)}");
    }

    final bytes = Uint8List.fromList(buffer.toString().codeUnits);

    final filename = "${title.replaceAll(' ', '_')}_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }
}
