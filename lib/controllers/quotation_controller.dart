import 'package:flutter/material.dart';
import '../models/company_settings.dart';
import '../models/quotation_model.dart';
import '../utils/file_helper.dart';
import '../utils/drive_helper.dart';
import '../utils/media_sync_helper.dart';
import 'auth_controller.dart';
import '../services/notification_service.dart';

class QuotationController with ChangeNotifier {
  final AuthController authController;
  
  CompanySettings? _settings;
  List<Quotation> _quotations = [];
  List<Quotation> _bills = [];
  Map<String, dynamic> _driveDataCache = {};
  bool _isLoading = false;

  CompanySettings? get settings => _settings;
  List<Quotation> get quotations => _quotations;
  List<Quotation> get bills => _bills;
  bool get isLoading => _isLoading;

  QuotationController(this.authController) {
    _loadData();
    authController.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (authController.user != null && _quotations.isEmpty) {
      syncWithDrive();
    }
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    
    _settings = await FileHelper.loadSettings();
    _quotations = await FileHelper.getAllQuotations();
    _bills = await FileHelper.getAllBills();
    
    // If local data is empty, try to sync from Drive
    if (_quotations.isEmpty && _bills.isEmpty && authController.user != null) {
      await syncWithDrive();
    }
    _isLoading = false;
    _scheduleAllReminders();
    notifyListeners();
  }

  Future<void> syncWithDrive() async {
    if (authController.user == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final driveDataRaw = await DriveHelper.downloadUserData(authController.googleSignIn);
      if (driveDataRaw != null) {
        // Process Media (converts Base64 to local paths)
        final driveData = await MediaSyncHelper.processAfterDownload(driveDataRaw);
        
        // Update cache with processed data (local paths instead of massive Base64)
        _driveDataCache = Map<String, dynamic>.from(driveData);
        
        // Restore Settings
        if (driveData.containsKey('settings')) {
          _settings = CompanySettings.fromJson(driveData['settings']);
          await FileHelper.saveSettings(_settings!);
        }
        
        // Restore Quotations
        final List<Quotation> restoredQuotes = [];
        driveData.forEach((key, value) {
          if (key.startsWith('quotation_')) {
            restoredQuotes.add(Quotation.fromJson(value));
          }
        });
        
        if (restoredQuotes.isNotEmpty) {
          for (var q in restoredQuotes) {
            await FileHelper.saveQuotation(q);
          }
          _quotations = restoredQuotes;
        }

        // Restore Bills
        final List<Quotation> restoredBills = [];
        driveData.forEach((key, value) {
          if (key.startsWith('bill_')) {
            restoredBills.add(Quotation.fromJson(value));
          }
        });

        if (restoredBills.isNotEmpty) {
          for (var b in restoredBills) {
            await FileHelper.saveBill(b);
          }
          _bills = restoredBills;
        }
      }
    } catch (e) {
      print("Sync error: $e");
    }
    _isLoading = false;
    _scheduleAllReminders();
    notifyListeners();
  }

  Future<void> saveSettings(CompanySettings settings) async {
    await FileHelper.saveSettings(settings);
    _settings = settings;
    
    if (authController.user != null) {
      _driveDataCache['settings'] = settings.toJson();
      
      // Process for upload
      final driveData = await MediaSyncHelper.prepareForUpload(_driveDataCache);
      await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
    }
    
    notifyListeners();
  }

  Future<void> saveQuotation(Quotation quotation) async {
    await FileHelper.saveQuotation(quotation);
    
    final index = _quotations.indexWhere((q) => q.id == quotation.id);
    if (index != -1) {
      _quotations[index] = quotation;
    } else {
      _quotations.add(quotation);
    }

    if (authController.user != null) {
      _driveDataCache['quotation_${quotation.id}'] = quotation.toJson();
      
      // Process for upload
      final driveData = await MediaSyncHelper.prepareForUpload(_driveDataCache);
      await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
    }

    notifyListeners();
  }

  Future<void> deleteQuotation(String id) async {
    await FileHelper.deleteQuotation(id);
    _quotations.removeWhere((q) => q.id == id);

    if (authController.user != null) {
      _driveDataCache.remove('quotation_$id');
      try {
        final driveData = await MediaSyncHelper.prepareForUpload(_driveDataCache);
        await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
      } catch (e) {
        print("Error updating Drive after deletion: $e");
      }
    }
    notifyListeners();
  }

  Future<void> saveBill(Quotation bill) async {
    await FileHelper.saveBill(bill);
    
    final index = _bills.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      _bills[index] = bill;
    } else {
      _bills.add(bill);
    }

    if (authController.user != null) {
      _driveDataCache['bill_${bill.id}'] = bill.toJson();
      
      // Process for upload
      final driveData = await MediaSyncHelper.prepareForUpload(_driveDataCache);
      await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
    }

    notifyListeners();
  }

  Future<void> deleteBill(String id) async {
    await FileHelper.deleteBill(id);
    _bills.removeWhere((b) => b.id == id);

    if (authController.user != null) {
      _driveDataCache.remove('bill_$id');
      try {
        final driveData = await MediaSyncHelper.prepareForUpload(_driveDataCache);
        await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
      } catch (e) {
        print("Error updating Drive after deletion: $e");
      }
    }
    notifyListeners();
  }

  void _scheduleAllReminders() {
    for (var q in _quotations) {
      for (int i = 0; i < q.reminderDates.length; i++) {
        final date = q.reminderDates[i];
        if (date.isAfter(DateTime.now())) {
          // Use a combination of quote hash and index to keep IDs unique
          NotificationService().scheduleNotification(
            id: q.id.hashCode + i * 1000,
            title: 'Quotation Follow-up',
            body: 'Follow up with ${q.clientName} for quote ${q.quoteNumber}',
            scheduledDate: date,
          );
        }
      }
    }
  }
}
