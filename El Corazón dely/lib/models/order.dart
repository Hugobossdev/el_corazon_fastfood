class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final OrderStatus status;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? restaurantLatitude;
  final double? restaurantLongitude;
  final String? restaurantName;
  final String? restaurantAddress;
  final String? deliveryNotes;
  final String? promoCode;
  final double discount;
  final PaymentMethod paymentMethod;
  final DateTime orderTime;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final String? deliveryPersonId;
  final List<OrderStatusUpdate> statusUpdates;
  final String? specialInstructions;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 5.0,
    required this.total,
    this.status = OrderStatus.pending,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.restaurantLatitude,
    this.restaurantLongitude,
    this.restaurantName,
    this.restaurantAddress,
    this.deliveryNotes,
    this.promoCode,
    this.discount = 0.0,
    required this.paymentMethod,
    required this.orderTime,
    required this.createdAt,
    this.estimatedDeliveryTime,
    this.deliveryPersonId,
    this.statusUpdates = const [],
    this.specialInstructions,
  });

  Order copyWith({
    String? id,
    String? userId,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? total,
    OrderStatus? status,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double? restaurantLatitude,
    double? restaurantLongitude,
    String? restaurantName,
    String? restaurantAddress,
    String? deliveryNotes,
    String? promoCode,
    double? discount,
    PaymentMethod? paymentMethod,
    DateTime? orderTime,
    DateTime? createdAt,
    DateTime? estimatedDeliveryTime,
    String? deliveryPersonId,
    List<OrderStatusUpdate>? statusUpdates,
    String? specialInstructions,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      restaurantLatitude: restaurantLatitude ?? this.restaurantLatitude,
      restaurantLongitude: restaurantLongitude ?? this.restaurantLongitude,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      promoCode: promoCode ?? this.promoCode,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderTime: orderTime ?? this.orderTime,
      createdAt: createdAt ?? this.createdAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      statusUpdates: statusUpdates ?? this.statusUpdates,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': status.toString(),
      'deliveryAddress': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'restaurant_latitude': restaurantLatitude,
      'restaurant_longitude': restaurantLongitude,
      'restaurant_name': restaurantName,
      'restaurant_address': restaurantAddress,
      'deliveryNotes': deliveryNotes,
      'promoCode': promoCode,
      'discount': discount,
      'paymentMethod': paymentMethod.toString(),
      'orderTime': orderTime.toIso8601String(),
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'deliveryPersonId': deliveryPersonId,
      'specialInstructions': specialInstructions,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    // Parse status from database format
    OrderStatus status;
    final statusStr = map['status'] as String? ?? 'pending';
    try {
      status = OrderStatus.values.firstWhere(
        (e) =>
            e.dbValue == statusStr ||
            e.toString().split('.').last.toLowerCase() ==
                statusStr.toLowerCase(),
        orElse: () => OrderStatus.pending,
      );
    } catch (e) {
      status = OrderStatus.pending;
    }

    // Parse payment method from database format
    PaymentMethod paymentMethod;
    final paymentStr = map['payment_method'] as String? ??
        map['paymentMethod'] as String? ??
        'cash';
    try {
      paymentMethod = PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == paymentStr.toLowerCase(),
        orElse: () => PaymentMethod.cash,
      );
    } catch (e) {
      paymentMethod = PaymentMethod.cash;
    }

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s);
    }

    // Load order items from database structure
    List<OrderItem> items = [];
    if (map['order_items'] != null) {
      final orderItemsData = map['order_items'] as List;
      items = orderItemsData.map((itemData) {
        return OrderItem(
          menuItemId: itemData['menu_item_id'] as String? ??
              itemData['menuItemId'] as String? ??
              '',
          menuItemName: itemData['menu_item_name'] as String? ??
              itemData['menuItemName'] as String? ??
              '',
          name: itemData['menu_item_name'] as String? ??
              itemData['menuItemName'] as String? ??
              '',
          category: itemData['category'] as String? ?? '',
          menuItemImage: itemData['menu_item_image'] as String? ??
              itemData['menuItemImage'] as String? ??
              '',
          quantity: itemData['quantity'] as int? ?? 1,
          unitPrice: (itemData['unit_price'] as num?)?.toDouble() ??
              (itemData['unitPrice'] as num?)?.toDouble() ??
              0.0,
          totalPrice: (itemData['total_price'] as num?)?.toDouble() ??
              (itemData['totalPrice'] as num?)?.toDouble() ??
              0.0,
          customizations: itemData['customizations'] is Map
              ? Map<String, String>.from(itemData['customizations'])
              : {},
          notes: itemData['notes'] as String?,
        );
      }).toList();
    }

    return Order(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? map['userId'] as String? ?? '',
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ??
          (map['deliveryFee'] as num?)?.toDouble() ??
          0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: status,
      deliveryAddress: map['delivery_address'] as String? ??
          map['deliveryAddress'] as String? ??
          '',
      deliveryLatitude: toDouble(
        map['delivery_latitude'] ??
            map['delivery_lat'] ??
            map['deliveryLatitude'],
      ),
      deliveryLongitude: toDouble(
        map['delivery_longitude'] ??
            map['delivery_lng'] ??
            map['deliveryLongitude'],
      ),
      restaurantLatitude: toDouble(
        map['restaurant_latitude'] ??
            map['restaurant_lat'] ??
            map['restaurantLatitude'],
      ),
      restaurantLongitude: toDouble(
        map['restaurant_longitude'] ??
            map['restaurant_lng'] ??
            map['restaurantLongitude'],
      ),
      restaurantName:
          map['restaurant_name'] as String? ?? map['restaurantName'] as String?,
      restaurantAddress: map['restaurant_address'] as String? ??
          map['restaurantAddress'] as String?,
      deliveryNotes: map['notes'] as String? ?? map['deliveryNotes'] as String?,
      promoCode: map['promo_code'] as String? ?? map['promoCode'] as String?,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: paymentMethod,
      orderTime: map['order_time'] != null
          ? DateTime.parse(map['order_time'] as String)
          : map['orderTime'] != null
              ? DateTime.parse(map['orderTime'] as String)
              : map['created_at'] != null
                  ? DateTime.parse(map['created_at'] as String)
                  : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : DateTime.now(),
      estimatedDeliveryTime: map['estimated_delivery_time'] != null
          ? DateTime.parse(map['estimated_delivery_time'] as String)
          : map['estimatedDeliveryTime'] != null
              ? DateTime.parse(map['estimatedDeliveryTime'] as String)
              : null,
      deliveryPersonId: map['delivery_person_id'] as String? ??
          map['deliveryPersonId'] as String?,
      specialInstructions: map['special_instructions'] as String? ??
          map['specialInstructions'] as String?,
    );
  }
}

