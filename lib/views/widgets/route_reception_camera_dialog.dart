import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';

/// Modal de Cámara / Evidencia Fotográfica para recibir el pedido de la ruta asignada
class RouteReceptionCameraDialog extends StatefulWidget {
  final String routeCode;
  final String routeZone;
  final int totalOrders;
  final int totalUnits;

  const RouteReceptionCameraDialog({
    super.key,
    required this.routeCode,
    required this.routeZone,
    required this.totalOrders,
    required this.totalUnits,
  });

  static Future<String?> show(
    BuildContext context, {
    required String routeCode,
    required String routeZone,
    required int totalOrders,
    required int totalUnits,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => RouteReceptionCameraDialog(
        routeCode: routeCode,
        routeZone: routeZone,
        totalOrders: totalOrders,
        totalUnits: totalUnits,
      ),
    );
  }

  @override
  State<RouteReceptionCameraDialog> createState() =>
      _RouteReceptionCameraDialogState();
}

class _RouteReceptionCameraDialogState
    extends State<RouteReceptionCameraDialog> {
  bool _showFlash = false;
  bool _hasCapturedPhoto = false;
  String _capturedTimestamp = '';

  void _capturePhoto() {
    final now = DateTime.now();
    final formatted = DateFormat('dd/MM/yyyy • hh:mm:ss a').format(now);

    setState(() {
      _showFlash = true;
    });

    Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() {
        _showFlash = false;
        _hasCapturedPhoto = true;
        _capturedTimestamp = formatted;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Barra superior de la cámara
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xFF34D399),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evidencia de Recepción',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${widget.routeCode} • ${widget.totalOrders} pedidos (${widget.totalUnits} un.)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Visor de Cámara / Vista Previa de Foto Capturada
              SizedBox(
                height: 310,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fondo del visor simulando encuadre de canastillas de pulpa
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E293B),
                            Color(0xFF0F291E),
                            Color(0xFF0F172A),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: _hasCapturedPhoto
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _hasCapturedPhoto
                                      ? const Color(0xFF34D399)
                                      : Colors.white.withValues(alpha: 0.22),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _hasCapturedPhoto
                                    ? Icons.check_circle_rounded
                                    : Icons.inventory_2_outlined,
                                color: _hasCapturedPhoto
                                    ? const Color(0xFF34D399)
                                    : Colors.white.withValues(alpha: 0.85),
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _hasCapturedPhoto
                                  ? 'FOTO DE CARGUE CAPTURADA'
                                  : 'ENCUADRA EL PEDIDO / CANASTILLAS',
                              style: TextStyle(
                                color: _hasCapturedPhoto
                                    ? const Color(0xFF34D399)
                                    : Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasCapturedPhoto
                                  ? 'Registro listo para habilitar las entregas'
                                  : '${widget.totalOrders} pedidos • ${widget.totalUnits} bolsas de pulpa',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Esquinas de enfoque del visor
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: CustomPaint(
                        painter: _ViewfinderCornersPainter(
                          color: _hasCapturedPhoto
                              ? const Color(0xFF34D399)
                              : Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),

                    // Marca de agua inferior con GPS y Ruta
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_outlined,
                                  color: Color(0xFF34D399),
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'DGL Domi • ${widget.routeCode}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _hasCapturedPhoto
                                  ? _capturedTimestamp
                                  : 'Cámara activa',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Efecto Flash al obturar
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showFlash ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Controles inferiores: Botón de Tomar Foto o Confirmar Recepción
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1E293B),
                child: !_hasCapturedPhoto
                    ? Column(
                        children: [
                          GestureDetector(
                            onTap: _capturePhoto,
                            child: Container(
                              width: 68,
                              height: 68,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toca para tomar foto del pedido recibido',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _hasCapturedPhoto = false);
                              },
                              icon: const Icon(Icons.replay_rounded, size: 17),
                              label: const Text(
                                'Repetir Foto',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop(_capturedTimestamp);
                              },
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Confirmar y Recibir',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;

  const _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const double len = 24;

    // Top-left
    canvas.drawLine(const Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

