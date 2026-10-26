import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/orders_cubit.dart';
import '../blocs/tracking_cubit.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../models/order_model.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import 'widgets/osm_map_widget.dart';

/// Pantalla de vista previa cartográfica con los puntos y secuencia de paradas antes de iniciar ruta.
class RoutePreviewMapScreen extends StatefulWidget {
  /// Crea una nueva instancia de [RoutePreviewMapScreen].
  const RoutePreviewMapScreen({super.key});

  @override
  State<RoutePreviewMapScreen> createState() => _RoutePreviewMapScreenState();
}

/// Estado interno de [RoutePreviewMapScreen] para el cálculo de polilínea y selección de paradas.
class _RoutePreviewMapScreenState extends State<RoutePreviewMapScreen> {
  /// Servicio de cálculo de rutas viales.
  final RoutingService _routingService = RoutingService();

  /// Lista de coordenadas que conforman la polilínea completa del recorrido.
  List<LatLng> _fullRoutePoints = [];

  /// Indica si se está calculando la geometría de la ruta en segundo plano.
  bool _isLoadingRoute = false;

  /// Indica si se está procesando el inicio de la ruta.
  bool _isStartingRoute = false;

  /// Indica si el listado flotante de paradas se encuentra desplegado.
  bool _isStopsListExpanded = true;

