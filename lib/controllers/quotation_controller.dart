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
  Map<String, dynamic> _driveDataCache = {};
  bool _isLoading = false;

  CompanySettings? get settings => _settings;
  List<Quotation> get quotations => _quotations;
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
    
    // If local data is empty, try to sync from Drive
    if (_quotations.isEmpty && authController.user != null) {
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
        _driveDataCache = Map<String, dynamic>.from(driveDataRaw);
        // Process Media
        final driveData = await MediaSyncHelper.processAfterDownload(driveDataRaw);
        
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
      final driveData = await MediaSyncHelper.prepareForUpload(_driveDataCache);
      await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
    }
    
    notifyListeners();
  }

  void _scheduleAllReminders() {
    for (var q in _quotations) {
      if (q.reminderDate != null && q.reminderDate!.isAfter(DateTime.now())) {
        NotificationService().scheduleNotification(
          id: q.id.hashCode,
          title: 'Quotation Follow-up',
          body: 'Follow up with ${q.clientName} for quote ${q.quoteNumber}',
          scheduledDate: q.reminderDate!,
        );
      }
    }
  }
}
