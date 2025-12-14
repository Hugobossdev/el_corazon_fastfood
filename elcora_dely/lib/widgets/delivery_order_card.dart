import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../utils/price_formatter.dart';

class DeliveryOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onAccept;
  final VoidCallback? onNavigate;
  final VoidCallback? onAction;
  final VoidCallback? onChat;
  final VoidCallback? onSupport;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool isAvailable;

  const DeliveryOrderCard({
    super.key,
    required this.order,
    this.onAccept,
    this.onNavigate,
    this.onAction,
    this.onChat,
    this.onSupport,
    this.actionLabel,
    this.actionIcon,
    this.isAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isAvailable ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildLocationRow(),
            const SizedBox(height: 12),
            if (isAvailable) _buildAcceptButton(context) else _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAvailable
                ? Colors.orange.withOpacity(0.1)
                : _getStatusColor(order.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              isAvailable ? '📦' : order.status.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              if (isAvailable)
                Text(
                  '${order.items.length} articles - ${PriceFormatter.format(order.total)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  order.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(order.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Flexible(
          child: Text(
            PriceFormatter.format(order.total),
            style: TextStyle(
              color: isAvailable ? Theme.of(context).colorScheme.primary : null,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    return Row(
      children: [
        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            order.deliveryAddress,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onAccept,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Accepter la livraison'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigation'),
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.arrow_forward, size: 18),
                  label: Text(actionLabel ?? 'Suivant'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (onChat != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Chat'),
                ),
              ),
            if (onChat != null && onSupport != null) const SizedBox(width: 8),
            if (onSupport != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSupport,
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Support'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.onTheWay:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}



