import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import 'database_service.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];
  double _deliveryFee = 500.0;
  double _discount = 0.0;
  String? _promoCode;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get deliveryFee => _deliveryFee;
  double get discount => _discount;
  double get total => subtotal + _deliveryFee - _discount;
  String? get promoCode => _promoCode;

  // Le prix de livraison est calculé par l'app.
  // Quand le calcul est fait (distance/zone/restaurant/promo), il doit appeler setDeliveryFee().

  void addItem(
    MenuItem menuItem, {
    int quantity = 1,
    Map<String, dynamic>? customization,
  }) {
    // Check if item already exists
    final existingIndex = _items.indexWhere(
      (item) =>
          item.id == menuItem.id &&
          _mapsEqual(item.customization, customization),
    );

    if (existingIndex >= 0) {
      // Update existing item quantity
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + quantity,
      );
    } else {
      // Add new item
      _items.add(
        CartItem(
          id: menuItem.id,
          name: menuItem.name,
          price: menuItem.price,
          quantity: quantity,
          imageUrl: menuItem.imageUrl,
          customization: customization,
        ),
      );
    }
    notifyListeners();
  }

  void updateItemQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _items.length) {
      if (newQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: newQuantity);
      }
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void removeItemById(String menuItemId) {
    _items.removeWhere((item) => item.id == menuItemId);
    notifyListeners();
  }

  void updateItemCustomizations(
    int index,
    Map<String, dynamic>? customization,
  ) {
    if (index >= 0 && index < _items.length) {
      _items[index] = _items[index].copyWith(customization: customization);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _discount = 0.0;
    _promoCode = null;
    notifyListeners();
  }

  // Helper methods for backward compatibility
  int getTotalItems() => itemCount;
  double getTotalPrice() => total;

  void setDeliveryFee(double fee) {
    _deliveryFee = fee;
    notifyListeners();
  }

  /// Initialise le frais de livraison depuis la table `orders` (dernière valeur persistée).
  /// Ne remplace pas un frais déjà calculé si on a déjà un montant pertinent.
  Future<void> hydrateDeliveryFeeFromOrders(String userId) async {
    try {
      final lastFee = await DatabaseService().getLastDeliveryFeeForUser(userId);
      if (lastFee == null) return;
      if (lastFee > 0 && lastFee != _deliveryFee) {
        _deliveryFee = lastFee;
        notifyListeners();
      }
    } catch (_) {
      // silencieux: on garde la valeur courante
    }
  }

  Future<bool> validatePromoCode(
    String code,
    double orderAmount,
    List<MenuCategory> categories,
  ) async {
    try {
      final promoData = await DatabaseService().validatePromoCode(code);
      if (promoData == null) return false;

      final minAmount =
          (promoData['minimum_order_amount'] as num?)?.toDouble() ?? 0.0;
      if (orderAmount < minAmount) return false;

      final discountType = (promoData['discount_type'] as String?) ?? 'fixed';
      final discountValue =
          (promoData['discount_value'] as num?)?.toDouble() ?? 0.0;

      double discount = 0.0;
      switch (discountType) {
        case 'percentage':
          discount = (orderAmount * discountValue / 100).clamp(0.0, orderAmount);
          break;
        case 'free_delivery':
          discount = _deliveryFee.clamp(0.0, orderAmount);
          break;
        case 'fixed':
        default:
          discount = discountValue.clamp(0.0, orderAmount);
          break;
      }

      if (discount <= 0) return false;

      _promoCode = code;
      _discount = discount;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void removePromoCode() {
    _promoCode = null;
    _discount = 0.0;
    notifyListeners();
  }

  Map<String, dynamic> toOrderData() {
    return {
      'items': _items
          .map(
            (item) => {
              'menu_item_id': item.id,
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'customization': item.customization,
            },
          )
          .toList(),
      'subtotal': subtotal,
      'delivery_fee': _deliveryFee,
      'discount': _discount,
      'promo_code': _promoCode,
      'total': total,
    };
  }

  int getItemQuantity(String menuItemId) {
    final item = _items.firstWhere(
      (item) => item.id == menuItemId,
      orElse: () => CartItem(id: '', name: '', price: 0, quantity: 0),
    );
    return item.quantity;
  }

  bool hasItem(String menuItemId) {
    return _items.any((item) => item.id == menuItemId);
  }

  void incrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.id == menuItemId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + 1,
      );
      notifyListeners();
    }
  }

  void decrementItemQuantity(String menuItemId) {
    final index = _items.indexWhere((item) => item.id == menuItemId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index] = _items[index].copyWith(
          quantity: _items[index].quantity - 1,
        );
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  // Save cart to local storage
  Future<void> saveToStorage() async {
    // Implement local storage save
    // For now, we'll just simulate it
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Load cart from local storage
  Future<void> loadFromStorage() async {
    // Implement local storage load
    // For now, we'll just simulate it
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Helper method to compare maps
  bool _mapsEqual(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    if (map1 == null && map2 == null) return true;
    if (map1 == null || map2 == null) return false;
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }
}
