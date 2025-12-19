import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/promo_code_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import '../../models/promo_code.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';
import '../../ui/ui.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await Provider.of<PromoCodeService>(context, listen: false).initialize();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur initialisation codes promo', details: e);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes promo'),
        actions: [
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
      body: Column(
        children: [
          _buildCodeInputSection(),
          const Divider(),
          Expanded(
            child: _buildPromoCodesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputSection() {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appliquer un code promo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code promo',
                      hintText: 'Entrez votre code',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: _isLoading ? null : _applyPromoCode,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Appliquer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodesList() {
    return Consumer<PromoCodeService>(
      builder: (context, promoCodeService, child) {
        if (!promoCodeService.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (promoCodeService.usedPromoCodes.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: AppSpacing.pagePadding,
          itemCount: promoCodeService.usedPromoCodes.length,
          itemBuilder: (context, index) {
            final usage = promoCodeService.usedPromoCodes[index];
            return _buildPromoCodeCard(usage);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_offer_outlined, size: 44, color: scheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aucun code promo utilisé',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Appliquez un code promo pour voir vos économies.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCodeCard(PromoCodeUsage usage) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final promoColor = _getPromoTypeColor(
      context,
      usage.promoCode?.type ?? PromoCodeType.percentage,
    );
    final statusColor = _getStatusColor(context, usage.status);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: promoColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(Icons.card_giftcard_outlined, color: promoColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usage.promoCode?.code ?? 'Code inconnu',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      usage.promoCode?.description ?? 'Description non disponible',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Text(
                  usage.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _infoPair(
                  label: 'Économie',
                  value: '${usage.discountAmount.toStringAsFixed(0)} FCFA',
                  valueColor: scheme.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _infoPair(
                  label: 'Utilisé le',
                  value: _formatDate(usage.usedAt),
                ),
              ),
            ],
          ),
          if (usage.promoCode?.type == PromoCodeType.percentage) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: (usage.promoCode?.usageCount ?? 0) /
                  (usage.promoCode?.usageLimit ?? 1),
              valueColor: AlwaysStoppedAnimation<Color>(promoColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${usage.promoCode?.usageCount ?? 0}/${usage.promoCode?.usageLimit ?? 1} utilisations',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPair({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: valueColor ?? scheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _applyPromoCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un code promo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Provider.of<PerformanceService>(context, listen: false)
          .startTimer('apply_promo_code');

      final promoCodeService =
          Provider.of<PromoCodeService>(context, listen: false);

      // Utiliser l'ID de l'utilisateur connecté
      final appService = Provider.of<AppService>(context, listen: false);
      final userId = appService.currentUser?.id;
      
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Simuler un montant de commande pour le test si pas de commande active
      // Idéalement, on devrait passer la commande en cours ou le panier
      const testOrderAmount = 5000.0;

      final result = await promoCodeService.validateAndApplyPromoCode(
        code: _codeController.text.trim(),
        orderAmount: testOrderAmount,
        userId: userId,
      );

      if (!mounted || !context.mounted) return;
      Provider.of<PerformanceService>(context, listen: false)
          .stopTimer('apply_promo_code');

      if (result.isValid) {
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Code appliqué! Économie: ${result.discountAmount.toStringAsFixed(2)} FCFA',
              ),
              backgroundColor: Colors.green,
            ),
          );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Code promo invalide'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur application code promo', details: e);
      Provider.of<ErrorHandlerService>(context, listen: false)
          .showErrorSnackBar(
              context, 'Erreur lors de l\'application du code promo');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getPromoTypeColor(BuildContext context, PromoCodeType type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case PromoCodeType.percentage:
        return scheme.primary;
      case PromoCodeType.fixedAmount:
        return scheme.secondary;
      case PromoCodeType.freeDelivery:
        return scheme.tertiary;
      case PromoCodeType.buyOneGetOne:
        return scheme.onSurface;
    }
  }

  Color _getStatusColor(BuildContext context, PromoCodeStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case PromoCodeStatus.active:
        return scheme.secondary;
      case PromoCodeStatus.inactive:
        return scheme.outline;
      case PromoCodeStatus.expired:
        return scheme.error;
      case PromoCodeStatus.usedUp:
        return scheme.outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
