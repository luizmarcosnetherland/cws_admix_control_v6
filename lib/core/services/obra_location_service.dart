import 'dart:io';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ObraLocationResult {
  final double latitude;
  final double longitude;
  final String descricao;

  const ObraLocationResult({
    required this.latitude,
    required this.longitude,
    required this.descricao,
  });
}

class ObraLocationService {
  Future<ObraLocationResult> obterLocalizacaoAtual() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Ative a localizacao do aparelho para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permissao de localizacao negada.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permissao de localizacao negada permanentemente. Libere nas configuracoes do aparelho.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final descricao = await _resolverDescricao(
      position.latitude,
      position.longitude,
    );

    return ObraLocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      descricao: descricao,
    );
  }

  Future<String> _resolverDescricao(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _fallbackDescricao(latitude, longitude);

      final p = placemarks.first;
      final parts =
          <String?>[
                p.street,
                p.subLocality,
                p.locality,
                p.administrativeArea,
                p.postalCode,
              ]
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      if (parts.isEmpty) return _fallbackDescricao(latitude, longitude);
      return parts.join(', ');
    } catch (_) {
      return _fallbackDescricao(latitude, longitude);
    }
  }

  String _fallbackDescricao(double latitude, double longitude) {
    return 'Lat ${latitude.toStringAsFixed(6)}, Lon ${longitude.toStringAsFixed(6)}';
  }

  String coordenadasLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  Future<void> abrirNoMapa({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final encodedLabel = Uri.encodeComponent(
      label?.trim().isNotEmpty == true ? label!.trim() : 'Obra',
    );
    if (Platform.isIOS) {
      final googleMapsUri = Uri.parse(
        'comgooglemaps://?q=$latitude,$longitude&center=$latitude,$longitude',
      );
      if (await canLaunchUrl(googleMapsUri)) {
        if (await launchUrl(
          googleMapsUri,
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      }

      final appleMapsUri = Uri.parse(
        'https://maps.apple.com/?ll=$latitude,$longitude&q=$encodedLabel',
      );
      if (await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication)) {
        return;
      }

      final webFallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
      if (await launchUrl(webFallback, mode: LaunchMode.externalApplication)) {
        return;
      }

      throw Exception('Nao foi possivel abrir o app de mapas.');
    }

    final uri = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
      if (!await launchUrl(fallback, mode: LaunchMode.externalApplication)) {
        throw Exception('Nao foi possivel abrir o app de mapas.');
      }
    }
  }
}
