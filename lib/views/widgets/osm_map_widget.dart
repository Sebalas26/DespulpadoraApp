import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';

/// Widget de mapa interactivo con el diseño blanco minimalista de la PWA (OpenStreetMap White Smooth + Pines Enumerados)
class OsmMapWidget extends StatefulWidget {
  final LatLng courierLocation;
  final LatLng destinationLocation;
  final String destinationTitle;
  final String courierPlate;
  final double heading;
  final bool showPolyline;
  final bool showPlantaMatriz;
  final bool showCourierMarker;
  final int stopSequenceNumber;
  final List<LatLng>? routePoints; // Trazado activo por calles
  final List<LatLng>? fullRoutePoints; // Trazado completo multiparada (#1 -> #2 -> #3...)
  final List<OrderModel>? allStops; // Todas las paradas del domiciliario para mostrar enumeradas
  final String? activeStopId; // ID de la parada activa/seleccionada
  final ValueChanged<OrderModel>? onStopTap;
  final VoidCallback? onRecenter;
  final double bottomControlsOffset;
  final bool isNavigationMode; // Activa el efecto zoom-in estilo Waze/Maps al iniciar ruta
  final int navigationZoomTrigger; // Incrementar para disparar de nuevo el zoom-in estilo Waze

  const OsmMapWidget({
    super.key,
    required this.courierLocation,
    required this.destinationLocation,
    required this.destinationTitle,
    this.courierPlate = 'XYZ-789',
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

class _OsmMapWidgetState extends State<OsmMapWidget>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  AnimationController? _cameraAnimController;
  final MapStyleOption _selectedStyle = ApiConfig.mapStyles.first; // OpenStreetMap White Smooth fijo

  // Matriz de color de alto brillo y escala de grises suave (Estilo Positron / Alidade White Smooth)
  // Convierte los tiles oficiales de OpenStreetMap en un mapa blanco minimalista sin requerir API Key
  static const ColorFilter _whiteSmoothTileFilter = ColorFilter.matrix(<double>[
    0.32, 0.52, 0.08, 0.0, 22.0,
    0.32, 0.53, 0.08, 0.0, 23.0,
    0.32, 0.53, 0.10, 0.0, 25.0,
    0.0,  0.0,  0.0,  1.0,  0.0,
  ]);
  bool _hasAutoFitted = false;
  bool _isMapReady = false;

  static const LatLng _plantaMatriz = LatLng(
    ApiConfig.plantaMatrizLat,
    ApiConfig.plantaMatrizLng,
  );

  LatLng get _safeCourierLocation {
    final loc = widget.courierLocation;
    if (loc.latitude >= -4.5 &&
        loc.latitude <= 13.5 &&
        loc.longitude >= -80.0 &&
        loc.longitude <= -66.5) {
      return loc;
    }
    return const LatLng(4.69680, -74.09250);
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

  /// Animación suave de cámara estilo Waze / Google Maps (interpolando centro y zoom)
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

  /// Calcula el punto focal cercano de navegación (como Waze/Maps al dar "Iniciar Ruta")
  /// enfocando la moto del domiciliario y el tramo inmediato de la ruta verde activa.
  void _animateToWazeNavigationCloseUp({
    Duration duration = const Duration(milliseconds: 1550),
  }) {
    if (!_isMapReady || !mounted) return;

    final courier = _safeCourierLocation;
    final activePoints = widget.routePoints;

    LatLng targetCenter;
    double targetZoom = 15.55;

    if (activePoints != null && activePoints.length > 4) {
      // Tomar un punto ~20% adelante del domiciliario sobre la polilínea vial verde
      // para que en pantalla se vea de cerca tanto la moto como el camino por las calles
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
      // Si aún se está calculando la polilínea, enfocar cerca del domiciliario hacia la parada #1
      targetCenter = LatLng(
        (courier.latitude * 0.78) + (widget.destinationLocation.latitude * 0.22),
        (courier.longitude * 0.78) +
            (widget.destinationLocation.longitude * 0.22),
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
    final hasRouteNow =
        (widget.fullRoutePoints != null && widget.fullRoutePoints!.length > 5) ||
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
          // Efecto Waze / Google Maps: acercar suavemente la cámara a la ruta activa
          _animateToWazeNavigationCloseUp();
        } else {
          _fitAllRouteBounds();
        }
      });
    } else if (widget.activeStopId != null &&
        widget.activeStopId != oldWidget.activeStopId &&
        widget.allStops != null) {
      try {
        final target =
            widget.allStops!.firstWhere((s) => s.id == widget.activeStopId);
        _animateCameraTo(
          LatLng(target.latitud, target.longitud),
          widget.isNavigationMode ? 15.5 : 14.8,
          duration: const Duration(milliseconds: 950),
        );
      } catch (_) {}
    }
  }

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
    pointsToFit.add(widget.destinationLocation);

    if (widget.showPlantaMatriz) {
      pointsToFit.add(_plantaMatriz);
    }

    if (widget.allStops != null) {
      for (final stop in widget.allStops!) {
        pointsToFit.add(LatLng(stop.latitud, stop.longitud));
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

  String get _plateShort {
    final clean = widget.courierPlate.trim();
    if (clean.isEmpty) return 'MOTO';
    return clean.split(' ').first.split('-').first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final courierLoc = _safeCourierLocation;
    final centerPoint = LatLng(
      (courierLoc.latitude + widget.destinationLocation.latitude) / 2,
      (courierLoc.longitude + widget.destinationLocation.longitude) / 2,
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
            // 1. Capa Cartográfica Blanca Minimalista 100% Gratuita (OpenStreetMap White Smooth sin API Key)
            TileLayer(
              urlTemplate: _selectedStyle.url,
              userAgentPackageName: ApiConfig.userAgentPackageName,
              maxNativeZoom: 19,
              maxZoom: _selectedStyle.maxZoom,
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: _whiteSmoothTileFilter,
                  child: tileWidget,
                );
              },
            ),

            // 2. Polilíneas de Enrutamiento Vial Calle por Calle (Estilo PWA)
            if (widget.showPolyline &&
                (effectiveFullRoute != null || effectiveActiveLeg != null))
              PolylineLayer(
                polylines: [
                  // Circuito multiparada completo por calles reales
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

                  // Tramo activo hacia la parada en turno (Verde Esmeralda PWA #10B981)
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

            // 3. Capa de Marcadores (Paradas Enumeradas #1, #2, #3 + Moto en Vivo)
            MarkerLayer(
              markers: [
                // Marcadores de Paradas Enumeradas (#1, #2, #3...)
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

                // Marcador del Domiciliario en Vivo con Placa
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

        // Botones flotantes de control de cámara (Solo Encuadrar Ruta y Mi Ubicación GPS)
        Positioned(
          right: 14,
          bottom: widget.bottomControlsOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón encuadrar todo el enrutado
              _buildMapControlFab(
                heroTag: 'fab_fit_route',
                icon: Icons.zoom_out_map_rounded,
                tooltip: 'Encuadrar todo el enrutado',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                onPressed: _fitAllRouteBounds,
              ),
              const SizedBox(height: 8),

              // Botón centrar en mi ubicación GPS
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

        // Badge de atribución cartográfica OpenStreetMap
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
              '© OpenStreetMap',
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

  /// Construye todos los pines enumerados (#1, #2, #3...) del enrutado del domiciliario
  List<Marker> _buildMultiStopMarkers() {
    final stops = widget.allStops!;
    final List<Marker> markers = [];

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final seqNum = i + 1;
      final isActive = widget.activeStopId == stop.id ||
          (widget.activeStopId == null &&
              (stop.estado == OrderStatus.enCamino ||
                  stop.estado == OrderStatus.enPunto));

      markers.add(
        Marker(
          point: LatLng(stop.latitud, stop.longitud),
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

  /// Pin de Parada Enumerada (#1, #2, #3 o ✓) idéntico a renderStopMarkers() de la PWA
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
      bgColor = const Color(0xFF10B981); // Emerald Green PWA
    } else if (isNovelty) {
      bgColor = const Color(0xFFDC2626); // Red PWA
    } else if (isActive) {
      bgColor = AppColors.primary; // DGL Forest Green (#1E5E3A)
    } else {
      bgColor = const Color(0xFF2563EB); // Royal Blue para paradas siguientes
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

  /// Marcador del Mensajero en Vivo con Placa idéntico a renderCourierMarkers() de la PWA
  Widget _buildPwaCourierMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo de pulso esmeralda
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.22),
          ),
        ),
        // Círculo principal del vehículo
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
        // Etiqueta inferior de placa (#0F172A igual a la PWA)
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
