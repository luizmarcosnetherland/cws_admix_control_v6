import 'dart:convert';
import 'package:http/http.dart' as http;

class DropboxApiException implements Exception {
  final String operation;
  final int statusCode;
  final String body;
  final String? path;

  DropboxApiException({
    required this.operation,
    required this.statusCode,
    required this.body,
    this.path,
  });

  @override
  String toString() {
    final target = path == null ? '' : ' [$path]';
    return 'DropboxApiException($operation$target): HTTP $statusCode $body';
  }
}

class DropboxApi {
  final String accessToken;
  DropboxApi(this.accessToken);

  Map<String, String> get _jsonHeaders => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  Future<void> createFolder(String path) async {
    final res = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/create_folder_v2'),
      headers: _jsonHeaders,
      body: jsonEncode({'path': path, 'autorename': false}),
    );
    if (res.statusCode == 200) return;

    if (res.statusCode == 409 && _isAlreadyExistsConflict(res.body)) {
      return;
    }

    throw DropboxApiException(
      operation: 'createFolder',
      statusCode: res.statusCode,
      body: res.body,
      path: path,
    );
  }

  bool _isAlreadyExistsConflict(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return false;
      final errorSummary = decoded['error_summary']?.toString() ?? '';
      if (errorSummary.contains('conflict/folder')) return true;

      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final path = error['path'];
        if (path is Map<String, dynamic> &&
            path['.tag']?.toString() == 'conflict') {
          final conflict = path['conflict'];
          if (conflict is Map<String, dynamic> &&
              conflict['.tag']?.toString() == 'folder') {
            return true;
          }
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<void> uploadBytes({
    required String dropboxPath,
    required List<int> bytes,
    bool overwrite = true,
  }) async {
    final arg = {
      'path': dropboxPath,
      'mode': overwrite ? 'overwrite' : 'add',
      'autorename': true,
      'mute': false,
    };

    final res = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/upload'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode(arg),
      },
      body: bytes,
    );

    if (res.statusCode != 200) {
      throw DropboxApiException(
        operation: 'uploadBytes',
        statusCode: res.statusCode,
        body: res.body,
        path: dropboxPath,
      );
    }
  }
}
