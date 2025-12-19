import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/error_handler_service.dart';
import '../../models/order.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import '../delivery/driver_profile_screen.dart';
import '../delivery/settings_screen.dart';
import '../../ui/ui.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'today';

  // Données calculées à partir de l'historique des livraisons (source: AppService.driverOrderHistory)
  Map<String, dynamic> _earningsData = {};
  List<Map<String, dynamic>> _recentEarnings = [];

  @override
  void initState() {
    super.initState();
    _loadEarningsData();
  }

  Future<void> _loadEarningsData() async {
    if (!mounted) return;

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      // Load available orders to get latest data (with timeout)
      try {
        await appService.loadAvailableOrders().timeout(
          const Duration(seconds: 15),
        );
      } catch (e) {
        // Continuer même si le chargement échoue, utiliser les données en cache
        debugPrint('⚠️ Could not refresh orders, using cached data: $e');
      }

      // Les gains se calculent sur l'historique (livraisons terminées),
      // pas uniquement les livraisons actives.
      final deliveries = appService.driverOrderHistory
          .where((order) => order.status == OrderStatus.delivered)
          .toList();

      // Calculate earnings by period
      final todayDeliveries = deliveries
          .where((d) => _isToday(d.orderTime))
          .toList();
      final weekDeliveries = deliveries
          .where((d) => _isThisWeek(d.orderTime))
          .toList();
      final monthDeliveries = deliveries
          .where((d) => _isThisMonth(d.orderTime))
          .toList();

      // Calculate earnings (10% commission per delivery, plus estimated tips and bonuses)
      const commissionRate = 0.10;

      Map<String, num> calculateEarnings(List<Order> orders) {
        if (orders.isEmpty) {
          return {'total': 0.0, 'deliveries': 0, 'bonus': 0.0, 'tips': 0.0};
        }

        final baseEarnings = orders.fold<double>(
          0.0,
          (sum, order) => sum + (order.total * commissionRate),
        );
        final deliveriesCount = orders.length;
        final estimatedTips = baseEarnings * 0.1; // 10% of earnings as tips
        final estimatedBonus = deliveriesCount > 10
            ? baseEarnings * 0.05
            : 0.0; // 5% bonus if > 10 deliveries

        return {
          'total': baseEarnings + estimatedTips + estimatedBonus,
          'deliveries': deliveriesCount,
          'bonus': estimatedBonus,
          'tips': estimatedTips,
        };
      }

      if (mounted) {
        setState(() {
          _earningsData = {
            'today': calculateEarnings(todayDeliveries),
            'week': calculateEarnings(weekDeliveries),
            'month': calculateEarnings(monthDeliveries),
          };

          // Build recent earnings from recent deliveries (sorted by date)
          final sortedDeliveries = List<Order>.from(deliveries)
            ..sort((a, b) => b.orderTime.compareTo(a.orderTime));

          _recentEarnings = sortedDeliveries
              .take(10)
              .map(
                (order) => {
                  'id': order.id,
                  'orderId': order.id.substring(0, 8).toUpperCase(),
                  'amount': order.total * commissionRate,
                  'tip': (order.total * commissionRate * 0.1),
                  'bonus': 0.0,
                  'timestamp': order.orderTime,
                  'status': 'completed',
                },
              )
              .toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur chargement gains', details: e);
        errorHandler.showErrorSnackBar(
          context,
          'Erreur de chargement des gains: $e',
        );
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.month == now.month && date.year == now.year;
  }

  Future<void> _requestWithdrawal() async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final totalEarnings = _getCurrentEarnings()['total'] ?? 0.0;

      if (totalEarnings <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun solde disponible pour le retrait'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // In real app, integrate with PayDunya for withdrawal
      await appService.requestWithdrawal(totalEarnings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait soumise avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur retrait', details: e);
        errorHandler.showErrorSnackBar(context, 'Erreur de retrait: $e');
      }
    }
  }

  Map<String, dynamic> _getCurrentEarnings() {
    return _earningsData[_selectedPeriod] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes gains'),
        actions: [
          IconButton(
            onPressed: _requestWithdrawal,
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Demander un retrait',
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
          ? const LoadingWidget(message: 'Chargement des gains...')
          : SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSection(
                    title: 'Période',
                    padding: EdgeInsets.zero,
                    child: _buildPeriodSelector(),
                  ),
                  AppSection(title: 'Résumé', child: _buildEarningsSummary()),
                  AppSection(title: 'Détail', child: _buildEarningsBreakdown()),
                  AppSection(title: 'Récents', child: _buildRecentEarnings()),
                  AppSection(
                    title: 'Retrait',
                    child: _buildWithdrawalSection(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _buildPeriodButton('Aujourd\'hui', 'today'),
        const SizedBox(width: AppSpacing.sm),
        _buildPeriodButton('Semaine', 'week'),
        const SizedBox(width: AppSpacing.sm),
        _buildPeriodButton('Mois', 'month'),
      ],
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: FilledButton(
        onPressed: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        style: FilledButton.styleFrom(
          backgroundColor: isSelected
              ? scheme.primary
              : scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          foregroundColor: isSelected ? scheme.onPrimary : scheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEarningsSummary() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final earnings = _getCurrentEarnings();

    return AppCard(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gains totaux',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${earnings['total']?.toStringAsFixed(0) ?? '0'} FCFA',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildSummaryChip(
                  'Livraisons',
                  '${earnings['deliveries'] ?? 0}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryChip(
                  'Bonus',
                  '${earnings['bonus']?.toStringAsFixed(0) ?? '0'}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryChip(
                  'Pourboires',
                  '${earnings['tips']?.toStringAsFixed(0) ?? '0'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdown() {
    final earnings = _getCurrentEarnings();
    final deliveriesCount = earnings['deliveries'] ?? 0;
    final baseAmount = earnings['total'] ?? 0.0;
    final deliveriesEarning =
        baseAmount - (earnings['tips'] ?? 0.0) - (earnings['bonus'] ?? 0.0);
    final avgPerDelivery = deliveriesCount > 0
        ? deliveriesEarning / deliveriesCount
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détail des gains',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildBreakdownItem(
              'Livraisons',
              '$deliveriesCount livraison${deliveriesCount > 1 ? 's' : ''}',
              '${deliveriesEarning.toStringAsFixed(0)} FCFA',
              Icons.delivery_dining,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Bonus',
              'Prime de performance',
              '${earnings['bonus']?.toStringAsFixed(0) ?? '0'} FCFA',
              Icons.star,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Pourboires',
              'Gratifications clients',
              '${earnings['tips']?.toStringAsFixed(0) ?? '0'} FCFA',
              Icons.volunteer_activism,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Gain moyen',
              'par livraison',
              '${avgPerDelivery.toStringAsFixed(0)} FCFA',
              Icons.payments_outlined,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(
    String title,
    String subtitle,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEarnings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gains récents',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._recentEarnings.map((earning) => _buildEarningItem(earning)),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningItem(Map<String, dynamic> earning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande ${earning['orderId']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatTimestamp(earning['timestamp']),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(earning['amount'] + earning['tip'] + earning['bonus']).toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (earning['tip'] > 0)
                Text(
                  '+${earning['tip'].toStringAsFixed(0)} FCFA pourboire',
                  style: TextStyle(color: Colors.green[600], fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalSection() {
    final totalEarnings = _getCurrentEarnings()['total'] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retrait',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde disponible',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        '${totalEarnings.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomButton(
                  text: 'Retirer',
                  onPressed: totalEarnings > 0 ? _requestWithdrawal : null,
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les retraits sont traités dans les 24h via PayDunya',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}
