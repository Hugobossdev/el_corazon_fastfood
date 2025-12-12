import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/category_management_service.dart';
import '../../models/category.dart';
import '../../widgets/custom_button.dart';
import '../../utils/dialog_helper.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryManagementService>().refreshCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Catégories'),
      ),
      body: Consumer<CategoryManagementService>(
        builder: (context, categoryService, child) {
          if (categoryService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categoryService.categories;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucune catégorie définie'),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Créer une catégorie',
                    onPressed: () => _showCategoryDialog(context),
                    icon: Icons.add,
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = categories.removeAt(oldIndex);
              categories.insert(newIndex, item);

              // Mettre à jour l'ordre dans le service/backend
              categoryService.reorderCategories(categories);
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                key: ValueKey(category.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.emoji ?? '🍽️',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${category.description ?? 'Pas de description'} • ${category.isActive ? 'Active' : 'Inactive'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          category.isActive
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: category.isActive ? Colors.green : Colors.grey,
                        ),
                        onPressed: () =>
                            categoryService.toggleCategoryStatus(category.id),
                        tooltip: category.isActive ? 'Désactiver' : 'Activer',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showCategoryDialog(context, category: category),
                        tooltip: 'Modifier',
                      ),
                      IconButton(
                        icon: const Icon(Icons.drag_handle),
                        onPressed:
                            () {}, // Le drag se fait sur toute la tuile ou via ce handle
                        tooltip: 'Réorganiser',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        tooltip: 'Nouvelle catégorie',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final nameController = TextEditingController(text: category?.name);
    final descController = TextEditingController(text: category?.description);
    final emojiController =
        TextEditingController(text: category?.emoji ?? '🍽️');

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            category == null ? 'Nouvelle Catégorie' : 'Modifier Catégorie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: emojiController,
                      decoration: const InputDecoration(
                        labelText: 'Emoji',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      textAlign: TextAlign.center,
                      maxLength: 2,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final service = context.read<CategoryManagementService>();
              Navigator.pop(context);

              bool success;
              if (category == null) {
                success = await service.createCategory(
                      name: nameController.text,
                      displayName: nameController.text,
                      emoji: emojiController.text,
                      description: descController.text,
                    ) !=
                    null;
              } else {
                success = await service.updateCategory(
                  category.copyWith(
                    name: nameController.text,
                    emoji: emojiController.text,
                    description: descController.text,
                  ),
                );
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Catégorie enregistrée'
                        : 'Erreur lors de l\'enregistrement'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
