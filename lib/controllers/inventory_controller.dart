import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quotation_model.dart';
import '../utils/file_helper.dart';
import '../utils/drive_helper.dart';
import '../utils/media_sync_helper.dart';
import 'auth_controller.dart';

class InventoryController with ChangeNotifier {
  final AuthController authController;
  List<QuotationItem> _items = [];
  bool _isLoading = false;
  Timer? _autoRefreshTimer;
  int _refreshInterval = 5;

  List<QuotationItem> get items => _items;
  bool get isLoading => _isLoading;

  InventoryController(this.authController) {
    _loadData();
    authController.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (authController.user != null && _items.isEmpty) {
      syncFromDrive();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    _items = await FileHelper.loadInventory();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _refreshInterval = prefs.getInt('auto_refresh_interval') ?? 5;
    } catch (_) {}
    _startAutoRefreshTimer();
    
    _isLoading = false;
    notifyListeners();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (_refreshInterval > 0) {
      _autoRefreshTimer = Timer.periodic(
        Duration(minutes: _refreshInterval),
        (timer) {
          if (!_isLoading) {
            syncFromDrive();
          }
        },
      );
    }
  }

  Future<void> saveItem(QuotationItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    await FileHelper.saveInventory(_items);
    notifyListeners(); // Update UI immediately
    syncToDrive(); // Sync in background
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await FileHelper.saveInventory(_items);
    notifyListeners(); // Update UI immediately
    syncToDrive(); // Sync in background
  }

  Future<void> syncToDrive() async {
    if (authController.user == null) return;
    
    try {
      final driveDataRaw = await DriveHelper.downloadUserData(authController.googleSignIn) ?? {};
      driveDataRaw['inventory'] = _items.map((e) => e.toJson()).toList();
      
      final driveData = await MediaSyncHelper.prepareForUpload(driveDataRaw);
      await DriveHelper.uploadUserData(authController.googleSignIn, driveData);
    } catch (e) {
      print("Inventory Sync Error: $e");
    }
  }

  Future<void> syncFromDrive() async {
    if (authController.user == null) return;
    
    // Only show loading if we don't have items yet
    if (_items.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final driveDataRaw = await DriveHelper.downloadUserData(authController.googleSignIn);
      if (driveDataRaw != null && driveDataRaw.containsKey('inventory')) {
        // IMPORTANT: Process the data to decode base64 images back to local files
        final processedData = await MediaSyncHelper.processAfterDownload(driveDataRaw);
        
        final List list = processedData['inventory'];
        _items = list.map((e) => QuotationItem.fromJson(e)).toList();
        await FileHelper.saveInventory(_items);
      }
    } catch (e) {
      print("Inventory Download Error: $e");
    }
    _isLoading = false;
    notifyListeners();
  }
}
