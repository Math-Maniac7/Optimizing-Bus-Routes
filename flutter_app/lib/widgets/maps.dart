import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_app/locations.dart' as locations;

class GoogleMaps extends StatefulWidget {
  const GoogleMaps({super.key});

  @override
  State<GoogleMaps> createState() => _GoogleMapsState();
}

class _GoogleMapsState extends State<GoogleMaps> {
  final Map<String, Marker> _markers = {};
  int _id = 0;

  Future<void> _onMapCreated(GoogleMapController controller) async {
    final stops = await locations.loadGeoJson();
    final newMarkers = <String, Marker>{};
    // print('Loaded ${stops.length} stops from GeoJSON');
    for (final stop in stops) {
      _id += 1;
      final key = _id.toString();
      newMarkers[key] = Marker(
        markerId: MarkerId(key),
        position: LatLng(stop.lat, stop.lng),
      );
      // print('Created marker $key at (${stop.lng}, ${stop.lat})');
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });

    print('Total markers after setState: ${_markers.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: _onMapCreated,

        initialCameraPosition: CameraPosition(
          target: LatLng(30.622405, -96.353055),
          zoom: 11,
        ),
        markers: _markers.values.toSet(),
      ),
    );
  }
}
