import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/directions_service.dart';
import '../../services/geocoding_service.dart' as geocoding;
import '../../config/api_config.dart';
import '../../models/order.dart';
import '../../widgets/loading_widget.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';
import '../../ui/ui.dart';

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: scheme.onSurface, size: 22),
          ),
        ),
      ),
    );
  }
}

class RealTimeTrackingScreen extends StatefulWidget {
  final Order order;

  const RealTimeTrackingScreen({
    super.key,
    required this.order,
  });

  @override
  State<RealTimeTrackingScreen> createState() => _RealTimeTrackingScreenState();
}

class _RealTimeTrackingScreenState extends State<RealTimeTrackingScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _lastRoutePoints = const [];

  LatLng? _driverLocation;
  LatLng? _customerLocation;
  LatLng? _restaurantLocation;

  bool _isTracking = false;
  bool _isLoading = true;
  bool _isCalculatingRoute = false;
  String _estimatedTime = 'Calcul en cours...';
  double _estimatedDistance = 0.0;

  StreamSubscription<Position>? _positionSubscription;
  final DirectionsService _directionsService = DirectionsService();
  final geocoding.GeocodingService _geocodingService =
      geocoding.GeocodingService();

  // Dernière position pour éviter trop de recalculs
  LatLng? _lastCalculatedPosition;
  DateTime? _lastCalculationTime;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    if (!mounted || !context.mounted) return;

    try {
      // Get current driver location with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: Impossible de récupérer la position');
        },
      );

      if (!mounted || !context.mounted) return;

      _driverLocation = LatLng(position.latitude, position.longitude);

      // 1) Client: préférer les coordonnées stockées sur la commande (si disponibles)
      if (widget.order.deliveryLatitude != null &&
          widget.order.deliveryLongitude != null) {
        _customerLocation = LatLng(
          widget.order.deliveryLatitude!,
          widget.order.deliveryLongitude!,
        );
        debugPrint(
            '✅ Coordonnées client depuis la commande: $_customerLocation');
      } else {
        // 2) Fallback: géocoder l'adresse
        try {
          final customerLatLng = await _geocodingService.geocodeAddress(
            widget.order.deliveryAddress,
          );

          if (customerLatLng != null) {
            // Convertir geocoding.LatLng en google_maps_flutter.LatLng
            _customerLocation =
                LatLng(customerLatLng.latitude, customerLatLng.longitude);
            debugPrint('✅ Coordonnées client géocodées: $_customerLocation');
          } else {
            _customerLocation = const LatLng(
              ApiConfig.defaultRestaurantLat,
              ApiConfig.defaultRestaurantLng,
            );
            debugPrint('⚠️ Géocodage KO, coords défaut pour le client');
          }
        } catch (e) {
          debugPrint('❌ Erreur géocodage adresse client: $e');
          _customerLocation = const LatLng(
            ApiConfig.defaultRestaurantLat,
            ApiConfig.defaultRestaurantLng,
          );
        }
      }

      // Restaurant: préférer les coords stockées sur la commande (si disponibles)
      if (widget.order.restaurantLatitude != null &&
          widget.order.restaurantLongitude != null) {
        _restaurantLocation = LatLng(
          widget.order.restaurantLatitude!,
          widget.order.restaurantLongitude!,
        );
        debugPrint(
          '✅ Coordonnées restaurant depuis la commande: $_restaurantLocation',
        );
      } else {
        _restaurantLocation = const LatLng(
          ApiConfig.defaultRestaurantLat,
          ApiConfig.defaultRestaurantLng,
        );
        debugPrint('ℹ️ Restaurant: coords défaut (ApiConfig)');
      }

      // Start tracking
      if (!mounted || !context.mounted) return;
      await _startTracking();

      // Calculate route and ETA
      if (!mounted || !context.mounted) return;
      await _calculateRoute();

      if (!mounted || !context.mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || !context.mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'initialisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startTracking() async {
    if (_isTracking || !mounted) return;

    setState(() => _isTracking = true);

    // Start position stream
    final positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );

    _positionSubscription = positionStream.listen(
      (Position position) async {
        if (!mounted) return;

        _driverLocation = LatLng(position.latitude, position.longitude);

        // Update map
        if (_mapController != null && mounted) {
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newLatLng(_driverLocation!),
            );
          } catch (e) {
            debugPrint('Error updating camera: $e');
          }
        }

        // Update markers
        if (mounted) {
          _updateMarkers();
        }

        // Send location to backend
        try {
          if (!mounted || !context.mounted) return;
          final appService = Provider.of<AppService>(context, listen: false);
          await appService.updateDeliveryLocation(
            orderId: widget.order.id,
            latitude: _driverLocation!.latitude,
            longitude: _driverLocation!.longitude,
          );
        } catch (e) {
          debugPrint('Erreur envoi position: $e');
        }

        // Recalculate route if needed (throttle to avoid too many calculations)
        if (!mounted || !context.mounted) return;
        await _calculateRoute();
        if (!mounted || !context.mounted) return;

        setState(() {});
      },
      onError: (error) {
        debugPrint('Error in position stream: $error');
        if (!mounted || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de localisation: $error'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (mounted) {
      setState(() => _isTracking = false);
    }
  }

  Future<void> _calculateRoute() async {
    if (_driverLocation == null || _customerLocation == null || !mounted) {
      return;
    }

    // Éviter trop de recalculs (throttling)
    if (_lastCalculatedPosition != null && _lastCalculationTime != null) {
      final distanceSinceLastCalc = _calculateDistance(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        _lastCalculatedPosition!.latitude,
        _lastCalculatedPosition!.longitude,
      );

      final timeSinceLastCalc =
          DateTime.now().difference(_lastCalculationTime!);

      // Ne recalculer que si déplacé de plus de 100m ou après 30 secondes
      if (distanceSinceLastCalc < 0.1 && timeSinceLastCalc.inSeconds < 30) {
        return;
      }
    }

    if (_isCalculatingRoute) return;

    setState(() => _isCalculatingRoute = true);

    try {
      // Choisir la destination "prochaine étape" selon l'état de la commande:
      // - Avant pickup -> restaurant
      // - Après pickup/onTheWay -> client
      final destination = _nextStopDestination();

      // Utiliser Google Directions API pour obtenir la vraie route
      final routeInfo = await _directionsService.getRoute(
        origin: _driverLocation!,
        destination: destination,
        mode: 'driving',
      );

      if (routeInfo != null && mounted) {
        // Mettre à jour les informations
        setState(() {
          _estimatedDistance = routeInfo.distanceKm;
          _estimatedTime = routeInfo.formattedDuration;
          _lastCalculatedPosition = _driverLocation;
          _lastCalculationTime = DateTime.now();
        });

        // Mettre à jour le polyline avec la vraie route
        await _updateRoutePolyline(routeInfo.polylinePoints);
        if (!mounted) return;
      } else {
        // Fallback: utiliser le calcul Haversine si l'API échoue
        _calculateRouteFallback();
      }
    } catch (e) {
      debugPrint('❌ Erreur calcul route avec Directions API: $e');

      // Fallback: utiliser le calcul Haversine
      _calculateRouteFallback();
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  /// Calcul de route en fallback (Haversine) si l'API échoue
  void _calculateRouteFallback() {
    try {
      double distance = 0.0;
      if (_driverLocation != null && _customerLocation != null) {
        final destination = _nextStopDestination();
        distance = _calculateDistance(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
          destination.latitude,
          destination.longitude,
        );
      }

      // Estimation basée sur la distance (vitesse moyenne: 30 km/h en ville)
      // Ajouter 5 minutes pour le ramassage
      const averageSpeedKmh = 30.0;
      final minutesPerKm = 60.0 / averageSpeedKmh;
      final estimatedMinutes = (distance * minutesPerKm).round() + 5;
      final duration = Duration(minutes: estimatedMinutes.clamp(5, 60));

      if (mounted) {
        setState(() {
          _estimatedDistance = distance;
          _estimatedTime = _formatDuration(duration);
          _lastCalculatedPosition = _driverLocation;
          _lastCalculationTime = DateTime.now();
        });
      }

      // Créer un polyline simple (ligne droite)
      _updateRoutePolyline([_driverLocation!, _nextStopDestination()]);
    } catch (e) {
      debugPrint('❌ Erreur calcul route fallback: $e');
    }
  }

  LatLng _nextStopDestination() {
    final status = widget.order.status;
    final goToRestaurant = status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.preparing ||
        status == OrderStatus.ready;

    if (goToRestaurant && _restaurantLocation != null) {
      return _restaurantLocation!;
    }
    return _customerLocation ??
        const LatLng(
          ApiConfig.defaultRestaurantLat,
          ApiConfig.defaultRestaurantLng,
        );
  }

  /// Met à jour le polyline de la route sur la carte
  Future<void> _updateRoutePolyline(List<LatLng> points) async {
    if (!mounted || points.isEmpty) return;

    setState(() {
      _lastRoutePoints = points;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });

    // Ne pas auto-fit à chaque update (sinon la carte "saute" pendant la conduite).
  }

  Future<void> _centerOnDriver() async {
    if (_mapController == null || _driverLocation == null) return;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverLocation!, zoom: 16),
        ),
      );
    } catch (e) {
      debugPrint('Erreur centrage livreur: $e');
    }
  }

  Future<void> _centerOnNextStop() async {
    if (_mapController == null) return;
    final dest = _nextStopDestination();
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 16),
        ),
      );
    } catch (e) {
      debugPrint('Erreur centrage destination: $e');
    }
  }

  Future<void> _fitRoute() async {
    if (_mapController == null || _lastRoutePoints.length < 2) return;
    try {
      final bounds = _calculateBounds(_lastRoutePoints);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } catch (e) {
      debugPrint('Erreur fit route: $e');
    }
  }

  /// Calcule les limites (bounds) d'une liste de points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _updateMarkers() {
    if (!mounted) return;

    setState(() {
      _markers = {
        if (_driverLocation != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(
              title: 'Votre position',
              snippet: 'Livreur',
            ),
          ),
        if (_customerLocation != null)
          Marker(
            markerId: const MarkerId('customer'),
            position: _customerLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Client',
              snippet: widget.order.deliveryAddress,
            ),
          ),
        if (_restaurantLocation != null)
          Marker(
            markerId: const MarkerId('restaurant'),
            position: _restaurantLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(
              title: 'Restaurant',
              snippet: 'Point de départ',
            ),
          ),
      };
    });
  }

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0; // Earth radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    final double distance = earthRadius * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  Future<void> _updateOrderStatus(OrderStatus status) async {
    if (!mounted || !context.mounted) return;
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.updateOrderStatus(widget.order.id, status);

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut mis à jour: ${status.displayName}'),
        ),
      );
      // Navigate back after status update
      Navigator.pop(context);
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de mise à jour: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi - Commande #${widget.order.id.substring(0, 8)}'),
        actions: [
          IconButton(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
            tooltip: _isTracking ? 'Arrêter le suivi' : 'Démarrer le suivi',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Initialisation du suivi...')
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _driverLocation ??
                              const LatLng(
                                ApiConfig.defaultRestaurantLat,
                                ApiConfig.defaultRestaurantLng,
                              ),
                          zoom: 15,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                          _updateMarkers();
                        },
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: true,
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Column(
                          children: [
                            _MapActionButton(
                              icon: Icons.my_location,
                              tooltip: 'Centrer livreur',
                              onTap: _centerOnDriver,
                            ),
                            const SizedBox(height: 10),
                            _MapActionButton(
                              icon: Icons.route,
                              tooltip: 'Voir route complète',
                              onTap: _fitRoute,
                            ),
                            const SizedBox(height: 10),
                            _MapActionButton(
                              icon: Icons.flag,
                              tooltip: 'Aller restaurant / client',
                              onTap: _centerOnNextStop,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status and controls
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: AppSpacing.pagePadding,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order info
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _isTracking
                                    ? scheme.secondary
                                    : scheme.onSurfaceVariant,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isTracking ? 'Suivi actif' : 'Suivi arrêté',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isTracking
                                      ? scheme.secondary
                                      : scheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ETA and distance
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Temps estimé',
                                _isCalculatingRoute
                                    ? 'Calcul...'
                                    : _estimatedTime,
                                Icons.access_time,
                                scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Distance',
                                _isCalculatingRoute
                                    ? 'Calcul...'
                                    : '${_estimatedDistance.toStringAsFixed(1)} km',
                                Icons.straighten,
                                scheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Order status
                        Text(
                          'Statut: ${widget.order.status.displayName}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _updateOrderStatus(OrderStatus.pickedUp),
                                icon: const Icon(Icons.shopping_bag),
                                label: const Text('Commande récupérée'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _updateOrderStatus(OrderStatus.delivered),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Livré'),
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
