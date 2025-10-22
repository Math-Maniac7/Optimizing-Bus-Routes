import 'package:flutter/material.dart';
import '../widgets/maps.dart';
import '../widgets/location_upload_drawer.dart';

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});
  static const String routeName = '/routes';

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                  child: const Text("Add Locations"),
                ),
                TextButton(onPressed: () {}, child: const Text("Generate Routes")),
                TextButton(onPressed: () {}, child: const Text("New Params")),
                TextButton(onPressed: () {}, child: const Text("Boundaries")),
              ],
            ),
            const Expanded(child: GoogleMaps()),
          ],
        ),
      ),
      endDrawer: const LocationUploadDrawer(),
    );
  }
}