class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final String name;
  final String category;
  final String menuItemImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Map<String, String> customizations;
  final String? notes;

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.name,
    required this.category,
    required this.menuItemImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.customizations = const {},
    this.notes,
  });

  OrderItem copyWith({
    String? menuItemId,
    String? menuItemName,
    String? name,
    String? category,
    String? menuItemImage,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    Map<String, String>? customizations,
    String? notes,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      name: name ?? this.name,
      category: category ?? this.category,
      menuItemImage: menuItemImage ?? this.menuItemImage,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      customizations: customizations ?? this.customizations,
      notes: notes ?? this.notes,
    );
  }
}

class OrderStatusUpdate {
  final OrderStatus status;
  final DateTime timestamp;
  final String? message;
  final String? updatedBy;

  OrderStatusUpdate({
    required this.status,
    required this.timestamp,
    this.message,
    this.updatedBy,
  });
}

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
  refunded,
  failed,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.onTheWay:
        return 'On the Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.failed:
        return 'Failed';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.pending:
        return '⏳';
      case OrderStatus.confirmed:
        return '✅';
      case OrderStatus.preparing:
        return '👨‍🍳';
      case OrderStatus.ready:
        return '📦';
      case OrderStatus.pickedUp:
        return '🏃‍♂️';
      case OrderStatus.onTheWay:
        return '🛵';
      case OrderStatus.delivered:
        return '🎉';
      case OrderStatus.cancelled:
        return '❌';
      case OrderStatus.refunded:
        return '💰';
      case OrderStatus.failed:
        return '⚠️';
    }
  }

  /// Valeur canonique stockée en base (compat Supabase/Postgres).
  /// Important: certains statuts sont en snake_case dans la DB.
  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.onTheWay:
        return 'on_the_way';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.failed:
        return 'failed';
    }
  }

  /// Alias pour compatibilité avec le code existant
  @Deprecated('Utilisez dbValue à la place')
  String get toDbString => dbValue;
}

enum PaymentMethod { mobileMoney, creditCard, debitCard, wallet, cash }

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.wallet:
        return 'El Corazon Dely Wallet';
      case PaymentMethod.cash:
        return 'Cash on Delivery';
    }
  }

  String get description {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Orange Money, MTN Money, Moov Money';
      case PaymentMethod.creditCard:
        return 'Visa, Mastercard, American Express';
      case PaymentMethod.debitCard:
        return 'Carte de débit bancaire';
      case PaymentMethod.wallet:
        return 'Portefeuille El Corazon Dely';
      case PaymentMethod.cash:
        return 'Paiement à la livraison';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return '📱';
      case PaymentMethod.creditCard:
        return '💳';
      case PaymentMethod.debitCard:
        return '💳';
      case PaymentMethod.wallet:
        return '👛';
      case PaymentMethod.cash:
        return '💵';
    }
  }
}
