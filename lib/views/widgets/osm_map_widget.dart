import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

/// Widget de mapa interactivo basado 100% en OpenStreetMap gratuito
class OsmMapWidget extends StatefulWidget {
  final LatLng courierLocation;
  final LatLng destinationLocation;
  final String destinationTitle;
  final double heading;
  final bool showPolyline;
  final List<LatLng>? routePoints; // Trazado por las calles reales
  final VoidCallback? onRecenter;

  const OsmMapWidget({
    super.key,
    required this.courierLocation,
    required this.destinationLocation,
    required this.destinationTitle,
    this.heading = 0.0,
    this.showPolyline = true,
    this.routePoints,
    this.onRecenter,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _centerOnCourier() {
    _mapController.move(widget.courierLocation, 15.5);
    widget.onRecenter?.call();
  }

  void _fitBothMarkers() {
    final pointsToFit = (widget.routePoints != null && widget.routePoints!.isNotEmpty)
        ? widget.routePoints!
        : [widget.courierLocation, widget.destinationLocation];

    final bounds = LatLngBounds.fromPoints(pointsToFit);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerPoint = LatLng(
      (widget.courierLocation.latitude + widget.destinationLocation.latitude) / 2,
      (widget.courierLocation.longitude + widget.destinationLocation.longitude) / 2,
    );

    final effectiveRoutePoints = (widget.routePoints != null && widget.routePoints!.isNotEmpty)
        ? widget.routePoints!
        : [widget.courierLocation, widget.destinationLocation];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerPoint,
            initialZoom: 14.2,
            minZoom: 5.0,
            maxZoom: 18.5,
          ),
          children: [
            // Capa de mosaicos OpenStreetMap (Gratuito)
            TileLayer(
              urlTemplate: ApiConfig.osmTileUrl,
              userAgentPackageName: ApiConfig.userAgentPackageName,
              maxZoom: 19,
            ),

            // Línea de ruta por las calles (Polilínea con bordes de alto contraste)
            if (widget.showPolyline)
              PolylineLayer(
                polylines: [
                  // Capa base de borde exterior oscuro
                  Polyline(
                    points: effectiveRoutePoints,
                    strokeWidth: 6.0,
                    color: const Color(0xFF064E3B), // Dark Emerald / Slate border
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                  // Capa principal verde esmeralda brillante
                  Polyline(
                    points: effectiveRoutePoints,
                    strokeWidth: 4.0,
                    color: AppColors.primary,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),

            // Capa de Marcadores (Mensajero y Destino)
            MarkerLayer(
              markers: [
                // Marcador del Mensajero (Moto Esmeralda con pulso)
                Marker(
                  point: widget.courierLocation,
                  width: 52,
                  height: 52,
                  child: _buildCourierMarker(),
                ),

                // Marcador del Cliente / Destino
                Marker(
                  point: widget.destinationLocation,
                  width: 48,
                  height: 58,
                  child: _buildDestinationMarker(),
                ),
              ],
            ),
          ],
        ),

        // Botones flotantes de control de cámara
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón encuadrar ruta completa
              FloatingActionButton.small(
                heroTag: 'fab_fit_route',
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: _fitBothMarkers,
                child: const Icon(Icons.route_outlined, size: 20),
              ),
              const SizedBox(height: 10),

              // Botón centrar en mi ubicación
              FloatingActionButton(
                heroTag: 'fab_center_me',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onPressed: _centerOnCourier,
                child: const Icon(Icons.my_location_rounded, size: 24),
              ),
            ],
          ),
        ),

        // Attribution Badge OSM
        Positioned(
          left: 10,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourierMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo de pulso
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        // Círculo base
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              FontAwesomeIcons.motorcycle,
              color: Colors.black,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        Container(
          width: 4,
          height: 10,
          color: AppColors.error,
        ),
      ],
    );
  }
}
