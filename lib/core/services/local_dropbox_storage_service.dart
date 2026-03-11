import 'dart:io';

import 'package:path/path.dart' as p;

class LocalDropboxStorageService {
  static const rootPath =
      '/Users/luizmarcosvahollanda/Library/CloudStorage/Dropbox/CWSadmixControl';

  Directory get rootDir => Directory(rootPath);
  Directory get exportsDir => Directory(p.join(rootPath, 'exports'));
  Directory get dataDir => Directory(p.join(rootPath, 'data'));
  Directory get snapshotsDir => Directory(p.join(rootPath, 'data', 'snapshots'));

  Future<void> ensureBaseStructure() async {
    await rootDir.create(recursive: true);
    await exportsDir.create(recursive: true);
    await dataDir.create(recursive: true);
    await snapshotsDir.create(recursive: true);
  }

  String exportFilePath(String filename) => p.join(exportsDir.path, filename);

  String dataFilePath(String filename) => p.join(dataDir.path, filename);

  String snapshotFilePath(String filename) => p.join(snapshotsDir.path, filename);
}
