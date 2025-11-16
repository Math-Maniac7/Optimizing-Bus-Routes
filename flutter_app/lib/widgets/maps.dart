import 'dart:collection';
import 'package:flutter/material.dart';
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
  bool isSaved;
  bool cancelModify;
  int addMarker;
  final bool interactionEnabled;

  GoogleMaps({
    super.key,
    required this.isModified,
    required this.isSaved,
    required this.cancelModify,
    required this.addMarker,
    this.interactionEnabled = true,
  });

  @override
  State<GoogleMaps> createState() => _GoogleMapsState();
}

class _GoogleMapsState extends State<GoogleMaps> {
  late GoogleMapController
  mapController; //controller that connects movements made on map
  final Map<String, Marker> _markers = {};
  List<dynamic> stops = [];
  List<dynamic> students = [];
  List<dynamic>? _originalStops;
  List<dynamic>? _originalStudents;
  LatLng? _savedCenter;
  double? _savedZoom;
  int id = 0;
  int touchedMarkerId = 0;
  String markerType = "";
  bool markerInfo = false;
  late BitmapDescriptor stopIcon;
  late BitmapDescriptor dragIcon;
  late BitmapDescriptor studentIcon;
  MarkerLabel? selectedMarker = MarkerLabel.stop;

  Future<void> initIcons() async {
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

  //centers the camera on the marker map majority
  void _fitToMarkers() async {
    if (_markers.isEmpty) return;

    // Build the bounds that include all marker positions
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

    // Animate camera to fit bounds
    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // 50 = padding
    );

    _savedCenter = LatLng((south + north) / 2, (west + east) / 2);
    _savedZoom = await _estimateZoomToFitBounds(bounds);
  }

