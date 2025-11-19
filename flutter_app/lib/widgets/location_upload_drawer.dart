import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/csv_parser.dart';
import '../services/geocoding_service.dart';
import '../services/storage_service.dart';
import '../utils/sample_download.dart';

class LocationUploadDrawer extends StatefulWidget {
  final ValueChanged<bool>? onProcessingChanged;
  
  const LocationUploadDrawer({super.key, this.onProcessingChanged});

  @override
  State<LocationUploadDrawer> createState() => _LocationUploadDrawerState();
}

class _LocationUploadDrawerState extends State<LocationUploadDrawer> {
  String? _csvContent;
  Map<String, dynamic>? _generatedJson;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  final List<Map<String, dynamic>> _buses = [
    {'id': 0, 'capacity': 100}
  ]; // List of buses with id and capacity
  final List<TextEditingController> _busCapacityControllers = [];
  final ScrollController _busListScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load cached data from session storage
    _loadCachedData();
  }
  
  Future<void> _loadCachedData() async {
    // Load CSV content
    final cachedCsv = StorageService.getCsvContent();
    if (cachedCsv != null) {
      setState(() {
        _csvContent = cachedCsv;
      });
    }
    
    // Load bus data
    final cachedBuses = StorageService.getBusData();
    if (cachedBuses != null && cachedBuses.isNotEmpty) {
      setState(() {
        _buses.clear();
        _buses.addAll(cachedBuses);
        // Dispose old controllers
        for (var controller in _busCapacityControllers) {
          controller.dispose();
        }
        _busCapacityControllers.clear();
        // Create new controllers with cached capacities
        for (var bus in _buses) {
          _busCapacityControllers.add(
            TextEditingController(text: bus['capacity'].toString()),
          );
        }
      });
    } else {
      // Initialize controller for the default bus if no cached data
      _busCapacityControllers.add(TextEditingController(text: '100'));
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _busCapacityControllers) {
      controller.dispose();
    }
    _busListScrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getCurrentBusData() {
    // Get current bus data with updated capacities from controllers
    final currentBuses = <Map<String, dynamic>>[];
    for (int i = 0; i < _buses.length; i++) {
      final capacityText = _busCapacityControllers[i].text.trim();
      final capacity = int.tryParse(capacityText);
      currentBuses.add({
        'id': _buses[i]['id'],
        'capacity': capacity ?? _buses[i]['capacity'],
      });
    }
    return currentBuses;
  }

  bool _shouldShowProcessButton() {
    if (_csvContent == null) return false;
    if (_isProcessing) return false;
    
    // Get current bus data with updated capacities
    final currentBuses = _getCurrentBusData();
    
    // Check if data has changed since last processing
    final currentState = StorageService.generateStateHash(_csvContent, currentBuses);
    final lastProcessedState = StorageService.getLastProcessedState();
    
    // Show button if never processed or if state has changed
    return lastProcessedState == null || lastProcessedState != currentState;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Drawer(
        child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(57, 103, 136, 1),
        ),
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Locations',
                  style: GoogleFonts.quicksand(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: _isProcessing ? Colors.white38 : Colors.white,
                  ),
                  tooltip: _isProcessing ? 'Cannot close while processing' : 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Instructions
            Text(
              'Upload a CSV file with school, bus yard, and student locations.',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Expected format: type,address,id',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),

            // Sample download button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _downloadSampleTemplate,
                icon: const Icon(Icons.download, color: Colors.white),
                label: Text(
                  'Download Sample Template (.xlsx)',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll<Color>(
                    Color.fromARGB(160, 255, 255, 255),
                  ),
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                  shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // File picker button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: Text(
                  'Choose CSV File',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll<Color>(
                    Color.fromARGB(180, 255, 255, 255),
                  ),
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                  shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            
            // CSV loaded indicator
            if (_csvContent != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withOpacity(0.3),
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CSV file loaded and ready to process',
                        style: GoogleFonts.quicksand(
                          color: Colors.green.shade100,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Bus Management Section
            const Divider(color: Colors.white30),
            const SizedBox(height: 8),
            Text(
              'Bus Configuration',
              style: GoogleFonts.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add buses and set their capacity',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            
            // Bus list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                controller: _busListScrollController,
                shrinkWrap: true,
                itemCount: _buses.length,
                itemBuilder: (context, index) {
                  return _buildBusItem(index);
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // Add bus button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _addBus,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Add Bus',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll<Color>(
                    Color.fromARGB(180, 255, 255, 255),
                  ),
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                  shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            
            // Processing indicator
            if (_isProcessing)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing locations...',
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade900.withOpacity(0.3),
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Please wait - drawer cannot be closed during processing',
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          color: Colors.orange.shade100,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.quicksand(
                    color: Colors.red.shade100,
                    fontSize: 14,
                  ),
                ),
              ),
            
            // Success message
            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withOpacity(0.3),
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _successMessage!,
                  style: GoogleFonts.quicksand(
                    color: Colors.green.shade100,
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Process button (only show if data has changed or never processed)
            if (_shouldShowProcessButton())
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _processCsv,
                  style: ButtonStyle(
                    backgroundColor: const WidgetStatePropertyAll<Color>(
                      Color.fromARGB(180, 255, 255, 255),
                    ),
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    ),
                    shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  child: Text(
                    'Process Locations',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 16), // Bottom padding for scrollable content
          ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBusItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(180, 255, 255, 255),
        border: Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Bus ID label
          Text(
            'Bus ${_buses[index]['id']}:',
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color.fromRGBO(57, 103, 136, 1),
            ),
          ),
          const SizedBox(width: 12),
          // Capacity input
          Expanded(
            child: TextField(
              controller: _busCapacityControllers[index],
              onChanged: (_) => _onBusDataChanged(),
              decoration: InputDecoration(
                labelText: 'Capacity',
                labelStyle: GoogleFonts.quicksand(
                  color: const Color.fromRGBO(57, 103, 136, 1),
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: const Color.fromARGB(180, 255, 255, 255),
                isDense: true,
              ),
              style: GoogleFonts.quicksand(
                color: const Color.fromRGBO(57, 103, 136, 1),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          // Remove button (disabled if only one bus)
          IconButton(
            onPressed: _buses.length > 1 ? () => _removeBus(index) : null,
            icon: const Icon(Icons.delete),
            color: Colors.red.shade300,
            tooltip: _buses.length > 1 ? 'Remove bus' : 'At least one bus required',
          ),
        ],
      ),
    );
  }
  
  void _onBusDataChanged() {
    // Update bus capacities from controllers
    for (int i = 0; i < _buses.length; i++) {
      final capacityText = _busCapacityControllers[i].text.trim();
      final capacity = int.tryParse(capacityText);
      if (capacity != null && capacity > 0) {
        _buses[i]['capacity'] = capacity;
      }
    }
    // Save to session storage
    StorageService.saveBusData(_buses);
    // Trigger rebuild to update Process button visibility
    setState(() {});
  }

  void _addBus() {
    setState(() {
      final newId = _buses.length; // Auto-increment ID
      _buses.add({'id': newId, 'capacity': 50}); // Default capacity of 50
      _busCapacityControllers.add(TextEditingController(text: '50'));
    });
    
    // Save to session storage
    StorageService.saveBusData(_buses);
    
    // Scroll to the bottom to show the newly added bus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_busListScrollController.hasClients) {
        _busListScrollController.animateTo(
          _busListScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeBus(int index) {
    if (_buses.length <= 1) return; // Prevent removing the last bus
    
    setState(() {
      _busCapacityControllers[index].dispose();
      _busCapacityControllers.removeAt(index);
      _buses.removeAt(index);
      // Reassign IDs to maintain sequential order starting from 0
      for (int i = 0; i < _buses.length; i++) {
        _buses[i]['id'] = i;
      }
    });
    
    // Save to session storage
    StorageService.saveBusData(_buses);
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
      // Save to session storage
      await StorageService.saveCsvContent(content);
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
      // Save to session storage
      await StorageService.saveCsvContent(content);
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
    widget.onProcessingChanged?.call(true);

    try {
      print('DEBUG: Starting CSV processing...');
      
      // Validate buses
      if (_buses.isEmpty) {
        throw Exception('At least one bus is required');
      }
      
      // Update bus capacities from controllers
      for (int i = 0; i < _buses.length; i++) {
        final capacityText = _busCapacityControllers[i].text.trim();
        final capacity = int.tryParse(capacityText);
        if (capacity == null || capacity <= 0) {
          throw Exception('Bus $i capacity must be a positive number');
        }
        _buses[i]['capacity'] = capacity;
      }
      
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
      
      // Generate JSON with coordinates and buses
      final jsonData = CsvParser.generateJson(locations, buses: _buses);
      
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
      
      // Save the updated bus data to session storage (with updated capacities)
      await StorageService.saveBusData(_buses);
      
      // Save the current state as the last processed state (use updated bus data)
      final currentBuses = _getCurrentBusData();
      final currentState = StorageService.generateStateHash(_csvContent, currentBuses);
      await StorageService.saveLastProcessedState(currentState);
      
      setState(() {
        _generatedJson = jsonData;
        _isProcessing = false;
        _successMessage = 'Locations processed successfully!';
      });
      widget.onProcessingChanged?.call(false);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error processing CSV: $e';
      });
      widget.onProcessingChanged?.call(false);
    }
  }

  Future<void> _downloadSampleTemplate() async {
    try {
      final byteData = await rootBundle.load('assets/sample_locations.xlsx');
      final bytes = byteData.buffer.asUint8List();
      await downloadSampleFile(bytes, 'sample_locations.xlsx');
      if (!kIsWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample template is bundled with the app assets.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on UnsupportedError catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading the sample file is only available on web builds.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download sample file: $e')),
      );
    }
  }
}