  /// Identificador de la parada enfocada manualmente en la vista previa.
  String? _selectedPreviewStopId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreviewStreetRoute();
    });
  }

  /// Resuelve una coordenada válida para el domiciliario dentro de los límites nacionales.
  LatLng _resolveCourierLocation(LatLng? rawLoc) {
    if (rawLoc != null &&
        LocationService.isWithinColombia(rawLoc.latitude, rawLoc.longitude)) {
      return rawLoc;
    }
    return LocationService.defaultLocation;
  }

  /// Calcula la ruta vial completa que une todas las paradas asignadas.
  Future<void> _loadPreviewStreetRoute() async {
    if (_isLoadingRoute) return;
    _isLoadingRoute = true;

    try {
      final ordersState = context.read<OrdersCubit>().state;
      final trackState = context.read<TrackingCubit>().state;
      final courierLoc = _resolveCourierLocation(trackState.currentLocation);

      final waypoints = <LatLng>[
        courierLoc,
        ...ordersState.orders.map((o) => LatLng(o.latitud, o.longitud)),
      ];

      final multiRoute = await _routingService.getMultiStopRoute(
        waypoints: waypoints,
      );

      if (mounted) {
        setState(() {
          _fullRoutePoints = multiRoute.fullPoints;
          _isLoadingRoute = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  /// Activa el turno del domiciliario, inicia el recorrido secuencial y navega al mapa en vivo.
  Future<void> _handleIniciarRuta() async {
    if (_isStartingRoute) return;
    setState(() => _isStartingRoute = true);

    try {
      final authCubit = context.read<AuthCubit>();
      final ordersCubit = context.read<OrdersCubit>();
      final trackingCubit = context.read<TrackingCubit>();
      final courier = authCubit.currentCourier;

      if (courier != null && !courier.isOnline) {
        await authCubit.toggleShiftStatus(true);
      }

      final activeStop = await ordersCubit.startFullCourierRoute(
        token: courier?.token,
      );

      trackingCubit.syncWithShiftStatus(
        courier: authCubit.currentCourier?.copyWith(isOnline: true),
        activeOrderId: activeStop?.id ?? ordersCubit.state.activeOrderId,
      );

      if (mounted) {
        setState(() => _isStartingRoute = false);
        Navigator.of(context).pushReplacementNamed(AppRoutes.courierRouteMap);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isStartingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courier = context.watch<AuthCubit>().currentCourier;
    final plateDisplay =
        (courier != null && courier.placaVehiculo.trim().isNotEmpty)
            ? courier.placaVehiculo.trim()
            : 'Sin placa';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Puntos y Orden de Ruta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${state.totalCount} entregas programadas • ${state.pendingCount} pendientes',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, ordersState) {
          final turnOrder = ordersState.currentTurnOrder;
          final focusedId = _selectedPreviewStopId ??
              turnOrder?.id ??
              ordersState.activeOrder?.id;
          OrderModel? focusedOrder;
          if (focusedId != null) {
            try {
              focusedOrder =
                  ordersState.orders.firstWhere((o) => o.id == focusedId);
            } catch (_) {}
          }
          focusedOrder ??=
              ordersState.orders.isNotEmpty ? ordersState.orders.first : null;

          return BlocBuilder<TrackingCubit, TrackingState>(
            builder: (context, trackState) {
              final courierLatLng = _resolveCourierLocation(
                trackState.currentLocation,
              );
              final destLatLng = focusedOrder != null
                  ? LatLng(focusedOrder.latitud, focusedOrder.longitud)
                  : courierLatLng;

              return Stack(
                children: [
                  Positioned.fill(
                    child: OsmMapWidget(
                      courierLocation: courierLatLng,
                      destinationLocation: destLatLng,
                      destinationTitle:
                          focusedOrder?.clienteNombre ?? 'Punto de Entrega',
                      courierPlate: plateDisplay,
                      heading: trackState.heading,
                      showPolyline: true,
                      showCourierMarker: true,
                      fullRoutePoints: _fullRoutePoints,
                      allStops: ordersState.orders,
                      activeStopId: focusedOrder?.id,
                      bottomControlsOffset: 84,
                      onStopTap: (tappedStop) {
                        setState(() {
                          _selectedPreviewStopId = tappedStop.id;
                        });
                      },
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _buildFloatingStopsListOverlay(
                      ordersState: ordersState,
                      focusedOrderId: focusedOrder?.id,
                      turnOrderId: turnOrder?.id,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: Builder(
                      builder: (context) {
                        final hasAlreadyStarted = ordersState.isRouteActive ||
                            ordersState.orders.any(
                              (o) => o.estado != OrderStatus.asignado,
                            );

                        return FloatingActionButton.extended(
                          heroTag: 'fab_iniciar_ruta_en_mapa',
                          onPressed:
                              _isStartingRoute ? null : _handleIniciarRuta,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          icon: _isStartingRoute
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  hasAlreadyStarted
                                      ? Icons.directions_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 24,
                                ),
                          label: Text(
                            hasAlreadyStarted
                                ? 'Continuar Ruta'
                                : 'Iniciar Ruta',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        );
                      },
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

  /// Construye la tarjeta flotante superior con la secuencia ordenada de paradas.
  Widget _buildFloatingStopsListOverlay({
    required OrdersState ordersState,
    required String? focusedOrderId,
    required String? turnOrderId,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: _isStopsListExpanded ? 245 : 48,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderHighlight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _isStopsListExpanded = !_isStopsListExpanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.format_list_numbered_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ORDEN DE PUNTOS (${ordersState.totalCount} PARADAS)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _isStopsListExpanded ? 'Ocultar' : 'Ver puntos',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        _isStopsListExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isStopsListExpanded) ...[
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: ordersState.orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final stop = ordersState.orders[index];
                  final seq = index + 1;
                  final isFocused = focusedOrderId == stop.id;
                  final isTurn = turnOrderId == stop.id;
                  final isDelivered = stop.estado == OrderStatus.entregado;
                  final isNovelty = stop.estado == OrderStatus.novedad;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPreviewStopId = stop.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppColors.primarySoft
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isFocused ? AppColors.primary : AppColors.border,
                          width: isFocused ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? const Color(0xFF10B981)
                                  : isNovelty
                                      ? AppColors.error
                                      : isTurn
                                          ? AppColors.primary
                                          : const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isDelivered
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '$seq',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF08A),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stop.id,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 9,
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
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stop.direccion} • ${stop.barrio}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? const Color(0xFFD1FAE5)
                                  : isTurn
                                      ? AppColors.primarySoft
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isDelivered
                                  ? 'Entregado'
                                  : isNovelty
                                      ? 'Novedad'
                                      : isTurn
                                          ? 'Siguiente'
                                          : 'En cola #$seq',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDelivered
                                    ? const Color(0xFF047857)
                                    : isTurn
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
