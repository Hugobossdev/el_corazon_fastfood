import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/screens/client/address_management_screen.dart';

class AddressSelectorScreen extends StatefulWidget {
  final Address? currentAddress;
  final Function(Address) onAddressSelected;

  const AddressSelectorScreen({
    required this.onAddressSelected, super.key,
    this.currentAddress,
  });

  @override
  State<AddressSelectorScreen> createState() => _AddressSelectorScreenState();
}

class _AddressSelectorScreenState extends State<AddressSelectorScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner une adresse'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: () => _showAddAddressDialog(),
            icon: const Icon(Icons.add_location),
            tooltip: 'Ajouter une adresse',
          ),
        ],
      ),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          final addresses = _searchQuery.isEmpty
              ? addressService.addresses
              : addressService.searchAddresses(_searchQuery);

          if (!addressService.hasAddresses) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Barre de recherche
              Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher une adresse...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Liste des adresses
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final isSelected = widget.currentAddress?.id == address.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: address.type.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              address.type.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                address.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (address.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4,),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Défaut',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(address.fullAddress),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2,),
                                  decoration: BoxDecoration(
                                    color: address.type.color
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    address.type.displayName,
                                    style: TextStyle(
                                      color: address.type.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              )
                            : null,
                        onTap: () {
                          widget.onAddressSelected(address);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: CustomButton(
          onPressed: () => _showAddAddressDialog(),
          text: 'Ajouter une nouvelle adresse',
          icon: Icons.add_location,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune adresse enregistrée',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre première adresse pour continuer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddAddressDialog(),
            icon: const Icon(Icons.add_location),
            label: const Text('Ajouter une adresse'),
          ),
        ],
      ),
    );
  }

  void _showAddAddressDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddressManagementScreen()),
    );
  }

  // Ajout d'adresse géré par `AddressManagementScreen`
}

// NOTE: l'ancien "quick dialog" a été retiré au profit d'un seul flux unifié
// via `AddressManagementScreen` (position / carte / recherche Places).
