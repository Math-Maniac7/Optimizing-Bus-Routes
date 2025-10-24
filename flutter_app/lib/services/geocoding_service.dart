import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  
  /// Geocodes an address to latitude and longitude coordinates
  /// Returns a Map with 'lat' and 'lon' keys, or null if geocoding fails
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    print('DEBUG: Geocoding address: "$address"');
    
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
        'addressdetails': '1',
      });
      
      print('DEBUG: Geocoding URL: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'BusRouteOptimizer/1.0',
        },
      );
      
      print('DEBUG: Geocoding response status: ${response.statusCode}');
      print('DEBUG: Geocoding response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        print('DEBUG: Geocoding results count: ${results.length}');
        
        if (results.isNotEmpty) {
          final result = results.first;
          final coords = {
            'lat': double.parse(result['lat']),
            'lon': double.parse(result['lon']),
          };
          print('DEBUG: Geocoding successful: $coords');
          return coords;
        } else {
          print('DEBUG: No geocoding results found');
        }
      } else {
        print('DEBUG: Geocoding failed with status: ${response.statusCode}');
      }
      
      return null;
    } catch (e) {
      print('DEBUG: Geocoding error: $e');
      return null;
    }
  }
  
  /// Geocodes multiple addresses in batch
  /// Returns a list of Maps with 'lat' and 'lon' keys, null for failed geocoding
  static Future<List<Map<String, double>?>> geocodeAddresses(List<String> addresses) async {
    final results = <Map<String, double>?>[];
    
    for (final address in addresses) {
      final result = await geocodeAddress(address);
      results.add(result);
      
      // Add delay to respect rate limits
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    return results;
  }
}
