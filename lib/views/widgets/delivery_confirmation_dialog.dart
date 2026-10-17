import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';

/// Modal para confirmar la entrega exitosa y el recaudo de dinero en efectivo
class DeliveryConfirmationDialog extends StatefulWidget {
  final OrderModel order;
  final Function(double cashReceived, String receiverName, String notes) onConfirm;

  const DeliveryConfirmationDialog({
    super.key,
    required this.order,
    required this.onConfirm,
  });

  @override
  State<DeliveryConfirmationDialog> createState() => _DeliveryConfirmationDialogState();
}

class _DeliveryConfirmationDialogState extends State<DeliveryConfirmationDialog> {
  late final TextEditingController _cashController;
  late final TextEditingController _receiverController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(
      text: widget.order.requiereCobro ? widget.order.montoTotal.toInt().toString() : '0',
    );
    _receiverController = TextEditingController(text: widget.order.clienteNombre);
    _notesController = TextEditingController();
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
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
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
                        'Confirmar Entrega',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.order.id,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),

            // Card Resumen de Cobro
            if (widget.order.requiereCobro) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto a recaudar:',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Efectivo contraentrega',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.order.montoFormatted,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Campo Efectivo Recibido
              const Text(
                'Efectivo Recibido (\$ COP)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  hintText: 'Ej. 148000',
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Nombre de quién recibe
            const Text(
              'Nombre de quién recibe',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
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

            // Observaciones opcionales
            const Text(
              'Observaciones de entrega (Opcional)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes_rounded),
                hintText: 'Ej. Recibió portero Luis en torre 2',
              ),
            ),

            const SizedBox(height: 22),

            // Botones de Acción
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
                  child: ElevatedButton(
                    onPressed: () {
                      final cash = double.tryParse(_cashController.text) ?? widget.order.montoTotal;
                      final receiver = _receiverController.text.trim();
                      final notes = _notesController.text.trim();
                      widget.onConfirm(cash, receiver, notes);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmar Cobro'),
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