  //how the bounding box for the camera is created
  Future<double> _estimateZoomToFitBounds(LatLngBounds bounds) async {
    // Approximation: zoom out based on lat/long difference
    final latDiff = (bounds.northeast.latitude - bounds.southwest.latitude)
        .abs();
    final lonDiff = (bounds.northeast.longitude - bounds.southwest.longitude)
        .abs();
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff < 0.001) return 18;
    if (maxDiff < 0.01) return 15;
    if (maxDiff < 0.1) return 12;
    return 10; // Fallback
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    //creates the bitmapmarkers that creates our custom colors for markers
    await initIcons();
    if (StorageService.hasBusRouteData()) {
      final jsonData = StorageService.getBusRouteData();
      if (jsonData != null && jsonData['stops'] != null) {
        stops = jsonData['stops'];
        buildMarkers(stops, MarkerType.stop);
      }
      if (jsonData != null && jsonData['students'] != null) {
        students = jsonData['students'];
        buildMarkers(students, MarkerType.student);
      }
    }
  }

  //Creation of markers with their parameters
  void buildMarkers(List<dynamic> markers, MarkerType flag) async {
    final newMarkers = <String, Marker>{};
    id = 0;
    for (final m in markers) {
      if (!m.containsKey('id')) {
        id += 1;
        m['id'] = id;
      }
      final currentId = m['id'] as int;
      if (currentId > id) id = currentId;
      final key = '${flag.name}_$currentId';
      final lat = m['pos']['lat'] as num;
      final lon = m['pos']['lon'] as num;

      newMarkers[key] = Marker(
        onTap: () {
          if (widget.isModified) {
            setState(() {
              markerInfo = true;
              touchedMarkerId = currentId;
              markerType = flag.name;
            });
          }
        },
        markerId: MarkerId(key),
        position: LatLng(lat.toDouble(), lon.toDouble()),
        draggable: widget.isModified,
        icon: (flag == MarkerType.stop) ? stopIcon : studentIcon,
        //movement features
        onDragStart: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(iconParam: dragIcon);
          });
        },
        onDrag: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(iconParam: dragIcon);
          });
        },
        onDragEnd: (position) {
          setState(() {
            _markers[key] = _markers[key]!.copyWith(
              positionParam: LatLng(position.latitude, position.longitude),
              iconParam: (flag == MarkerType.stop) ? stopIcon : studentIcon,
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
        _fitToMarkers(); // First time only
      });
    }
  }

  //didUpdateWidget is the dynamic way at noticing when one of the widgets from parent has changed
  //Based on changes is what determines the modify, save, and cancel button clicks from routes page
  @override
  void didUpdateWidget(covariant GoogleMaps oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.addMarker < widget.addMarker) {
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

    if (!oldWidget.isSaved && widget.isSaved) {
      final jsonData = StorageService.getBusRouteData();
      final data = jsonData != null
          ? Map<String, dynamic>.from(jsonData)
          : <String, dynamic>{};
      data['stops'] = stops;
      data['students'] = students;
      StorageService.saveBusRouteData(data);
      buildMarkers(stops, MarkerType.stop);
      buildMarkers(students, MarkerType.student);
    }

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

    final updatedMarkers = <String, Marker>{};
    _markers.forEach((key, marker) {
      updatedMarkers[key] = marker.copyWith(draggableParam: widget.isModified);
    });

    setState(() {
      _markers
        ..clear()
        ..addAll(updatedMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _savedCenter ?? const LatLng(30.622405, -96.353055),
            zoom: _savedZoom ?? 15,
          ),
          markers: _markers.values.toSet(),
          onCameraMove: (position) {
            _savedCenter = position.target;
            _savedZoom = position.zoom;
            setState(() {
              markerInfo = false;
            });
          },
          scrollGesturesEnabled: !markerInfo
              ? widget.interactionEnabled
              : false,
          zoomGesturesEnabled: !markerInfo ? widget.interactionEnabled : false,
          tiltGesturesEnabled: !markerInfo ? widget.interactionEnabled : false,
          rotateGesturesEnabled: !markerInfo
              ? widget.interactionEnabled
              : false,
          zoomControlsEnabled: !markerInfo ? widget.interactionEnabled : false,
          myLocationButtonEnabled: !markerInfo
              ? widget.interactionEnabled
              : false,
          mapToolbarEnabled: !markerInfo ? widget.interactionEnabled : false,
          onTap: widget.interactionEnabled ? null : (_) {},
        ),
        if (markerInfo)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => markerInfo = false);
              },
            ),
          ),
        if (markerInfo && widget.isModified)
          Positioned(
            left: 0,

            width: screenWidth * 0.16,
            height: screenHeight * 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.white),
                  padding: EdgeInsets.symmetric(
                    vertical: screenHeight * .05,
                    horizontal: screenWidth * .02,
                  ),
                  height: screenHeight * 1,
                  width: screenWidth * .16,
                  child: AbsorbPointer(
                    absorbing: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            '$markerType $touchedMarkerId',
                            style: GoogleFonts.quicksand(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 48, 56, 149),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DropdownMenu<MarkerLabel>(
                              width: screenWidth * .08,
                              initialSelection: (markerType == "stop") ? MarkerLabel.stop : MarkerLabel.student,
                              requestFocusOnTap: false,
                              onSelected: (MarkerLabel? m) {
                                setState(() {
                                  selectedMarker = m;
                                  if(selectedMarker?.label == 'Bus Stop'){
                                    _markers['${markerType}_$touchedMarkerId'] = _markers['${markerType}_$touchedMarkerId']!.copyWith(iconParam: stopIcon);
                                  } 
                                  if(selectedMarker?.label == 'Student'){
                                    _markers['${markerType}_$touchedMarkerId'] = _markers['${markerType}_$touchedMarkerId']!.copyWith(iconParam: studentIcon);
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
                                  stops.removeWhere((stop) {
                                    return stop['id'] == touchedMarkerId;
                                  });

                                  students.removeWhere((student) {
                                    return student['id'] == touchedMarkerId;
                                  });

                                  _markers.remove(
                                    '${markerType}_$touchedMarkerId',
                                  );
                                  buildMarkers(stops, MarkerType.stop);
                                  buildMarkers(students, MarkerType.student);

                                  markerInfo = false;
                                });
                              },
                              icon: Icon(Icons.delete),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
