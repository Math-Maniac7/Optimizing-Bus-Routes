import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../widgets/maps.dart';
import '../widgets/location_upload_drawer.dart';
import '../WASM/wasm_interop.dart';
import '../services/storage_service.dart';
import 'package:collection/collection.dart';

typedef PhaseType = DropdownMenuEntry<Phase>;

enum Phase {
  phaseOne('Phase', 1),
  phaseTwo('Phase', 2),
  phaseThree('Phase', 3);

  const Phase(this.label, this.phase);
  final String label;
  final int phase;

  static final List<PhaseType> entries = UnmodifiableListView<PhaseType>(
    values.map<PhaseType>(
      (Phase p) => PhaseType(
        value: p,
        label: '${p.label} ${p.phase}',
        style: MenuItemButton.styleFrom(
          foregroundColor: const Color.fromRGBO(57, 103, 136, 1),
        ),
      ),
    ),
  );
}

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});
  static const String routeName = '/routes';

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Phase? selectedPhase = Phase.phaseOne; // Default to Phase 1
  bool _isModified = false;
  bool _isDrawerOpen = false;
  bool _isGeneratingRoutes = false;
  int _addMarker = 0;
  bool _saveMarkers = false;
  bool _cancelModify = false;
  int _mapReloadKey = 0;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      onEndDrawerChanged: (isOpened) {
        setState(() {
          _isDrawerOpen = isOpened;
        });
      },
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.02,
              vertical: screenHeight * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _isModified ? 'Edit Mode' : 'Bus Route Optimizer',
                  style: GoogleFonts.quicksand(
                    fontSize: 70,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isModified) ...[
                              _buildSideButton("Add Locations", screenWidth),
                              SizedBox(height: screenHeight * 0.02),
                              _buildSideButton("Generate Routes", screenWidth),
                              SizedBox(height: screenHeight * 0.02),
                              _buildSideButton("Modify", screenWidth),
                              SizedBox(height: screenHeight * 0.02),
                              DropdownMenu<Phase>(
                                width: screenWidth * .15,
                                initialSelection: Phase.phaseOne,
                                requestFocusOnTap: false,
                                onSelected: (Phase? p) {
                                  setState(() {
                                    selectedPhase = p;
                                  });
                                },
                                dropdownMenuEntries: Phase.entries,
                                inputDecorationTheme: InputDecorationTheme(
                                  fillColor: const Color.fromARGB(
                                    180,
                                    255,
                                    255,
                                    255,
                                  ),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                menuStyle: MenuStyle(
                                  minimumSize: WidgetStatePropertyAll(
                                    Size(screenWidth * 0.15, 0),
                                  ),
                                  backgroundColor:
                                      const WidgetStatePropertyAll<Color>(
                                        Colors.white,
                                      ),
                                ),
                                textStyle: GoogleFonts.quicksand(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ] else ...[
                              // When modified, show Save and Cancel
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'Use the scroll wheel to zoom in and out.',
                                      style: GoogleFonts.quicksand(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    SizedBox(height: screenHeight * 0.02),
                                    _buildSideButton("Add Marker", screenWidth),
                                    SizedBox(height: screenHeight * 0.02),
                                    _buildSideButton("Save", screenWidth),
                                    SizedBox(height: screenHeight * 0.02),
                                    _buildSideButton("Cancel", screenWidth),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        flex: 6, // give more width to the map
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AbsorbPointer(
                                absorbing: _isDrawerOpen,
                                child: GoogleMaps(
                                  key: ValueKey(_mapReloadKey),
                                  isModified: _isModified,
                                  isSaved: _saveMarkers,
                                  cancelModify: _cancelModify,
                                  addMarker: _addMarker,
                                  interactionEnabled: !_isDrawerOpen,
                                  phaseType: selectedPhase,
                                ),
                              ),
                            ),
                            if (_isModified)
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      35,
                                      255,
                                      255,
                                      255,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Full-screen blocking overlay when drawer is open
          if (_isDrawerOpen)
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) {},
                onPointerMove: (_) {},
                onPointerUp: (_) {},
                onPointerCancel: (_) {},
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          // Loading overlay when generating routes
          if (_isGeneratingRoutes)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Generating routes...',
                        style: GoogleFonts.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      endDrawer: const LocationUploadDrawer(),
    );
  }

  Widget _buildSideButton(String text, double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.15,
      child: TextButton(
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
        onPressed: () {
          if (text == "Add Locations") {
            _onAddLocations();
          } else if (text == "Generate Routes") {
            _onGenerateRoutes();
          } else if (text == "Modify") {
            _onModify();
          } else if (text == "Save") {
            _onSave();
          } else if (text == "Cancel") {
            _onCancel();
          } else if (text == "Add Marker") {
            _onAddMarker();
          }
        },
        child: Text(
          text,
          style: GoogleFonts.quicksand(
            fontSize: 25,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _onAddLocations() {
    debugPrint("Add Locations button pressed");
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _onGenerateRoutes() async {
    debugPrint("Generate Routes button pressed");

    // Determine which phase to use (default to Phase 1 if not selected)
    final phase = selectedPhase ?? Phase.phaseOne;
    final phaseNumber = phase.phase;

    if (phaseNumber == 1) {
      await _generatePhase1Routes();
    } else if (phaseNumber == 2) {
      await _generatePhase2Routes();
    } else if (phaseNumber == 3) {
      await _generatePhase3Routes();
    }
  }

  Future<void> _generatePhase1Routes() async {
    // Check if data exists in session storage
    if (!StorageService.hasBusRouteData()) {
      _showMessage(
        'No location data found. Please add locations first.',
        isError: true,
      );
      return;
    }

    // Get JSON from session storage
    final jsonData = StorageService.getBusRouteData();
    if (jsonData == null) {
      _showMessage(
        'Failed to retrieve location data from storage.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isGeneratingRoutes = true;
    });

    try {
      // Convert JSON map to string
      final jsonString = jsonEncode(jsonData);
      debugPrint('Calling phase_1 with JSON data...');

      // Call the WASM phase_1 function
      final resultString = await phase_1(jsonString);
      debugPrint('Received result from phase_1');

      // Parse the BRP JSON result (not GeoJSON)
      final brpResult = jsonDecode(resultString) as Map<String, dynamic>;
      debugPrint('Parsed BRP JSON result');
      debugPrint("RAW BRP RESULT:\n$resultString");

      // Extract stops from the BRP JSON (stops are already in the correct format)
      final stops = brpResult['stops'] as List<dynamic>?;
      if (stops == null) {
        _showMessage(
          'No stops found in phase 1 result.',
          isError: true,
        );
        return;
      }
      debugPrint('Extracted ${stops.length} stops from BRP JSON');

      // Merge the result with existing JSON data
      // The result contains the full BRP with stops, assignments, routes, etc.
      // We want to preserve our existing data and add the stops
      final updatedJsonData = Map<String, dynamic>.from(jsonData);
      updatedJsonData['stops'] = stops;
      
      // Also update other fields if they exist in the result (evals, etc.)
      if (brpResult.containsKey('evals')) {
        updatedJsonData['evals'] = brpResult['evals'];
      }
      
      debugPrint('Updated JSON with stops');

      // Save the updated JSON back to session storage
      await StorageService.saveBusRouteData(updatedJsonData);
      debugPrint('Saved updated JSON to session storage');

      setState(() {
        _mapReloadKey++; // force map to rebuild
      });

      _showMessage('Routes generated successfully!', isError: false);
    } catch (e) {
      debugPrint('Error generating routes: $e');
      _showMessage('Error generating routes: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isGeneratingRoutes = false;
      });
    }
  }

  Future<void> _generatePhase2Routes() async {
    // Check if data exists in session storage
    if (!StorageService.hasBusRouteData()) {
      _showMessage(
        'No location data found. Please add locations first.',
        isError: true,
      );
      return;
    }

    // Get JSON from session storage
    final jsonData = StorageService.getBusRouteData();
    if (jsonData == null) {
      _showMessage(
        'Failed to retrieve location data from storage.',
        isError: true,
      );
      return;
    }

    // Phase 2 requires stops from Phase 1
    final stops = jsonData['stops'] as List<dynamic>?;
    if (stops == null || stops.isEmpty) {
      _showMessage(
        'Phase 1 must be completed first. Please generate Phase 1 routes.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isGeneratingRoutes = true;
    });

    try {
      // Convert JSON map to string
      final jsonString = jsonEncode(jsonData);
      debugPrint('Calling phase_2 with JSON data...');

      // Call the WASM phase_2 function
      final resultString = await phase_2(jsonString);
      debugPrint('Received result from phase_2');

      // Parse the BRP JSON result (not GeoJSON)
      final brpResult = jsonDecode(resultString) as Map<String, dynamic>;
      debugPrint('Parsed BRP JSON result');
      debugPrint("RAW BRP RESULT:\n$resultString");

      // Extract assignments from the BRP JSON (assignments are already in the correct format)
      final assignments = brpResult['assignments'] as List<dynamic>?;
      if (assignments == null) {
        _showMessage(
          'No assignments found in phase 2 result.',
          isError: true,
        );
        return;
      }
      debugPrint('Extracted ${assignments.length} assignments from BRP JSON');

      // Merge the result with existing JSON data
      final updatedJsonData = Map<String, dynamic>.from(jsonData);
      updatedJsonData['assignments'] = assignments;
      
      // Also update other fields if they exist in the result (evals, etc.)
      if (brpResult.containsKey('evals')) {
        updatedJsonData['evals'] = brpResult['evals'];
      }
      
      // Preserve stops if they exist in the result
      if (brpResult.containsKey('stops')) {
        updatedJsonData['stops'] = brpResult['stops'];
      }
      
      debugPrint('Updated JSON with assignments');

      // Save the updated JSON back to session storage
      await StorageService.saveBusRouteData(updatedJsonData);
      debugPrint('Saved updated JSON to session storage');

      setState(() {
        _mapReloadKey++; // force map to rebuild
      });

      _showMessage('Routes generated successfully!', isError: false);
    } catch (e) {
      debugPrint('Error generating routes: $e');
      _showMessage('Error generating routes: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isGeneratingRoutes = false;
      });
    }
  }

  Future<void> _generatePhase3Routes() async {
    // Check if data exists in session storage
    if (!StorageService.hasBusRouteData()) {
      _showMessage(
        'No location data found. Please add locations first.',
        isError: true,
      );
      return;
    }

    // Get JSON from session storage
    final jsonData = StorageService.getBusRouteData();
    if (jsonData == null) {
      _showMessage(
        'Failed to retrieve location data from storage.',
        isError: true,
      );
      return;
    }

    // Phase 3 requires stops from Phase 1 and assignments from Phase 2
    final stops = jsonData['stops'] as List<dynamic>?;
    if (stops == null || stops.isEmpty) {
      _showMessage(
        'Phase 1 must be completed first. Please generate Phase 1 routes.',
        isError: true,
      );
      return;
    }

    final assignments = jsonData['assignments'] as List<dynamic>?;
    if (assignments == null || assignments.isEmpty) {
      _showMessage(
        'Phase 2 must be completed first. Please generate Phase 2 routes.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isGeneratingRoutes = true;
    });

    try {
      // Convert JSON map to string
      final jsonString = jsonEncode(jsonData);
      debugPrint('Calling phase_3 with JSON data...');

      // Call the WASM phase_3 function
      final resultString = await phase_3(jsonString);
      debugPrint('Received result from phase_3');

      // Parse the BRP JSON result (not GeoJSON)
      final brpResult = jsonDecode(resultString) as Map<String, dynamic>;
      debugPrint('Parsed BRP JSON result');
      debugPrint("RAW BRP RESULT:\n$resultString");

      // Extract routes from the BRP JSON (routes are already in the correct format)
      final routes = brpResult['routes'] as List<dynamic>?;
      if (routes == null) {
        _showMessage(
          'No routes found in phase 3 result.',
          isError: true,
        );
        return;
      }
      debugPrint('Extracted ${routes.length} routes from BRP JSON');

      // Merge the result with existing JSON data
      final updatedJsonData = Map<String, dynamic>.from(jsonData);
      updatedJsonData['routes'] = routes;
      
      // Also update other fields if they exist in the result (evals, etc.)
      if (brpResult.containsKey('evals')) {
        updatedJsonData['evals'] = brpResult['evals'];
      }
      
      // Preserve stops and assignments if they exist in the result
      if (brpResult.containsKey('stops')) {
        updatedJsonData['stops'] = brpResult['stops'];
      }
      if (brpResult.containsKey('assignments')) {
        updatedJsonData['assignments'] = brpResult['assignments'];
      }
      
      debugPrint('Updated JSON with routes');

      // Save the updated JSON back to session storage
      await StorageService.saveBusRouteData(updatedJsonData);
      debugPrint('Saved updated JSON to session storage');

      setState(() {
        _mapReloadKey++; // force map to rebuild
      });

      _showMessage('Routes generated successfully!', isError: false);
    } catch (e) {
      debugPrint('Error generating routes: $e');
      _showMessage('Error generating routes: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isGeneratingRoutes = false;
      });
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _onModify() {
    debugPrint("Modify button pressed");
    setState(() {
      _isModified = true;
      _cancelModify = false;
    });
  }

  void _onAddMarker() {
    setState(() => _addMarker++);
  }

  void _onSave() {
    debugPrint("Save button pressed");
    setState(() {
      _saveMarkers = true;
      _isModified = false;
    });
  }

  void _onCancel() {
    debugPrint("Cancel button pressed");

    setState(() {
      _cancelModify = true;
      _isModified = false;
      _saveMarkers = false;
    });
  }
}
