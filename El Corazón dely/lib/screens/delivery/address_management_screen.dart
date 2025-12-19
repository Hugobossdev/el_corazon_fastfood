import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/address_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import '../../models/address.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';
import '../../ui/ui.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await Provider.of<AddressService>(context, listen: false).initialize();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur initialisation adresses', details: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des adresses'),
        actions: [
          IconButton(
            onPressed: _addNewAddress,
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter une adresse',
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
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: AppSpacing.pagePadding,
            itemCount: addressService.addresses.length,
            itemBuilder: (context, index) {
              final address = addressService.addresses[index];
              return _buildAddressCard(address, addressService);
            },
          );
        },
      ),
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
              Icon(Icons.location_off_outlined, size: 44, color: scheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aucune adresse enregistrée',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ajoutez vos adresses de livraison préférées.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _addNewAddress,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une adresse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(Address address, AddressService addressService) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _getAddressTypeColor(context, address.type);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      onTap: () => _editAddress(address),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(Icons.place_outlined, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondary,
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                            ),
                            child: Text(
                              'Défaut',
                              style: TextStyle(
                                color: scheme.onSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      address.type.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleAddressAction(value, address),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'set_default',
                    child: Row(
                      children: [
                        Icon(Icons.star_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Définir par défaut'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: scheme.error, size: 18),
                        const SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: scheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  address.fullAddress,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (address.latitude != null && address.longitude != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.my_location, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Coordonnées: ${address.latitude!.toStringAsFixed(4)}, ${address.longitude!.toStringAsFixed(4)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _addNewAddress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditAddressScreen(),
      ),
    ).then((_) {
      // Rafraîchir la liste après ajout/modification
      setState(() {});
    });
  }

  void _editAddress(Address address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAddressScreen(address: address),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _handleAddressAction(String action, Address address) {
    switch (action) {
      case 'edit':
        _editAddress(address);
        break;
      case 'set_default':
        _setDefaultAddress(address);
        break;
      case 'delete':
        _deleteAddress(address);
        break;
    }
  }

  Future<void> _setDefaultAddress(Address address) async {
    try {
      if (!mounted || !context.mounted) return;
      Provider.of<PerformanceService>(context, listen: false)
          .startTimer('set_default_address');

      await Provider.of<AddressService>(context, listen: false)
          .setDefaultAddress(address.id);

      if (!mounted || !context.mounted) return;
      Provider.of<PerformanceService>(context, listen: false)
          .stopTimer('set_default_address');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${address.name} définie comme adresse par défaut'),
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur définition adresse par défaut', details: e);
      Provider.of<ErrorHandlerService>(context, listen: false)
          .showErrorSnackBar(context,
              'Erreur lors de la définition de l\'adresse par défaut');
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'adresse'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${address.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted || !context.mounted) return;
        Provider.of<PerformanceService>(context, listen: false)
            .startTimer('delete_address');

        await Provider.of<AddressService>(context, listen: false)
            .deleteAddress(address.id);

        if (!mounted || !context.mounted) return;
        Provider.of<PerformanceService>(context, listen: false)
            .stopTimer('delete_address');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${address.name} supprimée'),
          ),
        );
      } catch (e) {
        if (!mounted || !context.mounted) return;
        Provider.of<ErrorHandlerService>(context, listen: false)
            .logError('Erreur suppression adresse', details: e);
        Provider.of<ErrorHandlerService>(context, listen: false)
            .showErrorSnackBar(
                context, 'Erreur lors de la suppression de l\'adresse');
      }
    }
  }

  Color _getAddressTypeColor(BuildContext context, AddressType type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case AddressType.home:
        return scheme.primary;
      case AddressType.work:
        return scheme.tertiary;
      case AddressType.other:
        return scheme.outline;
    }
  }
}

class AddEditAddressScreen extends StatefulWidget {
  final Address? address;

  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  AddressType _selectedType = AddressType.other;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _nameController.text = address.name;
      _addressController.text = address.address;
      _cityController.text = address.city;
      _postalCodeController.text = address.postalCode;
      _selectedType = address.type;
      _isDefault = address.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null
            ? 'Ajouter une adresse'
            : 'Modifier l\'adresse'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'adresse',
                        hintText: 'Ex: Maison, Bureau, etc.',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<AddressType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type d\'adresse',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: AddressType.values.map((type) {
                        return DropdownMenuItem<AddressType>(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse',
                        hintText: 'Ex: 123 Rue de la Paix',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer l\'adresse';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Ville',
                              hintText: 'Ex: Abidjan',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer la ville';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _postalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Code postal',
                              hintText: 'Ex: 00225',
                              prefixIcon: Icon(Icons.local_post_office_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer le code postal';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      title: const Text('Définir comme adresse par défaut'),
                      subtitle: const Text(
                        'Cette adresse sera utilisée par défaut pour les livraisons',
                      ),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          widget.address == null
                              ? 'Ajouter l\'adresse'
                              : 'Modifier l\'adresse',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (mounted) {
        Provider.of<PerformanceService>(context, listen: false)
            .startTimer('save_address');
      }

      final addressService =
          Provider.of<AddressService>(context, listen: false);

      if (widget.address == null) {
        // Ajouter une nouvelle adresse
        await addressService.addAddress(
          name: _nameController.text,
          address: _addressController.text,
          city: _cityController.text,
          postalCode: _postalCodeController.text,
          type: _selectedType,
          isDefault: _isDefault,
        );
      } else {
        // Modifier l'adresse existante
        final address = widget.address;
        if (address == null) {
          throw Exception('Address cannot be null when updating');
        }
        await addressService.updateAddress(
          addressId: address.id,
          name: _nameController.text,
          address: _addressController.text,
          city: _cityController.text,
          postalCode: _postalCodeController.text,
          type: _selectedType,
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        Provider.of<PerformanceService>(context, listen: false)
            .stopTimer('save_address');

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.address == null
                ? 'Adresse ajoutée avec succès!'
                : 'Adresse modifiée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Provider.of<ErrorHandlerService>(context, listen: false)
            .logError('Erreur sauvegarde adresse', details: e);
        Provider.of<ErrorHandlerService>(context, listen: false)
            .showErrorSnackBar(
                context, 'Erreur lors de la sauvegarde de l\'adresse');
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
