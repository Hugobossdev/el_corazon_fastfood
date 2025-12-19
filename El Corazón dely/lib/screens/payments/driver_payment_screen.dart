import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/paydunya_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import '../../models/order.dart';
import '../delivery/driver_profile_screen.dart';
import '../delivery/settings_screen.dart';
import '../../ui/ui.dart';

class DriverPaymentScreen extends StatefulWidget {
  final Order order;
  final double amount;

  const DriverPaymentScreen({
    super.key,
    required this.order,
    required this.amount,
  });

  @override
  State<DriverPaymentScreen> createState() => _DriverPaymentScreenState();
}

class _DriverPaymentScreenState extends State<DriverPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();

  String _selectedPaymentMethod = 'mobile_money';
  String _selectedOperator = 'mtn';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      final payDunyaService = Provider.of<PayDunyaService>(
        context,
        listen: false,
      );
      if (!payDunyaService.isInitialized) {
        await payDunyaService.initialize(
          masterKey: 'test_master_key',
          privateKey: 'test_private_key',
          token: 'test_token',
          isSandbox: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        ).logError('Erreur initialisation paiement', details: e);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
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
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderSummary(),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                title: 'Méthode de paiement',
                padding: EdgeInsets.zero,
                child: _buildPaymentMethodSelector(),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_selectedPaymentMethod == 'mobile_money')
                _buildMobileMoneyForm()
              else
                _buildCardForm(),
              const SizedBox(height: AppSpacing.xl),
              _buildPaymentButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final deliveryFee = widget.order.deliveryFee;
    final total = widget.amount + deliveryFee;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé de la commande',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _rowLine(
            'Commande',
            '#${widget.order.id.substring(0, 8).toUpperCase()}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _rowLine('Montant', '${widget.amount.toStringAsFixed(0)} FCFA'),
          const SizedBox(height: AppSpacing.sm),
          _rowLine(
            'Frais de livraison',
            '${deliveryFee.toStringAsFixed(0)} FCFA',
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          _rowLine(
            'Total',
            '${total.toStringAsFixed(0)} FCFA',
            valueStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: RadioGroup<String>(
        groupValue: _selectedPaymentMethod,
        onChanged: (value) {
          setState(() {
            _selectedPaymentMethod = value ?? 'mobile_money';
          });
        },
        child: Column(
          children: [
            RadioListTile<String>(
              title: const Text('Mobile Money'),
              subtitle: const Text('MTN, Orange, Moov'),
              value: 'mobile_money',
            ),
            const Divider(height: 1),
            RadioListTile<String>(
              title: const Text('Carte bancaire'),
              subtitle: const Text('Visa, Mastercard'),
              value: 'card',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMoneyForm() {
    return AppSection(
      title: 'Mobile Money',
      padding: EdgeInsets.zero,
      child: AppCard(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedOperator,
              decoration: const InputDecoration(labelText: 'Opérateur'),
              items: const [
                DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
                DropdownMenuItem(value: 'orange', child: Text('Orange Money')),
                DropdownMenuItem(value: 'moov', child: Text('Moov Money')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedOperator = value!;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: '+225 XX XX XX XX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre numéro';
                }
                if (value.length < 10) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return AppSection(
      title: 'Carte bancaire',
      padding: EdgeInsets.zero,
      child: AppCard(
        child: Column(
          children: [
            TextFormField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro de carte',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le numéro de carte';
                }
                if (value.replaceAll(' ', '').length < 16) {
                  return 'Numéro de carte invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _cardHolderController,
              decoration: const InputDecoration(
                labelText: 'Nom du titulaire',
                hintText: 'Jean Dupont',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nom du titulaire';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryMonthController,
                    decoration: const InputDecoration(
                      labelText: 'Mois',
                      hintText: 'MM',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Mois requis';
                      }
                      final month = int.tryParse(value);
                      if (month == null || month < 1 || month > 12) {
                        return 'Mois invalide';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _expiryYearController,
                    decoration: const InputDecoration(
                      labelText: 'Année',
                      hintText: 'YYYY',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Année requise';
                      }
                      final year = int.tryParse(value);
                      if (year == null || year < DateTime.now().year) {
                        return 'Année invalide';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'CVV requis';
                      }
                      if (value.length < 3) {
                        return 'CVV invalide';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isProcessing ? null : _processPayment,
        child: _isProcessing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Traitement en cours...'),
                ],
              )
            : Text(
                'Payer ${widget.amount.toStringAsFixed(2)} FCFA',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Provider.of<PerformanceService>(
        context,
        listen: false,
      ).startTimer('process_payment');

      final payDunyaService = Provider.of<PayDunyaService>(
        context,
        listen: false,
      );
      final errorHandler = Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      );

      if (_selectedPaymentMethod == 'mobile_money') {
        await _processMobileMoneyPayment(payDunyaService, errorHandler);
      } else {
        await _processCardPayment(payDunyaService, errorHandler);
      }

      if (!mounted || !context.mounted) return;

      Provider.of<PerformanceService>(
        context,
        listen: false,
      ).stopTimer('process_payment');

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement effectué avec succès!')),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      final errorHandlerService = Provider.of<ErrorHandlerService>(
        context,
        listen: false,
      );
      errorHandlerService.logError('Erreur paiement', details: e);
      errorHandlerService.showErrorSnackBar(
        context,
        'Erreur lors du paiement: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processMobileMoneyPayment(
    PayDunyaService payDunyaService,
    ErrorHandlerService errorHandler,
  ) async {
    final result = await payDunyaService.processMobileMoneyPayment(
      orderId: widget.order.id,
      amount: widget.amount,
      phoneNumber: _phoneController.text,
      operator: _selectedOperator,
      customerName: 'Livreur ${widget.order.id.substring(0, 8)}',
      customerEmail: 'driver@fasteat.ci',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Erreur paiement mobile money');
    }
  }

  Future<void> _processCardPayment(
    PayDunyaService payDunyaService,
    ErrorHandlerService errorHandler,
  ) async {
    final result = await payDunyaService.processCardPayment(
      orderId: widget.order.id,
      amount: widget.amount,
      cardNumber: _cardNumberController.text,
      cardHolderName: _cardHolderController.text,
      expiryMonth: _expiryMonthController.text,
      expiryYear: _expiryYearController.text,
      cvv: _cvvController.text,
      customerName: 'Livreur ${widget.order.id.substring(0, 8)}',
      customerEmail: 'driver@fasteat.ci',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Erreur paiement carte');
    }
  }

  Widget _rowLine(String label, String value, {TextStyle? valueStyle}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
