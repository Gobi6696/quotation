import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DriveHelper {
  static const String fileName = "quotation_user_data.json";

  static Future<void> uploadUserData(GoogleSignIn googleSignIn, Map<String, dynamic> userData) async {
    final client = await googleSignIn.authenticatedClient();
    if (client == null) {
      print("DriveHelper: Client is null, cannot upload");
      return;
    }

    var driveApi = drive.DriveApi(client);
    final content = json.encode(userData);
    final bytes = utf8.encode(content);
    final stream = Stream.fromIterable([bytes]);

    try {
      // Search specifically in appDataFolder
      final list = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName'",
      );

      if (list.files != null && list.files!.isNotEmpty) {
        final fileId = list.files!.first.id!;
        print("DriveHelper: Updating existing file $fileId");
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: drive.Media(stream, bytes.length),
        );
      } else {
        print("DriveHelper: Creating new file in appDataFolder");
        var driveFile = drive.File();
        driveFile.name = fileName;
        driveFile.parents = ["appDataFolder"];
        await driveApi.files.create(
          driveFile,
          uploadMedia: drive.Media(stream, bytes.length),
        );
      }
      print("DriveHelper: Upload success");
    } catch (e) {
      print("DriveHelper Error: $e");
    }
  }

  static Future<Map<String, dynamic>?> downloadUserData(GoogleSignIn googleSignIn) async {
    final client = await googleSignIn.authenticatedClient();
    if (client == null) return null;

    var driveApi = drive.DriveApi(client);

    try {
      final list = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName'",
      );

      if (list.files != null && list.files!.isNotEmpty) {
        final fileId = list.files!.first.id!;
        print("DriveHelper: Found file $fileId, downloading...");
        final response = await driveApi.files.get(
          fileId, 
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
        
        final content = await utf8.decodeStream(response.stream);
        print("DriveHelper: Download success, content length: ${content.length}");
        return json.decode(content) as Map<String, dynamic>;
      } else {
        print("DriveHelper: No file found in appDataFolder");
      }
    } catch (e) {
      print("DriveHelper Download Error: $e");
    }
    return null;
  }
}
