import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../utils/price_formatter.dart';
import '../ui/ui.dart';

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
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: AppSpacing.md),
          _buildLocationRow(context),
          const SizedBox(height: AppSpacing.md),
          if (isAvailable)
            _buildAcceptButton(context)
          else
            _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isAvailable ? scheme.secondary : _getStatusColor(context, order.status))
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Center(
            child: Icon(
              isAvailable ? Icons.inventory_2_outlined : _getStatusIcon(order.status),
              color: isAvailable ? scheme.onSecondary : _getStatusColor(context, order.status),
              size: 20,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isAvailable)
                Text(
                  '${order.items.length} articles - ${PriceFormatter.format(order.total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  order.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(context, order.status),
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
              color: isAvailable ? scheme.primary : scheme.onSurface,
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

  Widget _buildLocationRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            order.deliveryAddress,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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

  Color _getStatusColor(BuildContext context, OrderStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case OrderStatus.pickedUp:
        return scheme.tertiary;
      case OrderStatus.onTheWay:
        return scheme.primary;
      case OrderStatus.delivered:
        return scheme.secondary;
      default:
        return scheme.outline;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return Icons.shopping_bag_outlined;
      case OrderStatus.onTheWay:
        return Icons.navigation_outlined;
      case OrderStatus.delivered:
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }
}





