import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/directions_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/screens/client/chat_screen.dart';

/// Écran de suivi de livraison en temps réel
class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;

  const DeliveryTrackingScreen({
    required this.orderId,
    super.key,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _deliveryLocation;
  String? _estimatedDeliveryTime;
  Map<String, dynamic>? _driverProfile;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _deliveryLatLng;

  StreamSubscription<Order>? _orderUpdatesSubscription;
  StreamSubscription<Map<String, dynamic>>? _deliveryLocationSubscription;
  late RealtimeTrackingService? _trackingService;
  late DatabaseService? _databaseService;
  late GeocodingService? _geocodingService;
  late DirectionsService? _directionsService;
  Timer? _estimatedTimeUpdateTimer;
  Timer?
      _orderRefreshTimer; // Timer pour rafraîchir périodiquement depuis la DB

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _startTracking();
  }

  @override
  void dispose() {
    _orderUpdatesSubscription?.cancel();
    _deliveryLocationSubscription?.cancel();
    _estimatedTimeUpdateTimer?.cancel();
    _orderRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    try {
      // Valider l'ID de commande avant de faire la requête
      if (widget.orderId.isEmpty) {
        throw Exception('ID de commande invalide: l\'ID est vide');
      }

      // Valider le format UUID (format basique)
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      if (!uuidPattern.hasMatch(widget.orderId)) {
        debugPrint('⚠️ Order ID format may be invalid: ${widget.orderId}');
        // On continue quand même, car certains IDs peuvent avoir un format différent
      }

      final appService = Provider.of<AppService>(context, listen: false);
      _databaseService = appService.databaseService;
      _geocodingService = GeocodingService();
      _directionsService = DirectionsService();

      // Charger la commande depuis la base de données
      try {
        final orderResponse =
            await _databaseService!.supabase.from('orders').select('''
              *,
              order_items(*)
            ''').eq('id', widget.orderId).maybeSingle();

        if (orderResponse != null) {
          _order = Order.fromMap(orderResponse);
        } else {
          // Fallback: chercher dans les commandes locales
          final orders = appService.orders;
          try {
            _order = orders.firstWhere(
              (order) => order.id == widget.orderId,
            );
          } catch (e) {
            throw Exception(
              'Commande non trouvée dans la base de données ni localement',
            );
          }
        }
      } catch (e) {
        // Si c'est une erreur UUID invalide, ne pas essayer le fallback local
        if (e.toString().contains('invalid input syntax for type uuid') ||
            e.toString().contains('22P02')) {
          debugPrint('⚠️ UUID invalide pour la commande: ${widget.orderId}');
          throw Exception('ID de commande invalide. Veuillez réessayer.');
        }

        debugPrint('⚠️ Error loading order from database, using local: $e');
        // Fallback: chercher dans les commandes locales
        final orders = appService.orders;
        try {
          _order = orders.firstWhere(
            (order) => order.id == widget.orderId,
          );
        } catch (e2) {
          throw Exception(
            'Commande non trouvée dans la base de données ni localement',
          );
        }
      }

      // Charger le profil du livreur si assigné
      if (_order != null && _order!.deliveryPersonId != null) {
        await _loadDriverProfile(_order!.deliveryPersonId!);
      }

      // Charger la dernière position de livraison seulement si la commande existe
      if (_order != null) {
        await _geocodeDeliveryAddress();
        await _loadLatestDeliveryLocation();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading order details: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erreur lors du chargement de la commande: ${e.toString()}';
      });
    }
  }

  Future<void> _loadDriverProfile(String driverId) async {
    try {
      if (_databaseService == null) return;
      final profile = await _databaseService!.getUserProfile(driverId);
      if (profile != null && mounted) {
        setState(() {
          _driverProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading driver profile: $e');
    }
  }

  Future<void> _geocodeDeliveryAddress() async {
    if (_order == null || _geocodingService == null) return;
    try {
      final latLng =
          await _geocodingService!.geocodeAddress(_order!.deliveryAddress);
      if (latLng != null && mounted) {
        setState(() {
          _deliveryLatLng = latLng;
        });
        _updateMapMarkers();
      }
    } catch (e) {
      debugPrint('⚠️ Error geocoding delivery address: $e');
    }
  }

  void _updateMapMarkers() {
    if (!mounted) return;

    final Set<Marker> markers = {};

    // Marker client (destination)
    if (_deliveryLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _deliveryLatLng!,
          infoWindow: InfoWindow(
            title: 'Votre adresse',
            snippet: _order?.deliveryAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Marker livreur
    if (_deliveryLocation != null) {
      final driverPos = LatLng(
        _deliveryLocation!['latitude'] as double,
        _deliveryLocation!['longitude'] as double,
      );

      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          infoWindow: const InfoWindow(
            title: 'Livreur',
            snippet: 'En route',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: (_deliveryLocation!['heading'] as num?)?.toDouble() ?? 0.0,
        ),
      );

      // Update camera if map is ready
      if (_mapController != null) {
        if (_deliveryLatLng != null) {
          // Fit bounds if both exist
          _fitBounds(driverPos, _deliveryLatLng!);
          _getDirections(driverPos, _deliveryLatLng!);
        } else {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(driverPos),
          );
        }
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    if (_directionsService == null) return;

    try {
      final routeInfo = await _directionsService!.getRoute(
        origin: origin,
        destination: destination,
      );

      if (routeInfo != null && mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeInfo.polylinePoints,
              color: Theme.of(context).colorScheme.primary,
              width: 5,
            ),
          };

          // Update estimated time with traffic info if available
          if (routeInfo.durationInTrafficMinutes != null) {
            _estimatedDeliveryTime =
                '${routeInfo.durationInTrafficMinutes} min';
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error getting directions: $e');
    }
  }

  void _fitBounds(LatLng p1, LatLng p2) {
    LatLngBounds bounds;
    if (p1.latitude > p2.latitude && p1.longitude > p2.longitude) {
      bounds = LatLngBounds(southwest: p2, northeast: p1);
    } else if (p1.longitude > p2.longitude) {
      bounds = LatLngBounds(
        southwest: LatLng(p1.latitude, p2.longitude),
        northeast: LatLng(p2.latitude, p1.longitude),
      );
    } else if (p1.latitude > p2.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(p2.latitude, p1.longitude),
        northeast: LatLng(p1.latitude, p2.longitude),
      );
    } else {
      bounds = LatLngBounds(southwest: p1, northeast: p2);
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _loadLatestDeliveryLocation() async {
    try {
      if (_databaseService == null) return;

      final locations =
          await _databaseService!.getDeliveryLocations(widget.orderId);
      if (locations.isNotEmpty) {
        final latestLocation = locations.first;
        setState(() {
          _deliveryLocation = {
            'latitude': (latestLocation['latitude'] as num).toDouble(),
            'longitude': (latestLocation['longitude'] as num).toDouble(),
            'timestamp': DateTime.parse(latestLocation['timestamp'] as String),
            'accuracy': latestLocation['accuracy'] != null
                ? (latestLocation['accuracy'] as num).toDouble()
                : null,
            'speed': latestLocation['speed'] != null
                ? (latestLocation['speed'] as num).toDouble()
                : null,
            'heading': latestLocation['heading'] != null
                ? (latestLocation['heading'] as num).toDouble()
                : null,
          };
        });

        // Calculer le temps estimé de livraison
        await _calculateEstimatedDeliveryTime();
        _updateMapMarkers();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading delivery location: $e');
    }
  }

  Future<void> _startTracking() async {
    try {
      if (!mounted || !context.mounted) return;
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        debugPrint('⚠️ User not logged in, cannot start tracking');
        return;
      }

      // Initialiser le service de tracking en temps réel
      _trackingService = RealtimeTrackingService();

      if (!_trackingService!.isConnected) {
        await _trackingService!.initialize(
          userId: currentUser.id,
          userRole: currentUser.role,
        );
      }

      if (!mounted || !context.mounted) return;

      // Suivre cette commande spécifique
      await _trackingService!.trackOrder(widget.orderId);

      // S'abonner aux mises à jour de la commande
      _orderUpdatesSubscription = _trackingService!.orderUpdates.listen(
        (updatedOrder) {
          if (updatedOrder.id == widget.orderId && mounted) {
            setState(() {
              _order = updatedOrder;
            });

            // Mettre à jour le profil du livreur si nouvellement assigné
            if (updatedOrder.deliveryPersonId != null &&
                (_driverProfile == null ||
                    _driverProfile!['auth_user_id'] !=
                        updatedOrder.deliveryPersonId)) {
              _loadDriverProfile(updatedOrder.deliveryPersonId!);
            }

            // Si la commande est livrée, arrêter le suivi
            if (updatedOrder.status == OrderStatus.delivered) {
              _estimatedTimeUpdateTimer?.cancel();
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in order updates stream: $error');
        },
      );

      // S'abonner aux mises à jour de position du livreur
      _deliveryLocationSubscription =
          _trackingService!.deliveryLocationUpdates.listen(
        (locationUpdate) {
          // Filtrer pour cette commande uniquement
          if (locationUpdate['orderId'] == widget.orderId && mounted) {
            setState(() {
              _deliveryLocation = {
                'latitude': locationUpdate['latitude'] as double,
                'longitude': locationUpdate['longitude'] as double,
                'timestamp':
                    DateTime.parse(locationUpdate['timestamp'] as String),
              };
            });

            // Recalculer le temps estimé
            _calculateEstimatedDeliveryTime();
            _updateMapMarkers();
          }
        },
        onError: (error) {
          debugPrint('❌ Error in delivery location stream: $error');
        },
      );

      // Mettre à jour le temps estimé périodiquement
      _estimatedTimeUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _calculateEstimatedDeliveryTime(),
      );

      // Rafraîchir la commande depuis la base de données périodiquement
      // pour s'assurer que l'UI reste synchronisée même si le realtime ne fonctionne pas
      _orderRefreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) {
          if (mounted) {
            _loadOrderDetails();
          }
        },
      );

      debugPrint('✅ Started real-time tracking for order: ${widget.orderId}');
    } catch (e) {
      debugPrint('❌ Error starting tracking: $e');
    }
  }

  Future<void> _calculateEstimatedDeliveryTime() async {
    if (_order == null ||
        _deliveryLocation == null ||
        _geocodingService == null ||
        _order!.status != OrderStatus.onTheWay) {
      return;
    }

    try {
      // Géocoder l'adresse de livraison
      final deliveryCoords =
          await _geocodingService!.geocodeAddress(_order!.deliveryAddress);

      if (deliveryCoords == null) {
        debugPrint('⚠️ Could not geocode delivery address');
        return;
      }

      // Coordonnées du livreur
      final driverCoords = LatLng(
        _deliveryLocation!['latitude'] as double,
        _deliveryLocation!['longitude'] as double,
      );

      // Calculer le temps de trajet estimé
      final travelTime = await _geocodingService!
          .calculateTravelTime(driverCoords, deliveryCoords);

      if (travelTime != null && mounted) {
        setState(() {
          _estimatedDeliveryTime = '$travelTime min';
        });
      } else {
        // Fallback: calculer la distance et estimer
        final distanceKm =
            _geocodingService!.calculateDistance(driverCoords, deliveryCoords);
        final estimatedMinutes = (distanceKm * 2).round(); // ~2 min/km en ville

        if (mounted) {
          setState(() {
            _estimatedDeliveryTime = '$estimatedMinutes min';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error calculating estimated delivery time: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de passer l\'appel vers $phoneNumber'),
          ),
        );
      }
    }
  }

  void _openChat() {
    if (_order?.deliveryPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le chat sera disponible une fois qu\'un livreur aura accepté votre commande.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: widget.orderId,
          driverId: _order?.deliveryPersonId,
          driverName: _driverProfile?['name'] ?? 'Livreur',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Suivi de livraison'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Réessayer',
                onPressed: _loadOrderDetails,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de livraison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetails,
          ),
        ],
      ),
      body: _order == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadOrderDetails();
                await _loadLatestDeliveryLocation();
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOrderHeader(),
                          const SizedBox(height: 12),
                          _buildQuickStatusCard(),
                          const SizedBox(height: 16),
                          _buildActions(),
                          const SizedBox(height: 16),
                          _buildDeliveryMapOrPlaceholder(),
                          const SizedBox(height: 16),
                          _buildDeliveryStatus(),
                          const SizedBox(height: 16),
                          _buildDeliveryInfo(),
                          const SizedBox(height: 16),
                          _buildOrderDetails(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStatusCard() {
    final status = _order!.status;
    final hasDriver = _order?.deliveryPersonId != null;
    final subtitle = () {
      switch (status) {
        case OrderStatus.pending:
          return 'En attente de confirmation';
        case OrderStatus.confirmed:
          return 'Commande confirmée';
        case OrderStatus.preparing:
          return 'En préparation';
        case OrderStatus.ready:
          return 'Prête';
        case OrderStatus.pickedUp:
          return 'Récupérée par le livreur';
        case OrderStatus.onTheWay:
          return 'En route';
        case OrderStatus.delivered:
          return 'Livrée';
        case OrderStatus.cancelled:
          return 'Annulée';
        case OrderStatus.refunded:
          return 'Remboursée';
        case OrderStatus.failed:
          return 'Échouée';
      }
    }();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getStatusColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getStatusIcon(), color: _getStatusColor()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _order!.status.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (status == OrderStatus.onTheWay &&
                      _estimatedDeliveryTime != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Arrivée estimée: $_estimatedDeliveryTime',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasDriver ? 'Livreur: OK' : 'Livreur: —',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasDriver ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(_order!.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_order!.status) {
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.inventory_2_outlined;
      case OrderStatus.pickedUp:
        return Icons.shopping_bag_outlined;
      case OrderStatus.onTheWay:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
      case OrderStatus.failed:
        return Icons.error_outline;
    }
  }

  Widget _buildDeliveryMapOrPlaceholder() {
    if (_deliveryLatLng == null && _deliveryLocation == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.map_outlined,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Carte indisponible pour le moment (position ou adresse non résolue).',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _geocodeDeliveryAddress();
                  await _loadLatestDeliveryLocation();
                },
                child: const Text('Actualiser'),
              ),
            ],
          ),
        ),
      );
    }

    // Map existante, mais avec un wrapper + actions rapides
    return Stack(
      children: [
        _buildDeliveryMap(),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'fit',
                onPressed: () {
                  if (_deliveryLocation == null || _deliveryLatLng == null) {
                    return;
                  }
                  final driverPos = LatLng(
                    _deliveryLocation!['latitude'] as double,
                    _deliveryLocation!['longitude'] as double,
                  );
                  _fitBounds(driverPos, _deliveryLatLng!);
                },
                child: const Icon(Icons.fit_screen),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'center',
                onPressed: () {
                  if (_deliveryLocation == null || _mapController == null) {
                    return;
                  }
                  final driverPos = LatLng(
                    _deliveryLocation!['latitude'] as double,
                    _deliveryLocation!['longitude'] as double,
                  );
                  _mapController!
                      .animateCamera(CameraUpdate.newLatLng(driverPos));
                },
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final hasDriver = _order?.deliveryPersonId != null;
    final driverPhone = _driverProfile?['phone'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              onTap: _openChat,
              color: hasDriver ? Colors.blue : Colors.grey,
              isEnabled: hasDriver,
            ),
            _buildActionItem(
              icon: Icons.phone_in_talk,
              label: 'Livreur',
              onTap: () {
                if (hasDriver && driverPhone != null) {
                  _makePhoneCall(driverPhone);
                } else if (hasDriver) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Numéro du livreur non disponible pour le moment',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aucun livreur assigné pour le moment'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              color:
                  hasDriver && driverPhone != null ? Colors.green : Colors.grey,
              isEnabled: hasDriver && driverPhone != null,
            ),
            _buildActionItem(
              icon: Icons.headset_mic,
              label: 'Support',
              onTap: () => _makePhoneCall('+22507070707'), // Customer service
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? Colors.grey[700] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commande #${widget.orderId.substring(0, 8).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _order!.status.displayName,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Passée le ${_formatDateTime(_order!.orderTime)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${PriceFormatter.format(_order!.total)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            if (_driverProfile != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _driverProfile!['profile_image'] != null
                        ? NetworkImage(_driverProfile!['profile_image'])
                        : null,
                    child: _driverProfile!['profile_image'] == null
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Livreur',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _driverProfile!['name'] ?? 'Livreur assigné',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statut de livraison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatusTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];

    return Column(
      children: statuses.asMap().entries.map((entry) {
        final status = entry.value;
        final isCompleted = status.index <= _order!.status.index;
        final isCurrent = status == _order!.status;

        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
                border:
                    isCurrent ? Border.all(color: Colors.blue, width: 2) : null,
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : isCurrent
                      ? const Icon(
                          Icons.radio_button_checked,
                          size: 16,
                          color: Colors.blue,
                        )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status.displayName,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.green : Colors.grey[600],
                ),
              ),
            ),
            if (isCurrent && _estimatedDeliveryTime != null)
              Text(
                _estimatedDeliveryTime!,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOrderDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails de la commande',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._order!.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('${item.quantity}x'),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name)),
                    Text(PriceFormatter.format(item.totalPrice)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total'),
                Text(PriceFormatter.format(_order!.subtotal)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Livraison'),
                Text(PriceFormatter.format(_order!.deliveryFee)),
              ],
            ),
            if (_order!.discount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remise', style: TextStyle(color: Colors.green)),
                  Text(
                    '-${PriceFormatter.format(_order!.discount)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  PriceFormatter.format(_order!.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Adresse de livraison',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_order!.deliveryAddress),
            if (_order!.deliveryNotes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${_order!.deliveryNotes}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMap() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Position du livreur',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMapWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    // Utiliser un Builder pour capturer les erreurs de rendu
    return Builder(
      builder: (context) {
        try {
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _deliveryLocation != null
                  ? LatLng(
                      _deliveryLocation!['latitude'] as double,
                      _deliveryLocation!['longitude'] as double,
                    )
                  : (_deliveryLatLng ??
                      const LatLng(
                        5.3600,
                        -4.0080,
                      )), // Default fallback (Abidjan usually)
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapMarkers(); // Ensure markers are shown
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          );
        } catch (e) {
          debugPrint('❌ Erreur lors du chargement de Google Maps: $e');
          return Container(
            color: Colors.red[50],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[700],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Impossible de charger la carte.\nVérifiez votre connexion internet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Color _getStatusColor() {
    switch (_order!.status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.onTheWay:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.grey;
      case OrderStatus.failed:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
