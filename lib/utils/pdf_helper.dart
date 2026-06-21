import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/company_settings.dart';
import '../models/quotation_model.dart';

class PdfHelper {
  // ── Font cache: loaded once from bundled assets, reused across calls ──
  static pw.Font? _cachedFont;
  static pw.Font? _cachedFontBold;

  static Future<pw.Font> _getFont() async {
    _cachedFont ??= pw.Font.ttf(
      (await rootBundle.load(
        'assets/fonts/Poppins-Regular.ttf',
      )).buffer.asByteData(),
    );
    return _cachedFont!;
  }

  static Future<pw.Font> getFontBold() async {
    _cachedFontBold ??= pw.Font.ttf(
      (await rootBundle.load(
        'assets/fonts/Poppins-Bold.ttf',
      )).buffer.asByteData(),
    );
    return _cachedFontBold!;
  }

  /// Loads an image file, resizes it to max 800px, and compresses to JPEG.
  /// This is CRITICAL to prevent OOM crash when calling pdf.save() —
  /// raw camera photos are 3–15 MB each; this reduces them to ~50–150 KB.
  static Future<pw.MemoryImage?> _loadImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) return null;

      // Decode → resize → re-encode as JPEG
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        // Decoding failed: embed raw bytes as fallback (rare edge case)
        return pw.MemoryImage(rawBytes);
      }

      // Cap longest side at 800px — sufficient for PDF print quality
      const int maxDim = 800;
      img.Image scaled = decoded;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        if (decoded.width >= decoded.height) {
          scaled = img.copyResize(
            decoded,
            width: maxDim,
            interpolation: img.Interpolation.linear,
          );
        } else {
          scaled = img.copyResize(
            decoded,
            height: maxDim,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      // Re-encode as JPEG at 80% quality (~50–150 KB vs 3–15 MB raw)
      final compressed = Uint8List.fromList(img.encodeJpg(scaled, quality: 80));
      return pw.MemoryImage(compressed);
    } catch (e) {
      // ignore: avoid_print
      print('PDF image load error ($path): $e');
      return null;
    }
  }

  static Future<Uint8List> generateQuotation(
    Quotation quote,
    CompanySettings settings,
  ) async {
    final pdf = pw.Document();

    // 0. Load fonts from bundled assets (no network, no OOM)
    final font = await _getFont();
    final fontBold = await getFontBold();

    // Pre-load ALL images asynchronously before PDF layout begins.
    // This avoids synchronous disk I/O inside pw.MultiPage build callbacks.
    final Map<String, pw.MemoryImage> imageCache = {};

    // Collect every image path referenced by the quotation
    final Set<String> allImagePaths = {};
    for (final item in quote.items) {
      for (final p in item.images) {
        if (p.isNotEmpty) allImagePaths.add(p);
      }
    }
    for (final el in [
      ...settings.headerElements,
      ...settings.footerElements,
      ...settings.firstPageElements,
      ...settings.lastPageElements,
    ]) {
      if (el.type == PdfElementType.image && el.content.isNotEmpty) {
        allImagePaths.add(el.content);
      }
    }
    // Load images ONE AT A TIME (sequential, not parallel).
    // Parallel loading with Future.wait causes an OOM spike:
    //   each 12MP photo = ~48 MB RAM when decoded by the image package.
    //   5 photos in parallel = 240 MB peak → Android kills the process.
    // Sequential keeps peak at ~48 MB (one image decoded at a time).
    for (final path in allImagePaths) {
      final loaded = await _loadImage(path);
      if (loaded != null) imageCache[path] = loaded;
    }

    double originalGrandTotal = 0;
    if (quote.isBill) {
      try {
        final List<QuotationItem> originalItems = quote.items.map((item) {
          if (item.originalData != null) {
            return QuotationItem.fromJson(item.originalData!);
          }
          return item;
        }).toList();

        final tempQuote = Quotation(
          id: 'temp',
          quoteNumber: '',
          clientName: '',
          clientAddress: '',
          clientPhone: '',
          date: DateTime.now(),
          items: originalItems,
          gstValue: quote.gstValue,
          isGstPercentage: quote.isGstPercentage,
          showGst: quote.showGst,
          transportationValue: quote.transportationValue,
          isTransportationPercentage: quote.isTransportationPercentage,
          showTransportation: quote.showTransportation,
          additionalCostValue: quote.additionalCostValue,
          summaryExtras: quote.summaryExtras,
          adjustment: 0,
        );
        originalGrandTotal = tempQuote.grandTotal;
      } catch (e) {
        print("Error pre-calculating original total: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          // Draws a decorative border on EVERY page automatically
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              margin: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
            ),
          ),
        ),
        maxPages:
            1000, // default is only 20 — raises limit for large quotations
        header: (context) => _buildHeaderFooter(
          settings.headerElements,
          font,
          fontBold,
          isHeader: true,
          quote: quote,
          imageCache: imageCache,
        ),
        footer: (context) => _buildHeaderFooter(
          settings.footerElements,
          font,
          fontBold,
          isHeader: false,
          context: context,
          quote: quote,
          imageCache: imageCache,
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
                    quote: quote,
                    imageCache: imageCache,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.firstPageElements,
                    PdfElementPosition.center,
                    font,
                    fontBold,
                    quote: quote,
                    imageCache: imageCache,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.firstPageElements,
                    PdfElementPosition.right,
                    font,
                    fontBold,
                    quote: quote,
                    imageCache: imageCache,
                  ),
                ),
              ],
            ),
            pw.NewPage(),
          ],

          // 2. Middle Pages (Items)
          if (quote.isBill)
            pw.Center(
              child: pw.Text(
                "FINAL BILL",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.teal,
                ),
              ),
            ),
          if (quote.isBill) pw.SizedBox(height: 10),

          ...quote.items.map(
            (item) => _buildItemBlock(
              item,
              font,
              fontBold,
              isBill: quote.isBill,
              imageCache: imageCache,
            ),
          ),
          pw.SizedBox(height: 20),
          _buildSummary(quote, font, fontBold, originalGrandTotal),

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
                    quote: quote,
                    imageCache: imageCache,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.lastPageElements,
                    PdfElementPosition.center,
                    font,
                    fontBold,
                    quote: quote,
                    imageCache: imageCache,
                  ),
                ),
                pw.Expanded(
                  child: _buildAlignmentColumn(
                    settings.lastPageElements,
                    PdfElementPosition.right,
                    font,
                    fontBold,
                    quote: quote,
                    imageCache: imageCache,
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
    required Quotation quote,
    required Map<String, pw.MemoryImage> imageCache,
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
                quote: quote,
                imageCache: imageCache,
              ),
            ),
            pw.Expanded(
              child: _buildAlignmentColumn(
                elements,
                PdfElementPosition.center,
                font,
                fontBold,
                quote: quote,
                imageCache: imageCache,
              ),
            ),
            pw.Expanded(
              child: _buildAlignmentColumn(
                elements,
                PdfElementPosition.right,
                font,
                fontBold,
                quote: quote,
                imageCache: imageCache,
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
    pw.Font fontBold, {
    required Quotation quote,
    required Map<String, pw.MemoryImage> imageCache,
  }) {
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
          String content = el.content;
          // Placeholder Replacement Logic
          content = content
              .replaceAll('{{CLIENT_NAME}}', quote.clientName)
              .replaceAll('{{CLIENT_ADDRESS}}', quote.clientAddress)
              .replaceAll('{{CLIENT_PHONE}}', quote.clientPhone)
              .replaceAll('{{QUOTE_NUMBER}}', quote.quoteNumber)
              .replaceAll('{{DATE}}', quote.date.toString().split(' ')[0])
              .replaceAll(
                '{{GRAND_TOTAL}}',
                "₹${quote.grandTotal.toStringAsFixed(2)}",
              )
              .replaceAll(
                '{{SUBTOTAL}}',
                "₹${quote.subTotal.toStringAsFixed(2)}",
              )
              .replaceAll(
                '{{PAGE_TITLE}}',
                quote.isBill ? "FINAL BILL" : "QUOTATION",
              );

          // Additional Client Details replacement
          quote.additionalClientDetails.forEach((key, value) {
            content = content.replaceAll('{{$key}}', value);
          });

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: _parseRichText(content, font, fontBold, el.size),
          );
        } else {
          final String path = el.content;
          if (path.isEmpty) return pw.SizedBox();

          // Images pre-loaded asynchronously before layout — just look up cache
          // IMPORTANT: height MUST be bounded — unbounded image height causes
          // the pdf layout engine to enter an infinite loop → TooManyPagesException
          if (imageCache.containsKey(path)) {
            return pw.Container(
              width: el.size,
              height: el.size, // square bounding box; image contained within
              child: pw.Image(
                imageCache[path]!,
                fit: pw.BoxFit.contain, // preserves aspect ratio
              ),
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
    pw.Font fontBold, {
    bool isBill = false,
    required Map<String, pw.MemoryImage> imageCache,
  }) {
    final blueColor = PdfColor.fromHex('#D9E2F3');
    final greyColor = PdfColor.fromHex('#F2F2F2');
    final tealLight = PdfColor.fromHex('#E0F2F1');
    final headerBg = isBill ? tealLight : greyColor;
    final borderColor = PdfColors.grey400;
    const bSide = pw.BorderSide(color: PdfColors.grey400, width: 0.5);

    Map<String, dynamic>? orig = item.originalData;
    final originalItem = orig != null ? QuotationItem.fromJson(orig) : null;

    String _val(String current, String key) {
      return current; // Don't append here anymore, we'll build separate widgets
    }

    String _numVal(double current, String key) {
      return current.toStringAsFixed(2);
    }

    pw.Widget _comparisonRow(
      String label,
      String current,
      String? original, {
      bool isBold = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(font: font, fontSize: 6.5)),
            pw.Row(
              children: [
                pw.Text(
                  current,
                  style: pw.TextStyle(
                    font: isBold ? fontBold : font,
                    fontSize: 6.5,
                  ),
                ),
                if (original != null && original != current)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Text(
                      "(Quoted: $original)",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 6,
                        color: PdfColors.orange800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

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
              0: const pw.FixedColumnWidth(55),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      'Product :',
                      style: pw.TextStyle(font: fontBold, fontSize: 6.5),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      item.displayName,
                      style: pw.TextStyle(font: fontBold, fontSize: 6.5),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      'Size :',
                      style: pw.TextStyle(font: fontBold, fontSize: 6.5),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      '${item.width} x ${item.height} ${item.areaUnit}',
                      style: pw.TextStyle(font: fontBold, fontSize: 6.5),
                    ),
                  ),
                ],
              ),
              ..._buildDynamicHeaderRows(
                item.basicInfo.entries
                    .where((e) => e.key.toLowerCase() != 'description')
                    .fold<Map<String, String>>(
                      {},
                      (p, e) => p..[e.key] = e.value,
                    ),
                greyColor,
                font,
                fontBold,
              ),
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
                    // pw.Wrap is not reliable inside pw.MultiPage —
                    // use a simple Row of fixed-size boxes instead
                    if (item.images.isNotEmpty)
                      pw.Row(
                        children: item.images.take(4).map((path) {
                          if (path.isEmpty) return pw.SizedBox();
                          if (imageCache.containsKey(path)) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(right: 5),
                              child: pw.Container(
                                height: 60,
                                width: 50,
                                child: pw.Image(
                                  imageCache[path]!,
                                  fit: pw.BoxFit.cover,
                                ),
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
                      if (isBill && originalItem != null) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(2),
                          color: PdfColors.orange50,
                          child: pw.Text(
                            "Comparison: Quoted vs Final Bill",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 7,
                              color: PdfColors.orange900,
                            ),
                          ),
                        ),
                        pw.Table(
                          border: pw.TableBorder(
                            horizontalInside: bSide,
                            verticalInside: bSide,
                            bottom: bSide,
                          ),
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(2),
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "ORIGINAL QUOTED",
                                        style: pw.TextStyle(
                                          font: fontBold,
                                          fontSize: 6,
                                          color: PdfColors.orange800,
                                        ),
                                      ),
                                      _comparisonRow(
                                        originalItem.isUnitBased
                                            ? 'Rate'
                                            : 'Rate/SqFt',
                                        '₹${originalItem.isUnitBased ? originalItem.unitRate : originalItem.ratePerSqFt}',
                                        null,
                                      ),
                                      _comparisonRow(
                                        'Qty',
                                        '${originalItem.isUnitBased ? originalItem.unitQuantity : originalItem.quantity} ${originalItem.isUnitBased ? originalItem.itemUnit : 'Pcs'}',
                                        null,
                                      ),
                                      _comparisonRow(
                                        'Total',
                                        '₹${originalItem.totalValue.toStringAsFixed(2)}',
                                        null,
                                        isBold: true,
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(2),
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "FINAL BILL VALUES",
                                        style: pw.TextStyle(
                                          font: fontBold,
                                          fontSize: 6,
                                          color: PdfColors.teal900,
                                        ),
                                      ),
                                      _comparisonRow(
                                        item.isUnitBased ? 'Rate' : 'Rate/SqFt',
                                        '₹${item.isUnitBased ? item.unitRate : item.ratePerSqFt}',
                                        null,
                                      ),
                                      _comparisonRow(
                                        'Qty',
                                        '${item.isUnitBased ? item.unitQuantity : item.quantity} ${item.isUnitBased ? item.itemUnit : 'Pcs'}',
                                        null,
                                      ),
                                      _comparisonRow(
                                        'Total',
                                        '₹${item.totalValue.toStringAsFixed(2)}',
                                        null,
                                        isBold: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
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
                          children: item.isUnitBased
                              ? [
                                  pw.TableRow(
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(2),
                                        child: pw.Column(
                                          children: [
                                            _comparisonRow(
                                              'Rate',
                                              '₹${item.unitRate} / ${item.itemUnit}',
                                              null,
                                            ),
                                            _comparisonRow(
                                              'Quantity',
                                              '${item.unitQuantity} ${item.itemUnit}',
                                              null,
                                            ),
                                            _comparisonRow(
                                              'Total Value',
                                              '₹${item.totalValue.toStringAsFixed(2)}',
                                              null,
                                              isBold: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
                              : [
                                  pw.TableRow(
                                    children: [
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.all(2),
                                        child: pw.Column(
                                          children: [
                                            _comparisonRow(
                                              item.multiplyByArea
                                                  ? 'Area (${item.areaUnit}²)'
                                                  : 'Size Info',
                                              '${item.area.toStringAsFixed(3)} ${item.areaUnit}${item.multiplyByArea ? '²' : ''}',
                                              null,
                                            ),
                                            _comparisonRow(
                                              'Rate per ${item.multiplyByArea ? (item.areaUnit + '²') : 'Item'}',
                                              '₹${item.ratePerSqFt}',
                                              null,
                                            ),
                                            _comparisonRow(
                                              'Quantity',
                                              '${item.quantity} Pcs',
                                              null,
                                            ),
                                            _comparisonRow(
                                              'Total Value',
                                              '₹${item.totalValue.toStringAsFixed(2)}',
                                              null,
                                              isBold: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                        ),
                      ],

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
    double originalGrandTotal,
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
            if (quote.isBill && quote.adjustment != 0)
              pw.Text(
                "Bill Adjustment: ₹${quote.adjustment.toStringAsFixed(2)}",
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.teal,
                ),
              ),
            pw.Divider(),
            if (quote.isBill) ...[
              pw.Divider(color: PdfColors.teal, thickness: 1),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Quoted Amount: ₹${originalGrandTotal.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: PdfColors.orange800,
                    ),
                  ),
                  pw.Text(
                    "Final Adjusted Bill: ₹${quote.grandTotal.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 13,
                      color: PdfColors.teal,
                    ),
                  ),
                ],
              ),
            ] else
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

  static List<pw.TableRow> _buildDynamicHeaderRows(
    Map<String, String> data,
    PdfColor bgColor,
    pw.Font font,
    pw.Font fontBold,
  ) {
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
