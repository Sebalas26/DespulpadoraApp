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
import 'widgets/route_reception_camera_dialog.dart';

/// Pantalla principal de gestión de ruta y pedidos del domiciliario.
class HomeOrdersScreen extends StatefulWidget {
  /// Crea una nueva instancia de [HomeOrdersScreen].
  const HomeOrdersScreen({super.key});

  @override
  State<HomeOrdersScreen> createState() => _HomeOrdersScreenState();
}

/// Estado interno de [HomeOrdersScreen] que controla la carga de ruta, recepción y filtros.
class _HomeOrdersScreenState extends State<HomeOrdersScreen> {
  /// Clave global del botón de opciones superiores para posicionamiento del menú.
  final GlobalKey _menuButtonKey = GlobalKey();

  /// Indica si el menú contextual superior se encuentra desplegado.
  bool _isMenuOpen = false;

  /// Indica si el efecto visual de transición de carga se encuentra activo.
  bool _isLoadingTransition = false;

  /// Temporizador para finalizar la animación de carga de tarjetas.
  Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  /// Abre el modal de evidencia fotográfica y confirma la recepción de la ruta en el backend.
  Future<void> _handleOpenReceptionCamera(OrdersState ordersState) async {
    final photoTimestamp = await RouteReceptionCameraDialog.show(
      context,
      routeCode: ordersState.assignedRouteCode,
      routeZone: ordersState.assignedRouteZone,
      totalOrders: ordersState.totalCount,
      totalUnits: ordersState.totalUnitsInRoute,
    );

    if (!mounted || photoTimestamp == null) return;

    final courier = context.read<AuthCubit>().currentCourier;
    await context.read<OrdersCubit>().confirmRouteReception(
          photoTimestamp: photoTimestamp,
          courierId: courier?.id,
          token: courier?.token,
        );
    if (!mounted) return;
    _triggerShiftShimmerLoad();
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    super.dispose();
  }

