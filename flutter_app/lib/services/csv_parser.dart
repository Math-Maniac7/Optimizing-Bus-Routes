import 'package:csv/csv.dart';

class LocationData {
  final String type;
  final String address;
  final int? id;
  
  LocationData({
    required this.type,
    required this.address,
    this.id,
  });
}

class CsvParser {
  static List<LocationData> parseCsv(String csvContent) {
    print('DEBUG: CSV Content received:');
    print(csvContent);
    
    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
      fieldDelimiter: ',',
      textDelimiter: '"',
    ).convert(csvContent);
    
    print('DEBUG: Parsed CSV rows: $rows');
    
    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }
    
    // Skip header row
    final dataRows = rows.skip(1).toList();
    
    print('DEBUG: Data rows (excluding header): $dataRows');
    
    final List<LocationData> locations = [];
    
    for (final row in dataRows) {
      if (row.length < 2) continue; // Skip invalid rows
      
      final type = row[0]?.toString().trim();
      final address = row[1]?.toString().trim();
      final idString = row.length > 2 ? row[2]?.toString().trim() : '';
      
      print('DEBUG: Processing row - type: "$type", address: "$address", id: "$idString"');
      
      if (type != null && address != null && type.isNotEmpty && address.isNotEmpty) {
        final id = idString != null && idString.isNotEmpty ? int.tryParse(idString) : null;
        
        final location = LocationData(
          type: type,
          address: address,
          id: id,
        );
        
        print('DEBUG: Created location: type="${location.type}", address="${location.address}", id=${location.id}');
        locations.add(location);
      } else {
        print('DEBUG: Skipping row due to empty type or address');
      }
    }
    
    print('DEBUG: Final parsed locations: ${locations.map((l) => '${l.type}: ${l.address}').toList()}');
    
    return locations;
  }
  
  static Map<String, dynamic> generateJson(
    List<LocationData> locations, {
    List<Map<String, dynamic>>? buses,
  }) {
    print('DEBUG: generateJson called with ${locations.length} locations');
    print('DEBUG: Location types: ${locations.map((l) => l.type).toList()}');
    
    // Validate that we have required locations
    final hasSchool = locations.any((loc) => loc.type.toLowerCase() == 'school');
    final hasBusYard = locations.any((loc) => loc.type.toLowerCase() == 'bus_yard');
    
    print('DEBUG: Has school: $hasSchool, Has bus yard: $hasBusYard');
    
    if (!hasSchool) {
      print('DEBUG: School location not found. Available types: ${locations.map((l) => l.type).toList()}');
      throw Exception('School location not found');
    }
    
    if (!hasBusYard) {
      print('DEBUG: Bus yard location not found. Available types: ${locations.map((l) => l.type).toList()}');
      throw Exception('Bus yard location not found');
    }
    
    final students = locations.where(
      (loc) => loc.type.toLowerCase() == 'student',
    ).toList();
    
    // Use provided buses or fall back to default
    final busesList = buses ?? [
      {"id": 0, "capacity": 100}
    ];
    
    // Ensure buses are in the correct format (convert to int where needed)
    final formattedBuses = busesList.map((bus) => {
      'id': bus['id'] is int ? bus['id'] : int.parse(bus['id'].toString()),
      'capacity': bus['capacity'] is int ? bus['capacity'] : int.parse(bus['capacity'].toString()),
    }).toList();
    
    return {
      'school': {
        'lat': 0.0, // Will be filled by geocoding
        'lon': 0.0, // Will be filled by geocoding
      },
      'bus_yard': {
        'lat': 0.0, // Will be filled by geocoding
        'lon': 0.0, // Will be filled by geocoding
      },
      'students': students.map((student) => {
        'id': student.id ?? 0,
        'pos': {
          'lat': 0.0, // Will be filled by geocoding
          'lon': 0.0, // Will be filled by geocoding
        },
      }).toList(),
      'buses': formattedBuses,
    };
  }
}
