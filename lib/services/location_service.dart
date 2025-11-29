import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// 📍 Serviço de Localização GPS
class LocationService {
  /// Verificar se o serviço de localização está habilitado
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Verificar status da permissão de localização
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Solicitar permissão de localização
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Obter posição atual do dispositivo
  static Future<Position?> getCurrentPosition() async {
    try {
      debugPrint('📍 [LocationService] Verificando permissões...');

      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ [LocationService] Serviço de localização desabilitado');
        throw Exception('Serviço de localização desabilitado. Ative o GPS nas configurações.');
      }

      // Verificar permissão
      LocationPermission permission = await checkPermission();
      debugPrint('📍 [LocationService] Permissão atual: $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('📍 [LocationService] Solicitando permissão...');
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ [LocationService] Permissão negada');
          throw Exception('Permissão de localização negada');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ [LocationService] Permissão negada permanentemente');
        throw Exception(
          'Permissão de localização negada permanentemente. '
          'Ative nas configurações do aplicativo.',
        );
      }

      // Obter posição atual
      debugPrint('📍 [LocationService] Obtendo posição atual...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      debugPrint('✅ [LocationService] Posição obtida: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ [LocationService] Erro ao obter posição: $e');
      rethrow;
    }
  }

  /// Obter endereço a partir de coordenadas (geocodificação reversa)
  static Future<Map<String, String>?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint('📍 [LocationService] Obtendo endereço de: $latitude, $longitude');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        debugPrint('❌ [LocationService] Nenhum endereço encontrado');
        return null;
      }

      Placemark place = placemarks.first;
      debugPrint('✅ [LocationService] Endereço encontrado: ${place.street}');

      // Montar objeto de endereço
      final address = {
        'street': place.street ?? place.thoroughfare ?? '',
        'number': place.subThoroughfare ?? '',
        'neighborhood': place.subLocality ?? '',
        'city': place.subAdministrativeArea ?? place.locality ?? '',
        'state': place.administrativeArea ?? '',
        'zipCode': place.postalCode ?? '',
        'country': place.country ?? '',
      };

      debugPrint('📍 [LocationService] Endereço completo: $address');
      return address;
    } catch (e) {
      debugPrint('❌ [LocationService] Erro ao obter endereço: $e');
      rethrow;
    }
  }

  /// Obter endereço atual do usuário (GPS + Geocoding reverso)
  static Future<Map<String, String>?> getCurrentAddress() async {
    try {
      debugPrint('📍 [LocationService] Obtendo endereço atual...');

      // 1. Obter posição GPS
      Position? position = await getCurrentPosition();
      if (position == null) {
        debugPrint('❌ [LocationService] Posição não obtida');
        return null;
      }

      // 2. Converter coordenadas em endereço
      Map<String, String>? address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (address == null) {
        debugPrint('❌ [LocationService] Endereço não encontrado');
        return null;
      }

      debugPrint('✅ [LocationService] Endereço atual obtido com sucesso!');
      return address;
    } catch (e) {
      debugPrint('❌ [LocationService] Erro ao obter endereço atual: $e');
      rethrow;
    }
  }

  /// Calcular distância entre dois pontos (em metros)
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
