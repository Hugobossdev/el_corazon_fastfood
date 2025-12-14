import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/driver_management_service.dart';
import '../../models/driver.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/dialog_helper.dart';
import 'driver_form_dialog.dart';
import 'driver_history_screen.dart';
import 'driver_schedule_screen.dart';
import 'driver_detailed_stats_screen.dart';
import 'driver_map_screen.dart';

enum DriverSortOption { nameAsc, nameDesc, status, rating, deliveries }

extension DriverSortOptionExtension on DriverSortOption {
  String get displayName {
    switch (this) {
      case DriverSortOption.nameAsc:
        return 'Nom (A-Z)';
      case DriverSortOption.nameDesc:
        return 'Nom (Z-A)';
      case DriverSortOption.status:
        return 'Statut';
      case DriverSortOption.rating:
        return 'Note';
      case DriverSortOption.deliveries:
        return 'Livraisons';
    }
  }
}

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'Aperçu'),
                Tab(
                    icon: Icon(Icons.check_circle_outline),
                    text: 'Disponibles'),
                Tab(icon: Icon(Icons.delivery_dining), text: 'En course'),
                Tab(
                    icon: Icon(Icons.offline_bolt_outlined),
                    text: 'Hors ligne'),
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Stats'),
              ],
            ),
          ),
          Expanded(
            child: Consumer<DriverManagementService>(
              builder: (context, driverService, child) {
                if (driverService.isLoading) {
                  return const LoadingWidget(
                      message: 'Chargement des livreurs...');
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, driverService),
                    _buildDriverListTab(
                        context, driverService, DriverStatus.available),
                    _buildDriverListTab(
                        context, driverService, DriverStatus.onDelivery),
                    _buildDriverListTab(
                        context, driverService, DriverStatus.offline),
                    const DriverDetailedStatsScreen(
                        driver: null), // Placeholder for global stats tab
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un livreur...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (value) {
                context.read<DriverManagementService>().searchDrivers(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrer',
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _showAddDriverDialog,
            elevation: 0,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context, DriverManagementService driverService) {
    final stats = driverService.getDriverStats();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsGrid(context, stats),
        const SizedBox(height: 24),
        const Text(
          'Localisation en temps réel',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildMockMap(context, driverService.drivers),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Livreurs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(4), // Go to Stats
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...driverService.getTopRatedDrivers(limit: 3).map(
            (driver) => _buildDriverListItem(context, driver, driverService)),
      ],
    );
  }

  Widget _buildDriverListTab(BuildContext context,
      DriverManagementService service, DriverStatus status) {
    final drivers = service.getDriversByStatus(status);

    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucun livreur ${status.displayName.toLowerCase()}',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      itemBuilder: (context, index) =>
          _buildDriverCard(context, drivers[index], service),
    );
  }

  Widget _buildMockMap(BuildContext context, List<Driver> drivers) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverMapScreen()),
        );
      },
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
          image: const DecorationImage(
            image: NetworkImage(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/World_map_blank_without_borders.svg/2000px-World_map_blank_without_borders.svg.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map, color: Colors.blue[700], size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Ouvrir la carte interactive',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ...drivers.take(5).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final driver = entry.value;
              final alignments = [
                const Alignment(0.5, -0.5),
                const Alignment(-0.6, 0.2),
                const Alignment(0.3, 0.7),
                const Alignment(-0.2, -0.6),
                const Alignment(0.8, 0.1),
              ];

              return Align(
                alignment: alignments[index % alignments.length],
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          blurRadius: 4, color: Colors.black.withValues(alpha: 0.2))
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        _getStatusColor(driver.status).withValues(alpha: 0.2),
                    child: Text(
                      driver.name[0],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(driver.status)),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Livreurs',
          stats['total_drivers'].toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'En Ligne',
          stats['online_drivers'].toString(),
          Icons.wifi,
          Colors.green,
        ),
        _buildStatCard(
          'Courses actives',
          stats['busy_drivers'].toString(),
          Icons.local_shipping,
          Colors.orange,
        ),
        _buildStatCard(
          'Note Moyenne',
          (stats['average_rating'] as num).toStringAsFixed(1),
          Icons.star,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(
      BuildContext context, Driver driver, DriverManagementService service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 24,
                backgroundColor:
                    _getStatusColor(driver.status).withValues(alpha: 0.1),
                child: Text(
                  driver.name[0].toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(driver.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                driver.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber[700]),
                  Text(
                    ' ${driver.rating.toStringAsFixed(1)} • ${driver.totalDeliveries} courses',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(driver.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  driver.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(driver.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  Icons.calendar_month,
                  'Planning',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DriverScheduleScreen(driver: driver))),
                ),
                _buildActionButton(
                  context,
                  Icons.analytics_outlined,
                  'Stats',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DriverDetailedStatsScreen(driver: driver))),
                ),
                _buildActionButton(
                  context,
                  Icons.history,
                  'Historique',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DriverHistoryScreen(driver: driver))),
                ),
                _buildActionButton(
                  context,
                  Icons.edit_outlined,
                  'Éditer',
                  () => _editDriver(driver),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverListItem(
      BuildContext context, Driver driver, DriverManagementService service) {
    return ListTile(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DriverDetailedStatsScreen(driver: driver))),
      leading: CircleAvatar(
        child: Text(driver.name[0]),
      ),
      title: Text(driver.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${driver.totalDeliveries} livraisons'),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
    );
  }

  Widget _buildActionButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
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

  void _showFilterDialog() {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer les livreurs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filtrer par statut
            DropdownButtonFormField<DriverStatus>(
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_alt),
              ),
              items: DriverStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (status) {
                context.read<DriverManagementService>().filterByStatus(status);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            // Filtrer par tri
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Trier par',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sort),
              ),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Nom (A-Z)')),
                DropdownMenuItem(value: 'nameDesc', child: Text('Nom (Z-A)')),
                DropdownMenuItem(
                    value: 'rating', child: Text('Meilleure Note')),
                DropdownMenuItem(
                    value: 'deliveries', child: Text('Plus de livraisons')),
              ],
              onChanged: (value) {
                if (value != null) {
                  context.read<DriverManagementService>().setSortOption(value);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.read<DriverManagementService>().filterByStatus(null);
                context
                    .read<DriverManagementService>()
                    .setSortOption('name'); // Reset sort
                Navigator.pop(context);
              },
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => const DriverFormDialog(),
    );
  }

  void _editDriver(Driver driver) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => DriverFormDialog(driver: driver),
    );
  }
}
