import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalDropboxStorageService {
  Future<String> get rootPath async {
    if (Platform.isAndroid) {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, 'CWSadmixControl');
    }

    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, 'CWSadmixControl');
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

  Future<String> get exportRootPath async {
    if (Platform.isAndroid || Platform.isIOS) {
      return p.join(await rootPath, 'Downloads');
    }

    final home = _detectHomeDir();

    if (Platform.isMacOS) {
      return p.join(
        home,
        'Library',
        'CloudStorage',
        'Dropbox',
        'Downloads',
        'CWSadmixControl',
      );
    }

    return p.join(home, 'Dropbox', 'Downloads', 'CWSadmixControl');
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
  Future<Directory> get exportsDir async => Directory(await exportRootPath);
  Future<Directory> get dataDir async =>
      Directory(p.join(await rootPath, 'data'));
  Future<Directory> get snapshotsDir async =>
      Directory(p.join(await rootPath, 'data', 'snapshots'));
  Future<Directory> get lancamentosPhotosRootDir async =>
      Directory(p.join(await rootPath, 'data', 'lancamentos_fotos'));

  Future<String> ensureBaseStructure() async {
    final root = await rootDir;
    final exports = await exportsDir;
    final data = await dataDir;
    final snapshots = await snapshotsDir;
    final photos = await lancamentosPhotosRootDir;

    await root.create(recursive: true);
    await exports.create(recursive: true);
    await data.create(recursive: true);
    await snapshots.create(recursive: true);
    await photos.create(recursive: true);
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

  Future<Directory> lancamentoPhotosDir(int obraId) async {
    final root = await lancamentosPhotosRootDir;
    final dir = Directory(p.join(root.path, 'obra_$obraId'));
    await dir.create(recursive: true);
    return dir;
  }
}
