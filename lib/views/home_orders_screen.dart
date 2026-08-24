import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  @override
  void initState() {
    super.initState();
    _refreshData();
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

  String _formatCop(double value) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                FontAwesomeIcons.motorcycle,
                color: AppColors.primary,
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Placa: ${courier?.placaVehiculo.isNotEmpty == true ? courier?.placaVehiculo : "XYZ-123"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
              final isConnected = trackState.wsStatus == WsConnectionStatus.connected;
              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? AppColors.primary : AppColors.border,
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
                        color: isConnected ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'GPS En Vivo' : 'Sin Conexión',
                      style: TextStyle(
                        fontSize: 11,
                        color: isConnected ? AppColors.primary : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surface,
            onSelected: (val) {
              if (val == 'logout') {
                context.read<TrackingCubit>().stopTracking();
                context.read<AuthCubit>().logout();
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              } else if (val == 'refresh') {
                _refreshData();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 10),
                    Text('Actualizar Pedidos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
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
            return CustomScrollView(
              slivers: [
                // 1. Resumen superior y Switch de Turno
                SliverToBoxAdapter(
                  child: _buildHeaderMetrics(context, ordersState, isOnShift),
                ),

                // 2. Barra de Filtros (Todos, Pendientes, Entregados)
                SliverToBoxAdapter(
                  child: _buildFilterChips(context, ordersState),
                ),

                // 3. Lista de Pedidos
                if (ordersState.status == OrdersLoadingStatus.loading &&
                    ordersState.orders.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
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
                        return OrderCardWidget(
                          order: order,
                          onTap: () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.orderDetail,
                              arguments: order,
                            );
                            _refreshData();
                          },
                        );
                      },
                      childCount: ordersState.filteredOrders.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
        ),
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
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            isOnShift ? AppColors.surfaceElevated : AppColors.surface,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnShift ? AppColors.primary : AppColors.textMuted,
                          boxShadow: isOnShift
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnShift ? 'DISPONIBLE / EN TURNO' : 'DESCONECTADO',
                        style: TextStyle(
                          color: isOnShift ? AppColors.primaryLight : AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isOnShift
                        ? 'Transmitiendo coordenadas cada 5s'
                        : 'Activa el switch para recibir rutas y tracking',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isOnShift,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primaryDark.withValues(alpha: 0.4),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surfaceElevated,
                  onChanged: (val) {
                    context.read<AuthCubit>().toggleShiftStatus(val);
                    final courier = context.read<AuthCubit>().currentCourier;
                    context.read<TrackingCubit>().syncWithShiftStatus(
                          courier: courier?.copyWith(isOnline: val),
                          activeOrderId: state.activeOrderId,
                        );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

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
                  subtitle: '${state.totalCount > 0 ? ((state.deliveredCount / state.totalCount) * 100).toInt() : 0}% completado',
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
                  iconColor: AppColors.primaryLight,
                ),
              ),
            ],
          ),
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
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
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
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Icon(icon, size: 15, color: iconColor),
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
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
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
            onTap: () => context.read<OrdersCubit>().setFilter(OrdersFilter.todos),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Pendientes (${state.pendingCount})',
            isSelected: state.filter == OrdersFilter.pendientes,
            onTap: () => context.read<OrdersCubit>().setFilter(OrdersFilter.pendientes),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Entregados (${state.deliveredCount})',
            isSelected: state.filter == OrdersFilter.entregados,
            onTap: () => context.read<OrdersCubit>().setFilter(OrdersFilter.entregados),
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
          ),
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
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.boxOpen,
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
