import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centralisée des clés API pour l'application Deliver
class ApiConfig {
  // Configuration Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Configuration Google Maps
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Configuration Agora
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  // Backend (proxy + génération token Agora)
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  // Configuration PayDunya
  static String get payDunyaMasterKey => dotenv.env['PAYDUNYA_MASTER_KEY'] ?? '';
  static String get payDunyaPrivateKey =>
      dotenv.env['PAYDUNYA_PRIVATE_KEY'] ?? '';
  static String get payDunyaToken => dotenv.env['PAYDUNYA_TOKEN'] ?? '';
  static bool get payDunyaIsSandbox =>
      dotenv.env['PAYDUNYA_IS_SANDBOX']?.toLowerCase() == 'true';

  // Configuration de l'environnement
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static const bool debugMode = kDebugMode;

  // Configuration du restaurant
  static const double defaultRestaurantLat = 5.3600;
  static const double defaultRestaurantLng = -4.0080;
  static const String defaultRestaurantName = 'El Corazon';

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        googleMapsApiKey.isNotEmpty &&
        agoraAppId != 'YOUR_AGORA_APP_ID' &&
        payDunyaMasterKey != 'YOUR_PAYDUNYA_MASTER_KEY';
  }
}
