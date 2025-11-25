import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../widgets/maps.dart';
import '../widgets/location_upload_drawer.dart';
import '../WASM/wasm_interop.dart';
import '../services/storage_service.dart';
import '../services/firebase_route_service.dart';
import 'package:collection/collection.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/geocoding_service.dart';


typedef PhaseType = DropdownMenuEntry<Phase>;

enum Phase {
  phaseOne('Create Stops', 1),
  phaseTwo('Assign Buses', 2),
  phaseThree('Create Routes', 3);

  const Phase(this.label, this.phase);
  final String label;
  final int phase;

  static final List<PhaseType> entries = UnmodifiableListView<PhaseType>(
    values.map<PhaseType>(
      (Phase p) => PhaseType(
        value: p,
        label: p.label,
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
  Phase? savedPhase = Phase.phaseOne;
  bool _isModified = false;
  bool _isDrawerOpen = false;
  bool _isGeneratingRoutes = false;
  bool _isDrawerProcessing = false;
  int _addMarker = 0;
  bool _saveMarkers = false;
  bool _cancelModify = false;
  int _mapReloadKey = 0;
  String searchQuery = "";
  GlobalKey<GoogleMapsState> mapStateKey = GlobalKey<GoogleMapsState>();
  List<Map<String, double>> _geocodedSuggestions = [];
  bool _isGeocoding = false;


  
  Completer<void>? _routeGenerationCompleter;


  List<String> _getAddresses() {
    final jsonData = StorageService.getBusRouteData();
    if (jsonData == null) return [];

    final students = jsonData['students'] as List<dynamic>? ?? [];
    final stops = jsonData['stops'] as List<dynamic>? ?? [];

    // Convert students and stops to readable strings
    final studentIds = students.map((s) => "Student ${s['id']}").toList();
    final stopIds = stops.map((s) => "Stop ${s['id']}").toList();

    // Combine both lists
    return [...studentIds, ...stopIds];
}

  /// Returns the coordinates (latitude and longitude) for a given location label.
/// The label can be like "Student 0" or "Stop 1".
/// Returns null if the label is not found or if data is missing.
LatLng? getCoordinatesForLabel(String label) {
  final jsonData = StorageService.getBusRouteData();
  if (jsonData == null) return null;

  final students = jsonData['students'] as List<dynamic>? ?? [];
  final stops = jsonData['stops'] as List<dynamic>? ?? [];

  if (label.startsWith('Student ')) {
    final id = int.tryParse(label.replaceFirst('Student ', ''));
    if (id == null) return null;

    final student = students.firstWhereOrNull((s) => s['id'] == id);
    if (student == null) return null;

    final lat = (student['pos']['lat'] as num?)?.toDouble();
    final lng = (student['pos']['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return LatLng(lat, lng);
  }
  else if (label.startsWith('Stop ')) {
    final id = int.tryParse(label.replaceFirst('Stop ', ''));
    if (id == null) return null;

    final stop = stops.firstWhereOrNull((s) => s['id'] == id);
    if (stop == null) return null;

    final lat = (stop['pos']['lat'] as num?)?.toDouble();
    final lng = (stop['pos']['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return LatLng(lat, lng);
  }
  else{
    GeocodingService.geocodeAddress(label).then((coords) {
  final latLng = coords != null ? LatLng(coords['lat']!, coords['lon']!) : null;

  if (latLng != null) {
    // return
    return latLng;
  }
  return null;
  });
  }

  // Label didn't match Student or Stop
  return null;
}


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      onEndDrawerChanged: (isOpened) {
        // Prevent closing if processing
        if (!isOpened && _isDrawerProcessing) {
          // Re-open the drawer if it was closed while processing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scaffoldKey.currentState?.openEndDrawer();
          });
        } else {
          setState(() {
            _isDrawerOpen = isOpened;
            //update map
            setState(() {
             _mapReloadKey++; // force map to rebuild
             mapStateKey = GlobalKey<GoogleMapsState>();
            });
          });
        }
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

                              //search bar
                              
                              SearchAnchor(
                                key: ValueKey(_mapReloadKey),
                                builder: (context, controller) {
                                  return SearchBar(
                                    hintText: "Search pins...",
                                    onTap: controller.openView,     // open suggestions
                                    onChanged: (_) => controller.openView(),
                                  );
                                },

                                suggestionsBuilder: (context, controller) {
                                  final items = _getAddresses();

                                  // Filter items to match typed text
                                  final filtered = items
                                      .where((item) =>
                                          item.toLowerCase().contains(controller.text.toLowerCase()))
                                      .toList();

                                  // Always add the typed text as a selectable option
                                  final suggestions = <String>[
                                    if (controller.text.isNotEmpty &&
                                        !filtered.contains(controller.text)) 
                                      controller.text,
                                    ...filtered,
                                  ];

                                  return suggestions.map((item) {
                                    return ListTile(
                                      title: Text(item),
                                      onTap: () async {
                                        controller.closeView(item);

                                        LatLng? latLng;

                                        // First, check if it's a saved Student/Stop
                                        latLng = getCoordinatesForLabel(item);

                                        // If not found, fallback to geocoding
                                        if (latLng == null) {
                                          final coords = await GeocodingService.geocodeAddress(item);
                                          if (coords != null) {
                                            latLng = LatLng(coords['lat']!, coords['lon']!);
                                          }
                                        }

                                        if (latLng != null) {
                                          mapStateKey.currentState?.mapController.animateCamera(
                                            CameraUpdate.newLatLngZoom(latLng, 16),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Could not find location: $item')),
                                          );
                                        }
                                      },
                                    );
                                  }).toList();
                                },

                              ),

                              


                            if (!_isModified) ...[
                              _buildSideButton("Add Locations", screenWidth),
                              SizedBox(height: screenHeight * 0.02),
                              _buildSideButton("Generate Routes", screenWidth),
                              SizedBox(height: screenHeight * 0.02),
                              _buildSideButton("Modify", screenWidth),
                              SizedBox(height: screenHeight * 0.02),
                              DropdownMenu<Phase>(
                                width: screenWidth * .15,
                                initialSelection: selectedPhase,
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
                                    if (selectedPhase != Phase.phaseThree) ...[
                                      SizedBox(height: screenHeight * 0.02),
                                      _buildSideButton(
                                        "Add Marker",
                                        screenWidth,
                                      ),
                                      SizedBox(height: screenHeight * 0.02),
                                      _buildSideButton("Save", screenWidth),
                                      SizedBox(height: screenHeight * 0.02),
                                      _buildSideButton("Exit", screenWidth),
                                    ] else ...[
                                      _buildSideButton("Exit", screenWidth),
                                    ],
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
                                child: KeyedSubtree(
                                  key: ValueKey(_mapReloadKey), // ← forces full rebuild when changed
                                  child: GoogleMaps(
                                    key: mapStateKey,             // ← state key for controlling map
                                    isModified: _isModified,
                                    isSaved: _saveMarkers,
                                    cancelModify: _cancelModify,
                                    addMarker: _addMarker,
                                    isGenerating: _isGeneratingRoutes,
                                    interactionEnabled: !_isDrawerOpen,
                                    phaseType: selectedPhase,
                                  ),
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
          // Loading overlay when generating routes - uses independent animation
          if (_isGeneratingRoutes)
            Positioned.fill(
              child: _IndependentLoadingOverlay(
                completer: _routeGenerationCompleter,
              ),
            ),
        ],
      ),
      endDrawer: LocationUploadDrawer(
        onProcessingChanged: (isProcessing) {
          setState(() {
            _isDrawerProcessing = isProcessing;
          });
        },
      ),
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
          } else if (text == "Exit") {
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
    final phase = selectedPhase;
    final phaseNumber = phase?.phase;

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

    // Create completer to track completion
    _routeGenerationCompleter = Completer<void>();

    // Show spinner first
    setState(() {
      _isGeneratingRoutes = true;
    });

    // Ensure UI updates before blocking WASM call
    await Future.microtask(() {});
    await WidgetsBinding.instance.endOfFrame;

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
        _showMessage('No stops found in phase 1 result.', isError: true);
        _routeGenerationCompleter?.complete();
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
        mapStateKey = GlobalKey<GoogleMapsState>();
      });

      _showMessage('Routes generated successfully!', isError: false);

      // Complete the completer to signal spinner can stop
      _routeGenerationCompleter?.complete();
    } catch (e) {
      debugPrint('Error generating routes: $e');

      // Provide user-friendly error messages
      String errorMessage;
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        errorMessage =
            'Route generation timed out. The Overpass API may be experiencing high load. '
            'Please try again in a few minutes.';
      } else if (e.toString().contains('Overpass HTTP') ||
          e.toString().contains('504')) {
        errorMessage =
            'The Overpass API (OpenStreetMap) is currently unavailable or experiencing issues. '
            'This is a temporary problem with the external service. Please try again later.';
      } else if (e.toString().contains('WASM Error')) {
        errorMessage =
            'An error occurred during route generation: ${e.toString().replaceFirst('Exception: WASM Error: ', '')}';
      } else {
        errorMessage = 'Error generating routes: ${e.toString()}';
      }

      _showMessage(errorMessage, isError: true);
      _routeGenerationCompleter?.complete();
    } finally {
      // Wait a moment for the spinner to finish its animation
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _isGeneratingRoutes = false;
        _routeGenerationCompleter = null;
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

    // Create completer to track completion
    _routeGenerationCompleter = Completer<void>();

    // Show spinner first
    setState(() {
      _isGeneratingRoutes = true;
    });

    // Ensure UI updates before blocking WASM call
    await Future.microtask(() {});
    await WidgetsBinding.instance.endOfFrame;

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
        _showMessage('No assignments found in phase 2 result.', isError: true);
        _routeGenerationCompleter?.complete();
        return;
      }
      debugPrint('Extracted ${assignments.length} assignments from BRP JSON');

      // Merge the result with existing JSON data
      final updatedJsonData = Map<String, dynamic>.from(jsonData);
      updatedJsonData['assignments'] = assignments;
      updatedJsonData['students'] = jsonData['students'];

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
        mapStateKey = GlobalKey<GoogleMapsState>();
      });

      _showMessage('Routes generated successfully!', isError: false);

      // Complete the completer to signal spinner can stop
      _routeGenerationCompleter?.complete();
    } catch (e) {
      debugPrint('Error generating routes: $e');

      // Provide user-friendly error messages
      String errorMessage;
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        errorMessage =
            'Route generation timed out. The Overpass API may be experiencing high load. '
            'Please try again in a few minutes.';
      } else if (e.toString().contains('Overpass HTTP') ||
          e.toString().contains('504')) {
        errorMessage =
            'The Overpass API (OpenStreetMap) is currently unavailable or experiencing issues. '
            'This is a temporary problem with the external service. Please try again later.';
      } else if (e.toString().contains('WASM Error')) {
        errorMessage =
            'An error occurred during route generation: ${e.toString().replaceFirst('Exception: WASM Error: ', '')}';
      } else {
        errorMessage = 'Error generating routes: ${e.toString()}';
      }

