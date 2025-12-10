import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/driver_management_service.dart';
import '../../services/realtime_tracking_service.dart';
import '../../models/driver.dart';
import '../../models/order.dart';
import '../../services/order_management_service.dart';
import '../../utils/dialog_helper.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Map<String, Driver> _selectedDrivers = {};
  bool _showAllDrivers = true;
  String? _selectedZone;
  GoogleMapController? _mapController;
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(14.6928, -17.4467), // Dakar, Senegal
    zoom: 12,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des Livreurs'),
        actions: [
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(),
              tooltip: 'Filtres',
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<DriverManagementService>();
                context.read<RealtimeTrackingService>();
              },
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de filtres
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Tous'),
                        icon: Icon(Icons.people),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Sélectionnés'),
                        icon: Icon(Icons.check_circle),
                      ),
                    ],
                    selected: {_showAllDrivers},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _showAllDrivers = newSelection.first;
                      });
                    },
                  ),
                ),
                if (_selectedZone != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text(_selectedZone!),
                      onDeleted: () {
                        setState(() {
                          _selectedZone = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Carte
          Expanded(
            child: Consumer2<DriverManagementService, OrderManagementService>(
              builder: (context, driverService, orderService, child) {
                final drivers = _showAllDrivers
                    ? driverService.drivers
                    : _selectedDrivers.values.toList();

                // Filtrer par zone si sélectionnée
                final filteredDrivers = _selectedZone != null
                    ? drivers
                        .where((driver) => true) // TODO: Filtrer par zone
                        .toList()
                    : drivers;

                return _buildMapView(filteredDrivers, orderService.allOrders);
              },
            ),
          ),
          // Liste des livreurs
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.list, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Livreurs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Consumer<DriverManagementService>(
                        builder: (context, service, child) {
                          final onlineCount = service.drivers
                              .where((d) => d.status == DriverStatus.available ||
                                  d.status == DriverStatus.onDelivery)
                              .length;
                          return Text(
                            '$onlineCount en ligne',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer<DriverManagementService>(
                    builder: (context, service, child) {
                      final drivers = _showAllDrivers
                          ? service.drivers
                          : _selectedDrivers.values.toList();

                      if (drivers.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun livreur',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: drivers.length,
                        itemBuilder: (context, index) {
                          final driver = drivers[index];
                          final isSelected = _selectedDrivers.containsKey(driver.id);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(driver.status),
                                child: Icon(
                                  driver.status.icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                driver.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.status.displayName,
                                    style: TextStyle(
                                      color: _getStatusColor(driver.status),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (driver.vehicleType != null)
                                    Text(
                                      driver.vehicleType!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedDrivers[driver.id] = driver;
                                      } else {
                                        _selectedDrivers.remove(driver.id);
                                      }
                                    });
                                  },
                                ),
                              ),
                              onTap: () {
                                // Centrer la carte sur ce livreur
                                _centerOnDriver(driver);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(List<Driver> drivers, List<Order> orders) {
    Set<Marker> markers = {};

    for (var driver in drivers) {
      if (driver.latitude != null && driver.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId(driver.id),
            position: LatLng(driver.latitude!, driver.longitude!),
            infoWindow: InfoWindow(
              title: driver.name,
              snippet: '${driver.status.displayName} - ${driver.vehicleType ?? "Véhicule"}',
              onTap: () => _showDriverInfo(driver),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(driver.status),
            ),
          ),
        );
      }
    }

    return GoogleMap(
      initialCameraPosition: _initialPosition,
      markers: markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      myLocationEnabled: true,
      zoomControlsEnabled: true,
      mapType: MapType.normal,
    );
  }

  double _getMarkerHue(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return BitmapDescriptor.hueGreen;
      case DriverStatus.onDelivery:
        return BitmapDescriptor.hueOrange;
      case DriverStatus.offline:
        return BitmapDescriptor.hueViolet; // Grey not available as hue
      case DriverStatus.unavailable:
        return BitmapDescriptor.hueRed;
    }
  }


  // ignore: unused_element
  Widget _buildLegendItem(DriverStatus status, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return Colors.green;
      case DriverStatus.onDelivery:
        return Colors.orange;
      case DriverStatus.offline:
        return Colors.grey;
      case DriverStatus.unavailable:
        return Colors.red;
    }
  }

  void _showDriverInfo(Driver driver) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(driver.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Statut', driver.status.displayName),
            _buildInfoRow('Email', driver.email),
            _buildInfoRow('Téléphone', driver.phone),
            if (driver.vehicleType != null)
              _buildInfoRow('Véhicule', driver.vehicleType!),
            if (driver.latitude != null && driver.longitude != null)
              _buildInfoRow(
                'Position',
                '${driver.latitude!.toStringAsFixed(4)}, ${driver.longitude!.toStringAsFixed(4)}',
              ),
            _buildInfoRow('Note', driver.rating.toStringAsFixed(1)),
            _buildInfoRow('Livraisons', '${driver.totalDeliveries}'),
          ],
        ),
        actions: [
          Container(
            constraints: const BoxConstraints(
              minHeight: 48,
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minHeight: 48,
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _centerOnDriver(driver);
              },
              child: const Text('Centrer sur carte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _centerOnDriver(Driver driver) {
    if (driver.latitude != null && driver.longitude != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(driver.latitude!, driver.longitude!),
          15,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Position non disponible pour ${driver.name}'),
        ),
      );
    }
  }

  void _showFilterDialog() {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
        final dialogHeight = (screenSize.height * 0.5).clamp(300.0, 500.0);
        
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: dialogWidth,
              maxWidth: dialogWidth,
              minHeight: dialogHeight,
              maxHeight: dialogHeight,
            ),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filtres',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Zone:'),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 56,
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedZone,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Sélectionner une zone',
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Toutes')),
                                ...['Zone Centre', 'Zone Nord', 'Zone Sud', 'Zone Est', 'Zone Ouest']
                                    .map((zone) => DropdownMenuItem(
                                          value: zone,
                                          child: Text(zone),
                                        )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedZone = value;
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                          ),
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedZone = null;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Réinitialiser'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Fermer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}



