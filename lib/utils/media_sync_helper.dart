import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaSyncHelper {
  static const String base64Prefix = "base64:";

  /// Processes a Map recursively and converts image paths to Base64 strings
  static Future<Map<String, dynamic>> prepareForUpload(Map<String, dynamic> data) async {
    final Map<String, dynamic> processed = {};
    
    for (var entry in data.entries) {
      if (entry.value is Map<String, dynamic>) {
        processed[entry.key] = await prepareForUpload(entry.value);
      } else if (entry.value is List) {
        processed[entry.key] = await _processList(entry.value, entry.key);
      } else if (_isImagePathKey(entry.key) && entry.value is String) {
        processed[entry.key] = await encodeImage(entry.value);
      } else {
        processed[entry.key] = entry.value;
      }
    }
    return processed;
  }

  /// Processes a Map recursively and converts Base64 strings back to local file paths
  static Future<Map<String, dynamic>> processAfterDownload(Map<String, dynamic> data) async {
    final Map<String, dynamic> processed = {};
    
    for (var entry in data.entries) {
      if (entry.value is Map<String, dynamic>) {
        processed[entry.key] = await processAfterDownload(entry.value);
      } else if (entry.value is List) {
        processed[entry.key] = await _processListDownload(entry.value, entry.key);
      } else if (entry.value is String && entry.value.startsWith(base64Prefix)) {
        processed[entry.key] = await decodeImage(entry.value, "img_${DateTime.now().microsecondsSinceEpoch}_${entry.key}.jpg");
      } else {
        processed[entry.key] = entry.value;
      }
    }
    return processed;
  }

  static bool _isImagePathKey(String key) {
    const keys = {'content', 'images', 'photoURL', 'image', 'path', 'url'};
    return keys.contains(key.toLowerCase());
  }

  static Future<List> _processList(List list, String key) async {
    final processed = [];
    for (var item in list) {
      if (item is Map<String, dynamic>) {
        processed.add(await prepareForUpload(item));
      } else if (item is String && _isImagePathKey(key)) {
        // This is a list of image paths (like QuotationItem.images)
        processed.add(await encodeImage(item));
      } else if (item is String && (item.contains('/') || item.contains('\\'))) {
        // Fallback for strings that look like paths
        processed.add(await encodeImage(item));
      } else {
        processed.add(item);
      }
    }
    return processed;
  }

  static Future<List> _processListDownload(List list, String key) async {
    final processed = [];
    for (int i = 0; i < list.length; i++) {
      var item = list[i];
      if (item is Map<String, dynamic>) {
        processed.add(await processAfterDownload(item));
      } else if (item is String && item.startsWith(base64Prefix)) {
        processed.add(await decodeImage(item, "img_${DateTime.now().microsecondsSinceEpoch}_${key}_${i}_${i}.jpg"));
      } else {
        processed.add(item);
      }
    }
    return processed;
  }

  static Future<String> encodeImage(String path) async {
    if (path.isEmpty || path.startsWith(base64Prefix)) return path;
    final file = File(path);
    if (!await file.exists()) return path;
    
    try {
      final bytes = await file.readAsBytes();
      return "$base64Prefix${base64.encode(bytes)}";
    } catch (e) {
      print("Error encoding image: $e");
      return path;
    }
  }

  static Future<String> decodeImage(String data, String fileName) async {
    if (!data.startsWith(base64Prefix)) return data;
    
    try {
      final base64String = data.substring(base64Prefix.length);
      final bytes = base64.decode(base64String);
      
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, 'synced_images'));
      if (!await imagesDir.exists()) await imagesDir.create();
      
      final file = File(p.join(imagesDir.path, fileName));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      print("Error decoding image: $e");
      return data;
    }
  }
}
