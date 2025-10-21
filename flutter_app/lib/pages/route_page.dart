import 'package:flutter/material.dart';

import '../widgets/maps.dart';

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});
  static const String routeName = '/routes';

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  final addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Type in your school address to get started"),
                // GooglePlaceAutoCompleteTextField(
                //   textEditingController: addressController,
                //   googleAPIKey:
                //       "https://maps.googleapis.com/maps/api/js?key=AIzaSyBa81fx50q2olJpz7kxzzY_GkPIjlFsEOA",
                //   isLatLngRequired: true,
                // ),
                TextButton(onPressed: () {}, child: Text("Add Locations")),
                TextButton(onPressed: () {}, child: Text("Generate Routes")),
                TextButton(onPressed: () {}, child: Text("Modify")),
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
