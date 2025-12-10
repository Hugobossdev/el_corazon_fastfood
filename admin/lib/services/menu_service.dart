import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/menu_models.dart';

class MenuService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String?> uploadProductImage(XFile image, String productName) async {
    try {
      _isLoading = true;
      notifyListeners();

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.$fileExt';
      final filePath = 'products/$fileName';

      await _supabase.storage.from('product-images').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = _supabase.storage.from('product-images').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error uploading product image: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Menu Items ---

  Future<List<MenuItem>> getMenuItems(
    String? categoryId, {
    bool notify = true,
  }) async {
    try {
      if (notify) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }

      var query = _supabase.from('menu_items').select();
      
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      
      final response = await query.order('sort_order', ascending: true);

      return (response as List).map((e) => MenuItem.fromMap(e)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching menu items: $e');
      return [];
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<MenuItem?> getMenuItem(String id) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select('*, menu_option_groups(*, menu_options(*))')
          .eq('id', id)
          .single();

      // Sort groups and options manually since nested ordering in select is tricky
      final item = MenuItem.fromMap(response);
      item.optionGroups.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (var group in item.optionGroups) {
        group.options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      return item;
    } catch (e) {
      debugPrint('Error fetching menu item: $e');
      return null;
    }
  }

  Future<MenuItem?> createMenuItem(MenuItem item) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = item.toMap();
      data.remove('id'); // Let DB generate ID
      data.remove('created_at');
      data.remove('updated_at');
      data.remove(
        'option_groups',
      ); // Handle separately if needed, but usually empty on create

      final response = await _supabase
          .from('menu_items')
          .insert(data)
          .select()
          .single();

      return MenuItem.fromMap(response);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating menu item: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMenuItem(MenuItem item) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = item.toMap();
      data.remove('id');
      data.remove('created_at');
      data['updated_at'] = DateTime.now().toIso8601String();
      data.remove('option_groups');

      await _supabase.from('menu_items').update(data).eq('id', item.id);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating menu item: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMenuItem(String id) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _supabase.from('menu_items').delete().eq('id', id);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting menu item: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Option Groups ---

  Future<MenuOptionGroup?> createOptionGroup(MenuOptionGroup group) async {
    try {
      final data = group.toMap();
      data.remove('id');
      data.remove('options');

      final response = await _supabase
          .from('menu_option_groups')
          .insert(data)
          .select()
          .single();

      return MenuOptionGroup.fromMap(response);
    } catch (e) {
      debugPrint('Error creating option group: $e');
      return null;
    }
  }

  Future<bool> updateOptionGroup(MenuOptionGroup group) async {
    try {
      final data = group.toMap();
      data.remove('id');
      data.remove('menu_item_id'); // Should not change
      data.remove('options');

      await _supabase
          .from('menu_option_groups')
          .update(data)
          .eq('id', group.id);
      return true;
    } catch (e) {
      debugPrint('Error updating option group: $e');
      return false;
    }
  }

  Future<bool> deleteOptionGroup(String id) async {
    try {
      await _supabase.from('menu_option_groups').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting option group: $e');
      return false;
    }
  }

  // --- Options ---

  Future<MenuOption?> createOption(MenuOption option) async {
    try {
      final data = option.toMap();
      data.remove('id');

      final response = await _supabase
          .from('menu_options')
          .insert(data)
          .select()
          .single();

      return MenuOption.fromMap(response);
    } catch (e) {
      debugPrint('Error creating option: $e');
      return null;
    }
  }

  Future<bool> updateOption(MenuOption option) async {
    try {
      final data = option.toMap();
      data.remove('id');
      data.remove('group_id'); // Should not change

      await _supabase.from('menu_options').update(data).eq('id', option.id);
      return true;
    } catch (e) {
      debugPrint('Error updating option: $e');
      return false;
    }
  }

  Future<bool> deleteOption(String id) async {
    try {
      await _supabase.from('menu_options').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting option: $e');
      return false;
    }
  }
}
