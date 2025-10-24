import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Stops {
  Stops({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

Future<List<Stops>> loadGeoJson() async {
  final data = await rootBundle.loadString('assets/coords.geojson');
  final jsonData = jsonDecode(data);

  // Extract coordinates manually from the LineString
  final coords = jsonData['features'][0]['geometry']['coordinates'] as List;

  final stops = coords.map((pair) {
    final lon = pair[0];
    final lat = pair[1];
    return Stops(lat: lat, lng: lon);
  }).toList();

  // print('Parsed ${stops.length} coordinate stops');
  return stops;
}
