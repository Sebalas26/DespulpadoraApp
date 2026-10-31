import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';

/// Widget de mapa interactivo con teselas cartográficas, polilíneas viales y pines de paradas enumeradas.
class OsmMapWidget extends StatefulWidget {
  /// Coordenada GPS actual del domiciliario.
  final LatLng courierLocation;

  /// Coordenada GPS del destino o parada enfocada.
  final LatLng destinationLocation;

  /// Título del punto de destino enfocado.
  final String destinationTitle;

  /// Placa del vehículo del domiciliario.
  final String courierPlate;

  /// Rumbo actual del domiciliario en grados.
  final double heading;

  /// Indica si se debe dibujar la polilínea vial sobre el mapa.
  final bool showPolyline;

  /// Indica si se debe considerar la coordenada de la planta matriz en el encuadre.
  final bool showPlantaMatriz;

  /// Indica si se debe mostrar el marcador del domiciliario en vivo.
  final bool showCourierMarker;

  /// Número de secuencia de la parada activa.
  final int stopSequenceNumber;

  /// Puntos de la polilínea del tramo vial activo.
  final List<LatLng>? routePoints;

  /// Puntos de la polilínea del circuito multiparada completo.
  final List<LatLng>? fullRoutePoints;

  /// Lista completa de paradas asignadas al domiciliario.
  final List<OrderModel>? allStops;

  /// Identificador de la parada actualmente enfocada.
  final String? activeStopId;

  /// Callback invocado al tocar un marcador de parada en el mapa.
  final ValueChanged<OrderModel>? onStopTap;

  /// Callback invocado al centrar el mapa sobre la ubicación del domiciliario.
  final VoidCallback? onRecenter;

  /// Desplazamiento inferior para los botones flotantes de control de cámara.
  final double bottomControlsOffset;

  /// Indica si el mapa opera en modo de navegación cercana en vivo.
  final bool isNavigationMode;

  /// Contador incremental para disparar el acercamiento de navegación.
  final int navigationZoomTrigger;

