import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';

/// Diálogo modal para reportar incidencias o novedades en pedidos que no pudieron entregarse.
class NoveltyDialog extends StatefulWidget {
  /// Pedido sobre el cual se reporta la novedad.
  final OrderModel order;

  /// Callback invocado con la descripción del motivo de la novedad.
  final void Function(String reason) onReport;

  /// Crea una nueva instancia de [NoveltyDialog].
  const NoveltyDialog({
    super.key,
    required this.order,
    required this.onReport,
  });

  @override
  State<NoveltyDialog> createState() => _NoveltyDialogState();
}

/// Estado interno de [NoveltyDialog] para la selección de causal y observaciones adicionales.
class _NoveltyDialogState extends State<NoveltyDialog> {
  /// Motivos operativos estándar de novedad en entrega.
  final List<String> _commonReasons = [
    'Cliente no contesta llamadas ni portería',
    'Dirección errónea o incompleta',
    'Cliente no tiene el dinero en efectivo',
    'Cliente canceló el pedido en el punto',
    'Falla mecánica / avería de la moto',
    'Producto averiado en trayecto',
  ];

  /// Motivo seleccionado actualmente en la lista.
  String? _selectedReason;

  /// Controlador de texto para el detalle adicional de la novedad.
  late final TextEditingController _customReasonController;

  @override
  void initState() {
    super.initState();
    _selectedReason = _commonReasons.first;
    _customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reportar Novedad',
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Selecciona el motivo:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ..._commonReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.error.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.error : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color:
                            isSelected ? AppColors.error : AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            const Text(
              'Detalle adicional:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _customReasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Añade información para la central de logística...',
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
                  child: ElevatedButton(
                    onPressed: () {
                      final extra = _customReasonController.text.trim();
                      final finalReason = extra.isNotEmpty
                          ? '$_selectedReason - $extra'
                          : (_selectedReason ?? 'Novedad no especificada');
                      widget.onReport(finalReason);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reportar'),
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
