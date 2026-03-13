import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalStorageService {
  Future<String> get rootPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'CWSadmixControl');
  }

  Future<String> get exportRootPath async {
    if (Platform.isAndroid || Platform.isIOS) {
      return p.join(await rootPath, 'exports');
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return p.join(downloadsDir.path, 'CWSadmixControl');
    }

    return p.join(await rootPath, 'exports');
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
