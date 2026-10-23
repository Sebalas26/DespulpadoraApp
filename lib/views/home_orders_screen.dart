import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/orders_cubit.dart';
import '../blocs/tracking_cubit.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/websocket_service.dart';
import 'widgets/order_card_widget.dart';

/// Dashboard Principal de Domicilios y Rutas del Día
class HomeOrdersScreen extends StatefulWidget {
  const HomeOrdersScreen({super.key});

  @override
  State<HomeOrdersScreen> createState() => _HomeOrdersScreenState();
}

class _HomeOrdersScreenState extends State<HomeOrdersScreen> {
  final GlobalKey _menuButtonKey = GlobalKey();
  bool _isMenuOpen = false;
  bool _isSimulatingEndpointLoad = false;
  Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    final isCurrentlyOnline =
        context.read<AuthCubit>().currentCourier?.isOnline ?? false;
    if (isCurrentlyOnline) {
      _triggerShiftShimmerLoad();
    }
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    super.dispose();
  }

  void _triggerShiftShimmerLoad() {
    _shimmerTimer?.cancel();
    setState(() => _isSimulatingEndpointLoad = true);
    _shimmerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isSimulatingEndpointLoad = false);
      }
    });
  }

  void _refreshData() {
    final courier = context.read<AuthCubit>().currentCourier;
    if (courier != null) {
      context.read<OrdersCubit>().loadOrders(
            courierId: courier.id,
            token: courier.token,
          );
      // Sincronizar estado de rastreo
      final activeOrderId = context.read<OrdersCubit>().state.activeOrderId;
      context.read<TrackingCubit>().syncWithShiftStatus(
            courier: courier,
            activeOrderId: activeOrderId,
          );
    }
  }

  void _openRoutePreview() {
    Navigator.of(context).pushNamed(AppRoutes.routePreviewMap);
  }

  Future<void> _openTopOptionsMenu() async {
    final renderBox =
        _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    Offset buttonOffset = const Offset(0, 56);
    Size buttonSize = const Size(38, 38);

    if (renderBox != null && overlay != null) {
      buttonOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
      buttonSize = renderBox.size;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final rightEdge = screenWidth - (buttonOffset.dx + buttonSize.width);
    final hasAssignedRoute =
        context.read<OrdersCubit>().state.hasAssignedRoute;

    setState(() => _isMenuOpen = true);

    final selectedAction = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar menú de opciones',
      // Oscurecido suave y ligero en el fondo ("un poco no más, no tan oscuro")
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Botón de 3 puntos resaltado por encima del fondo oscurecido, conectado a la card
            Positioned(
              top: buttonOffset.dy,
              right: rightEdge,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    width: buttonSize.width,
                    height: buttonSize.height,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryBorder,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Card emergente que nace directamente desde el icono de los 3 puntos
            Positioned(
              top: buttonOffset.dy + buttonSize.height + 2,
              right: rightEdge,
              child: _AnimatedThreeDotsMenuCard(
                animation: animation,
                buttonWidth: buttonSize.width,
                hasAssignedRoute: hasAssignedRoute,
                onSelect: (action) => Navigator.of(dialogContext).pop(action),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      setState(() => _isMenuOpen = false);
    }

    if (!mounted || selectedAction == null) return;

    if (selectedAction == 'refresh') {
      _refreshData();
      context.read<OrdersCubit>().setRouteAssignment(true);
      if (context.read<AuthCubit>().currentCourier?.isOnline ?? false) {
        _triggerShiftShimmerLoad();
      }
    } else if (selectedAction == 'toggle_route_assignment') {
      final currentlyAssigned =
          context.read<OrdersCubit>().state.hasAssignedRoute;
      final nextState = !currentlyAssigned;
      context.read<OrdersCubit>().setRouteAssignment(nextState);
      if (nextState &&
          (context.read<AuthCubit>().currentCourier?.isOnline ?? false)) {
        _triggerShiftShimmerLoad();
      } else {
        _shimmerTimer?.cancel();
        setState(() => _isSimulatingEndpointLoad = false);
      }
    } else if (selectedAction == 'logout') {
      context.read<TrackingCubit>().stopTracking();
      context.read<AuthCubit>().logout();
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  String _formatCop(double value) {
    final fmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return fmt.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final courier = context.watch<AuthCubit>().currentCourier;
    final isOnShift = courier?.isOnline ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.two_wheeler,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    courier?.nombre ?? 'Mensajero PulpasPro',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Placa: ${courier?.placaVehiculo.isNotEmpty == true ? courier?.placaVehiculo : "XYZ-123"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Indicador de estado WebSocket en tiempo real
          BlocBuilder<TrackingCubit, TrackingState>(
            builder: (context, trackState) {
              final isConnected =
                  trackState.wsStatus == WsConnectionStatus.connected;
              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.primarySoft
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? AppColors.primaryBorder
                        : AppColors.borderHighlight,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'GPS En Vivo' : 'En Línea',
                      style: TextStyle(
                        fontSize: 11,
                        color: isConnected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: _menuButtonKey,
                borderRadius: BorderRadius.circular(12),
                onTap: _openTopOptionsMenu,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isMenuOpen
                        ? AppColors.primarySoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMenuOpen
                          ? AppColors.primaryBorder
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: _isMenuOpen
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: BlocConsumer<OrdersCubit, OrdersState>(
          listener: (context, state) {
            // Mantener sincronizado el tracking con el pedido activo
            context.read<TrackingCubit>().updateActiveOrder(state.activeOrderId);
          },
          builder: (context, ordersState) {
            final showAssignedUi = isOnShift && ordersState.hasAssignedRoute;

            return CustomScrollView(
              slivers: [
                // 1. Resumen superior y Switch de Turno
                SliverToBoxAdapter(
                  child: _buildHeaderMetrics(context, ordersState, isOnShift),
                ),

                // 2. Si está en turno pero AÚN NO tiene ruta asignada, mostrar el aviso centrado abajo
                if (isOnShift && !ordersState.hasAssignedRoute)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoRouteAssignedState(context),
                  ),

                // 3. Solo mostrar Filtros y Lista de Pedidos cuando el turno está ACTIVO y TIENE RUTA ASIGNADA
                if (showAssignedUi) ...[
                  SliverToBoxAdapter(
                    child: _isSimulatingEndpointLoad
                        ? const _FacebookShimmerFilterChips()
                        : _buildFilterChips(context, ordersState),
                  ),
                  if (_isSimulatingEndpointLoad)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const _FacebookShimmerOrderCard(),
                        childCount: ordersState.filteredOrders.isNotEmpty
                            ? ordersState.filteredOrders.length
                            : 3,
                      ),
                    )
                  else if (ordersState.status == OrdersLoadingStatus.loading &&
                      ordersState.orders.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (ordersState.filteredOrders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(ordersState.filter),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final order = ordersState.filteredOrders[index];
                          final stopNum =
                              ordersState.getStopSequenceNumber(order.id);
                          return OrderCardWidget(
                            order: order,
                            stopNumber: stopNum,
                          );
                        },
                        childCount: ordersState.filteredOrders.length,
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 88),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, ordersState) {
          // Ocultar el botón de Ver Ruta si está desconectado o si aún NO tiene ruta asignada
          if (!isOnShift ||
              !ordersState.hasAssignedRoute ||
              ordersState.orders.isEmpty) {
            return const SizedBox.shrink();
          }

          if (_isSimulatingEndpointLoad) {
            return const _FacebookShimmerFab();
          }

          return FloatingActionButton.extended(
            heroTag: 'fab_ver_ruta_home',
            onPressed: _openRoutePreview,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(
              Icons.map_rounded,
              size: 20,
            ),
            label: Text(
              'Ver Ruta (${ordersState.pendingCount})',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderMetrics(
    BuildContext context,
    OrdersState state,
    bool isOnShift,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnShift ? AppColors.primaryBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            isOnShift
                ? AppColors.primarySoft.withValues(alpha: 0.65)
                : AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Fila del Switch "En Turno"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnShift
                                ? AppColors.primary
                                : AppColors.textMuted,
                            boxShadow: isOnShift
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnShift ? 'DISPONIBLE / EN TURNO' : 'DESCONECTADO',
                          style: TextStyle(
                            color: isOnShift
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (!isOnShift)
                      const Text(
                        'Activa el switch para recibir rutas',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else if (state.hasAssignedRoute)
                      Row(
                        children: [
                          const Icon(
                            Icons.route_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Ruta: ${state.assignedRouteCode} • ${state.assignedRouteZone}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 13.5,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 5),
                          const Expanded(
                            child: Text(
                              'Sin ruta asignada • Esperando despacho PWA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isOnShift,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.surfaceElevated,
                  onChanged: (val) {
                    context.read<AuthCubit>().toggleShiftStatus(val);
                    final courier = context.read<AuthCubit>().currentCourier;
                    context.read<TrackingCubit>().syncWithShiftStatus(
                          courier: courier?.copyWith(isOnline: val),
                          activeOrderId: state.activeOrderId,
                        );
                    if (val && state.hasAssignedRoute) {
                      _triggerShiftShimmerLoad();
                    } else {
                      _shimmerTimer?.cancel();
                      setState(() => _isSimulatingEndpointLoad = false);
                    }
                  },
                ),
              ),
            ],
          ),

          // Las cards del informativo solo se muestran cuando el turno está ACTIVO y YA TIENE RUTA ASIGNADA
          if (isOnShift && state.hasAssignedRoute) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            if (_isSimulatingEndpointLoad)
              const _FacebookShimmerMetricsGrid()
            else ...[
              // Métricas en Grid de 2x2
              Row(
                children: [
                  // Total Asignados
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Asignados Hoy',
                      value: '${state.totalCount}',
                      subtitle: '${state.pendingCount} pendientes',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Total Entregados
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Entregados',
                      value: '${state.deliveredCount}',
                      subtitle:
                          '${state.totalCount > 0 ? ((state.deliveredCount / state.totalCount) * 100).toInt() : 0}% completado',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Métricas de Caja / Efectivo
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Por Recaudar',
                      value: _formatCop(state.totalCashToCollect),
                      subtitle: 'Efectivo pendiente',
                      icon: Icons.pending_actions_rounded,
                      iconColor: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Recaudado',
                      value: _formatCop(state.totalCashCollected),
                      subtitle: 'Efectivo en mano',
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, OrdersState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildChip(
            label: 'Todos (${state.totalCount})',
            isSelected: state.filter == OrdersFilter.todos,
            onTap: () =>
                context.read<OrdersCubit>().setFilter(OrdersFilter.todos),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Pendientes (${state.pendingCount})',
            isSelected: state.filter == OrdersFilter.pendientes,
            onTap: () =>
                context.read<OrdersCubit>().setFilter(OrdersFilter.pendientes),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Entregados (${state.deliveredCount})',
            isSelected: state.filter == OrdersFilter.entregados,
            onTap: () =>
                context.read<OrdersCubit>().setFilter(OrdersFilter.entregados),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderHighlight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoRouteAssignedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                color: AppColors.warning,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aún no tienes una ruta asignada',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando desde la PWA te asignen el enrutado del día, verás aquí tu resumen y listado de entregas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<OrdersCubit>().setRouteAssignment(true);
                  _triggerShiftShimmerLoad();
                },
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: const Text(
                  'Simular recepción de ruta (PWA)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryBorder),
                  backgroundColor: AppColors.primarySoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(OrdersFilter filter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay pedidos en esta categoría',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Desliza hacia abajo para actualizar la lista desde la central.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card desplegable animada que nace desde el botón de los 3 puntos
class _AnimatedThreeDotsMenuCard extends StatelessWidget {
  final Animation<double> animation;
  final double buttonWidth;
  final bool hasAssignedRoute;
  final ValueChanged<String> onSelect;

  const _AnimatedThreeDotsMenuCard({
    required this.animation,
    required this.buttonWidth,
    required this.hasAssignedRoute,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scaleCurved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final fadeCurved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: fadeCurved,
      child: ScaleTransition(
        alignment: const Alignment(0.86, -1.0),
        scale: scaleCurved,
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Puntero superior que conecta visualmente la card con el icono de 3 puntos
              Padding(
                padding: EdgeInsets.only(
                  right: (buttonWidth / 2) - 9,
                ),
                child: CustomPaint(
                  size: const Size(18, 9),
                  painter: _MenuTopPointerPainter(
                    fillColor: AppColors.surface,
                    borderColor: AppColors.borderHighlight,
                  ),
                ),
              ),

              // Cuerpo de la Card del menú (sin "Ver Ruta")
              Container(
                width: 248,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    topRight: Radius.circular(10),
                  ),
                  border: Border.all(
                    color: AppColors.borderHighlight,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Opción 1: Actualizar Pedidos
                    _buildMenuActionTile(
                      icon: Icons.refresh_rounded,
                      iconBgColor: AppColors.primarySoft,
                      iconColor: AppColors.primary,
                      title: 'Actualizar Pedidos',
                      subtitle: 'Sincronizar ruta actual',
                      titleColor: AppColors.textPrimary,
                      onTap: () => onSelect('refresh'),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Divider(height: 1),
                    ),

                    // Opción 2: Simular Con Ruta / Sin Ruta desde la PWA
                    _buildMenuActionTile(
                      icon: hasAssignedRoute
                          ? Icons.route_outlined
                          : Icons.bolt_rounded,
                      iconBgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: hasAssignedRoute
                          ? 'Probar Sin Ruta'
                          : 'Recibir Ruta PWA',
                      subtitle: hasAssignedRoute
                          ? 'Ver estado sin ruta asignada'
                          : 'Simular despacho desde PWA',
                      titleColor: AppColors.textPrimary,
                      onTap: () => onSelect('toggle_route_assignment'),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Divider(height: 1),
                    ),

                    // Opción 3: Cerrar Sesión
                    _buildMenuActionTile(
                      icon: Icons.logout_rounded,
                      iconBgColor: const Color(0xFFFEE2E2),
                      iconColor: AppColors.error,
                      title: 'Cerrar Sesión',
                      subtitle: 'Salir de la cuenta actual',
                      titleColor: AppColors.error,
                      onTap: () => onSelect('logout'),
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

  Widget _buildMenuActionTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: iconColor.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puntero triangular superior que une la card con el botón de los 3 puntos
class _MenuTopPointerPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _MenuTopPointerPainter({
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, fillPaint);

    final borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _MenuTopPointerPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}

/// Wrapper con ShaderMask para aplicar el barrido luminoso estilo Facebook
class _FacebookShimmerEffect extends StatefulWidget {
  final Widget child;

  const _FacebookShimmerEffect({required this.child});

  @override
  State<_FacebookShimmerEffect> createState() => _FacebookShimmerEffectState();
}

class _FacebookShimmerEffectState extends State<_FacebookShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final beginX = -2.2 + (_controller.value * 4.4);
        final endX = beginX + 1.6;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFCBD5E1),
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
                Color(0xFFCBD5E1),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              begin: Alignment(beginX, -0.2),
              end: Alignment(endX, 0.2),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

Widget _shimmerBone({
  double? width,
  required double height,
  double borderRadius = 6,
  BoxShape shape = BoxShape.rectangle,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: shape,
      borderRadius:
          shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
    ),
  );
}

/// 1. Grid 2x2 con efecto Shimmer estilo Facebook para las 4 cards del informativo
class _FacebookShimmerMetricsGrid extends StatelessWidget {
  const _FacebookShimmerMetricsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildShimmerMetricCard(
                titleWidth: 78,
                valueWidth: 38,
                subtitleWidth: 68,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildShimmerMetricCard(
                titleWidth: 68,
                valueWidth: 34,
                subtitleWidth: 82,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildShimmerMetricCard(
                titleWidth: 74,
                valueWidth: 92,
                subtitleWidth: 78,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildShimmerMetricCard(
                titleWidth: 66,
                valueWidth: 54,
                subtitleWidth: 72,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShimmerMetricCard({
    required double titleWidth,
    required double valueWidth,
    required double subtitleWidth,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: _FacebookShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerBone(width: titleWidth, height: 11, borderRadius: 5),
                _shimmerBone(width: 18, height: 18, borderRadius: 5),
              ],
            ),
            const SizedBox(height: 8),
            _shimmerBone(width: valueWidth, height: 18, borderRadius: 6),
            const SizedBox(height: 6),
            _shimmerBone(width: subtitleWidth, height: 10, borderRadius: 5),
          ],
        ),
      ),
    );
  }
}

/// 2. Fila de 3 botones de filtro (Todos, Pendientes, Entregados) con efecto Shimmer Facebook
class _FacebookShimmerFilterChips extends StatelessWidget {
  const _FacebookShimmerFilterChips();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: _buildShimmerChip(width: 60)),
          const SizedBox(width: 8),
          Expanded(child: _buildShimmerChip(width: 78)),
          const SizedBox(width: 8),
          Expanded(child: _buildShimmerChip(width: 76)),
        ],
      ),
    );
  }

  Widget _buildShimmerChip({required double width}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderHighlight),
      ),
      child: _FacebookShimmerEffect(
        child: _shimmerBone(width: width, height: 12, borderRadius: 6),
      ),
    );
  }
}

/// 3. Card de pedido con estructura completa en efecto Shimmer Facebook
class _FacebookShimmerOrderCard extends StatelessWidget {
  const _FacebookShimmerOrderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _FacebookShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Círculo #1 + Badge código + Pill estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _shimmerBone(
                      width: 28,
                      height: 28,
                      shape: BoxShape.circle,
                    ),
                    const SizedBox(width: 8),
                    _shimmerBone(width: 96, height: 24, borderRadius: 7),
                  ],
                ),
                _shimmerBone(width: 82, height: 24, borderRadius: 20),
              ],
            ),
            const SizedBox(height: 14),
            // Fila Cliente + Icono Teléfono
            Row(
              children: [
                _shimmerBone(width: 18, height: 18, borderRadius: 5),
                const SizedBox(width: 8),
                Expanded(
                  child: _shimmerBone(height: 15, borderRadius: 6),
                ),
                const SizedBox(width: 24),
                _shimmerBone(width: 22, height: 22, shape: BoxShape.circle),
              ],
            ),
            const SizedBox(height: 8),
            // Fila Dirección
            Row(
              children: [
                _shimmerBone(width: 16, height: 16, borderRadius: 5),
                const SizedBox(width: 8),
                _shimmerBone(width: 195, height: 12, borderRadius: 6),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Pie: Monto + Método de pago + Botón de productos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBone(width: 105, height: 16, borderRadius: 6),
                    const SizedBox(height: 6),
                    _shimmerBone(width: 125, height: 11, borderRadius: 5),
                  ],
                ),
                _shimmerBone(width: 108, height: 32, borderRadius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. Botón flotante "Ver Ruta" con efecto Shimmer Facebook
class _FacebookShimmerFab extends StatelessWidget {
  const _FacebookShimmerFab();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHighlight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _FacebookShimmerEffect(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _shimmerBone(width: 20, height: 20, borderRadius: 6),
            const SizedBox(width: 10),
            _shimmerBone(width: 88, height: 14, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}