      _showMessage(errorMessage, isError: true);
      _routeGenerationCompleter?.complete();
    } finally {
      // Wait a moment for the spinner to finish its animation
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _isGeneratingRoutes = false;
        _routeGenerationCompleter = null;
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

    // Create completer to track completion
    _routeGenerationCompleter = Completer<void>();

    // Show spinner first
    setState(() {
      _isGeneratingRoutes = true;
    });

    // Ensure UI updates before blocking WASM call
    await Future.microtask(() {});
    await WidgetsBinding.instance.endOfFrame;

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
        _showMessage('No routes found in phase 3 result.', isError: true);
        _routeGenerationCompleter?.complete();
        return;
      }
      debugPrint('Extracted ${routes.length} routes from BRP JSON');

      // Merge the result with existing JSON data
      final updatedJsonData = Map<String, dynamic>.from(jsonData);
      updatedJsonData['routes'] = routes;
      updatedJsonData['students'] = jsonData['students'];

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

      // Save routes to Firebase Firestore
      try {
        final sessionId = await FirebaseRouteService.saveBusRoutes(
          routes,
          sessionData: updatedJsonData,
        );
        if (sessionId != null) {
          debugPrint('Saved routes to Firestore with session ID: $sessionId');
        } else {
          debugPrint('WARNING: Could not save routes to Firestore (user not authenticated)');
        }
      } catch (e) {
        // Log error but don't fail the route generation
        debugPrint('ERROR: Failed to save routes to Firestore: $e');
        // Optionally show a warning to the user
        _showMessage(
          'Routes generated successfully, but failed to save to cloud storage: ${e.toString()}',
          isError: true,
        );
      }

      setState(() {
        _mapReloadKey++; // force map to rebuild
        mapStateKey = GlobalKey<GoogleMapsState>();
      });

      _showMessage('Routes generated successfully!', isError: false);

      // Complete the completer to signal spinner can stop
      _routeGenerationCompleter?.complete();
    } catch (e) {
      debugPrint('Error generating routes: $e');

      // Provide user-friendly error messages
      String errorMessage;
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        errorMessage =
            'Route generation timed out. The Overpass API may be experiencing high load. '
            'Please try again in a few minutes.';
      } else if (e.toString().contains('Overpass HTTP') ||
          e.toString().contains('504')) {
        errorMessage =
            'The Overpass API (OpenStreetMap) is currently unavailable or experiencing issues. '
            'This is a temporary problem with the external service. Please try again later.';
      } else if (e.toString().contains('WASM Error')) {
        errorMessage =
            'An error occurred during route generation: ${e.toString().replaceFirst('Exception: WASM Error: ', '')}';
      } else {
        errorMessage = 'Error generating routes: ${e.toString()}';
      }

      _showMessage(errorMessage, isError: true);
      _routeGenerationCompleter?.complete();
    } finally {
      // Wait a moment for the spinner to finish its animation
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _isGeneratingRoutes = false;
        _routeGenerationCompleter = null;
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
      savedPhase = selectedPhase;
    });
  }

  void _onAddMarker() {
    setState(() => _addMarker++);
  }

  void _onSave() {
    debugPrint("Save button pressed");
    setState(() {
      savedPhase = selectedPhase;

      _saveMarkers = true;
      _isModified = false;
    });
  }

  void _onCancel() {
    debugPrint("Cancel button pressed");

    setState(() {
      selectedPhase = savedPhase;

      _cancelModify = true;
      _isModified = false;
      _saveMarkers = false;
    });
  }
}

