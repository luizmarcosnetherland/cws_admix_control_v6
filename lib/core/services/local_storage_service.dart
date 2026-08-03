import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalStorageService {
  static const _managedRootName = 'CWSadmixControl';
  String? _rootPathCache;
  String? _exportRootPathCache;

  Future<String> get rootPath async {
    final cached = _rootPathCache;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _managedRootName);
    _rootPathCache = path;
    return path;
  }

  Future<String> get exportRootPath async {
    final cached = _exportRootPathCache;
    if (cached != null) return cached;

    if (Platform.isAndroid || Platform.isIOS) {
      final path = p.join(await rootPath, 'exports');
      _exportRootPathCache = path;
      return path;
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      final path = p.join(downloadsDir.path, 'CWSadmixControl');
      _exportRootPathCache = path;
      return path;
    }

    final path = p.join(await rootPath, 'exports');
    _exportRootPathCache = path;
    return path;
  }

  Future<Directory> get rootDir async => Directory(await rootPath);
  Future<Directory> get exportsDir async => Directory(await exportRootPath);
  Future<Directory> get dataDir async =>
      Directory(p.join(await rootPath, 'data'));
  Future<Directory> get snapshotsDir async =>
      Directory(p.join(await rootPath, 'data', 'snapshots'));
  Future<Directory> get lancamentosPhotosRootDir async =>
      Directory(p.join(await rootPath, 'data', 'lancamentos_fotos'));
  Future<Directory> get concretagensRastreioRootDir async =>
      Directory(p.join(await rootPath, 'data', 'concretagens_rastreio'));

  Future<String> ensureBaseStructure() async {
    final root = await rootDir;
    final exports = await exportsDir;
    final data = await dataDir;
    final snapshots = await snapshotsDir;
    final photos = await lancamentosPhotosRootDir;
    final rastreio = await concretagensRastreioRootDir;

    await root.create(recursive: true);
    await exports.create(recursive: true);
    await data.create(recursive: true);
    await snapshots.create(recursive: true);
    await photos.create(recursive: true);
    await rastreio.create(recursive: true);
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

  Future<Directory> concretagemRastreioDir(
    int obraId,
    int concretagemId,
  ) async {
    final root = await concretagensRastreioRootDir;
    final dir = Directory(
      p.join(root.path, 'obra_$obraId', 'concretagem_$concretagemId'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Resolves a file stored inside the app-managed directory even when iOS
  /// changes the application container's absolute path between installations
  /// or updates.
  Future<String?> resolveManagedFilePath(String storedPath) async {
    final trimmed = storedPath.trim();
    if (trimmed.isEmpty) return null;

    final storedFile = File(trimmed);
    if (await storedFile.exists()) return storedFile.path;

    final normalized = p.normalize(trimmed);
    final parts = p.split(normalized);
    final rootIndex = parts.lastIndexOf(_managedRootName);
    if (rootIndex < 0 || rootIndex == parts.length - 1) return null;

    final relativeParts = parts.sublist(rootIndex + 1);
    final candidate = File(p.join(await rootPath, p.joinAll(relativeParts)));
    if (await candidate.exists()) return candidate.path;
    return null;
  }
}
