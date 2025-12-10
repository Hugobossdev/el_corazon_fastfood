import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_service.dart';
import '../../models/order.dart';
import '../../models/menu_models.dart';
import '../../core/constants/admin_constants.dart';
import '../../core/utils/admin_helpers.dart';
import '../../core/widgets/admin_card.dart';
import '../../utils/dialog_helper.dart';
import '../../services/driver_document_service.dart';

class EnhancedAdminDashboard extends StatefulWidget {
  const EnhancedAdminDashboard({super.key});

  @override
  State<EnhancedAdminDashboard> createState() => _EnhancedAdminDashboardState();
}

class _EnhancedAdminDashboardState extends State<EnhancedAdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeRange = 'today';
  String _selectedZone = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkDocumentExpirations();
  }

  Future<void> _checkDocumentExpirations() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final service = context.read<DriverDocumentService>();
        await service.checkUpcomingExpirations();
        await service.checkExpiredDocuments();
      } catch (e) {
        debugPrint('Error checking document expirations: $e');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin - FastEat'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh data
                setState(() {});
              },
              tooltip: 'Actualiser',
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _showSettingsDialog(context);
              },
              tooltip: 'Paramètres',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Vue d\'ensemble'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.map), text: 'Carte'),
            Tab(icon: Icon(Icons.trending_up), text: 'Tendances'),
          ],
        ),
      ),
      body: Consumer<AppService>(
        builder: (context, appService, child) {
          final allOrders = appService.allOrders;
          final menuItems = appService.menuItems;

          // IMPORTANT: LayoutBuilder garantit que TabBarView a des contraintes de taille
          // pour éviter l'erreur "Cannot hit test a render box with no size"
          return LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, allOrders, menuItems),
                    _buildAnalyticsTab(context, allOrders, menuItems),
                    _buildMapTab(context, allOrders),
                    _buildTrendsTab(context, allOrders, menuItems),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    final todayRevenue = _calculateTodayRevenue(orders);
    final totalOrders = orders.length;
    final activeDrivers = _getActiveDriversCount(orders);
    final topSellingItems = _getTopSellingItems(orders, menuItems);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminConstants.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Range Selector
          _buildTimeRangeSelector(),
          const SizedBox(height: AdminConstants.spacingMD),

          // Welcome Card
          _buildWelcomeCard(context),
          const SizedBox(height: AdminConstants.spacingLG),

          // Key Metrics Grid
          _buildKeyMetricsGrid(
            context,
            todayRevenue,
            totalOrders,
            activeDrivers,
          ),
          const SizedBox(height: AdminConstants.spacingLG),

          // Quick Actions
          _buildQuickActions(context),
          const SizedBox(height: AdminConstants.spacingLG),

          // Top Selling Items
          _buildTopSellingItems(context, topSellingItems),
          const SizedBox(height: AdminConstants.spacingLG),

          // Recent Orders
          _buildRecentOrders(
            context,
            orders.take(AdminConstants.dashboardRecentItemsLimit).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Chart
          _buildRevenueChart(context, orders),
          const SizedBox(height: 20),

          // Orders Chart
          _buildOrdersChart(context, orders),
          const SizedBox(height: 20),

          // Category Performance
          _buildCategoryPerformance(context, orders, menuItems),
          const SizedBox(height: 20),

          // Driver Performance
          _buildDriverPerformance(context, orders),
        ],
      ),
    );
  }

  Widget _buildMapTab(BuildContext context, List<Order> orders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone Selector
          _buildZoneSelector(),
          const SizedBox(height: 16),

          // Map Container
          _buildMapContainer(context, orders),
          const SizedBox(height: 20),

          // Driver Locations
          _buildDriverLocations(context, orders),
          const SizedBox(height: 20),

          // Hot Zones
          _buildHotZones(context, orders),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sales Trends
          _buildSalesTrends(context, orders),
          const SizedBox(height: 20),

          // Popular Items
          _buildPopularItems(context, orders, menuItems),
          const SizedBox(height: 20),

          // Peak Hours
          _buildPeakHours(context, orders),
          const SizedBox(height: 20),

          // Customer Insights
          _buildCustomerInsights(context, orders),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            const Text('Période: '),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedTimeRange,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
                  DropdownMenuItem(value: 'week', child: Text('Cette semaine')),
                  DropdownMenuItem(value: 'month', child: Text('Ce mois')),
                  DropdownMenuItem(value: 'year', child: Text('Cette année')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTimeRange = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bonjour'
        : hour < 18
        ? 'Bon après-midi'
        : 'Bonsoir';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, Admin! 👨‍💼',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tableau de bord FastEat - Gestion complète',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Système opérationnel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsGrid(
    BuildContext context,
    double todayRevenue,
    int totalOrders,
    int activeDrivers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = AdminConstants.dashboardGridCrossAxisCount;
        final itemWidth =
            (constraints.maxWidth -
                (crossAxisCount - 1) * AdminConstants.dashboardGridSpacing) /
            crossAxisCount;
        final itemHeight =
            itemWidth / AdminConstants.dashboardGridChildAspectRatio;

        return SizedBox(
          height:
              ((4 / crossAxisCount).ceil() * itemHeight) +
              ((4 / crossAxisCount).ceil() - 1) *
                  AdminConstants.dashboardGridSpacing,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AdminConstants.dashboardGridSpacing,
            mainAxisSpacing: AdminConstants.dashboardGridSpacing,
            childAspectRatio: AdminConstants.dashboardGridChildAspectRatio,
            children: [
              _buildMetricCard(
                context,
                'Revenus du jour',
                AdminHelpers.formatEuro(todayRevenue),
                Icons.euro,
                Colors.green,
                '+12.5%',
              ),
              _buildMetricCard(
                context,
                'Commandes totales',
                AdminHelpers.formatNumber(totalOrders),
                Icons.receipt_long,
                Colors.blue,
                '+8.2%',
              ),
              _buildMetricCard(
                context,
                'Livreurs actifs',
                '$activeDrivers',
                Icons.delivery_dining,
                Colors.orange,
                AdminHelpers.formatPercentage((activeDrivers / 10 * 100)),
              ),
              _buildMetricCard(
                context,
                'Panier moyen',
                AdminHelpers.formatEuro(
                  _calculateAverageOrderValue(totalOrders, todayRevenue),
                ),
                Icons.shopping_cart,
                Colors.purple,
                '+5.1%',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return StatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      trend: change,
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AdminConstants.spacingMD),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                AdminConstants.quickActionsGridCrossAxisCount;
            final itemWidth =
                (constraints.maxWidth -
                    (crossAxisCount - 1) *
                        AdminConstants.quickActionsGridSpacing) /
                crossAxisCount;
            final itemHeight =
                itemWidth / AdminConstants.quickActionsGridChildAspectRatio;
            final itemCount = 6;

            return SizedBox(
              height:
                  ((itemCount / crossAxisCount).ceil() * itemHeight) +
                  ((itemCount / crossAxisCount).ceil() - 1) *
                      AdminConstants.quickActionsGridSpacing,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AdminConstants.quickActionsGridSpacing,
                mainAxisSpacing: AdminConstants.quickActionsGridSpacing,
                childAspectRatio:
                    AdminConstants.quickActionsGridChildAspectRatio,
                children: [
                  _buildActionButton(
                    context,
                    'Créer promotion',
                    Icons.local_offer,
                    Colors.orange,
                    () => _navigateToPromotions(),
                  ),
                  _buildActionButton(
                    context,
                    'Commandes',
                    Icons.shopping_cart,
                    Colors.green,
                    () => _navigateToOrderManagement(),
                  ),
                  _buildActionButton(
                    context,
                    'Gérer livreurs',
                    Icons.delivery_dining,
                    Colors.blue,
                    () => _navigateToDriverManagement(),
                  ),
                  _buildActionButton(
                    context,
                    'Notifications',
                    Icons.send,
                    Colors.purple,
                    () => _navigateToNotifications(),
                  ),
                  _buildActionButton(
                    context,
                    'Rapports',
                    Icons.analytics,
                    Colors.teal,
                    () => _navigateToReports(),
                  ),
                  _buildActionButton(
                    context,
                    'Paramètres',
                    Icons.settings,
                    Colors.grey,
                    () => _navigateToSettings(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // IMPORTANT: Material explicite pour garantir le hit testing correct
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minHeight: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSellingItems(
    BuildContext context,
    List<Map<String, dynamic>> topItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top ventes',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: topItems.take(5).map((item) {
              return Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    child: Text(
                      '${topItems.indexOf(item) + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  title: Text(item['name']),
                  subtitle: Text('${item['quantity']} vendus'),
                  trailing: Text(
                    '${item['revenue'].toStringAsFixed(2)}€',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context, List<Order> recentOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commandes récentes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _navigateToOrderManagement(),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: recentOrders.map((order) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(
                    order.status,
                  ).withValues(alpha: 0.1),
                  child: Text(order.status.emoji),
                ),
                title: Text(
                  'Commande #${AdminHelpers.formatOrderId(order.id)}',
                ),
                subtitle: Text(
                  '${order.status.displayName} - ${AdminHelpers.formatRelativeTime(order.orderTime)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AdminHelpers.formatEuro(order.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order.items.length} articles',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                onTap: () => _showOrderDetails(order),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Placeholder methods for charts and analytics
  Widget _buildRevenueChart(BuildContext context, List<Order> orders) {
    // Generate some mock data based on real orders if possible, or just mock data
    // Group orders by hour/day
    final spots = <FlSpot>[
      const FlSpot(0, 100),
      const FlSpot(1, 150),
      const FlSpot(2, 80),
      const FlSpot(3, 200),
      const FlSpot(4, 180),
      const FlSpot(5, 250),
      const FlSpot(6, 300),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des revenus',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersChart(BuildContext context, List<Order> orders) {
     final barGroups = [
      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 5, color: Colors.blue)]),
      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 8, color: Colors.blue)]),
      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 6, color: Colors.blue)]),
      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 10, color: Colors.blue)]),
      BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 7, color: Colors.blue)]),
      BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 12, color: Colors.blue)]),
      BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 9, color: Colors.blue)]),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution des commandes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                     rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPerformance(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    // Mock data for pie chart
    final sections = [
      PieChartSectionData(value: 35, title: 'Burgers', color: Colors.orange, radius: 50),
      PieChartSectionData(value: 25, title: 'Pizza', color: Colors.red, radius: 50),
      PieChartSectionData(value: 20, title: 'Drinks', color: Colors.blue, radius: 50),
      PieChartSectionData(value: 20, title: 'Desserts', color: Colors.purple, radius: 50),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance par catégorie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverPerformance(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance des livreurs',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Tableau des livreurs\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            const Text('Zone: '),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedZone,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Toutes les zones'),
                  ),
                  DropdownMenuItem(
                    value: 'zone1',
                    child: Text('Zone 1 - Centre'),
                  ),
                  DropdownMenuItem(
                    value: 'zone2',
                    child: Text('Zone 2 - Nord'),
                  ),
                  DropdownMenuItem(value: 'zone3', child: Text('Zone 3 - Sud')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedZone = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContainer(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Carte interactive',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Google Maps\n(À implémenter avec google_maps_flutter)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverLocations(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Positions des livreurs',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Liste des livreurs en ligne\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotZones(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zones chaudes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Heatmap des commandes\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTrends(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tendances des ventes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Graphique des tendances\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularItems(
    BuildContext context,
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Articles populaires',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Graphique des articles populaires\n(À implémenter)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHours(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heures de pointe',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Graphique des heures de pointe\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInsights(BuildContext context, List<Order> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights clients',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Analyse des clients\n(À implémenter)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  double _calculateTodayRevenue(List<Order> orders) {
    final today = DateTime.now();
    return orders
        .where(
          (order) =>
              order.orderTime.day == today.day &&
              order.orderTime.month == today.month &&
              order.orderTime.year == today.year &&
              order.status == OrderStatus.delivered,
        )
        .fold(0.0, (sum, order) => sum + order.total);
  }

  int _getActiveDriversCount(List<Order> orders) {
    // This would typically come from a real-time service
    return 8; // Placeholder
  }

  List<Map<String, dynamic>> _getTopSellingItems(
    List<Order> orders,
    List<MenuItem> menuItems,
  ) {
    // This would calculate actual top selling items
    return [
      {'name': 'Burger Classique', 'quantity': 45, 'revenue': 225.0},
      {'name': 'Pizza Margherita', 'quantity': 38, 'revenue': 190.0},
      {'name': 'Frites', 'quantity': 52, 'revenue': 104.0},
      {'name': 'Coca-Cola', 'quantity': 67, 'revenue': 134.0},
      {'name': 'Salade César', 'quantity': 23, 'revenue': 115.0},
    ];
  }

  double _calculateAverageOrderValue(int totalOrders, double totalRevenue) {
    if (totalOrders == 0) return 0.0;
    return totalRevenue / totalOrders;
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
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
        return Colors.brown;
    }
  }

  // Navigation methods
  void _navigateToPromotions() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation vers promotions')));
  }

  void _navigateToDriverManagement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation vers gestion des livreurs')),
    );
  }

  void _navigateToNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation vers notifications')),
    );
  }

  void _navigateToReports() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation vers rapports')));
  }

  void _navigateToSettings() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation vers paramètres')));
  }

  void _navigateToOrderManagement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation vers gestion des commandes')),
    );
  }

  void _showOrderDetails(Order order) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statut: ${order.status.displayName}'),
                const SizedBox(height: 8),
                Text('Total: ${order.total.toStringAsFixed(2)}€'),
                const SizedBox(height: 8),
                Text('Articles: ${order.items.length}'),
                const SizedBox(height: 8),
                Text('Adresse: ${order.deliveryAddress}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
    final dialogHeight = 200.0;

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Paramètres',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
              // Contenu
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Paramètres du tableau de bord'),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