/// A loading overlay widget that uses CSS animations
/// which run on the browser's compositor thread, independent of JavaScript execution.
/// This allows the spinner to continue animating even when WASM blocks the main thread.
class _IndependentLoadingOverlay extends StatefulWidget {
  final Completer<void>? completer;

  const _IndependentLoadingOverlay({required this.completer});

  @override
  State<_IndependentLoadingOverlay> createState() =>
      _IndependentLoadingOverlayState();
}

class _IndependentLoadingOverlayState
    extends State<_IndependentLoadingOverlay> {
  static int _spinnerCounter = 0;
  late String _spinnerId;
  bool _isComplete = false;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _spinnerId = 'css_spinner_${_spinnerCounter++}';
    _createCssSpinner();
    _registerPlatformView();

    // Listen for completion
    widget.completer?.future.then((_) {
      if (mounted) {
        setState(() {
          _isComplete = true;
        });
        _removeCssSpinner();
      }
    });
  }

  void _createCssSpinner() {
    // Inject CSS for the spinner animation
    final style = html.StyleElement()
      ..id = '${_spinnerId}_style'
      ..text =
          '''
        @keyframes ${_spinnerId}_spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        #$_spinnerId {
          animation: ${_spinnerId}_spin 1s linear infinite;
          width: 50px;
          height: 50px;
          border: 4px solid rgba(255, 255, 255, 0.3);
          border-top: 4px solid white;
          border-radius: 50%;
        }
      ''';
    html.document.head!.append(style);
  }

  void _registerPlatformView() {
    if (!_isRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_spinnerId, (int viewId) {
        final div = html.DivElement()
          ..id = _spinnerId
          ..style.width = '50px'
          ..style.height = '50px';
        return div;
      });
      _isRegistered = true;
    }
  }

  void _removeCssSpinner() {
    final styleElement = html.document.getElementById('${_spinnerId}_style');
    styleElement?.remove();
  }

  @override
  void dispose() {
    _removeCssSpinner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: HtmlElementView(viewType: _spinnerId),
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
    );
  }
}
