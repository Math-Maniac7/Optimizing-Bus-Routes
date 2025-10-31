import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_app/locations.dart' as locations;

class GoogleMaps extends StatefulWidget {
  final bool isModified;

  const GoogleMaps({super.key, required this.isModified});

  @override
  State<GoogleMaps> createState() => _GoogleMapsState();
}

class _GoogleMapsState extends State<GoogleMaps> {
  final Map<String, Marker> _markers = {};
  late GoogleMapController mapController;
  int id = 0;
  List<dynamic> stops = [];

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    stops = await locations.loadGeoJson();
    buildMarkers();
  }

  Future<void> buildMarkers() async {
    final newMarkers = <String, Marker>{};

    for (final stop in stops) {
      id += 1;
      final key = id.toString();
      newMarkers[key] = Marker(
        markerId: MarkerId(key),
        position: LatLng(stop.lat, stop.lng),
        draggable: widget.isModified,
        icon: await BitmapDescriptor.asset(
          ImageConfiguration(),
          'assets/blue_marker.png',
        ),
        onDragStart: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(
              iconParam: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            );
          });
          // debugPrint('Drag started at: $position');
        },
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  @override
  void didUpdateWidget(covariant GoogleMaps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isModified != widget.isModified) {
      buildMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: _onMapCreated,

        initialCameraPosition: CameraPosition(
          target: LatLng(30.622405, -96.353055),
          zoom: 15,
        ),
        markers: _markers.values.toSet(),
      ),
    );
  }
}
