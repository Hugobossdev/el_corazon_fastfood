import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/analytics_service.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/price_formatter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _generalStats;
  Map<String, dynamic>? _revenueData;
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _categoryData;
  Map<String, dynamic>? _driverData;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);

    // Charger les statistiques générales
    _generalStats = await analyticsService.getGeneralStats();

    // Charger les données de revenus
    _revenueData = await analyticsService.getRevenueAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Charger les données des commandes
    _orderData = await analyticsService.getOrderAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Charger les données des catégories
    _categoryData = await analyticsService.getCategoryAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    // Charger les données des livreurs
    _driverData = await analyticsService.getDriverAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pas d'AppBar ici car il est déjà géré par AdminNavigationScreen
    return Column(
      children: [
        // Barre d'actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loadAnalytics,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    // IMPORTANT: Row avec contraintes pour garantir des contraintes
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Actualiser'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Contenu
        Expanded(
          child: Consumer<AnalyticsService>(
        builder: (context, analyticsService, child) {
          if (analyticsService.isLoading) {
            return const LoadingWidget(message: 'Chargement des analytics...');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateRangeSelector(),
                const SizedBox(height: 20),
                _buildGeneralStatsCard(),
                const SizedBox(height: 20),
                _buildRevenueCard(),
                const SizedBox(height: 20),
                _buildOrdersCard(),
                const SizedBox(height: 20),
                _buildCategoriesCard(),
                const SizedBox(height: 20),
                _buildDriversCard(),
              ],
            ),
          );
        },
      ),
    ),
    ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Période d\'analyse',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de début'),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                              });
                              _loadAnalytics();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(
                              minHeight: 48,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // IMPORTANT: Row sans mainAxisSize.min car le Container a width: double.infinity
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de fin'),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _endDate = date;
                              });
                              _loadAnalytics();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(
                              minHeight: 48,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // IMPORTANT: Row sans mainAxisSize.min car le Container a width: double.infinity
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralStatsCard() {
    if (_generalStats == null) return const SizedBox.shrink();

    final orders = _generalStats!['orders'] as Map<String, dynamic>;
    final revenue = _generalStats!['revenue'] as Map<String, dynamic>;
    final users = _generalStats!['users'] as Map<String, dynamic>;
    final products = _generalStats!['products'] as Map<String, dynamic>;
    final drivers = _generalStats!['drivers'] as Map<String, dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques Générales',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  'Commandes Total',
                  orders['total'].toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Commandes Complétées',
                  orders['completed'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Revenus Total',
                  formatPrice(revenue['total']),
                  Icons.attach_money,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Valeur Moyenne',
                  formatPrice(revenue['averageOrderValue']),
                  Icons.trending_up,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Utilisateurs',
                  users['total'].toString(),
                  Icons.people,
                  Colors.teal,
                ),
                _buildStatCard(
                  'Produits',
                  products['total'].toString(),
                  Icons.restaurant,
                  Colors.red,
                ),
                _buildStatCard(
                  'Livreurs Actifs',
                  drivers['active'].toString(),
                  Icons.delivery_dining,
                  Colors.indigo,
                ),
                _buildStatCard(
                  'Taux de Complétion',
                  '${orders['completionRate'].toStringAsFixed(1)}%',
                  Icons.percent,
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    if (_revenueData == null) return const SizedBox.shrink();

    final totalRevenue = _revenueData!['totalRevenue'] as double;
    final dailyRevenue = _revenueData!['dailyRevenue'] as Map<String, double>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses des Revenus',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Revenus Total',
                    formatPrice(totalRevenue),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Jours Actifs',
                    dailyRevenue.length.toString(),
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            if (dailyRevenue.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Revenus par jour:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...dailyRevenue.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(formatPrice(entry.value)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersCard() {
    if (_orderData == null) return const SizedBox.shrink();

    final totalOrders = _orderData!['totalOrders'] as int;
    final statusCounts = _orderData!['statusCounts'] as Map<String, int>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses des Commandes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              'Total Commandes',
              totalOrders.toString(),
              Icons.shopping_cart,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'Répartition par statut:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...statusCounts.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(entry.value.toString()),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesCard() {
    if (_categoryData == null) return const SizedBox.shrink();

    final categoryCounts = _categoryData!['categoryCounts'] as Map<String, int>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses par Catégorie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (categoryCounts.isNotEmpty) ...[
              Text(
                'Commandes par catégorie:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...categoryCounts.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(entry.value.toString()),
                      ],
                    ),
                  )),
            ] else ...[
              const Text('Aucune donnée disponible pour cette période.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriversCard() {
    if (_driverData == null) return const SizedBox.shrink();

    final driverDeliveries =
        _driverData!['driverDeliveries'] as Map<String, int>;
    // final driverRatings = _driverData!['driverRatings'] as Map<String, double>; // Variable non utilisée

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyses des Livreurs',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (driverDeliveries.isNotEmpty) ...[
              Text(
                'Livraisons par livreur:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...driverDeliveries.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} livraisons'),
                      ],
                    ),
                  )),
            ] else ...[
              const Text('Aucune donnée disponible pour cette période.'),
            ],
          ],
        ),
      ),
    );
  }
}
