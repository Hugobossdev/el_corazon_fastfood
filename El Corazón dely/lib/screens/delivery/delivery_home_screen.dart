import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../widgets/delivery_order_card.dart';
import '../../services/paydunya_service.dart';
import '../../services/address_service.dart';
import '../../services/promo_code_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import '../../models/order.dart';
import '../payments/earnings_screen.dart';
import '../communication/chat_screen.dart';
import 'real_time_tracking_screen.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';
import '../../ui/ui.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    // Refresh orders every 30 seconds
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isRefreshing) {
        _refreshOrders(silent: true);
      }
    });
  }

  Future<void> _refreshOrders({bool silent = false}) async {
    // Debounce: Ne pas rafraîchir si le dernier rafraîchissement était il y a moins de 5 secondes
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) <
            const Duration(seconds: 5)) {
      return;
    }

    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _lastRefreshTime = DateTime.now();
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await Future.wait([
        appService.loadAvailableOrders(
            forceRefresh: true, includeAvailable: false),
        appService.loadDriverHistory(forceRefresh: true),
      ]);

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commandes mises à jour'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur rafraîchissement commandes', details: e);
        if (!silent) {
          errorHandler.showErrorSnackBar(
            context,
            'Erreur lors du rafraîchissement',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    if (!context.mounted) return;
    try {
      final appService = Provider.of<AppService>(context, listen: false);

      // Ensure AppService is fully initialized
      if (!appService.isInitialized) {
        await appService.initialize();
      }

      if (!context.mounted) return;

      // If user is logged in but profile not loaded, try loading it again
      if (appService.currentUser == null) {
        final authUser = appService.databaseService.currentUser;
        if (authUser != null) {
          // We can't access _loadUserProfile directly as it is private,
          // but initialize() calls it.
          // If we are here, initialize() might have failed to load user.
          // We can try logout/login logic or just show error.
        }
      }

      // Initialiser les services optionnels (ne pas bloquer si échec)
      try {
        if (!mounted || !context.mounted) return;
        await Provider.of<AddressService>(
          context,
          listen: false,
        ).initialize().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ AddressService initialization failed: $e');
      }

      try {
        if (!mounted || !context.mounted) return;
        await Provider.of<PromoCodeService>(
          context,
          listen: false,
        ).initialize().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ PromoCodeService initialization failed: $e');
      }

      try {
        if (!mounted || !context.mounted) return;
        // Initialiser PayDunya avec des clés de test
        await Provider.of<PayDunyaService>(context, listen: false)
            .initialize(
              masterKey: 'test_master_key',
              privateKey: 'test_private_key',
              token: 'test_token',
              isSandbox: true,
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ PayDunyaService initialization failed: $e');
      }

      // Load available orders from database (essentiel)
      try {
        if (!mounted || !context.mounted) return;
        await appService
            .loadAvailableOrders(forceRefresh: true, includeAvailable: false)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('⚠️ Failed to load orders: $e');
        // Ne pas bloquer l'application si le chargement échoue
        // Les commandes seront chargées lors du rafraîchissement
      }

      if (mounted) {
        debugPrint('✅ Services initialisés');
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      debugPrint('❌ Erreur initialisation services: $e');
      final errorHandler = Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      );
      errorHandler.logError('Erreur initialisation services', details: e);
      // Ne pas afficher d'erreur si c'est juste un service optionnel qui a échoué
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          Consumer<AppService>(
            builder: (context, appService, child) {
              final user = appService.currentUser;
              if (user == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: () => _toggleOnlineStatus(context),
                icon: Icon(
                  user.isOnline ? Icons.online_prediction : Icons.offline_pin,
                  color: user.isOnline
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EarningsScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Mes gains',
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
          ? const Center(child: CircularProgressIndicator())
          : Consumer<AppService>(
              builder: (context, appService, child) {
                final user = appService.currentUser;

                // Si l'initialisation est terminée mais pas d'utilisateur, c'est une erreur
                if (user == null && appService.isInitialized) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Impossible de charger le profil',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Votre session a peut-être expiré ou le profil est incomplet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              _initializeServices();
                            },
                            child: const Text('Réessayer'),
                          ),
                          TextButton(
                            onPressed: () {
                              appService.logout();
                              Navigator.of(context).pushReplacementNamed(
                                '/login',
                              ); // Ou votre route de login
                            },
                            child: const Text('Se déconnecter'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (user == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Chargement du profil...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                try {
                  final assignedDeliveries = appService.assignedDeliveries;

                  // Filter available orders (orders are already loaded via initState)
                  final availableOrders = appService.orders
                      .where(
                        (order) =>
                            order.status == OrderStatus.ready &&
                            order.deliveryPersonId == null,
                      )
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () => _refreshOrders(silent: false),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.pagePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isRefreshing)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Mise à jour...',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          _buildHeader(context, user),
                          AppSection(
                            title: 'Aperçu',
                            child: _buildStatsCard(context, assignedDeliveries),
                          ),
                          AppSection(
                            title: 'Commandes disponibles',
                            trailing:
                                _countPill(context, availableOrders.length),
                            child:
                                _buildAvailableOrders(context, availableOrders),
                          ),
                          AppSection(
                            title: 'Mes livraisons',
                            child:
                                _buildMyDeliveries(context, assignedDeliveries),
                          ),
                        ],
                      ),
                    ),
                  );
                } catch (e) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                            'Erreur de chargement',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e.toString(),
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              _initializeServices();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }

  Widget _buildHeader(BuildContext context, user) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOnline = user.isOnline == true;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.surface,
            child: Text(
              (user.name ?? 'DR').toString().substring(0, 2).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, ${user.name} !',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      isOnline
                          ? Icons.online_prediction
                          : Icons.do_not_disturb_on_outlined,
                      size: 16,
                      color:
                          isOnline ? scheme.secondary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isOnline ? 'En ligne' : 'Hors ligne',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!isOnline) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Activez votre statut pour recevoir des commandes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => _toggleOnlineStatus(context),
            icon: Icon(isOnline
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline),
            label: Text(isOnline ? 'Pause' : 'Activer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, List<Order> assignedDeliveries) {
    final completedToday = assignedDeliveries
        .where(
          (order) =>
              order.status == OrderStatus.delivered &&
              _isToday(order.orderTime),
        )
        .length;

    final activeDeliveries = assignedDeliveries
        .where(
          (order) =>
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled,
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Livraisons du jour',
            '$completedToday',
            Icons.check_circle,
            Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'En cours',
            '$activeDeliveries',
            Icons.delivery_dining,
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableOrders(
    BuildContext context,
    List<Order> availableOrders,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (availableOrders.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aucune commande disponible',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Les nouvelles commandes apparaîtront ici.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: availableOrders
          .take(3)
          .map(
            (order) => DeliveryOrderCard(
              order: order,
              isAvailable: true,
              onAccept: () => _acceptOrder(context, order),
            ),
          )
          .toList(),
    );
  }

  // _buildAvailableOrderCard supprimé (remplacé par DeliveryOrderCard)

  Widget _buildMyDeliveries(BuildContext context, List<Order> myDeliveries) {
    final activeDeliveries = myDeliveries
        .where(
          (order) =>
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled,
        )
        .toList();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (activeDeliveries.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aucune livraison en cours',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vos livraisons assignées apparaîtront ici.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: activeDeliveries
          .map(
            (order) => DeliveryOrderCard(
              order: order,
              isAvailable: false,
              onNavigate: () => _navigateToOrder(context, order),
              onAction: () => _updateDeliveryStatus(context, order),
              onChat: () => _openChat(context, order),
              onSupport: () => _openSupportChat(context, order),
              actionLabel: _getNextActionText(order.status),
              actionIcon: _getNextActionIcon(order.status),
            ),
          )
          .toList(),
    );
  }

  Widget _countPill(BuildContext context, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // _buildMyDeliveryCard supprimé (remplacé par DeliveryOrderCard)

  Future<void> _toggleOnlineStatus(BuildContext context) async {
    final appService = Provider.of<AppService>(context, listen: false);
    final user = appService.currentUser;
    if (user == null) return;

    try {
      // Mettre à jour le statut dans la base de données
      final newStatus = !user.isOnline;
      await appService.updateOnlineStatus(newStatus);

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Vous êtes maintenant en ligne'
                : 'Vous êtes maintenant hors ligne',
          ),
          backgroundColor: newStatus ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
      // Rafraîchir l'interface
      setState(() {});
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour du statut: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptOrder(BuildContext context, Order order) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final performanceService = Provider.of<PerformanceService>(
        context,
        listen: false,
      );

      // Mesurer les performances
      performanceService.startTimer('accept_delivery');

      await appService.acceptDelivery(order.id);

      performanceService.stopTimer('accept_delivery');

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Livraison acceptée pour la commande #${order.id.substring(0, 8).toUpperCase()}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Forcer le rafraîchissement pour charger les commandes assignées
      await appService.loadAvailableOrders(
          forceRefresh: true, includeAvailable: false);

      if (!mounted || !context.mounted) return;
      // Rafraîchir l'interface
      setState(() {});
    } catch (e) {
      if (!mounted || !context.mounted) return;
      final errorHandler = Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      );
      errorHandler.logError('Erreur acceptation livraison', details: e);
      errorHandler.showErrorSnackBar(
        context,
        'Erreur lors de l\'acceptation de la livraison: $e',
      );
    }
  }

  void _navigateToOrder(BuildContext context, Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealTimeTrackingScreen(order: order),
      ),
    );
  }

  Future<void> _updateDeliveryStatus(BuildContext context, Order order) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      OrderStatus nextStatus;

      // Workflow: confirmed (accepted) → picked_up → on_the_way → delivered
      switch (order.status) {
        case OrderStatus.confirmed:
          // After accepting, mark as picked up when arriving at restaurant
          nextStatus = OrderStatus.pickedUp;
          await appService.markOrderPickedUp(order.id);
          break;
        case OrderStatus.pickedUp:
          // After picking up, mark as on the way
          nextStatus = OrderStatus.onTheWay;
          await appService.markOrderOnTheWay(order.id);
          break;
        case OrderStatus.onTheWay:
          // After arriving, mark as delivered
          nextStatus = OrderStatus.delivered;
          await appService.markOrderDelivered(order.id);
          break;
        default:
          return;
      }

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande mise à jour: ${nextStatus.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh orders after status update
      await _refreshOrders(silent: true);
    } catch (e) {
      if (!mounted || !context.mounted) return;
      final errorHandler = Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      );
      errorHandler.logError('Erreur mise à jour statut', details: e);
      errorHandler.showErrorSnackBar(
        context,
        'Erreur lors de la mise à jour: $e',
      );
    }
  }

  String _getNextActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Récupérée';
      case OrderStatus.pickedUp:
        return 'En route';
      case OrderStatus.onTheWay:
        return 'Livré';
      default:
        return 'Suivant';
    }
  }

  IconData _getNextActionIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Icons.shopping_bag;
      case OrderStatus.pickedUp:
        return Icons.delivery_dining;
      case OrderStatus.onTheWay:
        return Icons.check_circle;
      default:
        return Icons.arrow_forward;
    }
  }

  void _openChat(BuildContext context, Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(order: order, chatType: 'customer'),
      ),
    );
  }

  void _openSupportChat(BuildContext context, Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(order: order, chatType: 'support'),
      ),
    );
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year;
  }
}
