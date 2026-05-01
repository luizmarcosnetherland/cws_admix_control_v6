import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class NotaFiscalOcrService {
  static const limiteCargaDescarga = Duration(minutes: 150);

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<NotaFiscalOcrResult> processarImagem(
    File imagem, {
    required DateTime dataHoraDescarga,
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'OCR de nota fiscal disponivel apenas em Android e iOS.',
      );
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await recognizer.processImage(
        InputImage.fromFile(imagem),
      );
      return parseText(recognizedText.text, dataHoraDescarga: dataHoraDescarga);
    } finally {
      await recognizer.close();
    }
  }

  static NotaFiscalOcrResult parseText(
    String rawText, {
    required DateTime dataHoraDescarga,
  }) {
    final text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text
        .split('\n')
        .map(_collapseSpaces)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final horarioCarregamento = _extractHorarioCarregamento(
      lines,
      dataHoraDescarga,
    );
    final intervalo = horarioCarregamento == null
        ? null
        : dataHoraDescarga.difference(horarioCarregamento);

    return NotaFiscalOcrResult(
      textoOriginal: rawText,
      numeroNotaFiscal: _extractNumeroNotaFiscal(lines),
      volumeM3: _extractVolume(lines),
      lacre: _extractLacre(lines),
      betoneira: _extractBetoneira(lines),
      traco: _extractTraco(lines),
      horarioCarregamento: horarioCarregamento,
      intervaloCargaDescarga: intervalo == null || intervalo.isNegative
          ? null
          : intervalo,
    );
  }

  static String? _extractNumeroNotaFiscal(List<String> lines) {
    final patterns = [
      RegExp(
        r'\b(?:nf\s*-?\s*e?|nfe|nota\s*fiscal)\D{0,24}([0-9][0-9.\-/ ]{2,18})',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:n[ºo°.]|numero)\s*(?:da\s*)?(?:nf\s*-?\s*e?|nota\s*fiscal)\D{0,16}([0-9][0-9.\-/ ]{2,18})',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:nf\s*-?\s*e?|nfe)\s*(?:n[ºo°.]|numero)?\D{0,12}([0-9][0-9.\-/ ]{2,18})',
        caseSensitive: false,
      ),
    ];

    final windowPatterns = [
      RegExp(
        r'\b(?:nf\s*-?\s*e?|nfe|danfe)\b.{0,90}\b(?:n\s*[ºo°.]?|n[uú]mero|numero)\s*[:\-]?\s*([0-9][0-9.\-/ ]{2,18})',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:n\s*[ºo°.]?|n[uú]mero|numero)\s*[:\-]?\s*([0-9][0-9.\-/ ]{2,18}).{0,36}\bs[ée]rie\b',
        caseSensitive: false,
      ),
    ];

    for (final line in lines) {
      if (!RegExp(
        r'\b(?:nf|nfe|nota\s*fiscal|danfe)\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }

      for (final pattern in patterns) {
        final normalized = _normalizedIdFromFirstMatch(line, pattern);
        if (_isLikelyNotaFiscal(normalized)) return normalized;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final window = _lineWindow(lines, i, 3);
      if (!RegExp(
        r'\b(?:nf\s*-?\s*e?|nfe|nota\s*fiscal|danfe)\b',
        caseSensitive: false,
      ).hasMatch(window)) {
        continue;
      }

      for (final pattern in windowPatterns) {
        final normalized = _normalizedIdFromFirstMatch(window, pattern);
        if (_isLikelyNotaFiscal(normalized)) return normalized;
      }
    }

    return null;
  }

  static double? _extractVolume(List<String> lines) {
    final labelPattern = RegExp(
      r'\b(?:volume|vol\.?|quantidade|qtd\.?)\s*(?:de\s*)?(?:concreto)?\D{0,22}([0-9]{1,3}(?:[,.][0-9]{1,2})?)\s*(?:m\s*[3³])?',
      caseSensitive: false,
    );
    final unitPattern = RegExp(
      r'\b([0-9]{1,3}(?:[,.][0-9]{1,2})?)\s*m\s*[3³]\b',
      caseSensitive: false,
    );
    final reversedUnitPattern = RegExp(
      r'\bm\s*[3³]\s+([0-9]{1,3}(?:[,.][0-9]{1,2})?)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!(lower.contains('volume') ||
          lower.contains('vol') ||
          lower.contains('concreto') ||
          lower.contains('m3') ||
          lower.contains('m³'))) {
        continue;
      }
      if (_isIgnoredVolumeContext(lower)) continue;

      final byLabel = _validVolume(_parseDecimalFromMatch(line, labelPattern));
      if (byLabel != null) return byLabel;

      final byUnit = _validVolume(_parseDecimalFromMatch(line, unitPattern));
      if (byUnit != null) return byUnit;

      final byReversedUnit = _validVolume(
        _parseDecimalFromMatch(line, reversedUnitPattern),
      );
      if (byReversedUnit != null) return byReversedUnit;
    }

    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (!(lower.contains('volume') ||
          lower.contains('quantidade') ||
          lower.contains('qtd') ||
          lower.contains('m3') ||
          lower.contains('m³'))) {
        continue;
      }
      if (_isIgnoredVolumeContext(lower)) continue;

      final window = _lineWindow(lines, i, 3);
      final byLabel = _validVolume(
        _parseDecimalFromMatch(window, labelPattern),
      );
      if (byLabel != null) return byLabel;

      final byUnit = _validVolume(_parseDecimalFromMatch(window, unitPattern));
      if (byUnit != null) return byUnit;

      final byReversedUnit = _validVolume(
        _parseDecimalFromMatch(window, reversedUnitPattern),
      );
      if (byReversedUnit != null) return byReversedUnit;
    }

    return null;
  }

  static String? _extractLacre(List<String> lines) {
    final pattern = RegExp(
      r'\blacre(?:\s*(?:n[ºo°.]|numero))?\s*[:\-]?\s*([A-Z0-9][A-Z0-9\-/.]{1,24})',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.toLowerCase().contains('lacre')) continue;
      final match = pattern.firstMatch(line);
      final value = match == null ? null : _cleanLabelValue(match.group(1));
      if (_isLikelyIdentifier(value)) return value;

      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        final nextValue = _firstIdentifierValue(lines[j]);
        if (_isLikelyIdentifier(nextValue)) return nextValue;
      }
    }

    return null;
  }

  static String? _extractBetoneira(List<String> lines) {
    final pattern = RegExp(
      r'\bbetoneira\s*[:\-]?\s*([A-Z]{0,4}\s*[0-9][0-9A-Z]{1,8})\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.toLowerCase().contains('betoneira')) continue;

      final match = pattern.firstMatch(line);
      final value = match == null
          ? null
          : _normalizeVehicleCode(match.group(1));
      if (_isLikelyIdentifier(value)) return value;

      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        final nextValue = _firstBetoneiraValue(lines[j]);
        if (_isLikelyIdentifier(nextValue)) return nextValue;
      }
    }

    return null;
  }

  static String? _extractTraco(List<String> lines) {
    final concreteTrace = _extractConcreteTrace(lines);
    if (concreteTrace != null) return concreteTrace;

    final label = RegExp(
      r'(?:tra[cç]o|fck|receita|mix|descri[cç][aã]o\s+do\s+produto)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!label.hasMatch(line)) continue;

      var value = line.replaceFirst(
        RegExp(
          r'^.*?(?:tra[cç]o|fck|receita|mix|produto|descri[cç][aã]o\s+do\s+produto)\s*[:\-]?\s*',
          caseSensitive: false,
        ),
        '',
      );
      value = _trimNextKnownLabel(value);

      if (value.trim().isEmpty && i + 1 < lines.length) {
        value = _trimNextKnownLabel(lines[i + 1]);
      }

      final cleaned = _cleanLabelValue(value);
      if (cleaned != null && cleaned.length >= 2) return cleaned;
    }

    return null;
  }

  static DateTime? _extractHorarioCarregamento(
    List<String> lines,
    DateTime dataHoraDescarga,
  ) {
    final patterns = [
      RegExp(
        r'(?:hor[aá]rio|hora|hr)\s*(?:de\s*)?(?:carregamento|carga|sa[ií]da|expedi[cç][aã]o)\D{0,28}([0-9]{1,2}\s*[:h]\s*[0-9]{2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:carregamento|carga|sa[ií]da|expedi[cç][aã]o)\D{0,28}([0-9]{1,2}\s*[:h]\s*[0-9]{2})',
        caseSensitive: false,
      ),
    ];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!RegExp(
        r'(?:carregamento|carga|sa[ií]da|expedi[cç][aã]o)',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }

      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;
        final time = _parseHourMinute(match.group(1)!);
        if (time == null) continue;

        final date =
            _extractDate(line) ??
            (i > 0 ? _extractDate(lines[i - 1]) : null) ??
            (i + 1 < lines.length ? _extractDate(lines[i + 1]) : null);

        return _composeCargaDateTime(
          date: date,
          hour: time.$1,
          minute: time.$2,
          dataHoraDescarga: dataHoraDescarga,
        );
      }

      final nearbyTime = _extractNearbyTime(lines, i);
      if (nearbyTime == null) continue;

      final date = _extractNearbyDate(lines, i);
      return _composeCargaDateTime(
        date: date,
        hour: nearbyTime.$1,
        minute: nearbyTime.$2,
        dataHoraDescarga: dataHoraDescarga,
      );
    }

    return null;
  }

  static DateTime _composeCargaDateTime({
    required _ParsedDate? date,
    required int hour,
    required int minute,
    required DateTime dataHoraDescarga,
  }) {
    var carga = date == null
        ? DateTime(
            dataHoraDescarga.year,
            dataHoraDescarga.month,
            dataHoraDescarga.day,
            hour,
            minute,
          )
        : DateTime(date.year, date.month, date.day, hour, minute);

    if (date == null &&
        carga.isAfter(dataHoraDescarga) &&
        carga.difference(dataHoraDescarga) > const Duration(hours: 12)) {
      carga = carga.subtract(const Duration(days: 1));
    }

    return carga;
  }

  static _ParsedDate? _extractDate(String line) {
    final match = RegExp(
      r'\b([0-9]{1,2})[/-]([0-9]{1,2})[/-]([0-9]{2,4})\b',
    ).firstMatch(line);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += year >= 70 ? 1900 : 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return _ParsedDate(day: day, month: month, year: year);
  }

  static (int, int)? _parseHourMinute(String raw) {
    final normalized = raw
        .toLowerCase()
        .replaceAll('h', ':')
        .replaceAll(RegExp(r'\s+'), '');
    final parts = normalized.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  static (int, int)? _extractNearbyTime(List<String> lines, int index) {
    final start = index < 1 ? 0 : index - 1;
    final end = index + 3 > lines.length ? lines.length : index + 3;
    for (var i = index; i < end; i++) {
      final time = _extractTimeFromLine(lines[i]);
      if (time != null) return time;
    }
    for (var i = start; i < index; i++) {
      final time = _extractTimeFromLine(lines[i]);
      if (time != null) return time;
    }
    return null;
  }

  static (int, int)? _extractTimeFromLine(String line) {
    final match = RegExp(
      r'\b([0-9]{1,2}\s*[:h]\s*[0-9]{2})\b',
    ).firstMatch(line);
    if (match == null) return null;
    return _parseHourMinute(match.group(1)!);
  }

  static _ParsedDate? _extractNearbyDate(List<String> lines, int index) {
    final start = index < 3 ? 0 : index - 3;
    final end = index + 3 > lines.length ? lines.length : index + 3;
    for (var i = index; i >= start; i--) {
      final date = _extractDate(lines[i]);
      if (date != null) return date;
    }
    for (var i = index + 1; i < end; i++) {
      final date = _extractDate(lines[i]);
      if (date != null) return date;
    }
    return null;
  }

  static String? _normalizedIdFromFirstMatch(String line, RegExp pattern) {
    final match = pattern.firstMatch(line);
    if (match == null) return null;
    return _normalizeIdentifier(match.group(1));
  }

  static bool _isLikelyNotaFiscal(String? value) {
    if (value == null) return false;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 3 && digits.length <= 12;
  }

  static double? _validVolume(double? value) {
    if (value == null || value <= 0 || value > 100) return null;
    return value;
  }

  static bool _isIgnoredVolumeContext(String lower) {
    return lower.contains('valor') ||
        lower.contains('volume total entregue') ||
        lower.contains('cimento') ||
        lower.contains('areia') ||
        lower.contains('aditivo') ||
        lower.contains('agua') ||
        lower.contains('água');
  }

  static double? _parseDecimalFromMatch(String line, RegExp pattern) {
    final match = pattern.firstMatch(line);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static String? _normalizeIdentifier(String? value) {
    if (value == null) return null;
    final cleaned = value
        .replaceAll(RegExp(r'[^0-9A-Za-z/\-.]'), '')
        .replaceAll(RegExp(r'^[.\-/]+|[.\-/]+$'), '');
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  static bool _isLikelyIdentifier(String? value) {
    if (value == null) return false;
    final cleaned = value.trim();
    return cleaned.length >= 2 && RegExp(r'[0-9]').hasMatch(cleaned);
  }

  static String? _firstIdentifierValue(String line) {
    final match = RegExp(
      r'\b([A-Z0-9][A-Z0-9\-/.]{1,24})\b',
      caseSensitive: false,
    ).firstMatch(line);
    return _cleanLabelValue(match?.group(1));
  }

  static String? _firstBetoneiraValue(String line) {
    final match = RegExp(
      r'\b([A-Z]{0,4}\s*[0-9][0-9A-Z]{1,8})\b',
      caseSensitive: false,
    ).firstMatch(line);
    return _normalizeVehicleCode(match?.group(1));
  }

  static String? _normalizeVehicleCode(String? value) {
    final cleaned = _cleanLabelValue(value)?.toUpperCase();
    if (cleaned == null) return null;

    final match = RegExp(
      r'^([A-Z]{1,4})\s*([0-9][0-9A-Z]{1,8})$',
    ).firstMatch(cleaned);
    if (match == null) return cleaned;
    return '${match.group(1)} ${match.group(2)}';
  }

  static String? _extractConcreteTrace(List<String> lines) {
    final traceLine = RegExp(
      r'\b(?:fck|slump|brita|resist[eê]ncia)\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (!traceLine.hasMatch(lines[i])) continue;

      final window = _lineWindow(lines, i, 3);
      final parts = <String>[];

      final fck = _extractFck(window);
      if (fck != null) parts.add('FCK $fck MPa');

      final slump = _extractSlump(window);
      if (slump != null) parts.add('Slump $slump');

      final brita = _extractBrita(window);
      if (brita != null) parts.add('Brita $brita');

      if (parts.isEmpty) continue;
      if (parts.length == 1 &&
          fck != null &&
          !RegExp(
            r'\b(?:slump|brita|resist[eê]ncia)\b',
            caseSensitive: false,
          ).hasMatch(window)) {
        continue;
      }
      return parts.join('; ');
    }

    return null;
  }

  static String? _extractFck(String text) {
    final fckMatch = RegExp(
      r'\bfck\b(?:\s*\(?\s*m\s*p?a?\s*\)?)?\s*[:\-]?\s*([0-9]{1,3}(?:[,.][0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (fckMatch != null) return _normalizeDecimalText(fckMatch.group(1)!);

    final resistenciaMatch = RegExp(
      r'\bresist[eê]ncia(?:\s+caracter[ií]stica)?\D{0,36}([0-9]{1,3}(?:[,.][0-9]{1,2})?)\s*m\s*p?a?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (resistenciaMatch == null) return null;
    return _normalizeDecimalText(resistenciaMatch.group(1)!);
  }

  static String? _extractSlump(String text) {
    final match = RegExp(
      r'\bslump\s*[:\-]?\s*([0-9]{1,3}\s*(?:[±+/\-]\s*[0-9]{1,3})?\s*(?:mm|cm)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final value = _collapseSpaces(
      match.group(1)!.replaceAll(RegExp(r'\s*±\s*'), '±'),
    );
    if (value.toLowerCase().endsWith('mm') ||
        value.toLowerCase().endsWith('cm')) {
      return value;
    }
    return '$value mm';
  }

  static String? _extractBrita(String text) {
    final match = RegExp(
      r'\bbrita\s*[:\-]?\s*(?:brita\s*)?([0-9A-Za-z][0-9A-Za-z +./\-]{0,18}?)(?=\s+(?:volume|adic|adicionais|bomba|taxa|m3|m³|pe[cç]a|$)|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    return _collapseSpaces(
      match.group(1)!.replaceAll(RegExp(r'\s*\+\s*'), ' + '),
    );
  }

  static String _normalizeDecimalText(String value) {
    final normalized = value.replaceAll('.', ',');
    return normalized.endsWith(',0')
        ? normalized.substring(0, normalized.length - 2)
        : normalized;
  }

  static String? _cleanLabelValue(String? value) {
    if (value == null) return null;
    final cleaned = _collapseSpaces(
      value
          .replaceAll(RegExp(r'^[\s:;\-–—]+'), '')
          .replaceAll(RegExp(r'[\s:;\-–—]+$'), ''),
    );
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _trimNextKnownLabel(String value) {
    final cleaned = _collapseSpaces(value);
    final match = RegExp(
      r'\b(?:nf|nota\s*fiscal|lacre|betoneira|volume|hor[aá]rio|hora|carregamento|carga|peso|valor|data)\b',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (match != null && match.start > 2) {
      return cleaned.substring(0, match.start).trim();
    }
    return cleaned;
  }

  static String _collapseSpaces(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _lineWindow(List<String> lines, int start, int count) {
    final end = start + count > lines.length ? lines.length : start + count;
    return _collapseSpaces(lines.sublist(start, end).join(' '));
  }
}

class NotaFiscalOcrResult {
  final String textoOriginal;
  final String? numeroNotaFiscal;
  final double? volumeM3;
  final String? lacre;
  final String? betoneira;
  final String? traco;
  final DateTime? horarioCarregamento;
  final Duration? intervaloCargaDescarga;

  const NotaFiscalOcrResult({
    required this.textoOriginal,
    this.numeroNotaFiscal,
    this.volumeM3,
    this.lacre,
    this.betoneira,
    this.traco,
    this.horarioCarregamento,
    this.intervaloCargaDescarga,
  });

  bool get hasStructuredData =>
      numeroNotaFiscal != null ||
      volumeM3 != null ||
      lacre != null ||
      betoneira != null ||
      traco != null ||
      horarioCarregamento != null;

  bool get cargaDescargaAcimaDoLimite {
    final intervalo = intervaloCargaDescarga;
    return intervalo != null &&
        intervalo > NotaFiscalOcrService.limiteCargaDescarga;
  }
}

class _ParsedDate {
  final int day;
  final int month;
  final int year;

  const _ParsedDate({
    required this.day,
    required this.month,
    required this.year,
  });
}
