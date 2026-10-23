import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
import 'widgets/order_items_dialog.dart';
import 'widgets/osm_map_widget.dart';

/// Pantalla de Enrutado en Vivo del Domiciliario
class CourierRouteMapScreen extends StatefulWidget {
  const CourierRouteMapScreen({super.key});

  @override
  State<CourierRouteMapScreen> createState() => _CourierRouteMapScreenState();
}

class _CourierRouteMapScreenState extends State<CourierRouteMapScreen> {
  final LocationService _locationService = LocationService();
  final RoutingService _routingService = RoutingService();

  MultiStopRouteData? _multiRouteData;
  List<LatLng> _activeLegPoints = [];
  RouteData? _activeLegData;
  bool _isCalculatingRoute = false;
  bool _isLoadingAction = false;
  bool _showAllStopsList = false;
  int _navigationZoomTrigger = 0;
  String _lastRouteSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Asegurar que al entrar a Enrutado en Vivo apunte a la parada en turno
      context.read<OrdersCubit>().focusCurrentTurnStop();
      _recalculateFullRoute(force: true);
    });
  }

  String _formatCop(double value) {
    final fmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return fmt.format(value);
  }

  LatLng _resolveCourierLocation(LatLng? rawLoc) {
    if (rawLoc != null &&
        LocationService.isWithinColombia(rawLoc.latitude, rawLoc.longitude)) {
      return rawLoc;
    }
    return LocationService.defaultLocation;
  }

  Future<void> _recalculateFullRoute({bool force = false}) async {
    if (_isCalculatingRoute) return;

    final ordersState = context.read<OrdersCubit>().state;
    final trackState = context.read<TrackingCubit>().state;
    final courierLoc = _resolveCourierLocation(trackState.currentLocation);
    final activeStop = ordersState.activeOrder;

    final pendingStops = ordersState.orders
        .where((o) =>
            o.estado != OrderStatus.entregado && o.estado != OrderStatus.novedad)
        .toList();

    final signature =
        '${courierLoc.latitude.toStringAsFixed(3)},${courierLoc.longitude.toStringAsFixed(3)}_'
        '${activeStop?.id ?? "none"}_'
        '${ordersState.orders.map((o) => "${o.id}:${o.estado.name}").join("|")}';

    if (!force && signature == _lastRouteSignature && _multiRouteData != null) {
      return;
    }

    _isCalculatingRoute = true;
    _lastRouteSignature = signature;

    // Construir secuencia de waypoints: Mensajero -> Paradas pendientes en orden
    final List<LatLng> waypoints = [
      courierLoc,
      ...(pendingStops.isNotEmpty
          ? pendingStops.map((s) => LatLng(s.latitud, s.longitud))
          : ordersState.orders.map((s) => LatLng(s.latitud, s.longitud))),
    ];

    final multiRoute = await _routingService.getMultiStopRoute(
      waypoints: waypoints,
    );

    RouteData? legData;
    if (activeStop != null) {
      legData = await _routingService.getRoute(
        start: courierLoc,
        end: LatLng(activeStop.latitud, activeStop.longitud),
      );
    }

    if (mounted) {
      setState(() {
        _multiRouteData = multiRoute;
        _activeLegData = legData;
        _activeLegPoints = legData?.points ?? [];
        _isCalculatingRoute = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(OrderModel order) async {
    final courierName =
        context.read<AuthCubit>().currentCourier?.nombre ?? 'tu mensajero';
    final cleanPhone = order.clienteTelefono.replaceAll(RegExp(r'[^0-9]'), '');
    final targetPhone = cleanPhone.startsWith('57')
        ? cleanPhone
        : cleanPhone.startsWith('3')
            ? '57$cleanPhone'
            : cleanPhone;

    final message = Uri.encodeComponent(
      'Hola ${order.clienteNombre}, te saluda $courierName de *PulpasPro*. '
      'Voy en ruta con tu pedido *${order.id}* hacia ${order.direccion}.',
    );

    final waUri = Uri.parse('https://wa.me/$targetPhone?text=$message');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showExternalNavigationSheet(OrderModel order) {
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
              Text(
                'Navegar a ${order.clienteNombre}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.direccion} • ${order.barrio}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.waze.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: AppColors.waze,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Waze',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Tráfico en vivo y alertas viales'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final wazeUri = Uri.parse(
                    'https://waze.com/ul?ll=${order.latitud},${order.longitud}&navigate=yes',
                  );
                  if (await canLaunchUrl(wazeUri)) {
                    await launchUrl(
                      wazeUri,
                      mode: LaunchMode.externalApplication,
                    );
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
                  child: const Icon(
                    Icons.map_rounded,
                    color: AppColors.info,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Google Maps',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Ruta paso a paso con voz'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final gmapsUri = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${order.latitud},${order.longitud}',
                  );
                  if (await canLaunchUrl(gmapsUri)) {
                    await launchUrl(
                      gmapsUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartLeg(OrderModel order) async {
    setState(() => _isLoadingAction = true);
    final token = context.read<AuthCubit>().currentCourier?.token;
    await context.read<OrdersCubit>().startRoute(order.id, token: token);
    if (mounted) {
      setState(() {
        _isLoadingAction = false;
        _navigationZoomTrigger++;
      });
      _recalculateFullRoute(force: true);
    }
  }

  Future<void> _handleArrivedAtStop(OrderModel order) async {
    setState(() => _isLoadingAction = true);
    final token = context.read<AuthCubit>().currentCourier?.token;
    await context.read<OrdersCubit>().arrivedAtPoint(order.id, token: token);
    if (mounted) {
      setState(() => _isLoadingAction = false);
    }
  }

  void _openConfirmDeliveryDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => DeliveryConfirmationDialog(
        order: order,
        onConfirm: (cashReceived, receiverName, notes, paymentMethod) async {
          setState(() => _isLoadingAction = true);
          final token = context.read<AuthCubit>().currentCourier?.token;
          await context.read<OrdersCubit>().confirmDelivery(
                order.id,
                token: token,
                cashReceived: cashReceived,
                paymentMethod: paymentMethod,
                receiverName: receiverName,
                notes: notes,
              );
          if (mounted) {
            setState(() => _isLoadingAction = false);
            _recalculateFullRoute(force: true);
            final nextTurn = context.read<OrdersCubit>().state.currentTurnOrder;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nextTurn != null
                      ? '¡Entrega confirmada ($paymentMethod)! Siguiente parada habilitada: ${nextTurn.clienteNombre}'
                      : '¡Excelente! Has completado todas las entregas de la ruta.',
                ),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        },
      ),
    );
  }

  void _openNoveltyDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => NoveltyDialog(
        order: order,
        onReport: (reason) async {
          setState(() => _isLoadingAction = true);
          final token = context.read<AuthCubit>().currentCourier?.token;
          await context.read<OrdersCubit>().reportNovelty(
                order.id,
                reason,
                token: token,
              );
          if (mounted) {
            setState(() => _isLoadingAction = false);
            _recalculateFullRoute(force: true);
            final nextTurn = context.read<OrdersCubit>().state.currentTurnOrder;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nextTurn != null
                      ? 'Novedad registrada. Siguiente parada habilitada: ${nextTurn.clienteNombre}'
                      : 'Ruta finalizada.',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courier = context.watch<AuthCubit>().currentCourier;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Enrutado en Vivo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Text(
              'Ruta ${courier?.placaVehiculo.split(" ").first ?? "XYZ-789"}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, ordersState) {
          final activeOrder = ordersState.activeOrder;

          return BlocBuilder<TrackingCubit, TrackingState>(
            builder: (context, trackState) {
              final courierLatLng = _resolveCourierLocation(
                trackState.currentLocation,
              );

              final destLatLng = activeOrder != null
                  ? LatLng(activeOrder.latitud, activeOrder.longitud)
                  : courierLatLng;

              final activeStopIndex = activeOrder != null
                  ? ordersState.getStopSequenceNumber(activeOrder.id)
                  : 1;

              final straightDist = _locationService.calculateDistanceInMeters(
                courierLatLng,
                destLatLng,
              );
              final legDistanceLabel = _activeLegData?.distanceFormatted ??
                  _locationService.formatDistance(straightDist);
              final legEtaLabel = _activeLegData?.durationMinutes ??
                  _locationService.estimateEtaMinutes(straightDist);

              return Column(
                children: [
                  // 1. Barra Superior de Telemetría
                  _buildPwaTelemetryHeader(ordersState),

                  // 2. Lienzo del Mapa Limpio (Sin pills superiores ni botón Cava Matriz ni Optimizar)
                  Expanded(
                    flex: _showAllStopsList ? 5 : 6,
                    child: OsmMapWidget(
                      courierLocation: courierLatLng,
                      destinationLocation: destLatLng,
                      destinationTitle:
                          activeOrder?.clienteNombre ?? 'Punto de Entrega',
                      courierPlate: courier?.placaVehiculo ?? 'XYZ-789',
                      heading: trackState.heading,
                      showPlantaMatriz: false,
                      isNavigationMode: true,
                      navigationZoomTrigger: _navigationZoomTrigger,
                      stopSequenceNumber: activeStopIndex,
                      routePoints: _activeLegPoints,
                      fullRoutePoints: _multiRouteData?.fullPoints,
                      allStops: ordersState.orders,
                      activeStopId: activeOrder?.id,
                      onStopTap: (tappedOrder) {
                        context.read<OrdersCubit>().selectStop(tappedOrder.id);
                        _recalculateFullRoute(force: true);
                      },
                    ),
                  ),

                  // 3. Panel Inferior de Secuencia de Enrutado y Control Secuencial Estricto
                  Expanded(
                    flex: _showAllStopsList ? 6 : 4,
                    child: _buildBottomRoutePanel(
                      ordersState: ordersState,
                      activeOrder: activeOrder,
                      activeStopIndex: activeStopIndex,
                      legDistanceLabel: legDistanceLabel,
                      legEtaLabel: legEtaLabel,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Barra de telemetría superior
  Widget _buildPwaTelemetryHeader(OrdersState state) {
    final totalDist =
        _multiRouteData?.totalDistanceFormatted ?? 'Calculando...';
    final totalMins = _multiRouteData != null
        ? '~${_multiRouteData!.totalDurationMinutes} min'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // 1. Progreso de Entregas
          Expanded(
            child: _buildTelemetryPill(
              icon: Icons.inventory_2_outlined,
              iconBg: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF2563EB),
              value: '${state.deliveredCount}/${state.totalCount} Entregas',
              label: '${state.pendingCount} en ruta',
            ),
          ),
          const SizedBox(width: 8),
          // 2. Distancia y Tiempo del Enrutado Completo
          Expanded(
            child: _buildTelemetryPill(
              icon: Icons.route_rounded,
              iconBg: const Color(0xFFD1FAE5),
              iconColor: const Color(0xFF059669),
              value: totalDist,
              label:
                  totalMins.isNotEmpty ? 'Circuito $totalMins' : 'Ruta vial',
            ),
          ),
          const SizedBox(width: 8),
          // 3. Recaudo en Calle
          Expanded(
            child: _buildTelemetryPill(
              icon: Icons.payments_outlined,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              value: _formatCop(state.totalCashToCollect),
              label: 'Por recaudar',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPill({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Panel inferior limpio (sin la tira horizontal de botones que se marcó con X)
  Widget _buildBottomRoutePanel({
    required OrdersState ordersState,
    required OrderModel? activeOrder,
    required int activeStopIndex,
    required String legDistanceLabel,
    required int legEtaLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: const Border(top: BorderSide(color: AppColors.borderHighlight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera del Drawer: Título + Botón Ver Lista Completa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.alt_route_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SECUENCIA DE ENRUTADO (${ordersState.totalCount} PARADAS)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () =>
                      setState(() => _showAllStopsList = !_showAllStopsList),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _showAllStopsList
                          ? AppColors.primary
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showAllStopsList
                              ? Icons.gps_fixed_rounded
                              : Icons.format_list_numbered_rounded,
                          size: 13,
                          color: _showAllStopsList
                              ? Colors.white
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showAllStopsList
                              ? 'Ver Parada Activa'
                              : 'Ver Lista Completa',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _showAllStopsList
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido del Panel: Lista Completa del Enrutado o Tarjeta de Parada Activa
          Expanded(
            child: _showAllStopsList
                ? _buildFullSequenceListView(ordersState, activeOrder)
                : activeOrder != null
                    ? _buildActiveStopFocusedCard(
                        ordersState: ordersState,
                        order: activeOrder,
                        stopIndex: activeStopIndex,
                        totalStops: ordersState.totalCount,
                        legDistanceLabel: legDistanceLabel,
                        legEtaLabel: legEtaLabel,
                      )
                    : const Center(
                        child: Text('No hay paradas asignadas en la ruta.'),
                      ),
          ),
        ],
      ),
    );
  }

  /// Vista enfocada en la parada seleccionada con bloqueo secuencial para paradas posteriores
  Widget _buildActiveStopFocusedCard({
    required OrdersState ordersState,
    required OrderModel order,
    required int stopIndex,
    required int totalStops,
    required String legDistanceLabel,
    required int legEtaLabel,
  }) {
    final isUnlocked = ordersState.isOrderUnlocked(order.id);
    final turnOrder = ordersState.currentTurnOrder;
    final turnIndex = turnOrder != null
        ? ordersState.getStopSequenceNumber(turnOrder.id)
        : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Badge Parada #X + Estado + Monto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE047)),
                    ),
                    child: Text(
                      'PARADA #$stopIndex DE $totalStops',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: order.estadoColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.estadoLabel.toUpperCase(),
                      style: TextStyle(
                        color: order.estadoColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                order.montoFormatted,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Nombre del Cliente y Dirección
          Text(
            order.clienteNombre,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${order.direccion} • ${order.barrio} ($legDistanceLabel, ~$legEtaLabel min)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Botones rápidos: Llamar, WhatsApp, Waze/Maps, Detalle
          Row(
            children: [
              Expanded(
                child: _buildQuickActionChip(
                  icon: Icons.phone_rounded,
                  label: 'Llamar',
                  color: AppColors.primary,
                  onTap: () => _makePhoneCall(order.clienteTelefono),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionChip(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: AppColors.whatsapp,
                  onTap: () => _openWhatsApp(order),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionChip(
                  icon: Icons.navigation_rounded,
                  label: 'Waze/Maps',
                  color: AppColors.info,
                  onTap: () => _showExternalNavigationSheet(order),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'Pulpas',
                  color: AppColors.textPrimary,
                  onTap: () {
                    OrderItemsDialog.show(
                      context,
                      order: order,
                      stopNumber: stopIndex,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Botón de acción secuencial (o bloqueo si no es la parada en turno)
          _buildDirectRouteStepButton(
            order: order,
            stopIndex: stopIndex,
            isUnlocked: isUnlocked,
            turnOrder: turnOrder,
            turnIndex: turnIndex,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectRouteStepButton({
    required OrderModel order,
    required int stopIndex,
    required bool isUnlocked,
    required OrderModel? turnOrder,
    required int turnIndex,
  }) {
    if (_isLoadingAction) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (order.estado == OrderStatus.entregado) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Parada #$stopIndex Entregada (${order.metodoPago})',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    if (order.estado == OrderStatus.novedad) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Novedad reportada: ${order.observacionesNovedad ?? "No entregado"}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    // BLOQUEO SECUENCIAL ESTRICTO: Si intenta entregar la 2da, 3ra, 4ta parada sin finalizar la que está en curso
    if (!isUnlocked && turnOrder != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFB45309),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Primero debes confirmar la entrega o novedad de la Parada #$turnIndex (${turnOrder.clienteNombre}).',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                context.read<OrdersCubit>().selectStop(turnOrder.id);
                _recalculateFullRoute(force: true);
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Ir a #$turnIndex',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    switch (order.estado) {
      case OrderStatus.asignado:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              'Iniciar Tramo hacia Parada #$stopIndex (${order.id})',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: () => _handleStartLeg(order),
          ),
        );

      case OrderStatus.enCamino:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusEnPunto,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.location_on_rounded, size: 19),
            label: Text(
              'Llegué a la Parada #$stopIndex • ${order.direccion}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: () => _handleArrivedAtStop(order),
          ),
        );

      case OrderStatus.enPunto:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.report_problem_outlined, size: 16),
                label: const Text('Novedad', style: TextStyle(fontSize: 12.5)),
                onPressed: () => _openNoveltyDialog(order),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  'Confirmar Entrega #$stopIndex',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => _openConfirmDeliveryDialog(order),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Lista completa de todas las paradas en orden de enrutamiento
  Widget _buildFullSequenceListView(
    OrdersState ordersState,
    OrderModel? activeOrder,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: ordersState.orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final stop = ordersState.orders[index];
        final seq = index + 1;
        final isSelected = activeOrder?.id == stop.id;
        final isUnlocked = ordersState.isOrderUnlocked(stop.id);
        final isDelivered = stop.estado == OrderStatus.entregado;
        final isNovelty = stop.estado == OrderStatus.novedad;

        return InkWell(
          onTap: () {
            context.read<OrdersCubit>().selectStop(stop.id);
            setState(() => _showAllStopsList = false);
            _recalculateFullRoute(force: true);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySoft : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.borderHighlight,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Círculo de secuencia (#1, #2, #3...)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? const Color(0xFF10B981)
                        : isNovelty
                            ? AppColors.error
                            : isUnlocked
                                ? AppColors.primary
                                : const Color(0xFF64748B),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDelivered
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : !isUnlocked && !isNovelty
                            ? const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 14,
                              )
                            : Text(
                                '$seq',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 10),
                // Datos de la parada
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF08A),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '#$seq • ${stop.id}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              stop.clienteNombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${stop.direccion} • ${stop.barrio}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Valor y Estado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stop.montoFormatted,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stop.estadoColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        !isUnlocked && !isDelivered && !isNovelty
                            ? 'En espera'
                            : stop.estadoLabel,
                        style: TextStyle(
                          color: stop.estadoColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
