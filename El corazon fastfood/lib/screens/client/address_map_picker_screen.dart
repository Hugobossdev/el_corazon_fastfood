import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:elcora_fast/services/geocoding_service.dart';

class PickedLocation {
  final LatLng location;
  final String? formattedAddress;

  const PickedLocation({
    required this.location,
    this.formattedAddress,
  });
}

/// Sélection d'adresse sur carte (pin + reverse geocode)
///
/// - Tap/Long-press pour placer le pin
/// - Bouton "Ma position" (si permissions OK)
/// - Retourne `PickedLocation` (lat/lng obligatoire)
class AddressMapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const AddressMapPickerScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<AddressMapPickerScreen> createState() => _AddressMapPickerScreenState();
}

class _AddressMapPickerScreenState extends State<AddressMapPickerScreen> {
  final GeocodingService _geocoding = GeocodingService();
  GoogleMapController? _controller;

  LatLng? _picked;
  String? _formatted;
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
    if (_picked != null) {
      _reverseGeocode(_picked!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() {
      _isReverseGeocoding = true;
      _formatted = null;
    });
    try {
      final address = await _geocoding.reverseGeocode(pos);
      if (!mounted) return;
      setState(() {
        _formatted = address;
      });
    } finally {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
      }
    }
  }

  void _onPick(LatLng pos) {
    setState(() {
      _picked = pos;
    });
    _reverseGeocode(pos);
  }

  Future<void> _goToMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localisation désactivée sur l’appareil.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission localisation refusée.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final pos = LatLng(position.latitude, position.longitude);
      _onPick(pos);

      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur localisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialLocation ?? const LatLng(5.3599, -4.0083); // Abidjan
    final marker = _picked == null
        ? <Marker>{}
        : {
            Marker(
              markerId: const MarkerId('picked'),
              position: _picked!,
              draggable: true,
              onDragEnd: _onPick,
            ),
          };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir sur la carte'),
        actions: [
          IconButton(
            tooltip: 'Ma position',
            onPressed: _goToMyLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 13),
              onMapCreated: (c) => _controller = c,
              markers: marker,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              onTap: _onPick,
              onLongPress: _onPick,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _picked == null
                      ? 'Tapez sur la carte pour placer le repère.'
                      : 'Coordonnées: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_picked != null)
                  Row(
                    children: [
                      Expanded(
                        child: _isReverseGeocoding
                            ? const Text('Recherche de l’adresse…')
                            : Text(_formatted ?? 'Adresse non trouvée (vous pouvez quand même valider).'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _picked == null
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              PickedLocation(
                                location: _picked!,
                                formattedAddress: _formatted,
                              ),
                            );
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Utiliser cette position'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