  /// Crea una nueva instancia de [OsmMapWidget].
  const OsmMapWidget({
    super.key,
    required this.courierLocation,
    required this.destinationLocation,
    required this.destinationTitle,
    this.courierPlate = '',
    this.heading = 0.0,
    this.showPolyline = true,
    this.showPlantaMatriz = false,
    this.showCourierMarker = true,
    this.stopSequenceNumber = 1,
    this.routePoints,
    this.fullRoutePoints,
    this.allStops,
    this.activeStopId,
    this.onStopTap,
    this.onRecenter,
    this.bottomControlsOffset = 18.0,
    this.isNavigationMode = false,
    this.navigationZoomTrigger = 0,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

/// Estado interno de [OsmMapWidget] que controla la cámara y las animaciones de encuadre.
class _OsmMapWidgetState extends State<OsmMapWidget>
    with TickerProviderStateMixin {
  /// Controlador del lienzo cartográfico de `FlutterMap`.
  late final MapController _mapController;

  /// Controlador de animación para transiciones suaves de cámara.
  AnimationController? _cameraAnimController;

  /// Estilo cartográfico activo.
  final MapStyleOption _selectedStyle = ApiConfig.mapStyles.first;

  /// Indica si ya se realizó el encuadre inicial automático de la ruta.
  bool _hasAutoFitted = false;

  /// Indica si el controlador del mapa ya se encuentra inicializado.
  bool _isMapReady = false;

  /// Coordenada geográfica de la planta matriz.
  static const LatLng _plantaMatriz = LatLng(
    ApiConfig.plantaMatrizLat,
    ApiConfig.plantaMatrizLng,
  );

  /// Retorna una coordenada válida del domiciliario dentro del territorio nacional.
  LatLng get _safeCourierLocation {
    final LatLng loc = widget.courierLocation;
    if (loc.latitude >= -4.5 &&
        loc.latitude <= 13.5 &&
        loc.longitude >= -80.0 &&
        loc.longitude <= -66.5) {
      return loc;
    }
    return const LatLng(4.69680, -74.09250);
  }

  /// Retorna una coordenada válida del destino activo dentro del territorio nacional.
  LatLng get _safeDestinationLocation {
    final LatLng dest = widget.destinationLocation;
    if (dest.latitude >= -4.5 &&
        dest.latitude <= 13.5 &&
        dest.longitude >= -80.0 &&
        dest.longitude <= -66.5) {
      return dest;
    }
    return _safeCourierLocation;
  }

  /// Retorna una coordenada válida para una parada específica dentro del territorio nacional.
  LatLng _safeStopLocation(OrderModel stop) {
    if (stop.latitud >= -4.5 &&
        stop.latitud <= 13.5 &&
        stop.longitud >= -80.0 &&
        stop.longitud <= -66.5) {
      return LatLng(stop.latitud, stop.longitud);
    }
    return _safeDestinationLocation;
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _cameraAnimController?.dispose();
    super.dispose();
  }

  /// Anima suavemente la cámara del mapa hacia una coordenada y nivel de zoom objetivo.
  void _animateCameraTo(
    LatLng destLocation,
    double destZoom, {
    Duration duration = const Duration(milliseconds: 1350),
    Curve curve = Curves.easeInOutCubic,
  }) {
    if (!_isMapReady || !mounted) return;

    _cameraAnimController?.stop();
    _cameraAnimController?.dispose();

    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: startZoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );
    _cameraAnimController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: curve,
    );

    controller.addListener(() {
      if (!mounted) return;
      _mapController.move(
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
        zoomTween.evaluate(animation),
      );
    });

    controller.forward();
  }

  /// Acerca la cámara sobre el domiciliario y el tramo vial activo inmediato.
  void _animateToWazeNavigationCloseUp({
    Duration duration = const Duration(milliseconds: 1550),
  }) {
    if (!_isMapReady || !mounted) return;

    final courier = _safeCourierLocation;
    final activePoints = widget.routePoints;

    LatLng targetCenter;
    double targetZoom = 15.55;

    if (activePoints != null && activePoints.length > 4) {
      final lookAheadIndex = (activePoints.length * 0.20).round().clamp(
            1,
            activePoints.length - 1,
          );
      final lookAheadPoint = activePoints[lookAheadIndex];
      targetCenter = LatLng(
        (courier.latitude * 0.62) + (lookAheadPoint.latitude * 0.38),
        (courier.longitude * 0.62) + (lookAheadPoint.longitude * 0.38),
      );
      targetZoom = 15.55;
    } else {
      final LatLng safeDest = _safeDestinationLocation;
      targetCenter = LatLng(
        (courier.latitude * 0.78) + (safeDest.latitude * 0.22),
        (courier.longitude * 0.78) + (safeDest.longitude * 0.22),
      );
      targetZoom = 15.45;
    }

    _animateCameraTo(
      targetCenter,
      targetZoom,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasRouteNow = (widget.fullRoutePoints != null &&
            widget.fullRoutePoints!.length > 5) ||
        (widget.routePoints != null && widget.routePoints!.length > 5);

    if (widget.navigationZoomTrigger != oldWidget.navigationZoomTrigger &&
        _isMapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateToWazeNavigationCloseUp();
      });
      return;
    }

    if (!_hasAutoFitted && hasRouteNow && _isMapReady) {
      _hasAutoFitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.isNavigationMode) {
          _animateToWazeNavigationCloseUp();
        } else {
          _fitAllRouteBounds();
        }
      });
    } else if (widget.activeStopId != null &&
        widget.activeStopId != oldWidget.activeStopId &&
        widget.allStops != null) {
      try {
        final OrderModel target =
            widget.allStops!.firstWhere((s) => s.id == widget.activeStopId);
        final LatLng safeTarget = _safeStopLocation(target);
        if (widget.isNavigationMode) {
          final LatLng courier = _safeCourierLocation;
          final LatLng navCenter = LatLng(
            (courier.latitude * 0.65) + (safeTarget.latitude * 0.35),
            (courier.longitude * 0.65) + (safeTarget.longitude * 0.35),
          );
          _animateCameraTo(
            navCenter,
            15.5,
            duration: const Duration(milliseconds: 950),
          );
        } else {
          _animateCameraTo(
            safeTarget,
            14.8,
            duration: const Duration(milliseconds: 950),
          );
        }
      } catch (_) {}
    }
  }

  /// Centra el mapa sobre la ubicación actual del domiciliario.
  void _centerOnCourier() {
    if (widget.isNavigationMode) {
      _animateToWazeNavigationCloseUp(
        duration: const Duration(milliseconds: 900),
      );
    } else {
      _animateCameraTo(
        _safeCourierLocation,
        15.8,
        duration: const Duration(milliseconds: 900),
      );
    }
    widget.onRecenter?.call();
  }

  /// Ajusta los límites de la cámara para abarcar todas las paradas y el trazado de la ruta.
  void _fitAllRouteBounds() {
    final List<LatLng> pointsToFit = [];

    if (widget.fullRoutePoints != null && widget.fullRoutePoints!.isNotEmpty) {
      pointsToFit.addAll(widget.fullRoutePoints!);
    } else if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      pointsToFit.addAll(widget.routePoints!);
    }

    if (widget.showCourierMarker) {
      pointsToFit.add(_safeCourierLocation);
    }
    pointsToFit.add(_safeDestinationLocation);

    if (widget.showPlantaMatriz) {
      pointsToFit.add(_plantaMatriz);
    }

    if (widget.allStops != null) {
      for (final OrderModel stop in widget.allStops!) {
        pointsToFit.add(_safeStopLocation(stop));
      }
    }

    if (pointsToFit.length > 1) {
      final bounds = LatLngBounds.fromPoints(pointsToFit);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(44, 68, 44, 56),
        ),
      );
    }
  }

  /// Obtiene la etiqueta abreviada de la placa para el marcador del vehículo.
  String get _plateShort {
    final clean = widget.courierPlate.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'sin placa') return 'MOTO';
    return clean.split(' ').first.split('-').first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng courierLoc = _safeCourierLocation;
    final LatLng safeDestLoc = _safeDestinationLocation;
    final LatLng centerPoint = LatLng(
      (courierLoc.latitude + safeDestLoc.latitude) / 2,
      (courierLoc.longitude + safeDestLoc.longitude) / 2,
    );

    final effectiveActiveLeg =
        (widget.routePoints != null && widget.routePoints!.length > 2)
            ? widget.routePoints!
            : null;

    final effectiveFullRoute =
        (widget.fullRoutePoints != null && widget.fullRoutePoints!.length > 2)
            ? widget.fullRoutePoints!
            : null;

    const casingColor = Colors.white;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerPoint,
            initialZoom: widget.allStops != null && widget.allStops!.length > 1
                ? 12.2
                : 13.5,
            minZoom: 5.0,
            maxZoom: _selectedStyle.maxZoom,
            onMapReady: () {
              _isMapReady = true;
              if (widget.isNavigationMode) {
                Future.delayed(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    _animateToWazeNavigationCloseUp();
                  }
                });
              } else {
                Future.delayed(const Duration(milliseconds: 120), () {
                  if (mounted && !_hasAutoFitted) {
                    _hasAutoFitted = true;
                    _fitAllRouteBounds();
                  }
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _selectedStyle.url,
              userAgentPackageName: ApiConfig.userAgentPackageName,
              maxNativeZoom: 18,
              maxZoom: _selectedStyle.maxZoom,
            ),
            if (widget.showPolyline &&
                (effectiveFullRoute != null || effectiveActiveLeg != null))
              PolylineLayer(
                polylines: [
                  if (effectiveFullRoute != null) ...[
                    Polyline(
                      points: effectiveFullRoute,
                      strokeWidth: 7.5,
                      color: casingColor.withValues(alpha: 0.92),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: effectiveFullRoute,
                      strokeWidth: 4.5,
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.82),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                  if (effectiveActiveLeg != null) ...[
                    Polyline(
                      points: effectiveActiveLeg,
                      strokeWidth: 8.0,
                      color: casingColor.withValues(alpha: 0.96),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: effectiveActiveLeg,
                      strokeWidth: 4.8,
                      color: const Color(0xFF10B981),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.allStops != null && widget.allStops!.isNotEmpty)
                  ..._buildMultiStopMarkers()
                else
                  Marker(
                    point: widget.destinationLocation,
                    width: 130,
                    height: 68,
                    child: _buildNumberedStopMarker(
                      sequenceNumber: widget.stopSequenceNumber,
                      label: widget.destinationTitle,
                      status: OrderStatus.enCamino,
                      isActive: true,
                    ),
                  ),
                if (widget.showCourierMarker)
                  Marker(
                    point: courierLoc,
                    width: 68,
                    height: 68,
                    child: GestureDetector(
                      onTap: _centerOnCourier,
                      child: _buildPwaCourierMarker(),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 14,
          bottom: widget.bottomControlsOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapControlFab(
                heroTag: 'fab_fit_route',
                icon: Icons.zoom_out_map_rounded,
                tooltip: 'Encuadrar todo el enrutado',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                onPressed: _fitAllRouteBounds,
              ),
              const SizedBox(height: 8),
              _buildMapControlFab(
                heroTag: 'fab_center_me',
                icon: Icons.my_location_rounded,
                tooltip: 'Mi ubicación GPS',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                isPrimary: true,
                onPressed: _centerOnCourier,
              ),
            ],
          ),
        ),
        Positioned(
          left: 10,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '© Esri ArcGIS • OpenStreetMap',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye un botón flotante cuadrado para los controles de zoom y centrado del mapa.
  Widget _buildMapControlFab({
    required String heroTag,
    required IconData icon,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: isPrimary ? 44 : 38,
          height: isPrimary ? 44 : 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isPrimary ? AppColors.primary : AppColors.borderHighlight,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: foregroundColor, size: isPrimary ? 21 : 18),
        ),
      ),
    );
  }

  /// Construye la lista de marcadores enumerados para cada parada de la ruta.
  List<Marker> _buildMultiStopMarkers() {
    final List<OrderModel> stops = widget.allStops!;
    final List<Marker> markers = [];

    for (int i = 0; i < stops.length; i++) {
      final OrderModel stop = stops[i];
      if (widget.isNavigationMode && stop.estado == OrderStatus.entregado) {
        continue;
      }
      final int seqNum = i + 1;
      final bool isActive = widget.activeStopId == stop.id ||
          (widget.activeStopId == null &&
              (stop.estado == OrderStatus.enCamino ||
                  stop.estado == OrderStatus.enPunto));

      markers.add(
        Marker(
          point: _safeStopLocation(stop),
          width: isActive ? 140 : 48,
          height: isActive ? 68 : 48,
          child: GestureDetector(
            onTap: () => widget.onStopTap?.call(stop),
            child: _buildNumberedStopMarker(
              sequenceNumber: seqNum,
              label: stop.clienteNombre,
              status: stop.estado,
              isActive: isActive,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  /// Construye el pin visual de una parada con su número de orden y color de estado.
  Widget _buildNumberedStopMarker({
    required int sequenceNumber,
    required String label,
    required OrderStatus status,
    required bool isActive,
  }) {
    final isDelivered = status == OrderStatus.entregado;
    final isNovelty = status == OrderStatus.novedad;

    Color bgColor;
    if (isDelivered) {
      bgColor = const Color(0xFF10B981);
    } else if (isNovelty) {
      bgColor = const Color(0xFFDC2626);
    } else if (isActive) {
      bgColor = AppColors.primary;
    } else {
      bgColor = const Color(0xFF2563EB);
    }

    final double circleSize = isActive ? 34 : 30;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isActive) ...[
          Container(
            constraints: const BoxConstraints(maxWidth: 135),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bgColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '#$sequenceNumber · $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bgColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
        ],
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.55),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: isDelivered
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                : Text(
                    isNovelty ? '!' : '$sequenceNumber',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: isActive ? 13 : 12,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Construye el marcador circular del vehículo del domiciliario con su placa.
  Widget _buildPwaCourierMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.22),
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.65),
                blurRadius: 14,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF10B981), width: 1),
            ),
            child: Text(
              _plateShort,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
