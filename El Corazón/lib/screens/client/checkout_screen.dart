import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/widgets/auth_style_card.dart';
import 'package:elcora_fast/widgets/auth_style_text_field.dart';
import 'package:elcora_fast/widgets/auth_style_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/screens/client/payment_screen.dart';
import 'package:elcora_fast/screens/client/address_selector_screen.dart';

/// Écran de finalisation de commande
class CheckoutScreen extends StatefulWidget {
  final String? existingOrderId;
  final List<CartItem>? preloadedItems;
  final double? preloadedTotal;

  const CheckoutScreen({
    super.key,
    this.existingOrderId,
    this.preloadedItems,
    this.preloadedTotal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _selectedPayment = PaymentMethod.mobileMoney;
  bool _isLoading = false;
  bool _isCalculatingDeliveryFee = false;
  Address? _selectedAddress;
  double? _estimatedDistance;
  int? _estimatedDeliveryTime;

  final AddressService _addressService = AddressService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
    _initializeDeliveryFeeService();
  }

  Future<void> _initializeDeliveryFeeService() async {
    try {
      await _deliveryFeeService.initialize();
    } catch (e) {
      debugPrint('Erreur initialisation DeliveryFeeService: $e');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAddress() async {
    try {
      // Initialiser le service si nécessaire
      if (!_addressService.isInitialized) {
        await _addressService.initialize();
      }

      // Charger l'adresse par défaut de l'utilisateur
      final defaultAddress = _addressService.defaultAddress;

      if (defaultAddress != null) {
        _selectedAddress = defaultAddress;
        _addressController.text = defaultAddress.fullAddress;
        // Calculer les frais de livraison automatiquement
        await _calculateDeliveryFeeForAddress(defaultAddress);
      } else if (_addressService.addresses.isNotEmpty) {
        final firstAddress = _addressService.addresses.first;
        _selectedAddress = firstAddress;
        _addressController.text = firstAddress.fullAddress;
        await _calculateDeliveryFeeForAddress(firstAddress);
      } else {
        _addressController.text = '';
      }
    } catch (e) {
      debugPrint('Erreur chargement adresse: $e');
      _addressController.text = '';
    }
  }

  Future<void> _calculateDeliveryFeeForAddress(Address? address) async {
    if (address == null) return;

    setState(() {
      _isCalculatingDeliveryFee = true;
    });

    try {
      final cartService = context.read<CartService>();

      // Calculer les frais de livraison
      await cartService.calculateAndSetDeliveryFee(address: address);

      // Obtenir les informations supplémentaires (distance, temps)
      final deliveryInfo = await _deliveryFeeService.getDeliveryInfo(
        deliveryAddress: address.fullAddress,
        deliveryLatitude: address.latitude,
        deliveryLongitude: address.longitude,
      );

      if (mounted) {
        setState(() {
          _estimatedDistance = deliveryInfo['distance'] as double?;
          _estimatedDeliveryTime = deliveryInfo['estimatedTime'] as int?;
        });
      }
    } catch (e) {
      debugPrint('Erreur calcul frais livraison: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingDeliveryFee = false;
        });
      }
    }
  }

  Future<void> _selectAddress() async {
    final selected = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (context) => AddressSelectorScreen(
          currentAddress: _selectedAddress,
          onAddressSelected: (Address address) {
            Navigator.of(context).pop(address);
          },
        ),
      ),
    );

