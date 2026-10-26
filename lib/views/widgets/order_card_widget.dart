import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import 'order_items_dialog.dart';

/// Tarjeta informativa de un pedido dentro del listado del panel principal.
class OrderCardWidget extends StatelessWidget {
  /// Modelo de datos del pedido a representar.
  final OrderModel order;

  /// Número de parada secuencial dentro de la ruta.
  final int? stopNumber;

  /// Crea una nueva instancia de [OrderCardWidget].
  const OrderCardWidget({
    super.key,
    required this.order,
    this.stopNumber,
  });

  /// Inicia una llamada telefónica hacia el número del cliente.
  Future<void> _makeCall(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
      if (cleanPhone.isEmpty) return;
      final uri = Uri.parse('tel:$cleanPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.estado == OrderStatus.entregado;
    final isEnCamino = order.estado == OrderStatus.enCamino;
    final isEnPunto = order.estado == OrderStatus.enPunto;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnCamino || isEnPunto
              ? order.estadoColor.withValues(alpha: 0.65)
              : AppColors.border,
          width: isEnCamino || isEnPunto ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnCamino || isEnPunto
                ? order.estadoColor.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (stopNumber != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDelivered
                              ? const Color(0xFF10B981)
                              : isEnCamino || isEnPunto
                                  ? AppColors.primary
                                  : const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDelivered
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  '#$stopNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF08A),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFFDE047)),
                      ),
                      child: Text(
                        order.id,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(order),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.clienteNombre,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.clienteTelefono.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.phone_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    onPressed: () => _makeCall(order.clienteTelefono),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${order.direccion} • ${order.barrio}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.montoFormatted,
                      style: TextStyle(
                        color: isDelivered
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          order.requiereCobro
                              ? Icons.payments_outlined
                              : Icons.check_circle_outline,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.metodoPago,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Material(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      OrderItemsDialog.show(
                        context,
                        order: order,
                        stopNumber: stopNumber,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${order.items.length} prod • ${order.totalUnidades} un.',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la etiqueta de estado con el color semántico correspondiente.
  Widget _buildStatusBadge(OrderModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: order.estadoColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: order.estadoColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(
              color: order.estadoColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            order.estadoLabel,
            style: TextStyle(
              color: order.estadoColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
