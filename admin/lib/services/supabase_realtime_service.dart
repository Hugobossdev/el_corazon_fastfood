import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _driversChannel;

  void initialize() {
    _subscribeToAllOrders();
    _subscribeToDriversStatus();
  }

  void _subscribeToAllOrders() {
    try {
      _ordersChannel = _supabase
          .channel('admin:orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              debugPrint('Admin: Order update: ${payload.eventType}');
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to all orders: $e');
    }
  }

  void _subscribeToDriversStatus() {
    try {
      _driversChannel = _supabase
          .channel('admin:drivers')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'drivers',
            callback: (payload) {
              debugPrint('Admin: Driver status update: ${payload.newRecord}');
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to drivers: $e');
    }
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _driversChannel?.unsubscribe();
    super.dispose();
  }
}

