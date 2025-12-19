import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import 'delivery_home_screen.dart';
import 'delivery_orders_screen.dart';
import 'analytics_screen.dart';
import 'address_management_screen.dart';
import 'promo_codes_screen.dart';
import 'settings_screen.dart';
import 'driver_profile_screen.dart';
import '../payments/earnings_screen.dart';
import '../payments/driver_payment_screen.dart';
import '../communication/chat_screen.dart';
import '../../ui/ui.dart';

class DeliveryNavigationScreen extends StatefulWidget {
  const DeliveryNavigationScreen({super.key});

  @override
  State<DeliveryNavigationScreen> createState() =>
      _DeliveryNavigationScreenState();
}

class _DeliveryNavigationScreenState extends State<DeliveryNavigationScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeServices();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;

    try {
      await Provider.of<PerformanceService>(
        context,
        listen: false,
      ).initialize().timeout(const Duration(seconds: 10));
      if (!mounted || !context.mounted) return;
      await Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      ).initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      if (!mounted || !context.mounted) return;
      final errorHandler = Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      );
      errorHandler.logError('Erreur initialisation services', details: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          DeliveryHomeScreen(),
          DeliveryOrdersScreen(),
          AnalyticsScreen(),
          EarningsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Livraisons',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Gains',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(
            icon: Icons.home,
            title: 'Accueil',
            onTap: () => _navigateToPage(0),
          ),
          _buildDrawerItem(
            icon: Icons.delivery_dining,
            title: 'Mes livraisons',
            onTap: () => _navigateToPage(1),
          ),
          _buildDrawerItem(
            icon: Icons.analytics,
            title: 'Analytics & Performance',
            onTap: () => _navigateToPage(2),
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_wallet,
            title: 'Mes gains',
            onTap: () => _navigateToPage(3),
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.location_on,
            title: 'Gestion des adresses',
            onTap: () => _navigateToAddressManagement(),
          ),
          _buildDrawerItem(
            icon: Icons.local_offer,
            title: 'Codes promo',
            onTap: () => _navigateToPromoCodes(),
          ),
          _buildDrawerItem(
            icon: Icons.payment,
            title: 'Paiements',
            onTap: () => _navigateToPayments(),
          ),
          _buildDrawerItem(
            icon: Icons.chat,
            title: 'Support',
            onTap: () => _navigateToSupport(),
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.person,
            title: 'Mon profil',
            onTap: () => _navigateToProfile(),
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Paramètres',
            onTap: () => _navigateToSettings(),
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Déconnexion',
            onTap: () => _logout(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final user = appService.currentUser;
        return DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.85)],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProfile();
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.surface,
                    child: Text(
                      _initials(user?.name ?? 'DR'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Livreur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'driver@fasteat.ci',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user?.isOnline == true
                        ? scheme.secondary.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user?.isOnline == true ? 'En ligne' : 'Hors ligne',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? scheme.error : scheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? scheme.error : null),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showQuickActions,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      child: const Icon(Icons.add),
    );
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToAddressManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressManagementScreen()),
    );
  }

  void _navigateToPromoCodes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PromoCodesScreen()),
    );
  }

  void _navigateToPayments() {
    final appService = Provider.of<AppService>(context, listen: false);
    final assignedDeliveries = appService.assignedDeliveries;

    if (assignedDeliveries.isNotEmpty) {
      final order = assignedDeliveries.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DriverPaymentScreen(order: order, amount: order.total),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune commande disponible pour le paiement'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _navigateToSupport() {
    final appService = Provider.of<AppService>(context, listen: false);
    final assignedDeliveries = appService.assignedDeliveries;

    if (assignedDeliveries.isNotEmpty) {
      final order = assignedDeliveries.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(order: order, chatType: 'support'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune commande active : impossible d’ouvrir le support.',
          ),
        ),
      );
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
    );
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        if (!mounted || !context.mounted) return;
        final appService = Provider.of<AppService>(context, listen: false);
        await appService.logout();

        if (!mounted || !context.mounted) return;
        // Revenir sur l'écran de login (route déclarée dans main.dart)
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        if (!mounted || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Actions rapides',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.location_on,
                    title: 'Adresses',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAddressManagement();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.local_offer,
                    title: 'Codes promo',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToPromoCodes();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.payment,
                    title: 'Paiement',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToPayments();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.chat,
                    title: 'Support',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSupport();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.person,
                    title: 'Profil',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToProfile();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.settings,
                    title: 'Paramètres',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSettings();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'DR';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'DR';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p.substring(0, 1))
          .toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
