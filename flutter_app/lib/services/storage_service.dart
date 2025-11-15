import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Web-specific imports
import 'dart:html' as html show window;

class StorageService {
  static const String _storageKey = 'bus_route_data';
  static const String _csvContentKey = 'csv_content';
  static const String _busDataKey = 'bus_data';
  static const String _lastProcessedStateKey = 'last_processed_state';
  
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
  
  /// Saves CSV content to sessionStorage
  static Future<void> saveCsvContent(String csvContent) async {
    if (kIsWeb) {
      try {
        html.window.sessionStorage[_csvContentKey] = csvContent;
        print('DEBUG: Saved CSV content to sessionStorage');
      } catch (e) {
        print('DEBUG: Error saving CSV content: $e');
      }
    }
  }
  
  /// Retrieves CSV content from sessionStorage
  static String? getCsvContent() {
    if (kIsWeb) {
      try {
        final csvContent = html.window.sessionStorage[_csvContentKey];
        if (csvContent != null && csvContent.isNotEmpty) {
          print('DEBUG: Retrieved CSV content from sessionStorage');
          return csvContent;
        }
      } catch (e) {
        print('DEBUG: Error retrieving CSV content: $e');
      }
    }
    return null;
  }
  
  /// Saves bus data to sessionStorage
  static Future<void> saveBusData(List<Map<String, dynamic>> buses) async {
    if (kIsWeb) {
      try {
        final jsonString = jsonEncode(buses);
        html.window.sessionStorage[_busDataKey] = jsonString;
        print('DEBUG: Saved bus data to sessionStorage');
      } catch (e) {
        print('DEBUG: Error saving bus data: $e');
      }
    }
  }
  
  /// Retrieves bus data from sessionStorage
  static List<Map<String, dynamic>>? getBusData() {
    if (kIsWeb) {
      try {
        final jsonString = html.window.sessionStorage[_busDataKey];
        if (jsonString != null && jsonString.isNotEmpty) {
          final data = json.decode(jsonString) as List<dynamic>;
          final buses = data.map((e) => e as Map<String, dynamic>).toList();
          print('DEBUG: Retrieved bus data from sessionStorage');
          return buses;
        }
      } catch (e) {
        print('DEBUG: Error retrieving bus data: $e');
      }
    }
    return null;
  }
  
  /// Saves the last processed state (hash of CSV + buses) to detect changes
  static Future<void> saveLastProcessedState(String stateHash) async {
    if (kIsWeb) {
      try {
        html.window.sessionStorage[_lastProcessedStateKey] = stateHash;
        print('DEBUG: Saved last processed state to sessionStorage');
      } catch (e) {
        print('DEBUG: Error saving last processed state: $e');
      }
    }
  }
  
  /// Retrieves the last processed state
  static String? getLastProcessedState() {
    if (kIsWeb) {
      try {
        return html.window.sessionStorage[_lastProcessedStateKey];
      } catch (e) {
        print('DEBUG: Error retrieving last processed state: $e');
      }
    }
    return null;
  }
  
  /// Generates a hash from CSV content and bus data to detect changes
  static String generateStateHash(String? csvContent, List<Map<String, dynamic>> buses) {
    final busData = jsonEncode(buses);
    final combined = '${csvContent ?? ''}|$busData';
    // Simple hash - in production you might want to use a proper hash function
    return combined.length.toString() + (csvContent?.hashCode ?? 0).toString() + busData.hashCode.toString();
  }
}
