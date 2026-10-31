import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';

/// Opción de método de pago disponible durante la confirmación de entrega.
class PaymentMethodOption {
  /// Identificador único del método de pago.
  final String id;

  /// Nombre visible del método de pago.
  final String label;

  /// Subtítulo descriptivo de la modalidad de recaudo.
  final String subtitle;

  /// Icono representativo del medio de pago.
  final IconData icon;

  /// Color distintivo de la opción.
  final Color color;

  /// Crea una nueva instancia de [PaymentMethodOption].
  const PaymentMethodOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// Diálogo modal para confirmar la entrega del pedido, seleccionar el medio de pago y registrar el recaudo.
class DeliveryConfirmationDialog extends StatefulWidget {
  /// Pedido cuya entrega se está confirmando.
  final OrderModel order;

  /// Función callback invocada al confirmar la entrega con los datos de pago y recepción.
  final void Function(
    double cashReceived,
    String receiverName,
    String notes,
    String paymentMethod,
  ) onConfirm;

  /// Crea una nueva instancia de [DeliveryConfirmationDialog].
  const DeliveryConfirmationDialog({
    super.key,
    required this.order,
    required this.onConfirm,
  });

  @override
  State<DeliveryConfirmationDialog> createState() =>
      _DeliveryConfirmationDialogState();
}

/// Estado interno de [DeliveryConfirmationDialog] que gestiona los campos de recaudo y receptor.
class _DeliveryConfirmationDialogState
    extends State<DeliveryConfirmationDialog> {
  /// Catálogo base de medios de pago mientras se sincronizan los parámetros del sistema.
  static const List<PaymentMethodOption> _defaultPaymentOptions = [
    PaymentMethodOption(
      id: 'Efectivo',
      label: 'Efectivo',
      subtitle: 'Recaudo en billetes/monedas',
      icon: Icons.payments_outlined,
      color: Color(0xFF1E5E3A),
    ),
    PaymentMethodOption(
      id: 'Nequi',
      label: 'Nequi',
      subtitle: 'Transferencia verificada',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF7C3AED),
    ),
    PaymentMethodOption(
      id: 'Bancolombia',
      label: 'Bancolombia',
      subtitle: 'Transferencia / QR',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF2563EB),
    ),
    PaymentMethodOption(
      id: 'Daviplata',
      label: 'Daviplata',
      subtitle: 'Billetera digital',
      icon: Icons.qr_code_2_rounded,
      color: Color(0xFFDC2626),
    ),
    PaymentMethodOption(
      id: 'Crédito',
      label: 'Crédito',
      subtitle: 'Cuenta por cobrar autorizada',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFD97706),
    ),
  ];

  /// Lista reactiva de opciones de pago configuradas en Parámetros del Sistema.
  List<PaymentMethodOption> _paymentOptions = _defaultPaymentOptions;

  /// Controlador para el monto recibido en efectivo.
  late final TextEditingController _cashController;

  /// Controlador para el nombre de la persona que recibe el pedido.
  late final TextEditingController _receiverController;

  /// Controlador para observaciones o número de comprobante.
  late final TextEditingController _notesController;

  /// Método de pago seleccionado actualmente.
  late String _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = _detectInitialMethod(
      widget.order.metodoPago,
      _paymentOptions,
    );
    _cashController = TextEditingController(
      text: widget.order.montoTotal.toInt().toString(),
    );
    _receiverController = TextEditingController(
      text: widget.order.clienteNombre,
    );
    _notesController = TextEditingController();
    _loadConfiguredPaymentMethods();
  }

  /// Carga dinámicamente los métodos de pago activos desde `/api/payment-methods`.
  Future<void> _loadConfiguredPaymentMethods() async {
    try {
      final rawMethods = await ApiService().fetchActivePaymentMethods();
      if (!mounted || rawMethods.isEmpty) return;

      final mapped = rawMethods
          .map(_buildOptionFromApi)
          .where((opt) => opt.label.trim().isNotEmpty)
          .toList();

      if (mapped.isEmpty) return;

      setState(() {
        _paymentOptions = mapped;
        final exists = _paymentOptions.any(
          (opt) => opt.id.toLowerCase() == _selectedPaymentMethod.toLowerCase(),
        );
        if (!exists) {
          _selectedPaymentMethod = _detectInitialMethod(
            widget.order.metodoPago,
            _paymentOptions,
          );
        } else {
          _selectedPaymentMethod = _paymentOptions
              .firstWhere(
                (opt) =>
                    opt.id.toLowerCase() ==
                    _selectedPaymentMethod.toLowerCase(),
              )
              .id;
        }
      });
    } catch (_) {}
  }

  /// Construye un [PaymentMethodOption] con estilo visual apropiado según el registro del backend.
  PaymentMethodOption _buildOptionFromApi(Map<String, dynamic> raw) {
    final name = (raw['name'] ?? raw['code'] ?? '').toString().trim();
    final lower = name.toLowerCase();
    final requiresRef = (raw['requiresReference'] ?? false) == true;

    if (lower.contains('efectivo') || lower.contains('cash')) {
      return PaymentMethodOption(
        id: name,
        label: name,
        subtitle: 'Recaudo en billetes/monedas',
        icon: Icons.payments_outlined,
        color: const Color(0xFF1E5E3A),
      );
    }
    if (lower.contains('nequi')) {
      return PaymentMethodOption(
        id: name,
        label: name,
        subtitle: 'Transferencia verificada',
        icon: Icons.phone_android_rounded,
        color: const Color(0xFF7C3AED),
      );
    }
    if (lower.contains('bancolombia') ||
        lower.contains('banco') ||
        lower.contains('transferencia')) {
      return PaymentMethodOption(
        id: name,
        label: name,
        subtitle: 'Transferencia / QR',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF2563EB),
      );
    }
    if (lower.contains('daviplata')) {
      return PaymentMethodOption(
        id: name,
        label: name,
        subtitle: 'Billetera digital',
        icon: Icons.qr_code_2_rounded,
        color: const Color(0xFFDC2626),
      );
    }
    if (lower.contains('crédito') || lower.contains('credito')) {
      return PaymentMethodOption(
        id: name,
        label: name,
        subtitle: 'Cuenta por cobrar autorizada',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFD97706),
      );
    }
    return PaymentMethodOption(
      id: name,
      label: name,
      subtitle: requiresRef ? 'Requiere comprobante' : 'Medio de pago activo',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF0D9488),
    );
  }

  /// Determina la opción de pago inicial a partir del método configurado en la orden y las opciones disponibles.
  String _detectInitialMethod(
    String rawMethod,
    List<PaymentMethodOption> options,
  ) {
    if (options.isEmpty) return 'Efectivo';
    final lower = rawMethod.trim().toLowerCase();

    for (final opt in options) {
      final optLower = opt.id.toLowerCase();
      if (optLower == lower ||
          (lower.isNotEmpty &&
              (lower.contains(optLower) || optLower.contains(lower)))) {
        return opt.id;
      }
    }

    if (lower.contains('transferencia') || lower.contains('bancolombia')) {
      for (final opt in options) {
        final optLower = opt.id.toLowerCase();
        if (optLower.contains('bancolombia') ||
            optLower.contains('transferencia')) {
          return opt.id;
        }
      }
    }

    for (final opt in options) {
      if (opt.id.toLowerCase().contains('efectivo')) {
        return opt.id;
      }
    }

    return options.first.id;
  }

  @override
  void dispose() {
    _cashController.dispose();
    _receiverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lowerSelected = _selectedPaymentMethod.toLowerCase();
    final isCashSelected =
        lowerSelected.contains('efectivo') || lowerSelected.contains('cash');
    final isCreditSelected =
        lowerSelected.contains('crédito') || lowerSelected.contains('credito');

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirmar Entrega y Pago',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${widget.order.id} • ${widget.order.clienteNombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total del pedido:',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Forma seleccionada: $_selectedPaymentMethod',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.order.montoFormatted,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecciona la Forma de Pago',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentOptions.map((opt) {
                final isSelected = _selectedPaymentMethod == opt.id;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = opt.id;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? opt.color.withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? opt.color : AppColors.borderHighlight,
                        width: isSelected ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 16,
                          color:
                              isSelected ? opt.color : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w900 : FontWeight.w700,
                            color:
                                isSelected ? opt.color : AppColors.textPrimary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: opt.color,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (isCashSelected) ...[
              const Text(
                'Efectivo Recibido (\$ COP)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  hintText: 'Monto recibido',
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderHighlight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCreditSelected
                            ? 'Se registrará como cuenta por cobrar a crédito.'
                            : 'Verifica el comprobante de pago por $_selectedPaymentMethod antes de entregar.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              'Nombre de quién recibe',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _receiverController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline_rounded),
                hintText: 'Nombre completo',
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Observaciones / N° Comprobante (Opcional)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes_rounded),
                hintText: 'Observaciones de la entrega o referencia de pago',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final cash = isCashSelected
                          ? (double.tryParse(_cashController.text) ??
                              widget.order.montoTotal)
                          : widget.order.montoTotal;
                      final receiver = _receiverController.text.trim();
                      final notes = _notesController.text.trim();
                      widget.onConfirm(
                        cash,
                        receiver,
                        notes,
                        _selectedPaymentMethod,
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Confirmar Entrega'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
