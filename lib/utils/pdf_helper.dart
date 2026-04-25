import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/company_settings.dart';
import '../models/quotation_model.dart';

class PdfHelper {
  static Future<Uint8List> generateQuotation(
    Quotation quote,
    CompanySettings settings,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeaderFooter(
          settings.headerElements,
          font,
          fontBold,
          isHeader: true,
        ),
        footer: (context) => _buildHeaderFooter(
          settings.footerElements,
          font,
          fontBold,
          isHeader: false,
          context: context,
        ),
        build: (context) => [
          // 1. First Page
          if (settings.firstPageElements.isNotEmpty) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.firstPageElements,
                    PdfElementPosition.left,
                    font,
                    fontBold,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.firstPageElements,
                    PdfElementPosition.center,
                    font,
                    fontBold,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.firstPageElements,
                    PdfElementPosition.right,
                    font,
                    fontBold,
                  ),
                ),
              ],
            ),
            pw.NewPage(),
          ],

          // 2. Middle Pages (Items)
          ...quote.items.map((item) => _buildItemBlock(item, font, fontBold)),
          pw.SizedBox(height: 20),
          _buildSummary(quote, font, fontBold),

          // 3. Last Page
          if (settings.lastPageElements.isNotEmpty) ...[
            pw.NewPage(),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.lastPageElements,
                    PdfElementPosition.left,
                    font,
                    fontBold,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.lastPageElements,
                    PdfElementPosition.center,
                    font,
                    fontBold,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.lastPageElements,
                    PdfElementPosition.right,
                    font,
                    fontBold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderFooter(
    List<PdfElement> elements,
    pw.Font font,
    pw.Font fontBold, {
    required bool isHeader,
    pw.Context? context,
  }) {
    return pw.Column(
      children: [
        if (isHeader) pw.SizedBox(height: 10),
        if (!isHeader)
          pw.Divider(
            thickness: 1,
            color: PdfColors.black,
          ), // Divider above footer

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _buildAlignmentColumn(
                elements,
                PdfElementPosition.left,
                font,
                fontBold,
              ),
            ),
            pw.Expanded(
              child: _buildAlignmentColumn(
                elements,
                PdfElementPosition.center,
                font,
                fontBold,
              ),
            ),
            pw.Expanded(
              child: _buildAlignmentColumn(
                elements,
                PdfElementPosition.right,
                font,
                fontBold,
              ),
            ),
          ],
        ),

        if (!isHeader && context != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
              ],
            ),
          ),

        if (isHeader)
          pw.Divider(
            thickness: 1,
            color: PdfColors.black,
          ), // Divider below header
        if (!isHeader) pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildAlignmentColumn(
    List<PdfElement> elements,
    PdfElementPosition pos,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final colElements = elements.where((e) => e.position == pos).toList();
    if (colElements.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pos == PdfElementPosition.left
          ? pw.CrossAxisAlignment.start
          : pos == PdfElementPosition.right
          ? pw.CrossAxisAlignment.end
          : pw.CrossAxisAlignment.center,
      children: colElements.map((el) {
        if (el.type == PdfElementType.text) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: _parseRichText(el.content, font, fontBold, el.size),
          );
        } else {
          final file = File(el.content);
          if (file.existsSync()) {
            return pw.Container(
              width: el.size,
              child: pw.Image(pw.MemoryImage(file.readAsBytesSync())),
            );
          }
          return pw.SizedBox();
        }
      }).toList(),
    );
  }

  static pw.Widget _buildItemBlock(
    QuotationItem item,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final blueColor = PdfColor.fromHex('#D9E2F3');
    final greyColor = PdfColor.fromHex('#F2F2F2');
    final borderColor = PdfColors.grey400;
    const bSide = pw.BorderSide(color: PdfColors.grey400, width: 0.5);

    pw.TableRow _row(
      List<String> texts, {
      PdfColor? bgColor,
      bool isBold = false,
    }) {
      return pw.TableRow(
        decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
        children: texts
            .map(
              (t) => pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Text(
                  t,
                  style: pw.TextStyle(
                    font: isBold ? fontBold : font,
                    fontSize: 6.5,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // HEADER TABLE
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: bSide,
              verticalInside: bSide,
              bottom: bSide,
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(45),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FixedColumnWidth(65),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              _row(
                [
                  'Size :',
                  'W: ${item.width}, H: ${item.height}',
                  '',
                  '',
                ],
                bgColor: greyColor,
                isBold: true,
              ),
              ..._buildDynamicHeaderRows(item.basicInfo, greyColor, font, fontBold),
            ],
          ),

          // BODY ROW
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // LEFT IMAGES
              pw.Container(
                width: 120,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Column(
                  children: [
                    if (item.images.isNotEmpty)
                      pw.Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: item.images.map((path) {
                          final file = File(path);
                          if (file.existsSync()) {
                            return pw.Container(
                              height: 60,
                              width: 50,
                              child: pw.Image(
                                pw.MemoryImage(file.readAsBytesSync()),
                              ),
                            );
                          }
                          return pw.SizedBox();
                        }).toList(),
                      ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "View From Inside",
                      style: pw.TextStyle(font: font, fontSize: 6),
                    ),
                  ],
                ),
              ),

              // RIGHT DATA
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border(left: bSide)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Computed Values
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        color: blueColor,
                        child: pw.Text(
                          "Computed Values",
                          style: pw.TextStyle(font: fontBold, fontSize: 7),
                        ),
                      ),
                      pw.Table(
                        border: pw.TableBorder(
                          horizontalInside: bSide,
                          top: bSide,
                          bottom: bSide,
                        ),
                        children: [
                          _row([
                            'Sq.Ft. per window',
                            '${item.area.toStringAsFixed(3)} Sq.Ft.',
                          ]),
                          _row([
                            'Value per Sq.Ft.',
                            '${item.ratePerSqFt.toStringAsFixed(2)} Rs.',
                          ]),
                          _row([
                            'Unit Price',
                            '${(item.area * item.ratePerSqFt).toStringAsFixed(2)} Rs.',
                          ]),
                          _row(['Quantity', '${item.quantity.toInt()} Pcs']),
                          _row([
                            'Value',
                            '${item.totalValue.toStringAsFixed(2)} Rs.',
                          ]),
                        ],
                      ),

                      // Profile & Accessories Row
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Profile Column
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(2),
                                  color: blueColor,
                                  child: pw.Text(
                                    "Profile",
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 7,
                                    ),
                                  ),
                                ),
                                pw.Table(
                                  border: pw.TableBorder(
                                    top: bSide,
                                    bottom: bSide,
                                  ),
                                  children: item.specs.entries
                                      .map(
                                        (e) => _row(['${e.key} : ${e.value}']),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),

                          // Divider
                          pw.Container(width: 0.5, color: borderColor),

                          // Accessories Column
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(2),
                                  color: blueColor,
                                  child: pw.Text(
                                    "Accessories",
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 7,
                                    ),
                                  ),
                                ),
                                pw.Table(
                                  border: pw.TableBorder(
                                    top: bSide,
                                    bottom: bSide,
                                  ),
                                  children: item.accessories.entries
                                      .map(
                                        (e) => _row(['${e.key} : ${e.value}']),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Remarks
                      pw.Container(
                        padding: const pw.EdgeInsets.all(2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(top: bSide),
                        ),
                        child: pw.Text(
                          "Remarks : ${item.remarks}",
                          style: pw.TextStyle(font: font, fontSize: 6.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummary(
    Quotation quote,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              "Subtotal: ₹${quote.subTotal.toStringAsFixed(2)}",
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            if (quote.showTransportation)
              pw.Text(
                "Transportation ${quote.isTransportationPercentage ? '(${quote.transportationValue}%)' : ''}: ₹${quote.transportationAmount.toStringAsFixed(2)}",
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            if (quote.additionalCostValue > 0)
              pw.Text(
                "${quote.additionalCostLabel.isNotEmpty ? quote.additionalCostLabel : 'Additional Cost'}: ₹${quote.additionalCostValue.toStringAsFixed(2)}",
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            if (quote.showGst)
              pw.Text(
                "GST ${quote.isGstPercentage ? '(${quote.gstValue}%)' : ''}: ₹${quote.gstAmount.toStringAsFixed(2)}",
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            pw.Divider(),
            pw.Text(
              "Grand Total: ₹${quote.grandTotal.toStringAsFixed(2)}",
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _parseRichText(
    String text,
    pw.Font font,
    pw.Font fontBold,
    double fontSize,
  ) {
    final List<pw.TextSpan> spans = [];
    final regExp = RegExp(r'(\*\*.*?\*\*|_+.*?_+)');
    int lastMatchEnd = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(pw.TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final matchText = match.group(0)!;
      if (matchText.startsWith('**')) {
        spans.add(
          pw.TextSpan(
            text: matchText.substring(2, matchText.length - 2),
            style: pw.TextStyle(font: fontBold),
          ),
        );
      } else if (matchText.startsWith('_')) {
        spans.add(
          pw.TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: pw.TextStyle(
              font: fontBold,
            ), // Using bold font for emphasis as a simple italic fallback
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(pw.TextSpan(text: text.substring(lastMatchEnd)));
    }

    if (spans.isEmpty) {
      return pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      );
    }

    return pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(font: font, fontSize: fontSize),
        children: spans,
      ),
    );
  }

  static List<pw.TableRow> _buildDynamicHeaderRows(Map<String, String> data, PdfColor bgColor, pw.Font font, pw.Font fontBold) {
    final List<pw.TableRow> rows = [];
    final entries = data.entries.toList();
    
    for (int i = 0; i < entries.length; i += 2) {
      final e1 = entries[i];
      final e2 = (i + 1 < entries.length) ? entries[i + 1] : null;
      
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: [
            _cell('${e1.key} :', fontBold),
            _cell(e1.value, font),
            if (e2 != null) ...[
              _cell('${e2.key} :', fontBold),
              _cell(e2.value, font),
            ] else ...[
              _cell('', font),
              _cell('', font),
            ],
          ],
        ),
      );
    }
    return rows;
  }

  static pw.Widget _cell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 6.5)),
    );
  }
}
