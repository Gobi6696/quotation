import 'dart:typed_data';
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../models/quotation_model.dart';
import 'package:intl/intl.dart';

class ExcelHelper {
  static Future<Uint8List> generateQuotationExcel(Quotation quote) async {
    // Create a new Excel document.
    final Workbook workbook = Workbook();
    // Accessing worksheet via index.
    final Worksheet sheet = workbook.worksheets[0];
    sheet.showGridlines = true;

    // Set column widths
    sheet.setColumnWidthInPixels(1, 50);  // S.No
    sheet.setColumnWidthInPixels(2, 100); // Image
    sheet.setColumnWidthInPixels(3, 200); // Description
    sheet.setColumnWidthInPixels(4, 200); // Specs
    sheet.setColumnWidthInPixels(5, 200); // Accessories
    sheet.setColumnWidthInPixels(6, 100); // Size
    sheet.setColumnWidthInPixels(7, 80);  // Area
    sheet.setColumnWidthInPixels(8, 80);  // Rate
    sheet.setColumnWidthInPixels(9, 60);  // Qty
    sheet.setColumnWidthInPixels(10, 100); // Total
    sheet.setColumnWidthInPixels(11, 150); // Remarks

    // Styles
    final Style headerStyle = workbook.styles.add('headerStyle');
    headerStyle.bold = true;
    headerStyle.fontSize = 16;
    headerStyle.backColor = '#4472C4';
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.hAlign = HAlignType.center;
    headerStyle.vAlign = VAlignType.center;

    final Style tableHeaderStyle = workbook.styles.add('tableHeaderStyle');
    tableHeaderStyle.bold = true;
    tableHeaderStyle.backColor = '#D9E2F3';
    tableHeaderStyle.hAlign = HAlignType.center;
    tableHeaderStyle.vAlign = VAlignType.center;
    tableHeaderStyle.borders.all.lineStyle = LineStyle.thin;

    final Style labelStyle = workbook.styles.add('labelStyle');
    labelStyle.bold = true;

    // 1. Title
    final Range titleRange = sheet.getRangeByName('A1:K1');
    titleRange.merge();
    titleRange.setText('BUSINESS QUOTATION');
    titleRange.cellStyle = headerStyle;
    sheet.setRowHeightInPixels(1, 40);

    // 2. Client Info
    int currentRow = 3;
    sheet.getRangeByIndex(currentRow, 1).setText('Quote Number:');
    sheet.getRangeByIndex(currentRow, 2).setText(quote.quoteNumber);
    sheet.getRangeByIndex(currentRow, 6).setText('Date:');
    sheet.getRangeByIndex(currentRow, 7).setText(DateFormat('dd-MM-yyyy').format(quote.date));
    
    currentRow++;
    sheet.getRangeByIndex(currentRow, 1).setText('Client Name:');
    sheet.getRangeByIndex(currentRow, 2).setText(quote.clientName);
    
    currentRow++;
    sheet.getRangeByIndex(currentRow, 1).setText('Address:');
    sheet.getRangeByIndex(currentRow, 2).setText(quote.clientAddress);
    
    currentRow++;
    sheet.getRangeByIndex(currentRow, 1).setText('Phone:');
    sheet.getRangeByIndex(currentRow, 2).setText(quote.clientPhone);

    quote.additionalClientDetails.forEach((key, value) {
      currentRow++;
      sheet.getRangeByIndex(currentRow, 1).setText('$key:');
      sheet.getRangeByIndex(currentRow, 2).setText(value);
    });

    currentRow += 2;

    // 3. Items Header
    final List<String> headers = [
      'S.No', 'Preview', 'Product / Description', 'Specifications', 'Accessories', 
      'Size (W x H)', 'Area / Units', 'Rate (Rs)', 'Qty', 'Total (Rs)', 'Remarks'
    ];
    for (int i = 0; i < headers.length; i++) {
      final Range cell = sheet.getRangeByIndex(currentRow, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = tableHeaderStyle;
    }

    // 4. Items Data
    for (int i = 0; i < quote.items.length; i++) {
      currentRow++;
      final item = quote.items[i];
      
      sheet.getRangeByIndex(currentRow, 1).setNumber(i + 1);
      // Image placeholder at index 2
      sheet.getRangeByIndex(currentRow, 3).setText(item.displayName);
      sheet.getRangeByIndex(currentRow, 4).setText(item.specs.entries.map((e) => "${e.key}: ${e.value}").join("\n"));
      sheet.getRangeByIndex(currentRow, 5).setText(item.accessories.entries.map((e) => "${e.key}: ${e.value}").join("\n"));
      
      if (item.isUnitBased) {
        sheet.getRangeByIndex(currentRow, 6).setText('Unit Based');
        sheet.getRangeByIndex(currentRow, 7).setText('${item.itemUnit}');
        sheet.getRangeByIndex(currentRow, 8).setNumber(item.unitRate);
        sheet.getRangeByIndex(currentRow, 9).setNumber(item.unitQuantity);
      } else {
        sheet.getRangeByIndex(currentRow, 6).setText('${item.width} x ${item.height} ${item.areaUnit}');
        sheet.getRangeByIndex(currentRow, 7).setText('${item.area.toStringAsFixed(2)} ${item.areaUnit}${item.multiplyByArea ? "²" : ""}');
        sheet.getRangeByIndex(currentRow, 8).setNumber(item.ratePerSqFt);
        sheet.getRangeByIndex(currentRow, 9).setNumber(item.quantity);
      }
      
      sheet.getRangeByIndex(currentRow, 10).setNumber(item.totalValue);
      sheet.getRangeByIndex(currentRow, 11).setText(item.remarks);

      sheet.setRowHeightInPixels(currentRow, 80); // Set row height for image

      if (item.images.isNotEmpty) {
        final file = File(item.images.first);
        if (file.existsSync()) {
          final List<int> bytes = file.readAsBytesSync();
          final Picture picture = sheet.pictures.addStream(currentRow, 2, bytes);
          picture.height = 70;
          picture.width = 90;
        }
      }
    }

    currentRow += 2;

    // 5. Summary
    void addSummaryRow(String label, double value, {bool isGrand = false}) {
      sheet.getRangeByIndex(currentRow, 9).setText(label);
      sheet.getRangeByIndex(currentRow, 10).setNumber(value);
      if (isGrand) {
        sheet.getRangeByIndex(currentRow, 9).cellStyle = headerStyle;
        sheet.getRangeByIndex(currentRow, 10).cellStyle = headerStyle;
      } else {
        sheet.getRangeByIndex(currentRow, 9).cellStyle = labelStyle;
      }
      currentRow++;
    }

    addSummaryRow('Sub Total', quote.subTotal);

    if (quote.showTransportation) {
      addSummaryRow('Transportation ${quote.isTransportationPercentage ? "(${quote.transportationValue}%)" : ""}', quote.transportationAmount);
    }

    if (quote.additionalCostValue > 0) {
      addSummaryRow(quote.additionalCostLabel.isNotEmpty ? quote.additionalCostLabel : 'Additional Cost', quote.additionalCostValue);
    }

    quote.summaryExtras.forEach((key, value) {
      addSummaryRow(key, value);
    });

    if (quote.showGst) {
      addSummaryRow('GST ${quote.isGstPercentage ? "(${quote.gstValue}%)" : ""}', quote.gstAmount);
    }

    currentRow++;
    addSummaryRow('Grand Total', quote.grandTotal, isGrand: true);

    // Save the document as a stream.
    final List<int> bytes = workbook.saveAsStream();
    // Dispose the workbook.
    workbook.dispose();

    return Uint8List.fromList(bytes);
  }
}
