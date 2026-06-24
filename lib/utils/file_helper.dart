import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/company_settings.dart';
import '../models/quotation_model.dart';
import '../models/employee_model.dart';

class FileHelper {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _settingsFile async {
    final path = await _localPath;
    return File('$path/settings.json');
  }

  static Future<File> _quotationFile(String id) async {
    final path = await _localPath;
    final dir = Directory('$path/quotations');
    if (!await dir.exists()) await dir.create();
    return File('$path/quotations/$id.json');
  }

  static Future<File> _billFile(String id) async {
    final path = await _localPath;
    final dir = Directory('$path/bills');
    if (!await dir.exists()) await dir.create();
    return File('$path/bills/$id.json');
  }

  static Future<File> get _inventoryFile async {
    final path = await _localPath;
    return File('$path/inventory.json');
  }

  static Future<File> get _employeesFile async {
    final path = await _localPath;
    return File('$path/employees.json');
  }

  static Future<void> saveSettings(CompanySettings settings) async {
    final file = await _settingsFile;
    await file.writeAsString(json.encode(settings.toJson()));
  }

  static Future<CompanySettings?> loadSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return CompanySettings.fromJson(json.decode(content));
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
    return null;
  }

  static Future<void> saveQuotation(Quotation quote) async {
    final file = await _quotationFile(quote.id);
    await file.writeAsString(json.encode(quote.toJson()));
  }

  static Future<List<Quotation>> getAllQuotations() async {
    final path = await _localPath;
    final dir = Directory('$path/quotations');
    if (!await dir.exists()) return [];

    List<Quotation> quotes = [];
    final files = dir.listSync();
    for (var f in files) {
      if (f is File && f.path.endsWith('.json')) {
        final content = await f.readAsString();
        quotes.add(Quotation.fromJson(json.decode(content)));
      }
    }
    quotes.sort((a, b) => b.date.compareTo(a.date));
    return quotes;
  }

  static Future<void> deleteQuotation(String id) async {
    final file = await _quotationFile(id);
    if (await file.exists()) await file.delete();
  }

  static Future<void> saveBill(Quotation bill) async {
    final file = await _billFile(bill.id);
    await file.writeAsString(json.encode(bill.toJson()));
  }

  static Future<List<Quotation>> getAllBills() async {
    final path = await _localPath;
    final dir = Directory('$path/bills');
    if (!await dir.exists()) return [];

    List<Quotation> bills = [];
    final files = dir.listSync();
    for (var f in files) {
      if (f is File && f.path.endsWith('.json')) {
        final content = await f.readAsString();
        bills.add(Quotation.fromJson(json.decode(content)));
      }
    }
    bills.sort((a, b) => b.date.compareTo(a.date));
    return bills;
  }

  static Future<void> deleteBill(String id) async {
    final file = await _billFile(id);
    if (await file.exists()) await file.delete();
  }

  static Future<void> saveInventory(List<QuotationItem> items) async {
    final file = await _inventoryFile;
    await file.writeAsString(
      json.encode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<QuotationItem>> loadInventory() async {
    try {
      final file = await _inventoryFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List list = json.decode(content);
        return list.map((e) => QuotationItem.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error loading inventory: $e");
    }
    return [];
  }

  static Future<void> saveEmployees(List<Employee> list) async {
    final file = await _employeesFile;
    await file.writeAsString(
      json.encode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<Employee>> loadEmployees() async {
    try {
      final file = await _employeesFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List list = json.decode(content);
        return list.map((e) => Employee.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error loading employees: $e");
    }
    return [];
  }
}
