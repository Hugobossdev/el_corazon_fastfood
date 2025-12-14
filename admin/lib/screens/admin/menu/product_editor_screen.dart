import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/menu_models.dart';
import '../../../services/menu_service.dart';
import 'widgets/option_group_widget.dart';

class ProductEditorScreen extends StatefulWidget {
  final String categoryId;
  final MenuItem? menuItem;

  const ProductEditorScreen({
    super.key,
    required this.categoryId,
    this.menuItem,
  });

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;

  bool _isPopular = false;
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isAvailable = true;

  List<MenuOptionGroup> _optionGroups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.menuItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _priceController = TextEditingController(
      text: item?.basePrice.toString() ?? '0',
    );
    _imageUrlController = TextEditingController(text: item?.imageUrl ?? '');

    if (item != null) {
      _isPopular = item.isPopular;
      _isVegetarian = item.isVegetarian;
      _isVegan = item.isVegan;
      _isAvailable = item.isAvailable;
      _optionGroups = List.from(item.optionGroups);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);

      final newItem = MenuItem(
        id: widget.menuItem?.id ?? '',
        categoryId: widget.categoryId,
        name: _nameController.text,
        description: _descriptionController.text,
        basePrice: double.tryParse(_priceController.text) ?? 0,
        imageUrl: _imageUrlController.text.isEmpty
            ? null
            : _imageUrlController.text,
        isPopular: _isPopular,
        isVegetarian: _isVegetarian,
        isVegan: _isVegan,
        isAvailable: _isAvailable,
        createdAt: widget.menuItem?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        optionGroups: _optionGroups,
      );

      if (widget.menuItem == null) {
        // Create
        final createdItem = await menuService.createMenuItem(newItem);
        if (createdItem != null) {
          // Save option groups
          for (var group in _optionGroups) {
            final groupWithItemId = group.copyWith(menuItemId: createdItem.id);
            final createdGroup = await menuService.createOptionGroup(
              groupWithItemId,
            );
            if (createdGroup != null) {
              for (var option in group.options) {
                final optionWithGroupId = option.copyWith(
                  groupId: createdGroup.id,
                );
                await menuService.createOption(optionWithGroupId);
              }
            }
          }
        }
      } else {
        // Update
        await menuService.updateMenuItem(newItem);

        // Handle groups update (simplified: delete all and recreate for now, or smart update)
        // For this MVP, we'll assume the user manages groups carefully.
        // A proper implementation would diff the groups.
        // Given the complexity, let's just save the item properties for now and handle groups if they are new.
        // Ideally, we should have specific API endpoints for syncing options.

        // NOTE: This is a simplified approach. In a real app, you'd want to handle IDs properly to avoid recreating everything.
        // For now, we will just update the main item properties.
        // Updating nested relations via Supabase directly is tricky without a stored procedure or multiple calls.

        // Let's try to update groups that have IDs, create those that don't.
        for (var group in _optionGroups) {
          if (group.id.isEmpty) {
            final groupWithItemId = group.copyWith(menuItemId: newItem.id);
            final createdGroup = await menuService.createOptionGroup(
              groupWithItemId,
            );
            if (createdGroup != null) {
              for (var option in group.options) {
                final optionWithGroupId = option.copyWith(
                  groupId: createdGroup.id,
                );
                await menuService.createOption(optionWithGroupId);
              }
            }
          } else {
            await menuService.updateOptionGroup(group);
            // Handle options within group
            for (var option in group.options) {
              if (option.id.isEmpty) {
                final optionWithGroupId = option.copyWith(groupId: group.id);
                await menuService.createOption(optionWithGroupId);
              } else {
                await menuService.updateOption(option);
              }
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addOptionGroup() {
    setState(() {
      _optionGroups.add(
        MenuOptionGroup(
          id: '', // Empty ID indicates new
          menuItemId: widget.menuItem?.id ?? '',
          name: 'Nouveau groupe',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.menuItem == null ? 'Nouveau Produit' : 'Modifier Produit',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du produit',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Prix de base',
                                      suffixText: 'CFA',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Requis'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _imageUrlController,
                              decoration: const InputDecoration(
                                labelText: 'URL de l\'image',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Flags
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Disponible'),
                            value: _isAvailable,
                            onChanged: (v) => setState(() => _isAvailable = v),
                          ),
                          SwitchListTile(
                            title: const Text('Populaire'),
                            value: _isPopular,
                            onChanged: (v) => setState(() => _isPopular = v),
                          ),
                          SwitchListTile(
                            title: const Text('Végétarien'),
                            value: _isVegetarian,
                            onChanged: (v) => setState(() => _isVegetarian = v),
                          ),
                          SwitchListTile(
                            title: const Text('Vegan'),
                            value: _isVegan,
                            onChanged: (v) => setState(() => _isVegan = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Customizations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Personnalisations',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ElevatedButton.icon(
                          onPressed: _addOptionGroup,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un groupe'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_optionGroups.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Aucune option de personnalisation'),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _optionGroups.length,
                        itemBuilder: (context, index) {
                          return OptionGroupWidget(
                            group: _optionGroups[index],
                            onUpdate: (updatedGroup) {
                              setState(() {
                                _optionGroups[index] = updatedGroup;
                              });
                            },
                            onDelete: () {
                              setState(() {
                                _optionGroups.removeAt(index);
                              });
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
