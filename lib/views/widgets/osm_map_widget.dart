import 'dart:math' as math;
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

  /// Indica si el mapa se encuentra expandido a pantalla completa.
  final bool isFullScreen;

  /// Callback opcional para alternar la visualización del mapa completo.
  final VoidCallback? onToggleFullScreen;

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
    this.isFullScreen = false,
    this.onToggleFullScreen,
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

  /// Último rumbo de avance válido calculado en grados `[0, 360)`.
  double _lastValidBearingDeg = 0.0;

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

  /// Calcula la distancia aproximada en metros entre dos coordenadas geográficas.
  double _distanceMetersBetween(LatLng a, LatLng b) {
    try {
      const double earthRadiusMeters = 6371000.0;
      final double dLat = (b.latitude - a.latitude) * math.pi / 180.0;
      final double dLng = (b.longitude - a.longitude) * math.pi / 180.0;
      final double lat1 = a.latitude * math.pi / 180.0;
      final double lat2 = b.latitude * math.pi / 180.0;
      final double sinDLat = math.sin(dLat / 2.0);
      final double sinDLng = math.sin(dLng / 2.0);
      final double h = (sinDLat * sinDLat) +
          (math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng);
      final double c =
          2.0 * math.atan2(math.sqrt(h), math.sqrt((1.0 - h).clamp(0.0, 1.0)));
      return earthRadiusMeters * c;
    } catch (_) {
      return 0.0;
    }
  }

  /// Calcula el azimut geodésico en grados `[0, 360)` desde [from] hacia [to].
  double _calculateBearingDegrees(LatLng from, LatLng to) {
    try {
      final double lat1 = from.latitude * math.pi / 180.0;
      final double lat2 = to.latitude * math.pi / 180.0;
      final double dLng = (to.longitude - from.longitude) * math.pi / 180.0;
      final double y = math.sin(dLng) * math.cos(lat2);
      final double x = (math.cos(lat1) * math.sin(lat2)) -
          (math.sin(lat1) * math.cos(lat2) * math.cos(dLng));
      if (y.abs() < 1e-12 && x.abs() < 1e-12) {
        return _lastValidBearingDeg;
      }
      final double rawDeg = math.atan2(y, x) * 180.0 / math.pi;
      return (rawDeg + 360.0) % 360.0;
    } catch (_) {
      return _lastValidBearingDeg;
    }
  }

  /// Determina el rumbo de avance sobre el tramo activo de la ruta desde la posición del domiciliario.
  double _calculateForwardRouteBearingDeg(
    LatLng courier,
    LatLng? dest,
    List<LatLng>? route,
  ) {
    try {
      if (route != null && route.length >= 2) {
        int closestIndex = 0;
        double minDistance = double.infinity;
        for (int i = 0; i < route.length; i++) {
          final double d = _distanceMetersBetween(courier, route[i]);
          if (d < minDistance) {
            minDistance = d;
            closestIndex = i;
          }
        }
        final LatLng anchorPoint =
            minDistance <= 65.0 ? route[closestIndex] : courier;
        for (int j = closestIndex + 1; j < route.length; j++) {
          final double stepDist = _distanceMetersBetween(anchorPoint, route[j]);
          if (stepDist >= 8.0) {
            final double computed =
                _calculateBearingDegrees(anchorPoint, route[j]);
            _lastValidBearingDeg = computed;
            return computed;
          }
        }
        if (closestIndex < route.length - 1) {
          final double computed = _calculateBearingDegrees(
            route[closestIndex],
            route.last,
          );
          _lastValidBearingDeg = computed;
          return computed;
        }
      }
      if (dest != null && _distanceMetersBetween(courier, dest) >= 3.0) {
        final double computed = _calculateBearingDegrees(courier, dest);
        _lastValidBearingDeg = computed;
        return computed;
      }
      if (widget.heading.isFinite && widget.heading != 0.0) {
        _lastValidBearingDeg = (widget.heading + 360.0) % 360.0;
      }
      return _lastValidBearingDeg;
    } catch (_) {
      return _lastValidBearingDeg;
    }
  }

  /// Proyecta una coordenada [distanceMeters] metros hacia adelante sobre el rumbo [bearingDeg].
  LatLng _offsetLatLngByMeters(
    LatLng origin,
    double distanceMeters,
    double bearingDeg,
  ) {
    try {
      const double earthRadiusMeters = 6378137.0;
      final double bearingRad = bearingDeg * math.pi / 180.0;
      final double latRad = origin.latitude * math.pi / 180.0;
      final double dNorth = distanceMeters * math.cos(bearingRad);
      final double dEast = distanceMeters * math.sin(bearingRad);
      final double dLat = (dNorth / earthRadiusMeters) * (180.0 / math.pi);
      final double cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);
      final double dLng =
          (dEast / (earthRadiusMeters * cosLat)) * (180.0 / math.pi);
      return LatLng(origin.latitude + dLat, origin.longitude + dLng);
    } catch (_) {
      return origin;
    }
  }

  /// Anima suavemente la cámara del mapa hacia una coordenada, zoom y rotación objetivo.
  void _animateCameraTo(
    LatLng destLocation,
    double destZoom, {
    double? targetRotationDeg,
    Duration duration = const Duration(milliseconds: 1350),
    Curve curve = Curves.easeInOutCubic,
  }) {
    try {
      if (!_isMapReady || !mounted) return;

      _cameraAnimController?.stop();
      _cameraAnimController?.dispose();

      final LatLng startCenter = _mapController.camera.center;
      final double startZoom = _mapController.camera.zoom;
      final double startRotation = _mapController.camera.rotation;
      final double? rawEndRotation = targetRotationDeg;
      final double shortestRotationDelta = rawEndRotation != null
          ? (((rawEndRotation - startRotation + 540.0) % 360.0) - 180.0)
          : 0.0;

      final Tween<double> latTween = Tween<double>(
        begin: startCenter.latitude,
        end: destLocation.latitude,
      );
      final Tween<double> lngTween = Tween<double>(
        begin: startCenter.longitude,
        end: destLocation.longitude,
      );
      final Tween<double> zoomTween = Tween<double>(
        begin: startZoom,
        end: destZoom,
      );

      final AnimationController controller = AnimationController(
        duration: duration,
        vsync: this,
      );
      _cameraAnimController = controller;

      final CurvedAnimation animation = CurvedAnimation(
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
        if (rawEndRotation != null) {
          final double interpolatedRotation =
              startRotation + (shortestRotationDelta * animation.value);
          _mapController.rotate(interpolatedRotation);
        }
      });

      controller.forward();
    } catch (_) {}
  }

  /// Acerca la cámara sobre el domiciliario orientando el camino activo hacia arriba en pantalla.
  void _animateToWazeNavigationCloseUp({
    Duration duration = const Duration(milliseconds: 1250),
  }) {
    try {
      if (!_isMapReady || !mounted) return;

      final LatLng courier = _safeCourierLocation;
      final LatLng safeDest = _safeDestinationLocation;
      final List<LatLng>? activePoints = widget.routePoints;
      final double bearingDeg = _calculateForwardRouteBearingDeg(
        courier,
        safeDest,
        activePoints,
      );

      final bool hasDestination =
          _distanceMetersBetween(courier, safeDest) >= 3.0 ||
              (activePoints != null && activePoints.length >= 2);
      final double targetZoom = hasDestination ? 17.65 : 17.40;
      final LatLng targetCenter = _offsetLatLngByMeters(
        courier,
        90.0,
        bearingDeg,
      );

      _animateCameraTo(
        targetCenter,
        targetZoom,
        targetRotationDeg: widget.isNavigationMode ? -bearingDeg : 0.0,
        duration: duration,
        curve: Curves.easeInOutCubic,
      );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant OsmMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    try {
      final bool hasRouteNow = (widget.fullRoutePoints != null &&
              widget.fullRoutePoints!.length > 5) ||
          (widget.routePoints != null && widget.routePoints!.length > 5);

      if (widget.isNavigationMode != oldWidget.isNavigationMode &&
          _isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.isNavigationMode) {
            _animateToWazeNavigationCloseUp();
          } else {
            _fitAllRouteBounds();
          }
        });
        return;
      }

      if (widget.navigationZoomTrigger != oldWidget.navigationZoomTrigger &&
          _isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _animateToWazeNavigationCloseUp();
        });
        return;
      }

      if (widget.isNavigationMode &&
          _isMapReady &&
          (widget.courierLocation != oldWidget.courierLocation ||
              widget.destinationLocation != oldWidget.destinationLocation ||
              widget.routePoints != oldWidget.routePoints)) {
        final double movedMeters = _distanceMetersBetween(
          oldWidget.courierLocation,
          widget.courierLocation,
        );
        final double destMovedMeters = _distanceMetersBetween(
          oldWidget.destinationLocation,
          widget.destinationLocation,
        );
        if (movedMeters >= 4.0 ||
            destMovedMeters >= 5.0 ||
            widget.routePoints != oldWidget.routePoints) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _animateToWazeNavigationCloseUp(
                duration: const Duration(milliseconds: 700),
              );
            }
          });
        }
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
        final OrderModel target =
            widget.allStops!.firstWhere((s) => s.id == widget.activeStopId);
        final LatLng safeTarget = _safeStopLocation(target);
        if (widget.isNavigationMode) {
          _animateToWazeNavigationCloseUp(
            duration: const Duration(milliseconds: 900),
          );
        } else {
          _animateCameraTo(
            safeTarget,
            14.8,
            targetRotationDeg: 0.0,
            duration: const Duration(milliseconds: 950),
          );
        }
      }
    } catch (_) {}
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
        targetRotationDeg: 0.0,
        duration: const Duration(milliseconds: 900),
      );
    }
    widget.onRecenter?.call();
  }

  /// Ajusta los límites de la cámara para abarcar todas las paradas y el trazado de la ruta.
  void _fitAllRouteBounds() {
    try {
      final List<LatLng> pointsToFit = [];

      if (widget.fullRoutePoints != null &&
          widget.fullRoutePoints!.isNotEmpty) {
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

      _mapController.rotate(0.0);

      if (pointsToFit.length > 1) {
        final LatLngBounds bounds = LatLngBounds.fromPoints(pointsToFit);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(44, 68, 44, 56),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final LatLng courierLoc = _safeCourierLocation;
    final LatLng safeDestLoc = _safeDestinationLocation;
    final LatLng centerPoint = LatLng(
      (courierLoc.latitude + safeDestLoc.latitude) / 2,
      (courierLoc.longitude + safeDestLoc.longitude) / 2,
    );

    final List<LatLng>? effectiveActiveLeg =
        (widget.routePoints != null && widget.routePoints!.length >= 2)
            ? widget.routePoints!
            : null;

    final List<LatLng>? effectiveFullRoute =
        (widget.fullRoutePoints != null && widget.fullRoutePoints!.length >= 2)
            ? widget.fullRoutePoints!
            : null;

    final double forwardBearingDeg = _calculateForwardRouteBearingDeg(
      courierLoc,
      safeDestLoc,
      effectiveActiveLeg,
    );

    const Color casingColor = Colors.white;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerPoint,
            initialZoom: widget.isNavigationMode
                ? 17.65
                : (widget.allStops != null && widget.allStops!.length > 1
                    ? 12.2
                    : 13.5),
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
                      strokeWidth: widget.isNavigationMode ? 12.0 : 8.5,
                      color: casingColor.withValues(alpha: 0.96),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: effectiveActiveLeg,
                      strokeWidth: widget.isNavigationMode ? 7.6 : 5.2,
                      color: const Color(0xFF10B981),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.showPolyline && effectiveActiveLeg != null)
                  ..._buildRouteDirectionMarkers(effectiveActiveLeg),
                if (widget.allStops != null && widget.allStops!.isNotEmpty)
                  ..._buildMultiStopMarkers()
                else
                  Marker(
                    point: widget.destinationLocation,
                    width: 130,
                    height: 68,
                    rotate: true,
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
                    rotate: false,
                    child: GestureDetector(
                      onTap: _centerOnCourier,
                      child: _buildPwaCourierMarker(forwardBearingDeg),
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
                icon: widget.onToggleFullScreen != null
                    ? (widget.isFullScreen
                        ? Icons.close_fullscreen_rounded
                        : Icons.open_in_full_rounded)
                    : Icons.zoom_out_map_rounded,
                tooltip: widget.onToggleFullScreen != null
                    ? (widget.isFullScreen
                        ? 'Disminuir mapa'
                        : 'Ver mapa completo')
                    : 'Encuadrar todo el enrutado',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                onPressed: widget.onToggleFullScreen ?? _fitAllRouteBounds,
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

  /// Construye marcadores con flechas direccionales sobre la polilínea activa para indicar el sentido de avance.
  List<Marker> _buildRouteDirectionMarkers(List<LatLng> activeLeg) {
    final List<Marker> arrowMarkers = [];
    try {
      if (activeLeg.length < 2) return arrowMarkers;

      final int step = math.max(1, (activeLeg.length / 8).floor());
      for (int i = 0; i < activeLeg.length - 1; i += step) {
        final LatLng from = activeLeg[i];
        final LatLng to = activeLeg[i + 1];
        if (_distanceMetersBetween(from, to) < 6.0) {
          continue;
        }
        final LatLng midPoint = LatLng(
          (from.latitude + to.latitude) / 2.0,
          (from.longitude + to.longitude) / 2.0,
        );
        final double segmentBearingDeg = _calculateBearingDegrees(from, to);

        arrowMarkers.add(
          Marker(
            point: midPoint,
            width: 22,
            height: 22,
            rotate: false,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: segmentBearingDeg * math.pi / 180.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (_) {}
    return arrowMarkers;
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
          rotate: true,
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
    final bool isDelivered = status == OrderStatus.entregado;
    final bool isNovelty = status == OrderStatus.novedad;

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

  /// Construye el indicador de ubicación y dirección de avance del domiciliario sin ícono de moto.
  Widget _buildPwaCourierMarker(double bearingDeg) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.24),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.55),
                blurRadius: 14,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: bearingDeg * math.pi / 180.0,
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
