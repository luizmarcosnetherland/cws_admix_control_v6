import 'dart:io';

import 'package:path/path.dart' as p;

class LocalDropboxStorageService {
  Future<String> get rootPath async {
    if (Platform.isIOS) {
      final sandboxRoot = Directory.systemTemp.parent.path;
      return p.join(sandboxRoot, 'Documents', 'CWSadmixControl');
    }

    final home = _detectHomeDir();

    if (Platform.isMacOS) {
      return p.join(
        home,
        'Library',
        'CloudStorage',
        'Dropbox',
        'CWSadmixControl',
      );
    }

    return p.join(home, 'Dropbox', 'CWSadmixControl');
  }

  static String _detectHomeDir() {
    final envHome =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (envHome.isNotEmpty) return envHome;

    final currentPath = Directory.current.path;
    const marker = '/Library/Developer/';
    final idx = currentPath.indexOf(marker);
    if (idx > 0) {
      return currentPath.substring(0, idx);
    }

    return '';
  }

  Future<Directory> get rootDir async => Directory(await rootPath);
  Future<Directory> get exportsDir async =>
      Directory(p.join(await rootPath, 'exports'));
  Future<Directory> get dataDir async =>
      Directory(p.join(await rootPath, 'data'));
  Future<Directory> get snapshotsDir async =>
      Directory(p.join(await rootPath, 'data', 'snapshots'));

  Future<String> ensureBaseStructure() async {
    final root = await rootDir;
    final exports = await exportsDir;
    final data = await dataDir;
    final snapshots = await snapshotsDir;

    await root.create(recursive: true);
    await exports.create(recursive: true);
    await data.create(recursive: true);
    await snapshots.create(recursive: true);
    return root.path;
  }

  Future<String> exportFilePath(String filename) async {
    final dir = await exportsDir;
    return p.join(dir.path, filename);
  }

  Future<String> dataFilePath(String filename) async {
    final dir = await dataDir;
    return p.join(dir.path, filename);
  }

  Future<String> snapshotFilePath(String filename) async {
    final dir = await snapshotsDir;
    return p.join(dir.path, filename);
  }
}