    if (selected != null && mounted && context.mounted) {
      setState(() {
        _selectedAddress = selected;
        _addressController.text = selected.fullAddress;
      });
      await _calculateDeliveryFeeForAddress(selected);
    }
  }

  // NOTE: V2 adresses: plus de saisie libre dans le checkout.
  // L'utilisateur doit sélectionner une Address (avec lat/lng).

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
        // UX: checkout = focus (notifications ailleurs)
      ),
      body: Consumer2<AppService, CartService>(
        builder: (context, appService, cartService, child) {
          final isGroupOrder = widget.existingOrderId != null;
          final cartItems =
              isGroupOrder ? (widget.preloadedItems ?? []) : cartService.items;
          final subtotal = isGroupOrder
              ? (widget.preloadedTotal ?? 0.0)
              : cartService.subtotal;
          final deliveryFee = cartService.deliveryFee;
          final discount = isGroupOrder ? 0.0 : cartService.discount;
          final total = subtotal + deliveryFee - discount;

          if (cartItems.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepHeader(context, '1. Récapitulatif'),
                        const SizedBox(height: 8),
                        _buildOrderSummary(
                          context,
                          cartItems,
                          subtotal,
                          deliveryFee,
                          discount,
                          total,
                          cartService.itemCount,
                          cartService.promoCode,
                        ),
                        const SizedBox(height: 24),
                        _buildStepHeader(context, '2. Livraison'),
                        const SizedBox(height: 8),
                        _buildDeliverySection(context),
                        const SizedBox(height: 24),
                        _buildStepHeader(context, '3. Paiement'),
                        const SizedBox(height: 8),
                        _buildPaymentSection(context),
                        const SizedBox(height: 24),
                        _buildStepHeader(context, '4. Notes'),
                        const SizedBox(height: 8),
                        _buildNotesSection(context),
                      ],
                    ),
                  ),
                ),
                _buildCheckoutButton(context, appService, cartService, total),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context, String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Votre panier est vide',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Ajoutez des plats à votre panier avant de commander',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 30),
          CustomButton(text: 'Voir le menu', onPressed: () => context.goBack()),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    List<CartItem> cartItems,
    double subtotal,
    double deliveryFee,
    double discount,
    double total,
    int itemCount,
    String? promoCode,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé de la commande',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...cartItems.map((item) => _buildOrderItem(context, item)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sous-total (${cartItems.length} article${cartItems.length > 1 ? 's' : ''})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  PriceFormatter.format(subtotal),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Livraison',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  PriceFormatter.format(deliveryFee),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (discount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remise${promoCode != null ? ' ($promoCode)' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.green),
                  ),
                  Text(
                    '-${PriceFormatter.format(discount)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  PriceFormatter.format(total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 40,
              height: 40,
              color: Colors.grey[200],
              child: item.imageUrl?.isNotEmpty == true
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.fastfood,
                          color: Colors.grey[400],
                          size: 20,
                        );
                      },
                    )
                  : Icon(Icons.fastfood, color: Colors.grey[400], size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Quantité: ${item.quantity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                Text(
                  PriceFormatter.format(item.totalPrice),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(BuildContext context) {
    return AuthStyleCard(
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
              const Spacer(),
              TextButton.icon(
                onPressed: _selectAddress,
                icon: const Icon(Icons.edit_location_alt),
                label: const Text('Changer'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AuthStyleTextField(
            controller: _addressController,
            label: 'Adresse sélectionnée',
            hintText: 'Sélectionnez une adresse',
            icon: Icons.location_on,
            maxLines: 3,
            enabled: false,
            validator: (_) {
              if (_selectedAddress == null) {
                return 'Veuillez sélectionner une adresse';
              }
              if (_selectedAddress!.latitude == null ||
                  _selectedAddress!.longitude == null) {
                return 'Adresse invalide (coordonnées manquantes)';
              }
              return null;
            },
          ),
          if (_isCalculatingDeliveryFee) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Text(
              'Calcul des frais de livraison...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          if (_estimatedDistance != null && !_isCalculatingDeliveryFee) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.straighten,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Distance: ${_estimatedDistance!.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_estimatedDeliveryTime != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Temps estimé: $_estimatedDeliveryTime min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    return AuthStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Méthode de paiement',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values.map((method) {
              final selected = _selectedPayment == method;
              return ChoiceChip(
                label: Text('${method.emoji} ${method.displayName}'),
                selected: selected,
                onSelected: (_) => setState(() => _selectedPayment = method),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedPayment.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return AuthStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Instructions spéciales',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AuthStyleTextField(
            controller: _notesController,
            label: 'Instructions pour le livreur (optionnel)',
            hintText: 'Ex: Sonner à la porte, laisser devant la porte...',
            icon: Icons.note,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    AppService appService,
    CartService cartService,
    double total,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total à payer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  PriceFormatter.format(total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthStyleButton(
              text: _isLoading ? 'Traitement...' : 'Confirmer la commande',
              onPressed: _isLoading
                  ? null
                  : () => _placeOrder(context, appService, cartService, total),
              isLoading: _isLoading,
              width: double.infinity,
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(
    BuildContext context,
    AppService appService,
    CartService cartService,
    double total,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use existing order ID or generate new one
      final orderId = widget.existingOrderId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Navigate to payment screen
      final paymentSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            orderId: orderId,
            amount: total,
            paymentMethod: _selectedPayment,
            customerName: appService.currentUser?.name ?? 'Client',
            customerEmail: appService.currentUser?.email ?? '',
            customerPhone: appService.currentUser?.phone ?? '',
          ),
        ),
      );

      if (paymentSuccess == true && mounted) {
        // V2: checkout = adresse sélectionnée obligatoire (avec lat/lng)
        final addressToUse = _selectedAddress;
        if (addressToUse == null ||
            addressToUse.latitude == null ||
            addressToUse.longitude == null) {
          throw Exception(
            'Adresse de livraison invalide. Veuillez sélectionner une adresse.',
          );
        }

        String finalOrderId;
        if (widget.existingOrderId != null) {
          // Finaliser la commande existante
          finalOrderId = await appService.finalizeExistingOrder(
            widget.existingOrderId!,
            addressToUse,
            _selectedPayment,
            total,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );
        } else {
          // Créer une nouvelle commande
          finalOrderId = await appService.placeOrderFromCartService(
            addressToUse,
            _selectedPayment,
            cartService.items,
            cartService.subtotal,
            cartService.deliveryFee,
            cartService.discount,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );
        }

        if (finalOrderId.isNotEmpty && mounted) {
          // Vider le panier seulement si c'était une commande depuis le panier
          if (widget.existingOrderId == null) {
            cartService.clear();
          }

          // Naviguer vers l'écran de suivi de commande
          if (mounted && context.mounted) {
            await context.navigateToDeliveryTracking(finalOrderId);
          }

          // Afficher un message de succès
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Commande #$finalOrderId passée avec succès! 🎉'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (mounted && context.mounted) {
        // Payment was cancelled or failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement annulé'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        // Capturer les valeurs nécessaires avant le gap async
        final errorColor = Theme.of(context).colorScheme.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la commande: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
