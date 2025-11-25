import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/route_page.dart';
import 'package:flutter_app/services/storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_custom_marker/google_maps_custom_marker.dart';

enum MarkerType { stop, student }

enum MarkerLabel {
  stop('Bus Stop', Colors.purple),
  student('Student', Colors.red);

  const MarkerLabel(this.label, this.color);
  final String label;
  final Color color;

  static final List<DropdownMenuEntry<MarkerLabel>> entries = MarkerLabel.values
      .map((m) {
        return DropdownMenuEntry<MarkerLabel>(
          value: m,
          label: m.label,
          style: MenuItemButton.styleFrom(foregroundColor: m.color),
        );
      })
      .toList();
}

class GoogleMaps extends StatefulWidget {
  final bool isModified;
  final bool isSaved;
  final bool cancelModify;
  final int addMarker;
  final bool isGenerating;
  final bool interactionEnabled;
  final Phase? phaseType;

  const GoogleMaps({
    super.key,
    required this.isModified,
    required this.isSaved,
    required this.cancelModify,
    required this.addMarker,
    required this.isGenerating,
    this.interactionEnabled = true,
    required this.phaseType,
  });

  @override
  State<GoogleMaps> createState() => _GoogleMapsState();
}

class _GoogleMapsState extends State<GoogleMaps> {
  late GoogleMapController mapController;

  final ClusterManager _myClusterPeople = ClusterManager(
    clusterManagerId: ClusterManagerId('people'),
  );

  final ClusterManager _myClusterStops = ClusterManager(
    clusterManagerId: ClusterManagerId('stops'),
  );

  final Map<String, Marker> _markers = {};
  Set<Polyline> polylines = {};
  Map<int, Color> routeColors = {};
  Map<int, BitmapDescriptor> routeIcons = {};

  List<dynamic> stops = [];
  List<dynamic> students = [];
  List<dynamic> assignments = [];
  List<dynamic> routes = [];

  List<dynamic>? _originalStops;
  List<dynamic>? _originalStudents;

  LatLng? _savedCenter;
  double? _savedZoom;

  int touchedMarkerId = 0;
  String markerType = "";
  bool markerInfo = false;

  late BitmapDescriptor stopIcon;
  late BitmapDescriptor dragIcon;
  late BitmapDescriptor studentIcon;

  MarkerLabel? selectedMarker = MarkerLabel.stop;

  final busController = TextEditingController();
  bool isEditingBus = false;

  late bool isSaved;
  late bool cancelModify;
  late int addMarker;
  late bool isGenerating;
  late Phase? phaseType;

  @override
  void initState() {
    super.initState();
    isSaved = widget.isSaved;
    cancelModify = widget.cancelModify;
    addMarker = widget.addMarker;
    isGenerating = widget.isGenerating;
    phaseType = widget.phaseType;
  }

  Future<void> initIcon() async {
    final base = Marker(
      markerId: const MarkerId('tmp'),
      position: const LatLng(0, 0),
    );

    final stopMarker = await GoogleMapsCustomMarker.createCustomMarker(
      marker: base,
      shape: MarkerShape.pin,
      backgroundColor: const Color.fromARGB(255, 162, 0, 255),
    );

    stopIcon = stopMarker.icon;

    final dragMarker = await GoogleMapsCustomMarker.createCustomMarker(
      marker: base,
      shape: MarkerShape.pin,
      backgroundColor: Colors.blue,
    );

    dragIcon = dragMarker.icon;

    final studentMarker = await GoogleMapsCustomMarker.createCustomMarker(
      marker: base,
      shape: MarkerShape.pin,
    );

    studentIcon = studentMarker.icon;
  }

  void _fitToMarkers() async {
    if (_markers.isEmpty) return;

    final positions = _markers.values.map((m) => m.position).toList();

    double south = positions.first.latitude;
    double north = positions.first.latitude;
    double west = positions.first.longitude;
    double east = positions.first.longitude;

    for (var pos in positions) {
      if (pos.latitude < south) south = pos.latitude;
      if (pos.latitude > north) north = pos.latitude;
      if (pos.longitude < west) west = pos.longitude;
      if (pos.longitude > east) east = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));

