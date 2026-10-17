import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/orders_cubit.dart';
import '../blocs/tracking_cubit.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import 'widgets/delivery_confirmation_dialog.dart';
import 'widgets/novelty_dialog.dart';
import 'widgets/osm_map_widget.dart';

/// Pantalla de Detalle de Entrega, Navegación con OpenStreetMap y Gestión de Estados
class OrderDetailMapScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailMapScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailMapScreen> createState() => _OrderDetailMapScreenState();
}

class _OrderDetailMapScreenState extends State<OrderDetailMapScreen> {
  final LocationService _locationService = LocationService();
  final RoutingService _routingService = RoutingService();
  late OrderModel _currentOrder;
  bool _isLoadingAction = false;

  List<LatLng> _routePoints = [];
  RouteData? _routeData;
  LatLng? _lastRouteStart;
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _initializeRoute();
  }

  void _initializeRoute() {
    final dest = LatLng(_currentOrder.latitud, _currentOrder.longitud);
    final trackingState = context.read<TrackingCubit>().state;
    final start = trackingState.currentLocation ?? LocationService.defaultLocation;
    _updateRoadRoute(start, dest);
  }

  Future<void> _updateRoadRoute(LatLng start, LatLng dest) async {
    if (_isFetchingRoute) return;

    if (_lastRouteStart != null) {
      final diff = _locationService.calculateDistanceInMeters(_lastRouteStart!, start);
      if (diff < 25 && _routePoints.isNotEmpty) {
        return; // No recalcular si se movió menos de 25m
      }
    }

    _isFetchingRoute = true;
    _lastRouteStart = start;

    final route = await _routingService.getRoute(start: start, end: dest);
    if (mounted) {
      setState(() {
        _routePoints = route.points;
        _routeData = route;
        _isFetchingRoute = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showToast('No se pudo abrir el marcador de llamadas');
    }
  }

  Future<void> _openWhatsApp(String phone, String customerName) async {
    final courierName = context.read<AuthCubit>().currentCourier?.nombre ?? 'tu mensajero';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Asegurar código de país Colombia (+57) si empieza por 3
    final targetPhone = cleanPhone.startsWith('57')
        ? cleanPhone
        : cleanPhone.startsWith('3')
            ? '57$cleanPhone'
            : cleanPhone;

    final message = Uri.encodeComponent(
      'Hola $customerName, te saluda $courierName de *PulpasPro*. '
      'Estoy gestionando la entrega de tu pedido *${_currentOrder.id}*. '
      '¡Voy en camino a tu dirección!',
    );

    final waUri = Uri.parse('https://wa.me/$targetPhone?text=$message');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('No se pudo abrir WhatsApp');
    }
  }

  void _showExternalNavigationSheet(double destLat, double destLng) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Abrir Navegación Externa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona tu aplicación de GPS con voz preferida:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.waze.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.navigation, color: AppColors.waze, size: 24),
                ),
                title: const Text('Waze', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Rutas con tráfico en tiempo real y alertas'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final wazeUri = Uri.parse('https://waze.com/ul?ll=$destLat,$destLng&navigate=yes');
                  if (await canLaunchUrl(wazeUri)) {
                    await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map_rounded, color: AppColors.info, size: 24),
                ),
                title: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Navegación asistida paso a paso'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final gmapsUri = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng',
                  );
                  if (await canLaunchUrl(gmapsUri)) {
                    await launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // Acciones de Estado
  Future<void> _handleStartRoute() async {
    setState(() => _isLoadingAction = true);
    final token = context.read<AuthCubit>().currentCourier?.token;
    final success = await context.read<OrdersCubit>().startRoute(_currentOrder.id, token: token);
    if (success && mounted) {
      setState(() {
        _currentOrder = _currentOrder.copyWith(estado: OrderStatus.enCamino);
        _isLoadingAction = false;
      });
      _showToast('Estado actualizado: ¡En Camino!');
    } else {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleArrivedAtPoint() async {
    setState(() => _isLoadingAction = true);
    final token = context.read<AuthCubit>().currentCourier?.token;
    final success = await context.read<OrdersCubit>().arrivedAtPoint(_currentOrder.id, token: token);
    if (success && mounted) {
      setState(() {
        _currentOrder = _currentOrder.copyWith(estado: OrderStatus.enPunto);
        _isLoadingAction = false;
      });
      _showToast('Estado actualizado: ¡En el Punto!');
    } else {
      setState(() => _isLoadingAction = false);
    }
  }

  void _openConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => DeliveryConfirmationDialog(
        order: _currentOrder,
        onConfirm: (cashReceived, receiverName, notes) async {
          setState(() => _isLoadingAction = true);
          final token = context.read<AuthCubit>().currentCourier?.token;
          final success = await context.read<OrdersCubit>().confirmDelivery(
                _currentOrder.id,
                token: token,
                cashReceived: cashReceived,
                receiverName: receiverName,
                notes: notes,
              );
          if (success && mounted) {
            setState(() {
              _currentOrder = _currentOrder.copyWith(estado: OrderStatus.entregado);
              _isLoadingAction = false;
            });
            _showToast('¡Entrega y cobro confirmados exitosamente!');
          } else {
            setState(() => _isLoadingAction = false);
          }
        },
      ),
    );
  }

  void _openNoveltyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => NoveltyDialog(
        order: _currentOrder,
        onReport: (reason) async {
          setState(() => _isLoadingAction = true);
          final token = context.read<AuthCubit>().currentCourier?.token;
          final success = await context.read<OrdersCubit>().reportNovelty(
                _currentOrder.id,
                reason,
                token: token,
              );
          if (success && mounted) {
            setState(() {
              _currentOrder = _currentOrder.copyWith(
                estado: OrderStatus.novedad,
                observacionesNovedad: reason,
              );
              _isLoadingAction = false;
            });
            _showToast('Novedad reportada a la central.');
          } else {
            setState(() => _isLoadingAction = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationLatLng = LatLng(_currentOrder.latitud, _currentOrder.longitud);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentOrder.id,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              _currentOrder.clienteNombre,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          // Botón Waze / Google Maps
          IconButton(
            icon: const Icon(Icons.navigation_outlined, color: AppColors.primary),
            tooltip: 'Navegación Externa',
            onPressed: () => _showExternalNavigationSheet(
              _currentOrder.latitud,
              _currentOrder.longitud,
            ),
          ),
        ],
      ),
      body: BlocBuilder<TrackingCubit, TrackingState>(
        builder: (context, trackState) {
          final courierLatLng = trackState.currentLocation ?? LocationService.defaultLocation;
          
          // Disparar actualización de ruta vehicular si se mueve el mensajero
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRoadRoute(courierLatLng, destinationLatLng);
          });

          final straightDistance = _locationService.calculateDistanceInMeters(
            courierLatLng,
            destinationLatLng,
          );
          final displayDistance = _routeData?.distanceFormatted ?? _locationService.formatDistance(straightDistance);
          final displayEta = _routeData?.durationMinutes ?? _locationService.estimateEtaMinutes(straightDistance);

          return Column(
            children: [
              // 1. Mapa Interactivo OSM (Ocupa el 38% superior de la pantalla)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.36,
                child: Stack(
                  children: [
                    OsmMapWidget(
                      courierLocation: courierLatLng,
                      destinationLocation: destinationLatLng,
                      destinationTitle: _currentOrder.clienteNombre,
                      heading: trackState.heading,
                      routePoints: _routePoints,
                    ),
                    // Floating Badge con Distancia y ETA Real por Carretera
                    Positioned(
                      top: 12,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderHighlight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_bike_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$displayDistance • ~$displayEta min',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Información Detallada del Pedido y Botones
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge de Estado y Prioridad
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _currentOrder.estadoColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _currentOrder.estadoColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _currentOrder.estadoLabel,
                              style: TextStyle(
                                color: _currentOrder.estadoColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            _currentOrder.montoFormatted,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Card de Contacto del Cliente
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentOrder.clienteNombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_currentOrder.direccion}, ${_currentOrder.barrio}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Botones Rápidos de Llamada y WhatsApp
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                                    label: const Text('Llamar'),
                                    onPressed: () => _makePhoneCall(_currentOrder.clienteTelefono),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.whatsapp,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text('WhatsApp'),
                                    onPressed: () => _openWhatsApp(
                                      _currentOrder.clienteTelefono,
                                      _currentOrder.clienteNombre,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Notas u Observaciones de Entrega
                      if (_currentOrder.notasEntrega?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentOrder.notasEntrega!,
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Desglose de Productos
                      const Text(
                        'Productos en la Orden (Pulpas)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _currentOrder.items.map((item) {
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_florist_outlined,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                item.nombre,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                              subtitle: Text(
                                '${item.presentacion} • x${item.cantidad} un.',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              trailing: Text(
                                '\$${item.subtotal.toInt()} COP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 3. Barra Inferior Fija de Acciones Secuenciales
              _buildBottomActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    if (_isLoadingAction) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: AppColors.surface,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    switch (_currentOrder.estado) {
      case OrderStatus.asignado:
        return _buildActionContainer(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('1. Iniciar Ruta / En Camino', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            onPressed: _handleStartRoute,
          ),
        );

      case OrderStatus.enCamino:
        return _buildActionContainer(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusEnPunto,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.location_on_rounded, size: 20),
            label: const Text('2. Llegué al Punto / Dirección', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            onPressed: _handleArrivedAtPoint,
          ),
        );

      case OrderStatus.enPunto:
        return _buildActionContainer(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: const Text('Novedad', style: TextStyle(fontSize: 13)),
                  onPressed: _openNoveltyDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Confirmar Cobro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  onPressed: _openConfirmationDialog,
                ),
              ),
            ],
          ),
        );

      case OrderStatus.entregado:
        return _buildActionContainer(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Pedido Entregado y Recaudado',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );

      case OrderStatus.novedad:
        return _buildActionContainer(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Novedad: ${_currentOrder.observacionesNovedad ?? "No entregado"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildActionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: child,
      ),
    );
  }
}
