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
  Map<int, Color> busColors = {};
  Map<int, BitmapDescriptor> busIcons = {};
  static const String _busColorsKey = 'busColors';

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
  int? selectedBusOption;

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

  Color? _colorForStop(int stopId) {
    final busId = busForStop(stopId);
    if (busId == null) return null;
    return busColors[busId];
  }

  int? _busForStudent(int studentId) {
    final stopId = _stopForStudent(studentId);
    if (stopId == null) return null;
    return busForStop(stopId);
  }

  BitmapDescriptor _studentIconForId(int studentId) {
    final stopId = _stopForStudent(studentId);
    if (stopId != null) {
      final busId = busForStop(stopId);
      if (busId != null) {
        return routeIcons[busId] ?? busIcons[busId] ?? studentIcon;
      }
    }
    return studentIcon;
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

  int _nextMarkerId() {
    final ids = <int>[
      ...stops.map((s) => s['id'] as int),
      ...students.map((s) => s['id'] as int),
    ];
    if (ids.isEmpty) return 0;
    return ids.reduce((a, b) => a > b ? a : b) + 1;
  }

  double _haversine(LatLng a, LatLng b) {
    const double earthRadiusMeters = 6371000.0;
    double toRad(double deg) => deg * pi / 180.0;

    final dLat = toRad(b.latitude - a.latitude);
    final dLon = toRad(b.longitude - a.longitude);
    final lat1 = toRad(a.latitude);
    final lat2 = toRad(b.latitude);

    final h =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return earthRadiusMeters * c;
  }

  void _assignStudentToNearestStop(int studentId, LatLng studentPos) {
    if (stops.isEmpty) return;

    int? nearestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final stopLat = (stop['pos']?['lat'] as num?)?.toDouble();
      final stopLon = (stop['pos']?['lon'] as num?)?.toDouble();
      if (stopLat == null || stopLon == null) continue;

      final dist = _haversine(studentPos, LatLng(stopLat, stopLon));
      if (dist < bestDist) {
        bestDist = dist;
        nearestIdx = i;
      }
    }

    if (nearestIdx == null) return;

    final stop = stops[nearestIdx];
    final stopStudents = List<int>.from((stop['students'] as List?) ?? []);
    if (!stopStudents.contains(studentId)) {
      stopStudents.add(studentId);
      stop['students'] = stopStudents;
    }

    final student = students.firstWhere(
      (s) => s['id'] == studentId,
      orElse: () => null,
    );
    if (student != null) {
      if (stop['bus'] != null) {
        student['bus'] = stop['bus'];
      } else {
        student.remove('bus');
      }
    }
  }

  int? _stopForStudent(int studentId) {
    for (final stop in stops) {
      final stopStudents = stop['students'] as List?;
      if (stopStudents != null && stopStudents.contains(studentId)) {
        return stop['id'] as int;
      }
    }
    return null;
  }

  void _removeStudentFromStops(int studentId) {
    for (final stop in stops) {
      final stopStudents = List<int>.from((stop['students'] as List?) ?? []);
      if (stopStudents.remove(studentId)) {
        stop['students'] = stopStudents;
      }
    }
  }

  void _reassignStudentToNearestStop(int studentId, LatLng studentPos) {
    if (stops.isEmpty) {
      final student = students.firstWhere(
        (s) => s['id'] == studentId,
        orElse: () => null,
      );
      student?.remove('bus');
      return;
    }

    final student = students.firstWhere(
      (s) => s['id'] == studentId,
      orElse: () => null,
    );
    student?.remove('bus');

    _removeStudentFromStops(studentId);
    _assignStudentToNearestStop(studentId, studentPos);
  }

  void _assignStudentToStopById(int studentId, int stopId) {
    final stop = stops.firstWhere((s) => s['id'] == stopId, orElse: () => null);
    if (stop == null) return;

    _removeStudentFromStops(studentId);

    final stopStudents = List<int>.from((stop['students'] as List?) ?? []);
    if (!stopStudents.contains(studentId)) {
      stopStudents.add(studentId);
      stop['students'] = stopStudents;
    }

    final student = students.firstWhere(
      (s) => s['id'] == studentId,
      orElse: () => null,
    );
    if (student != null) {
      if (stop['bus'] != null) {
        student['bus'] = stop['bus'];
      } else {
        student.remove('bus');
      }
    }
  }

  LatLng? _stopPosition(Map<String, dynamic> stop) {
    final lat = (stop['pos']?['lat'] as num?)?.toDouble();
    final lon = (stop['pos']?['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  void _assignStopToBus(int stopId, LatLng stopPos) {
    if (assignments.isEmpty) return;

    // Pick the bus for the geographically closest already-assigned stop.
    int? nearestBus;
    double best = double.infinity;
    for (final s in stops) {
      final sid = s['id'] as int;
      final bus = busForStop(sid);
      if (bus == null) continue;
      final pos = _stopPosition(s);
      if (pos == null) continue;
      final d = _haversine(stopPos, pos);
      if (d < best) {
        best = d;
        nearestBus = bus;
      }
    }

    // If nothing was found, fall back to the first assignment's bus.
    nearestBus ??= (assignments.first['bus'] as int?);
    if (nearestBus == null) return;

    // Append the stop to that bus's assignment list.
    for (final a in assignments) {
      if (a['bus'] == nearestBus) {
        final list = List<int>.from(a['stops'] ?? []);
        if (!list.contains(stopId)) {
          list.add(stopId);
          a['stops'] = list;
        }
        break;
      }
    }

    // Mark the stop with the bus id for icon coloring.
    final stop = stops.firstWhere((s) => s['id'] == stopId, orElse: () => null);
    if (stop != null) {
      stop['bus'] = nearestBus;
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;

    final phase = widget.phaseType;

    await initIcon();

    if (StorageService.hasBusRouteData()) {
      final jsonData = StorageService.getBusRouteData();
      _loadBusColors(jsonData);

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
          students = jsonData?['students'] ?? [];
          assignments = jsonData?['assignments'] ?? [];
          _assignBusColors();
          await _generateBusIcons();
          assignBusToStops();
          buildMarkers(stops, MarkerType.stop);
          break;

        case Phase.phaseThree:
          stops = jsonData?['stops'] ?? [];
          students = jsonData?['students'] ?? [];
          assignments = jsonData?['assignments'] ?? [];
          _assignBusColors();
          await _generateBusIcons();
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
        icon: () {
          if (flag == MarkerType.stop) {
            final busId = busForStop(currentId);
            if (busId != null) {
              return routeIcons[busId] ?? busIcons[busId] ?? stopIcon;
            }
            return stopIcon;
          }
          return _studentIconForId(currentId);
        }(),
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
                        : _studentIconForId(currentId),
                  );
                  m['pos']['lat'] = position.latitude;
                  m['pos']['lon'] = position.longitude;
                  if (flag == MarkerType.student) {
                    _reassignStudentToNearestStop(currentId, position);
                  }
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
    _assignBusColors();
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

      final randColor =
          busColors[bus] ??
          Color.fromARGB(
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
        buildMarkers(students, MarkerType.student);
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

  void _assignBusColors() {
    busColors.clear();
    final busIds =
        assignments
            .map((a) => a['bus'])
            .where((id) => id != null)
            .cast<int>()
            .toSet()
            .toList()
          ..sort();

    for (var i = 0; i < busIds.length; i++) {
      final hue = (i * 137) % 360; // golden angle step for distinct hues
      final color = HSLColor.fromAHSL(
        1.0,
        hue.toDouble(),
        0.65,
        0.55,
      ).toColor();
      busColors[busIds[i]] = color;
    }
  }

  void _loadBusColors(Map<String, dynamic>? data) {
    busColors.clear();
    if (data == null) return;
    final stored = data[_busColorsKey];
    if (stored is Map) {
      for (final entry in stored.entries) {
        final key = int.tryParse(entry.key.toString());
        final val = entry.value is int
            ? entry.value as int
            : int.tryParse(entry.value.toString() ?? '');
        if (key != null && val != null) {
          busColors[key] = Color(val);
        }
      }
    }
  }

  Map<String, int> _busColorsToMap() {
    return busColors.map((k, v) => MapEntry(k.toString(), v.value));
  }

  Future<void> _generateBusIcons() async {
    busIcons.clear();

    final base = Marker(
      markerId: const MarkerId('tmp'),
      position: const LatLng(0, 0),
    );

    for (final entry in busColors.entries) {
      final color = entry.value;

      final marker = await GoogleMapsCustomMarker.createCustomMarker(
        marker: base,
        shape: MarkerShape.pin,
        backgroundColor: color,
      );

      busIcons[entry.key] = marker.icon;
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

      final nextId = _nextMarkerId();
      final asStudent = selectedMarker == MarkerLabel.student;
      final newMarker = {
        'id': nextId,
        'pos': {'lat': center.latitude, 'lon': center.longitude},
        if (!asStudent) 'students': <int>[],
      };

      setState(() {
        if (asStudent) {
          students.add(newMarker);
          _assignStudentToNearestStop(nextId, center);
        } else {
          stops.add(newMarker);
          if (widget.phaseType == Phase.phaseTwo) {
            _assignStopToBus(nextId, center);
          }
        }
        buildMarkers(stops, MarkerType.stop);
        buildMarkers(students, MarkerType.student);
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
          data['students'] = students;
          data['assignments'] = assignments;
          data.remove('routes');
          data.remove('evals');
          data[_busColorsKey] = _busColorsToMap();
          break;

        case Phase.phaseThree:
          data['stops'] = stops;
          data['students'] = students;
          data['assignments'] = assignments;
          data['routes'] = routes;
          data[_busColorsKey] = _busColorsToMap();
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
          data.remove(_busColorsKey);
          break;

        case Phase.phaseTwo:
          data['stops'] = stops;
          data['students'] = students;
          data['assignments'] = assignments;
          data.remove('evals');
          data.remove('routes');
          data[_busColorsKey] = _busColorsToMap();
          break;

        case Phase.phaseThree:
          data['stops'] = stops;
          data['students'] = students;
          data['assignments'] = assignments;
          data['routes'] = routes;
          data[_busColorsKey] = _busColorsToMap();
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
      _loadBusColors(refreshed);
      _assignBusColors();
      _generateBusIcons();

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
        _assignBusColors();
        _generateBusIcons();
        buildMarkers(stops, MarkerType.stop);
      }
      // Phase 3 setup
      else if (newPhase == Phase.phaseThree) {
        _assignBusColors();
        _generateBusIcons();
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
    if (markerInfo && markerType == 'stop') {
      for (final a in assignments) {
        final stopsList = a['stops'] as List?;
        final busId = a['bus'] as int?;
        if (stopsList != null &&
            busId != null &&
            stopsList.contains(touchedMarkerId)) {
          busAssignment = busId + 1;
        }
      }
    }
    int busAssignmentIndex = -1;
    if (busAssignment > 0) {
      busAssignmentIndex = assignments.indexWhere(
        (a) => a['bus'] == busAssignment - 1,
      );
    }

    int? studentStopAssignment;
    if (markerInfo && markerType == 'student') {
      studentStopAssignment = _stopForStudent(touchedMarkerId);
    }
    final studentBusAssignment = markerInfo && markerType == 'student'
        ? _busForStudent(touchedMarkerId)
        : null;

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
        if (markerInfo && widget.isModified)
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
                                    if (m == null) return;
                                    if ((m == MarkerLabel.stop &&
                                            markerType == 'stop') ||
                                        (m == MarkerLabel.student &&
                                            markerType == 'student')) {
                                      return;
                                    }

                                    setState(() {
                                      selectedMarker = m;
                                      // Move the touched marker between lists
                                      if (m == MarkerLabel.stop) {
                                        final stu = students.firstWhere(
                                          (s) => s['id'] == touchedMarkerId,
                                          orElse: () => null,
                                        );
                                        if (stu != null) {
                                          students.remove(stu);
                                          stops.add({
                                            'id': stu['id'],
                                            'pos': {
                                              'lat': stu['pos']['lat'],
                                              'lon': stu['pos']['lon'],
                                            },
                                            'students': <int>[],
                                          });
                                        }
                                        markerType = 'stop';
                                      } else {
                                        final stp = stops.firstWhere(
                                          (s) => s['id'] == touchedMarkerId,
                                          orElse: () => null,
                                        );
                                        if (stp != null) {
                                          // remove from assignments if it was a stop
                                          for (final a in assignments) {
                                            final list = List<int>.from(
                                              a['stops'] ?? [],
                                            );
                                            list.remove(touchedMarkerId);
                                            a['stops'] = list;
                                          }
                                          stops.remove(stp);
                                          students.add({
                                            'id': stp['id'],
                                            'pos': {
                                              'lat': stp['pos']['lat'],
                                              'lon': stp['pos']['lon'],
                                            },
                                          });
                                        }
                                        markerType = 'student';
                                      }

                                      _assignBusColors();
                                      _generateBusIcons();
                                      _markers.clear();
                                      buildMarkers(stops, MarkerType.stop);
                                      buildMarkers(
                                        students,
                                        MarkerType.student,
                                      );
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
                              List<int> orphanedStudents = [];
                              if (markerType == 'stop') {
                                final removedStop = stops.firstWhere(
                                  (s) => s['id'] == touchedMarkerId,
                                  orElse: () => null,
                                );
                                if (removedStop != null) {
                                  orphanedStudents = List<int>.from(
                                    (removedStop['students'] as List?) ?? [],
                                  );
                                }
                              }

                              _removeStudentFromStops(touchedMarkerId);
                              stops.removeWhere(
                                (stop) => stop['id'] == touchedMarkerId,
                              );
                              students.removeWhere(
                                (student) => student['id'] == touchedMarkerId,
                              );
                              for (final a in assignments) {
                                final list = List<int>.from(a['stops'] ?? []);
                                list.remove(touchedMarkerId);
                                a['stops'] = list;
                              }

                              _markers.remove('${markerType}_$touchedMarkerId');

                              if (markerType == 'stop' &&
                                  orphanedStudents.isNotEmpty) {
                                for (final studentId in orphanedStudents) {
                                  final student = students.firstWhere(
                                    (s) => s['id'] == studentId,
                                    orElse: () => null,
                                  );
                                  if (student != null) {
                                    final lat = (student['pos']['lat'] as num)
                                        .toDouble();
                                    final lon = (student['pos']['lon'] as num)
                                        .toDouble();
                                    _reassignStudentToNearestStop(
                                      studentId,
                                      LatLng(lat, lon),
                                    );
                                  }
                                }
                              }

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
                  if (phaseType != Phase.phaseOne && markerType == 'stop')
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
                              DropdownMenu<int>(
                                width: screenWidth * 0.06,
                                initialSelection: selectedBusOption,
                                onSelected: (val) {
                                  setState(() {
                                    selectedBusOption = val;
                                  });
                                },
                                dropdownMenuEntries: assignments
                                    .map<DropdownMenuEntry<int>>((a) {
                                      final busId = (a['bus'] as int?) ?? 0;
                                      return DropdownMenuEntry<int>(
                                        value: busId + 1,
                                        label: 'Bus ${busId + 1}',
                                      );
                                    })
                                    .toList(),
                                inputDecorationTheme: InputDecorationTheme(
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                  SizedBox(height: screenHeight * 0.02),

                  if (markerType == 'student' &&
                      widget.phaseType != Phase.phaseThree)
                    Column(
                      children: [
                        Center(
                          child: Text(
                            'Assigned Stop',
                            style: GoogleFonts.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromRGBO(57, 103, 136, 1),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Center(
                          child: DropdownMenu<int>(
                            width: screenWidth * .1,
                            initialSelection: studentStopAssignment,
                            requestFocusOnTap: false,
                            dropdownMenuEntries: stops
                                .map<DropdownMenuEntry<int>>(
                                  (s) => DropdownMenuEntry(
                                    value: s['id'] as int,
                                    label: 'Stop ${(s['id'] as int) + 1}',
                                  ),
                                )
                                .toList(),
                            onSelected: widget.isModified
                                ? (int? stopId) {
                                    if (stopId == null) return;
                                    setState(() {
                                      _assignStudentToStopById(
                                        touchedMarkerId,
                                        stopId,
                                      );
                                      _markers.clear();
                                      buildMarkers(stops, MarkerType.stop);
                                      buildMarkers(
                                        students,
                                        MarkerType.student,
                                      );
                                    });
                                  }
                                : null,
                            inputDecorationTheme: InputDecorationTheme(
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        if (studentStopAssignment != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color:
                                      _colorForStop(studentStopAssignment) ??
                                      const Color.fromRGBO(57, 103, 136, 1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.008),
                              Text(
                                'Stop ${studentStopAssignment + 1}'
                                '${studentBusAssignment != null ? ' (Bus ${studentBusAssignment + 1})' : ''}',
                                style: GoogleFonts.quicksand(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color.fromRGBO(57, 103, 136, 1),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'No stop assigned',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade400,
                            ),
                          ),
                      ],
                    ),

                  SizedBox(height: screenHeight * 0.02),
                  if (phaseType == Phase.phaseThree)
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
                      busAssignmentIndex >= 0)
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
                                assignments[busAssignmentIndex]['stops'] ?? [],
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
                                        "Stop ${stopId + 1}",
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
                  if (widget.phaseType == Phase.phaseTwo &&
                      markerType == 'stop')
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
                                selectedBusOption = busAssignment > 0
                                    ? busAssignment
                                    : (assignments.isNotEmpty
                                          ? ((assignments.first['bus']
                                                        as int?) ??
                                                    0) +
                                                1
                                          : null);
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
                            onPressed: () async {
                              final busNum = selectedBusOption;

                              final targetBusId = (busNum ?? 1) - 1;
                              final targetIndex = assignments.indexWhere(
                                (a) => (a['bus'] as int?) == targetBusId,
                              );

                              if (busNum == null ||
                                  busNum < 1 ||
                                  targetIndex == -1) {
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

                              stop['bus'] = assignments[targetIndex]['bus'];

                              for (final stuId
                                  in (stop['students'] as List? ?? [])) {
                                final stu = students.firstWhere(
                                  (s) => s['id'] == stuId,
                                );
                                stu['bus'] = assignments[targetIndex]['bus'];
                              }

                              setState(() {
                                isEditingBus = false;
                                selectedBusOption = null;
                              });
                              _assignBusColors();
                              await _generateBusIcons();
                              setState(() {
                                _markers.clear();
                                buildMarkers(stops, MarkerType.stop);
                                buildMarkers(students, MarkerType.student);
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