    _savedCenter = LatLng((south + north) / 2, (west + east) / 2);

    _savedZoom = await _estimateZoomToFitBounds(bounds);
  }

  Future<double> _estimateZoomToFitBounds(LatLngBounds bounds) async {
    final latDiff = (bounds.northeast.latitude - bounds.southwest.latitude)
        .abs();
    final lonDiff = (bounds.northeast.longitude - bounds.southwest.longitude)
        .abs();

    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff < 0.001) return 18;
    if (maxDiff < 0.01) return 15;
    if (maxDiff < 0.1) return 12;

    return 10;
  }

  int? busForStop(int stopId) {
    for (final a in assignments) {
      if ((a['stops'] as List).contains(stopId)) {
        return a['bus'] as int;
      }
    }
    return null;
  }

  void assignBusToStops() {
    for (final a in assignments) {
      final bus = a['bus'];
      for (final stopId in a['stops']) {
        final stop = stops.firstWhere((s) => s['id'] == stopId);
        stop['bus'] = bus;
      }
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;

    final phase = widget.phaseType;

    await initIcon();

    if (StorageService.hasBusRouteData()) {
      final jsonData = StorageService.getBusRouteData();

      switch (phase) {
        case null:
          throw UnimplementedError();

        case Phase.phaseOne:
          stops = jsonData?['stops'] ?? [];
          students = jsonData?['students'] ?? [];
          buildMarkers(stops, MarkerType.stop);
          buildMarkers(students, MarkerType.student);
          break;

        case Phase.phaseTwo:
          stops = jsonData?['stops'] ?? [];
          assignments = jsonData?['assignments'] ?? [];
          assignBusToStops();
          buildMarkers(stops, MarkerType.stop);
          break;

        case Phase.phaseThree:
          stops = jsonData?['stops'] ?? [];
          assignments = jsonData?['assignments'] ?? [];
          assignBusToStops();
          routes = jsonData?['routes'] ?? [];
          buildMarkers(stops, MarkerType.stop);
          buildPolylines();
          break;
      }
    }
  }

  void buildMarkers(List<dynamic> markers, MarkerType flag) async {
    final newMarkers = <String, Marker>{};

    for (final m in markers) {
      final currentId = m['id'];
      final key = '${flag.name}_$currentId';

      final lat = m['pos']['lat'] as num;
      final lon = m['pos']['lon'] as num;

      newMarkers[key] = Marker(
        onTap: () {
          setState(() {
            markerInfo = true;
            touchedMarkerId = currentId;
            markerType = flag.name;
          });
        },
        clusterManagerId: (flag == MarkerType.stop)
            ? _myClusterStops.clusterManagerId
            : _myClusterPeople.clusterManagerId,
        markerId: MarkerId(key),
        position: LatLng(lat.toDouble(), lon.toDouble()),
        draggable: widget.phaseType != Phase.phaseThree && widget.isModified,
        icon: widget.phaseType == Phase.phaseThree && flag == MarkerType.stop
            ? routeIcons[busForStop(currentId)] ?? stopIcon
            : (flag == MarkerType.stop ? stopIcon : studentIcon),
        onDragStart: widget.phaseType == Phase.phaseThree
            ? null
            : (position) {
                setState(() {
                  _markers[key] = _markers[key]!.copyWith(iconParam: dragIcon);
                });
              },
        onDrag: widget.phaseType == Phase.phaseThree
            ? null
            : (position) {
                setState(() {
                  _markers[key] = _markers[key]!.copyWith(iconParam: dragIcon);
                });
              },
        onDragEnd: widget.phaseType == Phase.phaseThree
            ? null
            : (position) {
                setState(() {
                  _markers[key] = _markers[key]!.copyWith(
                    positionParam: LatLng(
                      position.latitude,
                      position.longitude,
                    ),
                    iconParam: (flag == MarkerType.stop)
                        ? stopIcon
                        : studentIcon,
                  );
                  m['pos']['lat'] = position.latitude;
                  m['pos']['lon'] = position.longitude;
                });
              },
      );
    }

    setState(() {
      _markers.addAll(newMarkers);
    });

    if (_savedCenter == null && _savedZoom == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToMarkers();
      });
    }
  }

  void buildPolylines() {
    Set<Polyline> temp = {};
    int idCounter = 0;

    routeColors.clear();

    for (final r in routes) {
      if (r == null || r['assignment'] == null || r['paths'] == null) {
        print("INVALID ROUTE ENTRY: $r");
        continue;
      }

      final bus = r['assignment'] as int;
      final paths = r['paths'] as List;

      final randColor = Color.fromARGB(
        255,
        Random().nextInt(200),
        Random().nextInt(200),
        Random().nextInt(200),
      );

      routeColors[bus] = randColor;

      for (final p in paths) {
        final points = (p as List)
            .map((p) => LatLng(p['lat'], p['lon']))
            .toList();

        temp.add(
          Polyline(
            polylineId: PolylineId('route_${idCounter++}'),
            width: 7,
            color: randColor,
            points: points,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }
    }

    setState(() {
      polylines = temp;
    });

    _generateRouteIcons().then((_) {
      setState(() {
        _markers.clear();
        buildMarkers(stops, MarkerType.stop);
      });
    });
  }

  Future<void> _generateRouteIcons() async {
    routeIcons.clear();

    final base = Marker(
      markerId: const MarkerId('tmp'),
      position: const LatLng(0, 0),
    );

    for (final entry in routeColors.entries) {
      final bus = entry.key;
      final color = entry.value;

      final marker = await GoogleMapsCustomMarker.createCustomMarker(
        marker: base,
        shape: MarkerShape.pin,
        backgroundColor: color,
      );

      routeIcons[bus] = marker.icon;
    }
  }

  @override
  void didUpdateWidget(covariant GoogleMaps oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start Modify — store originals
    if (!oldWidget.isModified && widget.isModified) {
      _originalStops = stops
          .map(
            (s) => {
              ...s,
              'pos': {'lat': s['pos']['lat'], 'lon': s['pos']['lon']},
            },
          )
          .toList();

      _originalStudents = students
          .map(
            (s) => {
              ...s,
              'pos': {'lat': s['pos']['lat'], 'lon': s['pos']['lon']},
            },
          )
          .toList();
    }

    // Update draggable state of markers
    final updatedMarkers = <String, Marker>{};
    _markers.forEach((key, marker) {
      updatedMarkers[key] = marker.copyWith(
        draggableParam:
            widget.phaseType != Phase.phaseThree && widget.isModified,
      );
    });

    setState(() {
      _markers
        ..clear()
        ..addAll(updatedMarkers);
    });

    // Cancel Modify → revert positions
    if (!oldWidget.cancelModify && widget.cancelModify) {
      if (_originalStops != null && _originalStudents != null) {
        stops = List.from(_originalStops!);
        students = List.from(_originalStudents!);

        setState(() {
          _markers.clear();
          buildMarkers(stops, MarkerType.stop);
          buildMarkers(students, MarkerType.student);
        });
      }
    }

    // Add Marker (Phase 1 + 2 only)
    if (oldWidget.addMarker < widget.addMarker &&
        widget.phaseType != Phase.phaseThree) {
      final center = _savedCenter ?? const LatLng(30.622405, -96.353055);

      final nextId = (stops.isEmpty)
          ? 1
          : (stops.map((s) => s['id'] as int).reduce((a, b) => a > b ? a : b) +
                1);

      final newStop = {
        'id': nextId,
        'pos': {'lat': center.latitude, 'lon': center.longitude},
      };

      setState(() {
        stops.add(newStop);
        buildMarkers(stops, MarkerType.stop);
      });
    }

    // SAVE button pressed
    if (!oldWidget.isSaved && widget.isSaved) {
      final jsonData = StorageService.getBusRouteData();

      final Map<String, dynamic> data = jsonData != null
          ? Map<String, dynamic>.from(jsonData)
          : <String, dynamic>{};

      final phase = widget.phaseType;

      switch (phase) {
        case Phase.phaseOne:
          data['stops'] = stops;
          data['students'] = students;
          data.remove('evals');
          data.remove('assignments');
          data.remove('routes');
          break;

        case Phase.phaseTwo:
          data['stops'] = stops;
          data['assignments'] = assignments;
          data.remove('routes');
          data.remove('evals');
          break;

        case Phase.phaseThree:
          data['stops'] = stops;
          data['assignments'] = assignments;
          data['routes'] = routes;
          break;

        case null:
          break;
      }

      StorageService.saveBusRouteData(data);

      buildMarkers(stops, MarkerType.stop);
      buildMarkers(students, MarkerType.student);
    }

    // PHASE CHANGE (Phase1 → Phase2 → Phase3)
    if (oldWidget.phaseType != widget.phaseType) {
      final oldPhase = oldWidget.phaseType;
      final newPhase = widget.phaseType;

      final jsonData = StorageService.getBusRouteData();

      final Map<String, dynamic> data = jsonData != null
          ? Map<String, dynamic>.from(jsonData)
          : <String, dynamic>{};

      // save data of OLD phase
      switch (oldPhase) {
        case Phase.phaseOne:
          data['stops'] = stops;
          data['students'] = students;
          data.remove('evals');
          data.remove('assignments');
          data.remove('routes');
          break;

        case Phase.phaseTwo:
          data['stops'] = stops;
          data['assignments'] = assignments;
          data.remove('evals');
          data.remove('routes');
          break;

        case Phase.phaseThree:
          data['stops'] = stops;
          data['assignments'] = assignments;
          data['routes'] = routes;
          break;

        case null:
          break;
      }

      StorageService.saveBusRouteData(data);

      // load NEW phase
      final refreshed = StorageService.getBusRouteData();
      stops = refreshed?['stops'] ?? [];
      students = refreshed?['students'] ?? [];
      assignments = refreshed?['assignments'] ?? [];
      routes = refreshed?['routes'] ?? [];

      _markers.clear();

      // Phase 1 setup
      if (newPhase == Phase.phaseOne) {
        assignments = [];
        routes = [];

        final cleaned = {'stops': stops, 'students': students};
        StorageService.saveBusRouteData(cleaned);

        buildMarkers(stops, MarkerType.stop);
        buildMarkers(students, MarkerType.student);
      }
      // Phase 2 setup
      else if (newPhase == Phase.phaseTwo) {
        buildMarkers(stops, MarkerType.stop);
      }
      // Phase 3 setup
      else if (newPhase == Phase.phaseThree) {
        buildMarkers(stops, MarkerType.stop);
        buildPolylines();
      }
    }

    // Phase 3 → force not draggable + reset editing
    if (widget.phaseType == Phase.phaseThree) {
      setState(() {
        isEditingBus = false;
        markerInfo = false;
      });

      final updated = <String, Marker>{};
      _markers.forEach((key, marker) {
        updated[key] = marker.copyWith(draggableParam: false);
      });

      _markers
        ..clear()
        ..addAll(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final markerNumber = touchedMarkerId + 1;

    int busAssignment = 0;
    if (markerInfo) {
      for (final a in assignments) {
        if (a['stops'].contains(touchedMarkerId)) {
          busAssignment = a['bus'] + 1;
        }
      }
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _savedCenter ?? const LatLng(30.622405, -96.353055),
            zoom: _savedZoom ?? 15,
          ),
          markers: _markers.values.toSet(),
          clusterManagers: {_myClusterStops, _myClusterPeople},
          polylines: polylines,
          onCameraMove: (position) {
            _savedCenter = position.target;
            _savedZoom = position.zoom;
            setState(() {
              markerInfo = false;
            });
          },
          scrollGesturesEnabled: widget.interactionEnabled,
          zoomGesturesEnabled: widget.interactionEnabled,
          tiltGesturesEnabled: widget.interactionEnabled,
          rotateGesturesEnabled: widget.interactionEnabled,
          zoomControlsEnabled: widget.interactionEnabled,
          myLocationButtonEnabled: widget.interactionEnabled,
          mapToolbarEnabled: widget.interactionEnabled,
        ),

        // Overlay tap-to-close
        if (markerInfo)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => markerInfo = false);
              },
            ),
          ),

        // Sidebar (Phase 2 + 3 only)
        if (markerInfo &&
            widget.isModified &&
            (widget.phaseType == Phase.phaseTwo ||
                widget.phaseType == Phase.phaseThree))
          Positioned(
            left: 0,
            width: screenWidth * 0.16,
            height: screenHeight,
            child: Container(
              decoration: const BoxDecoration(color: Colors.white),
              padding: EdgeInsets.symmetric(
                vertical: screenHeight * .05,
                horizontal: screenWidth * .02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      (markerType == 'stop')
                          ? 'Stop $markerNumber'
                          : 'Student $markerNumber',
                      style: GoogleFonts.quicksand(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromRGBO(57, 103, 136, 1),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Type selector + delete (Phase 1 only)
                  if (phaseType != Phase.phaseThree)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.phaseType == Phase.phaseOne)
                          DropdownMenu<MarkerLabel>(
                            width: screenWidth * .08,
                            initialSelection: (markerType == "stop")
                                ? MarkerLabel.stop
                                : MarkerLabel.student,
                            requestFocusOnTap: false,
                            onSelected: widget.phaseType == Phase.phaseThree
                                ? null
                                : (MarkerLabel? m) {
                                    setState(() {
                                      selectedMarker = m;
                                      if (selectedMarker?.label == 'Bus Stop') {
                                        _markers['${markerType}_$touchedMarkerId'] =
                                            _markers['${markerType}_$touchedMarkerId']!
                                                .copyWith(iconParam: stopIcon);
                                      }
                                      if (selectedMarker?.label == 'Student') {
                                        _markers['${markerType}_$touchedMarkerId'] =
                                            _markers['${markerType}_$touchedMarkerId']!
                                                .copyWith(
                                                  iconParam: studentIcon,
                                                );
                                      }
                                    });
                                  },
                            dropdownMenuEntries: MarkerLabel.entries,
                            inputDecorationTheme: InputDecorationTheme(
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                        IconButton(
                          onPressed: () {
                            setState(() {
                              stops.removeWhere(
                                (stop) => stop['id'] == touchedMarkerId,
                              );
                              students.removeWhere(
                                (student) => student['id'] == touchedMarkerId,
                              );

                              _markers.remove('${markerType}_$touchedMarkerId');

                              buildMarkers(stops, MarkerType.stop);
                              buildMarkers(students, MarkerType.student);

                              markerInfo = false;
                            });
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),

                  SizedBox(height: screenHeight * 0.02),

                  // Bus assignment display + edit field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isEditingBus)
                        Text(
                          'Bus $busAssignment',
                          style: GoogleFonts.quicksand(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromRGBO(57, 103, 136, 1),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Text(
                              'Bus',
                              style: GoogleFonts.quicksand(
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                                color: const Color.fromRGBO(57, 103, 136, 1),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            SizedBox(
                              width: screenWidth * 0.03,
                              child: TextField(
                                controller: busController,
                                style: GoogleFonts.quicksand(
                                  fontSize: 20,
                                  color: const Color.fromRGBO(57, 103, 136, 1),
                                ),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  Center(
                    child: Text(
                      'Bus Route Order',
                      style: GoogleFonts.quicksand(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromRGBO(57, 103, 136, 1),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Phase 3 route list
                  if (phaseType == Phase.phaseThree &&
                      busAssignment > 0 &&
                      busAssignment - 1 < assignments.length)
                    Center(
                      child: Container(
                        height: screenHeight * 0.2,
                        width: screenWidth * 0.4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView(
                            scrollDirection: Axis.vertical,
                            children: [
                              for (final stopId in List<int>.from(
                                assignments[busAssignment - 1]['stops'] ?? [],
                              ))
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      alignment: Alignment.center,
                                      width: screenWidth * .1,
                                      height: screenHeight * .05,
                                      margin: EdgeInsets.symmetric(
                                        vertical: screenHeight * .001,
                                      ),
                                      color: const Color.fromRGBO(
                                        57,
                                        103,
                                        136,
                                        1,
                                      ),
                                      child: Text(
                                        "Stop $stopId",
                                        style: GoogleFonts.quicksand(
                                          fontSize: 25,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: screenHeight * 0.02),

                  // Phase 2 bus editing
                  if (widget.phaseType == Phase.phaseTwo)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isEditingBus)
                          TextButton(
                            style: ButtonStyle(
                              backgroundColor:
                                  const WidgetStatePropertyAll<Color>(
                                    Color.fromARGB(117, 255, 255, 255),
                                  ),
                            ),
                            onPressed: () {
                              setState(() {
                                isEditingBus = true;
                              });
                            },
                            child: Text(
                              "Edit",
                              style: GoogleFonts.quicksand(
                                fontSize: 25,
                                color: const Color.fromRGBO(57, 103, 136, 1),
                              ),
                            ),
                          ),

                        if (isEditingBus)
                          TextButton(
                            style: ButtonStyle(
                              backgroundColor:
                                  const WidgetStatePropertyAll<Color>(
                                    Color.fromARGB(117, 255, 255, 255),
                                  ),
                            ),
                            onPressed: () {
                              final busNum =
                                  int.tryParse(busController.text) ?? 0;

                              if (busNum < 1 || busNum > assignments.length) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Center(
                                      child: Text(
                                        "Error: Bus number does not exist",
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              final targetIndex = busNum - 1;

                              // remove from old assignment
                              int? currentIndex;
                              for (var i = 0; i < assignments.length; i++) {
                                final stopsList = List<int>.from(
                                  assignments[i]['stops'] ?? [],
                                );
                                if (stopsList.contains(touchedMarkerId)) {
                                  currentIndex = i;
                                  stopsList.remove(touchedMarkerId);
                                  assignments[i]['stops'] = stopsList;
                                  break;
                                }
                              }

                              if (currentIndex == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Center(
                                      child: Text(
                                        "Error: Stop was not assigned to any bus",
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              // add to new bus
                              final targetStops = List<int>.from(
                                assignments[targetIndex]['stops'] ?? [],
                              );
                              if (!targetStops.contains(touchedMarkerId)) {
                                targetStops.add(touchedMarkerId);
                                assignments[targetIndex]['stops'] = targetStops;
                              }

                              // update underlying model
                              final stop = stops.firstWhere(
                                (s) => s['id'] == touchedMarkerId,
                                orElse: () => null,
                              );
                              if (stop == null) return;

                              stop['bus'] = targetIndex;

                              for (final stuId in stop['students']) {
                                final stu = students.firstWhere(
                                  (s) => s['id'] == stuId,
                                );
                                stu['bus'] = targetIndex;
                              }

                              setState(() {
                                isEditingBus = false;
                              });
                            },
                            child: Text(
                              "Save",
                              style: GoogleFonts.quicksand(
                                fontSize: 25,
                                color: const Color.fromRGBO(57, 103, 136, 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

typedef GoogleMapsState = _GoogleMapsState;
