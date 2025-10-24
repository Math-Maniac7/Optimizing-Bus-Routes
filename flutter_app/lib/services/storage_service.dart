import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Web-specific imports
import 'dart:html' as html show window;

class StorageService {
  static const String _storageKey = 'bus_route_data';
  
  /// Saves the bus route data to browser sessionStorage
  static Future<void> saveBusRouteData(Map<String, dynamic> data) async {
    if (kIsWeb) {
      try {
        final jsonString = const JsonEncoder.withIndent('  ').convert(data);
        html.window.sessionStorage[_storageKey] = jsonString;
        print('DEBUG: Saved bus route data to sessionStorage');
      } catch (e) {
        print('DEBUG: Error saving to sessionStorage: $e');
      }
    }
  }
  
  /// Retrieves the bus route data from browser sessionStorage
  static Map<String, dynamic>? getBusRouteData() {
    if (kIsWeb) {
      try {
        final jsonString = html.window.sessionStorage[_storageKey];
        if (jsonString != null && jsonString.isNotEmpty) {
          final data = json.decode(jsonString) as Map<String, dynamic>;
          print('DEBUG: Retrieved bus route data from sessionStorage');
          return data;
        }
      } catch (e) {
        print('DEBUG: Error retrieving from sessionStorage: $e');
      }
    }
    return null;
  }
  
  /// Checks if bus route data exists in sessionStorage
  static bool hasBusRouteData() {
    if (kIsWeb) {
      try {
        final jsonString = html.window.sessionStorage[_storageKey];
        return jsonString != null && jsonString.isNotEmpty;
      } catch (e) {
        print('DEBUG: Error checking sessionStorage: $e');
        return false;
      }
    }
    return false;
  }
  
  /// Clears the bus route data from sessionStorage
  static void clearBusRouteData() {
    if (kIsWeb) {
      try {
        html.window.sessionStorage.remove(_storageKey);
        print('DEBUG: Cleared bus route data from sessionStorage');
      } catch (e) {
        print('DEBUG: Error clearing sessionStorage: $e');
      }
    }
  }
}
