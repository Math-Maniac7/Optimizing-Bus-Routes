import 'package:flutter/material.dart';
import 'package:flutter_app/services/storage_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_custom_marker/google_maps_custom_marker.dart';

class GoogleMaps extends StatefulWidget {
  final bool isModified;
  bool isSaved;
  bool cancelModify;
  int addMarker;
  final bool interactionEnabled;

  GoogleMaps({
    super.key,
    required this.isModified,
    required this.isSaved,
    required this.cancelModify,
    required this.addMarker,
    this.interactionEnabled = true,
  });

  @override
  State<GoogleMaps> createState() => _GoogleMapsState();
}

class _GoogleMapsState extends State<GoogleMaps> {
  final Map<String, Marker> _markers = {};
  late GoogleMapController mapController;
  int id = 0;
  List<dynamic> stops = [];
  LatLng? _savedCenter;
  double? _savedZoom;
  late BitmapDescriptor idleIcon;
  late BitmapDescriptor dragIcon;
  List<dynamic>? _originalStops;

  Future<void> initIcons() async {
    final base = Marker(
      markerId: const MarkerId('tmp'),
      position: LatLng(0, 0),
    );

    final idleMarker = await GoogleMapsCustomMarker.createCustomMarker(
      marker: base,
      shape: MarkerShape.pin,
    );

    idleIcon = idleMarker.icon;

    final dragMarker = await GoogleMapsCustomMarker.createCustomMarker(
      marker: base,
      shape: MarkerShape.pin,
      backgroundColor: Colors.blue,
    );

    dragIcon = dragMarker.icon;
  }

  void _fitToMarkers() async {
    if (_markers.isEmpty) return;

    // Build the bounds that include all marker positions
    LatLngBounds bounds;
    final positions = _markers.values.map((m) => m.position).toList();

    double south = positions.first.latitude;
    double north = positions.first.latitude;
    double west = positions.first.longitude;
    double east = positions.first.longitude;

    for (var pos in positions) {
      if (pos.latitude < south) south = pos.latitude;
      if (pos.latitude > north) north = pos.latitude;
      if (pos.longitude < west) west = pos.longitude;
      if (pos.longitude > east) east = pos.longitude;
    }

    bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    // Animate camera to fit bounds
    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // 50 = padding
    );

    _savedCenter = LatLng((south + north) / 2, (west + east) / 2);
    _savedZoom = await _estimateZoomToFitBounds(bounds);
  }

  Future<double> _estimateZoomToFitBounds(LatLngBounds bounds) async {
    // Approximation: zoom out based on lat/long difference
    final latDiff = (bounds.northeast.latitude - bounds.southwest.latitude)
        .abs();
    final lonDiff = (bounds.northeast.longitude - bounds.southwest.longitude)
        .abs();
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff < 0.001) return 18;
    if (maxDiff < 0.01) return 15;
    if (maxDiff < 0.1) return 12;
    return 10; // Fallback
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    await initIcons();
    if (StorageService.hasBusRouteData()) {
      final jsonData = StorageService.getBusRouteData();
      if (jsonData != null && jsonData['stops'] != null) {
        stops = jsonData['stops'];
        buildMarkers(stops);
      }
    }
  }

  void buildMarkers(List<dynamic> stops) async {
    final newMarkers = <String, Marker>{};

    for (final stop in stops) {
      id += 1;
      final key = id.toString();
      final lat = stop['pos']['lat'] as num;
      final lon = stop['pos']['lon'] as num;

      newMarkers[key] = Marker(
        onTap: () {},
        markerId: MarkerId(key),
        position: LatLng(lat.toDouble(), lon.toDouble()),
        draggable: widget.isModified,
        icon: idleIcon,
        onDragStart: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(iconParam: dragIcon);
          });
        },
        onDrag: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(iconParam: dragIcon);
          });
        },
        onDragEnd: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(
              positionParam: LatLng(position.latitude, position.longitude),
              iconParam: idleIcon,
            );

            stop['pos']['lat'] = position.latitude;
            stop['pos']['lon'] = position.longitude;
          });
        },
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });

    if (_savedCenter == null && _savedZoom == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToMarkers(); // First time only
      });
    }
  }

  @override
  void didUpdateWidget(covariant GoogleMaps oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.addMarker < widget.addMarker) {
      final center = _savedCenter ?? const LatLng(30.622405, -96.353055);

      final newStop = {
        'pos': {'lat': center.latitude, 'lon': center.longitude},
      };

      setState(() {
        stops.add(newStop);
        buildMarkers(stops);
      });
    }

    if (!oldWidget.isSaved && widget.isSaved) {
      StorageService.saveBusRouteData({'stops': stops});
      buildMarkers(stops);
    }

    if (!oldWidget.isModified && widget.isModified) {
      _originalStops = stops
          .map(
            (s) => {
              ...s,
              'pos': {'lat': s['pos']['lat'], 'lon': s['pos']['lon']},
            },
          )
          .toList();
    }

    if (!oldWidget.cancelModify && widget.cancelModify) {
      if (_originalStops != null) {
        stops = List.from(_originalStops!);
        buildMarkers(stops);
      }
    }

    final updatedMarkers = <String, Marker>{};
    _markers.forEach((key, marker) {
      updatedMarkers[key] = marker.copyWith(draggableParam: widget.isModified);
    });

    setState(() {
      _markers
        ..clear()
        ..addAll(updatedMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _savedCenter ?? const LatLng(30.622405, -96.353055),
          zoom: _savedZoom ?? 15,
        ),
        markers: _markers.values.toSet(),
        onCameraMove: (position) {
          _savedCenter = position.target;
          _savedZoom = position.zoom;
        },
        scrollGesturesEnabled: widget.interactionEnabled,
        zoomGesturesEnabled: widget.interactionEnabled,
        tiltGesturesEnabled: widget.interactionEnabled,
        rotateGesturesEnabled: widget.interactionEnabled,
        zoomControlsEnabled: widget.interactionEnabled,
        myLocationButtonEnabled: widget.interactionEnabled,
        mapToolbarEnabled: widget.interactionEnabled,
        onTap: widget.interactionEnabled
            ? null
            : (_) {
                // Ignore taps when interactions are disabled
              },
      ),
    );
  }
}