  /// Activa brevemente el esqueleto visual durante la sincronización de interfaz.
  void _triggerShiftShimmerLoad() {
    _shimmerTimer?.cancel();
    setState(() => _isLoadingTransition = true);
    _shimmerTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _isLoadingTransition = false);
      }
    });
  }

  /// Consulta los pedidos asignados reales desde la API y sincroniza la telemetría GPS.
  void _refreshData() {
    final courier = context.read<AuthCubit>().currentCourier;
    if (courier != null) {
      context.read<OrdersCubit>().loadOrders(
            courierId: courier.id,
            token: courier.token,
          );
      final activeOrderId = context.read<OrdersCubit>().state.activeOrderId;
      context.read<TrackingCubit>().syncWithShiftStatus(
            courier: courier,
            activeOrderId: activeOrderId,
          );
    }
  }

  /// Navega a la vista previa del mapa de la ruta asignada.
  void _openRoutePreview() {
    Navigator.of(context).pushNamed(AppRoutes.routePreviewMap);
  }

  /// Despliega el menú superior de acciones de sincronización y cierre de sesión.
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

    setState(() => _isMenuOpen = true);

    final selectedAction = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar menú de opciones',
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
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
            Positioned(
              top: buttonOffset.dy + buttonSize.height + 2,
              right: rightEdge,
              child: _AnimatedThreeDotsMenuCard(
                animation: animation,
                buttonWidth: buttonSize.width,
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
      if (context.read<OrdersCubit>().state.isRouteReceived) {
        _triggerShiftShimmerLoad();
      }
    } else if (selectedAction == 'logout') {
      context.read<TrackingCubit>().stopTracking();
      await context.read<AuthCubit>().logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  /// Formatea un valor numérico en pesos colombianos (COP).
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
    final courierName =
        (courier != null && courier.nombre.trim().isNotEmpty)
            ? courier.nombre.trim()
            : '';
    final courierPlate =
        (courier != null && courier.placaVehiculo.trim().isNotEmpty)
            ? courier.placaVehiculo.trim()
            : 'Sin placa';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo-dgl.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    courierName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Placa: $courierPlate',
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
                    color:
                        _isMenuOpen ? AppColors.primary : AppColors.textPrimary,
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
            context
                .read<TrackingCubit>()
                .updateActiveOrder(state.activeOrderId);
          },
          builder: (context, ordersState) {
            final hasRoute = ordersState.hasAssignedRoute;
            final isReceived = ordersState.isRouteReceived;
            final showOrdersListUi = hasRoute && isReceived;

            return CustomScrollView(
              slivers: [
                if (!hasRoute)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoRouteAssignedState(context),
                  ),
                if (hasRoute && !isReceived)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildPendingRouteReceptionState(
                      context,
                      ordersState,
                    ),
                  ),
                if (showOrdersListUi) ...[
                  SliverToBoxAdapter(
                    child: _buildHeaderMetrics(context, ordersState),
                  ),
                  SliverToBoxAdapter(
                    child: _isLoadingTransition
                        ? const _FacebookShimmerFilterChips()
                        : _buildFilterChips(context, ordersState),
                  ),
                  if (_isLoadingTransition)
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
          if (!ordersState.hasAssignedRoute ||
              !ordersState.isRouteReceived ||
              ordersState.orders.isEmpty) {
            return const SizedBox.shrink();
          }

          if (_isLoadingTransition) {
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

  /// Construye el bloque superior con el código de ruta y el resumen de métricas 2x2.
  Widget _buildHeaderMetrics(
    BuildContext context,
    OrdersState state,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBorder),
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
            AppColors.primarySoft.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ruta: ${state.assignedRouteCode}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.assignedRouteZone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF047857),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pedido Recibido',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (_isLoadingTransition)
            const _FacebookShimmerMetricsGrid()
          else ...[
            Row(
              children: [
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
      ),
    );
  }

  /// Construye una tarjeta individual de métrica operativa.
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

  /// Construye la fila de botones de filtro (Todos, Pendientes, Entregados).
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

  /// Construye un botón de filtro individual estilizado como cápsula.
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

  /// Construye la vista informativa cuando el domiciliario aún no tiene una ruta asignada en el servidor.
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
              'Cuando desde la central te asignen el enrutado del día, podrás recibir el pedido y ver tu listado de entregas.',
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
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Actualizar Ruta',
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

  /// Construye la vista previa de recepción física cuando la ruta está asignada pero pendiente de evidencia fotográfica.
  Widget _buildPendingRouteReceptionState(
    BuildContext context,
    OrdersState state,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primaryBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'RUTA ASIGNADA DESDE CENTRAL',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ruta ${state.assignedRouteCode}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.assignedRouteZone,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${state.totalCount}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pedidos',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${state.totalUnitsInRoute} un.',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Total Pulpas',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _formatCop(state.totalRouteAmount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Valor Ruta',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verifica las canastillas de pulpa en planta y toma una foto de recepción para habilitar tu listado de pedidos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _handleOpenReceptionCamera(state),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text(
                    'Recibir Pedido y Tomar Foto',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el mensaje de estado vacío cuando el filtro seleccionado no arroja pedidos.
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

/// Tarjeta desplegable animada del menú de opciones superiores.
class _AnimatedThreeDotsMenuCard extends StatelessWidget {
  /// Animación de apertura y cierre del diálogo.
  final Animation<double> animation;

  /// Ancho del botón de origen para alinear el puntero superior.
  final double buttonWidth;

  /// Callback invocado al seleccionar una acción del menú.
  final ValueChanged<String> onSelect;

  /// Crea una nueva instancia de [_AnimatedThreeDotsMenuCard].
  const _AnimatedThreeDotsMenuCard({
    required this.animation,
    required this.buttonWidth,
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

  /// Construye un elemento interactivo dentro del menú desplegable.
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

/// Pintor personalizado para el triángulo superior de la tarjeta de menú.
class _MenuTopPointerPainter extends CustomPainter {
  /// Color de relleno del puntero.
  final Color fillColor;

  /// Color del borde del puntero.
  final Color borderColor;

  /// Crea una nueva instancia de [_MenuTopPointerPainter].
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

/// Contenedor animado con efecto de barrido luminoso para estados de carga.
class _FacebookShimmerEffect extends StatefulWidget {
  /// Widget hijo sobre el cual se proyecta el barrido luminoso.
  final Widget child;

  /// Crea una nueva instancia de [_FacebookShimmerEffect].
  const _FacebookShimmerEffect({required this.child});

  @override
  State<_FacebookShimmerEffect> createState() => _FacebookShimmerEffectState();
}

/// Estado interno de la animación continua de [_FacebookShimmerEffect].
class _FacebookShimmerEffectState extends State<_FacebookShimmerEffect>
    with SingleTickerProviderStateMixin {
  /// Controlador de la animación de barrido.
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

/// Construye un bloque geométrico base para los esqueletos de carga.
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
      borderRadius: shape == BoxShape.rectangle
          ? BorderRadius.circular(borderRadius)
          : null,
    ),
  );
}

/// Cuadrícula 2x2 de esqueletos de carga para las métricas del encabezado.
class _FacebookShimmerMetricsGrid extends StatelessWidget {
  /// Crea una nueva instancia de [_FacebookShimmerMetricsGrid].
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

  /// Construye un esqueleto individual de tarjeta de métrica.
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

/// Fila de esqueletos de carga para los botones de filtro.
class _FacebookShimmerFilterChips extends StatelessWidget {
  /// Crea una nueva instancia de [_FacebookShimmerFilterChips].
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

  /// Construye un esqueleto de cápsula de filtro.
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

/// Esqueleto de carga para una tarjeta de pedido en la lista principal.
class _FacebookShimmerOrderCard extends StatelessWidget {
  /// Crea una nueva instancia de [_FacebookShimmerOrderCard].
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

/// Esqueleto de carga para el botón flotante de visualización de ruta.
class _FacebookShimmerFab extends StatelessWidget {
  /// Crea una nueva instancia de [_FacebookShimmerFab].
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
