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
      position: LatLng(0, 0),
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

  //centers the camera on the marker map majority, chat made this
  void _fitToMarkers() async {
    if (_markers.isEmpty) return;

    LatLngBounds bounds;
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

    bounds = LatLngBounds(
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
          buildMarkers(stops, MarkerType.stop);
          break;

        case Phase.phaseThree:
          stops = jsonData?['stops'] ?? [];
          assignments = jsonData?['assignments'] ?? [];
          routes = jsonData?['routes'] ?? [];
          buildMarkers(stops, MarkerType.stop);
          buildPolylines();
          break;
      }
    }
  }

  //Creation of markers with their parameters
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
        draggable:
            widget.phaseType != Phase.phaseThree &&
            widget.isModified, // Phase 3 = not draggable
        icon: (flag == MarkerType.stop) ? stopIcon : studentIcon,
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

    for (final r in routes) {
      final paths = r['paths'];
      final randColor = Color.fromARGB(
        255,
        Random().nextInt(200),
        Random().nextInt(200),
        Random().nextInt(200),
      );

      for (final p in paths) {
        final points = (p as List)
            .map((p) => LatLng(p['lat'], p['lon']))
            .toList();

        temp.add(
          Polyline(
            polylineId: PolylineId('route_${idCounter++}'),
            width: 5,
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
  }

  //didUpdateWidget is the dynamic way at noticing when one of the widgets from parent has changed
  @override
  void didUpdateWidget(covariant GoogleMaps oldWidget) {
    super.didUpdateWidget(oldWidget);

    //Modify, you save the current stops to revert if you do not save
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

    //when modify is clicked you can update the markers to moveable
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

    //When cancel reset to original marker positions
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

    //Add Marker — disabled in Phase 3
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

    //Saved button
    if (!oldWidget.isSaved && widget.isSaved) {
      final jsonData = StorageService.getBusRouteData();
      final Map<String, dynamic> data = jsonData != null
          ? Map<String, dynamic>.from(jsonData)
          : <String, dynamic>{};

      final phase = widget.phaseType;

      switch (phase) {
        case null:
          throw UnimplementedError();

        case Phase.phaseOne:
          data['stops'] = stops;
          data['students'] = students;
          data.remove('routes');
          StorageService.saveBusRouteData(data);
          buildMarkers(stops, MarkerType.stop);
          buildMarkers(students, MarkerType.student);
          break;

        case Phase.phaseTwo:
          data['stops'] = stops;
          data['assignments'] = assignments;
          data.remove('routes');
          StorageService.saveBusRouteData(data);
          buildMarkers(stops, MarkerType.stop);
          break;

        case Phase.phaseThree:
          buildMarkers(stops, MarkerType.stop);
          buildPolylines();
          break;
      }
    }

    //what happens when the phase changes in the dropdown
    if (oldWidget.phaseType != widget.phaseType) {
      final oldPhase = oldWidget.phaseType;
      final newPhase = widget.phaseType;

      final jsonData = StorageService.getBusRouteData();
      final Map<String, dynamic> data = jsonData != null
          ? Map<String, dynamic>.from(jsonData)
          : <String, dynamic>{};

      switch (oldPhase) {
        case null:
          throw UnimplementedError();

        case Phase.phaseOne:
          data['stops'] = stops;
          data['students'] = students;
          data.remove('routes');
          StorageService.saveBusRouteData(data);
          break;

        case Phase.phaseTwo:
          data['stops'] = stops;
          data['assignments'] = assignments;
          data.remove('routes');
          StorageService.saveBusRouteData(data);
          break;

        case Phase.phaseThree:
          
          break;
      }

      final refreshed = StorageService.getBusRouteData();
      stops = refreshed?['stops'] ?? [];
      students = refreshed?['students'] ?? [];
      assignments = refreshed?['assignments'] ?? [];
      routes = refreshed?['routes'] ?? [];

      _markers.clear();

      switch (newPhase) {
        case null:
          throw UnimplementedError();

        case Phase.phaseOne:
          if (widget.isGenerating) {
            buildMarkers(stops, MarkerType.stop);
            buildMarkers(students, MarkerType.student);
          }
          break;

        case Phase.phaseTwo:
          if (widget.isGenerating) {
            buildMarkers(stops, MarkerType.stop);
          }
          break;

        case Phase.phaseThree:
          if (widget.isGenerating) {
            buildMarkers(stops, MarkerType.stop);
            buildPolylines();
          }
          break;
      }

      // When entering Phase 3 → force read-only mode
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

        // Overlay to close sidebar on tap
        if (markerInfo)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => markerInfo = false);
              },
            ),
          ),

        // Sidebar
        if (markerInfo)
          Positioned(
            left: 0,
            width: screenWidth * 0.16,
            height: screenHeight,
            child: Container(
              decoration: BoxDecoration(color: Colors.white),
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
                        color: const Color.fromARGB(255, 48, 56, 149),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  if (phaseType != Phase.phaseThree)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownMenu<MarkerLabel>(
                          width: screenWidth * .08,
                          initialSelection: (markerType == "stop")
                              ? MarkerLabel.stop
                              : MarkerLabel.student,
                          requestFocusOnTap: false,
                          onSelected: widget.phaseType == Phase.phaseThree
                              ? null // disable in phase 3
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
                                              .copyWith(iconParam: studentIcon);
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

                        // Delete disabled in Phase 3
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
                          icon: Icon(Icons.delete),
                        ),
                      ],
                    ),

                  SizedBox(height: screenHeight * 0.02),

                  // Bus assignment display only
                  Center(
                    child: Text(
                      'Bus $busAssignment',
                      style: GoogleFonts.quicksand(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromARGB(255, 48, 56, 149),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Edit button disabled in Phase 3
                  if (!isEditingBus && widget.phaseType != Phase.phaseThree)
                    TextButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll<Color>(
                          Color.fromARGB(117, 255, 255, 255),
                        ),
                        padding: WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(
                            horizontal: screenWidth * .01,
                            vertical: screenHeight * .01,
                          ),
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

                  // Save button disabled in Phase 3
                  if (isEditingBus && widget.phaseType != Phase.phaseThree)
                    TextButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll<Color>(
                          Color.fromARGB(117, 255, 255, 255),
                        ),
                        padding: WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(
                            horizontal: screenWidth * .01,
                            vertical: screenHeight * .01,
                          ),
                        ),
                      ),
                      onPressed: () {
                        final busNumber = int.tryParse(busController.text) ?? 0;

                        if (busNumber < 1 || busNumber > assignments.length) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Center(
                                child: Text('Error: Bus number does not exist'),
                              ),
                            ),
                          );
                          return;
                        }

                        for (final a in assignments) {
                          if (a['stops'].contains(touchedMarkerId)) {
                            a['bus'] = busNumber - 1;
                          }
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
            ),
          ),
      ],
    );
  }
}

typedef GoogleMapsState = _GoogleMapsState;
