import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/csv_parser.dart';
import '../services/geocoding_service.dart';
import '../services/storage_service.dart';

class LocationUploadDrawer extends StatefulWidget {
  const LocationUploadDrawer({super.key});

  @override
  State<LocationUploadDrawer> createState() => _LocationUploadDrawerState();
}

class _LocationUploadDrawerState extends State<LocationUploadDrawer> {
  String? _csvContent;
  Map<String, dynamic>? _generatedJson;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Locations',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Instructions
            const Text(
              'Upload a CSV file with school, bus yard, and student locations.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Expected format: type,address,id',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            
            // File picker button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose CSV File'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Processing indicator
            if (_isProcessing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Processing locations...'),
                  ],
                ),
              ),
            
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            
            // Success message
            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            
            const Spacer(),
            
            // Process button
            if (_csvContent != null && !_isProcessing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processCsv,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Process Locations',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            
            // View JSON button
            if (_generatedJson != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _viewJson,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'View JSON',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = result.files.single;
        
        // Handle web vs mobile platforms differently
        if (file.bytes != null) {
          // Web platform - use bytes
          final content = String.fromCharCodes(file.bytes!);
          await _handleContent(content);
        } else if (file.path != null) {
          // Mobile platform - use file path
          final fileObj = File(file.path!);
          await _handleFile(fileObj);
        } else {
          throw Exception('Unable to access file content');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
        _successMessage = null;
      });
    }
  }


  Future<void> _handleContent(String content) async {
    try {
      setState(() {
        _csvContent = content;
        _errorMessage = null;
        _successMessage = 'File loaded successfully';
        _generatedJson = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error reading file: $e';
        _successMessage = null;
      });
    }
  }

  Future<void> _handleFile(File file) async {
    try {
      final content = await file.readAsString();
      setState(() {
        _csvContent = content;
        _errorMessage = null;
        _successMessage = 'File loaded successfully';
        _generatedJson = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error reading file: $e';
        _successMessage = null;
      });
    }
  }

  Future<void> _processCsv() async {
    if (_csvContent == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      print('DEBUG: Starting CSV processing...');
      
      // Parse CSV
      final locations = CsvParser.parseCsv(_csvContent!);
      print('DEBUG: Parsed ${locations.length} locations from CSV');
      
      // Get all addresses for geocoding
      final addresses = locations.map((loc) => loc.address).toList();
      print('DEBUG: Addresses to geocode: $addresses');
      
      // Geocode addresses
      print('DEBUG: Starting geocoding process...');
      final coordinates = await GeocodingService.geocodeAddresses(addresses);
      print('DEBUG: Geocoding completed. Got ${coordinates.length} results');
      
      // Generate JSON with coordinates
      final jsonData = CsvParser.generateJson(locations);
      
      // Update coordinates in JSON
      int coordIndex = 0;
      int studentIndex = 0;
      
      for (final location in locations) {
        final coords = coordinates[coordIndex];
        print('DEBUG: Processing location ${location.type} at index $coordIndex with coords: $coords');
        
        if (coords != null) {
          if (location.type.toLowerCase() == 'school') {
            jsonData['school']['lat'] = coords['lat'];
            jsonData['school']['lon'] = coords['lon'];
            print('DEBUG: Updated school coordinates: ${coords['lat']}, ${coords['lon']}');
          } else if (location.type.toLowerCase() == 'bus_yard') {
            jsonData['bus_yard']['lat'] = coords['lat'];
            jsonData['bus_yard']['lon'] = coords['lon'];
            print('DEBUG: Updated bus_yard coordinates: ${coords['lat']}, ${coords['lon']}');
          } else if (location.type.toLowerCase() == 'student') {
            if (studentIndex < jsonData['students'].length) {
              jsonData['students'][studentIndex]['pos']['lat'] = coords['lat'];
              jsonData['students'][studentIndex]['pos']['lon'] = coords['lon'];
              print('DEBUG: Updated student $studentIndex coordinates: ${coords['lat']}, ${coords['lon']}');
              studentIndex++;
            }
          }
        } else {
          print('DEBUG: No coordinates found for ${location.type} at index $coordIndex');
        }
        coordIndex++;
      }
      
      // Save to local storage
      await StorageService.saveBusRouteData(jsonData);
      
      setState(() {
        _generatedJson = jsonData;
        _isProcessing = false;
        _successMessage = 'Locations processed successfully!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error processing CSV: $e';
      });
    }
  }


  void _viewJson() {
    if (_generatedJson == null) return;
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(_generatedJson);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generated JSON'),
        content: SingleChildScrollView(
          child: Text(
            jsonString,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
