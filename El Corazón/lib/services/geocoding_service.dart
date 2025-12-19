import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/config/api_config.dart';
import 'package:elcora_fast/services/rest_client.dart';

class GeocodingService extends ChangeNotifier {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // Cache pour éviter les appels répétés
  final Map<String, LatLng> _addressCache = {};
  final RestClient _rest = const RestClient();

  /// Convertit une adresse en coordonnées latitude/longitude
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final raw = address.trim();
      if (raw.isEmpty) {
        debugPrint('GeocodingService: adresse vide, skip');
        return null;
      }
      // Vérifier le cache d'abord
      if (_addressCache.containsKey(address)) {
        return _addressCache[address];
      }

      // Utiliser l'API de géocodage de Google
      final String apiKey = ApiConfig.googleMapsApiKey;
      final uri = kIsWeb
          ? Uri.parse('${ApiConfig.backendUrl}/api/google/geocode').replace(
              queryParameters: {
                // Ne pas pré-encoder quand on utilise queryParameters
                'address': raw,
                'key': apiKey,
              },
            )
          : Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
              'address': raw,
              'key': apiKey,
            });

      final data = await _rest.getJson(uri);

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final firstResult =
            (data['results'] as List).first as Map<String, dynamic>;
        final location = firstResult['geometry'] as Map<String, dynamic>;
        final latLng = LatLng(
          (location['lat'] as num).toDouble(),
          (location['lng'] as num).toDouble(),
        );

        // Mettre en cache le résultat
        _addressCache[address] = latLng;

        debugPrint(
          'GeocodingService: Adresse géocodée - $address -> $latLng',
        );
        return latLng;
      } else {
        debugPrint(
          'GeocodingService: Aucun résultat trouvé pour cette adresse (${data['status']})',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de géocodage - $e');
      return null;
    }
  }

  /// Convertit des coordonnées en adresse (géocodage inverse)
  Future<String?> reverseGeocode(LatLng coordinates) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      final uri = kIsWeb
          ? Uri.parse('${ApiConfig.backendUrl}/api/google/geocode').replace(
              queryParameters: {
                'latlng': '${coordinates.latitude},${coordinates.longitude}',
                'key': apiKey,
              },
            )
          : Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
              'latlng': '${coordinates.latitude},${coordinates.longitude}',
              'key': apiKey,
            });

      final data = await _rest.getJson(uri);

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final results = data['results'] as List;
        final firstResult = results.first as Map<String, dynamic>;
        final address = firstResult['formatted_address'] as String;
        debugPrint(
          'GeocodingService: Coordonnées inversées - $coordinates -> $address',
        );
        return address;
      } else {
        debugPrint(
          'GeocodingService: Erreur de géocodage inverse - ${data['status']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de géocodage inverse - $e');
      return null;
    }
  }

  /// Calcule la distance entre deux points en kilomètres
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    final double lat1Rad = point1.latitude * (3.14159265359 / 180);
    final double lat2Rad = point2.latitude * (3.14159265359 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  /// Calcule le temps de trajet estimé en minutes
  Future<int?> calculateTravelTime(LatLng origin, LatLng destination) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      final uri = kIsWeb
          ? Uri.parse('${ApiConfig.backendUrl}/api/google/distance-matrix')
              .replace(
              queryParameters: {
                'origins': '${origin.latitude},${origin.longitude}',
                'destinations':
                    '${destination.latitude},${destination.longitude}',
                'mode': 'driving',
                'key': apiKey,
              },
            )
          : Uri.https('maps.googleapis.com', '/maps/api/distancematrix/json', {
              'origins': '${origin.latitude},${origin.longitude}',
              'destinations':
                  '${destination.latitude},${destination.longitude}',
              'mode': 'driving',
              'key': apiKey,
            });

      final data = await _rest.getJson(uri);

      if (data['status'] == 'OK' && (data['rows'] as List).isNotEmpty) {
        final rows = data['rows'] as List;
        final firstRow = rows.first as Map<String, dynamic>;
        final elements = firstRow['elements'] as List;
        final firstElement = elements[0] as Map<String, dynamic>;
        final duration =
            ((firstElement['duration'] as Map<String, dynamic>)['value'] as num)
                .toInt(); // en secondes
        final minutes = (duration / 60).round();
        debugPrint(
          'GeocodingService: Temps de trajet calculé - $minutes minutes',
        );
        return minutes;
      } else {
        debugPrint(
          'GeocodingService: Erreur de calcul de temps - ${data['status']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de calcul de temps - $e');
      return null;
    }
  }

  /// Obtient les directions entre deux points
  Future<List<LatLng>?> getDirections(LatLng origin, LatLng destination) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      final uri = kIsWeb
          ? Uri.parse('${ApiConfig.backendUrl}/api/google/directions').replace(
              queryParameters: {
                'origin': '${origin.latitude},${origin.longitude}',
                'destination':
                    '${destination.latitude},${destination.longitude}',
                'key': apiKey,
              },
            )
          : Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
              'origin': '${origin.latitude},${origin.longitude}',
              'destination': '${destination.latitude},${destination.longitude}',
              'key': apiKey,
            });

      final data = await _rest.getJson(uri);

      if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
        final routes = data['routes'] as List;
        final route = routes.first as Map<String, dynamic>;
        final legs = route['legs'] as List;
        final List<LatLng> points = [];

        for (final legItem in legs) {
          final leg = legItem as Map<String, dynamic>;
          final steps = leg['steps'] as List;
          for (final stepItem in steps) {
            final step = stepItem as Map<String, dynamic>;
            final startLocation =
                step['start_location'] as Map<String, dynamic>;
            points.add(
              LatLng(
                (startLocation['lat'] as num).toDouble(),
                (startLocation['lng'] as num).toDouble(),
              ),
            );
          }
        }

        // Ajouter le point final
        final lastLeg = legs.last as Map<String, dynamic>;
        final endLocation = lastLeg['end_location'] as Map<String, dynamic>;
        points.add(
          LatLng(
            (endLocation['lat'] as num).toDouble(),
            (endLocation['lng'] as num).toDouble(),
          ),
        );

        debugPrint(
          'GeocodingService: Directions obtenues - ${points.length} points',
        );
        return points;
      } else {
        debugPrint(
          'GeocodingService: Erreur de directions - ${data['status']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Erreur de directions - $e');
      return null;
    }
  }

  /// Vide le cache de géocodage
  void clearCache() {
    _addressCache.clear();
    debugPrint('GeocodingService: Cache vidé');
  }
}
