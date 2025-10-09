import 'package:flutter/material.dart';
import '../widgets/maps.dart';

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});
  static const String routeName = '/routes';

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () {}, child: Text("Add Locations")),
                TextButton(onPressed: () {}, child: Text("Generate Routes")),
                TextButton(onPressed: () {}, child: Text("New Params")),
                TextButton(onPressed: () {}, child: Text("Boundaries")),
              ],
            ),
            Expanded(child: GoogleMaps()),
          ],
        ),
      ),
    );
  }
}
