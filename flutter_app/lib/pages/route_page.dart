import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/maps.dart';
import '../widgets/location_upload_drawer.dart';

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});
  static const String routeName = '/routes';

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  String activeMode = ''; // tracks which button is active
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.02,
          vertical: screenHeight * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Bus Route Optimizer',
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
                        _buildSideButton("Add Locations", screenWidth),
                        SizedBox(height: screenHeight * 0.02),
                        _buildSideButton("Generate Routes", screenWidth),
                        SizedBox(height: screenHeight * 0.02),
                        _buildSideButton("Modify", screenWidth),
                        SizedBox(height: screenHeight * 0.02),
                        _buildSideButton("Boundaries", screenWidth),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    flex: 6, // give more width to the map
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(57, 103, 136, 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: GoogleMaps(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      endDrawer: const LocationUploadDrawer(),
    );
  }

  Widget _buildSideButton(String text, double screenWidth) {
    final bool isActive = activeMode == text;
    return SizedBox(
      width: screenWidth * 0.15, // slim fixed width
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(
            isActive
                ? const Color.fromARGB(180, 255, 255, 255)
                : const Color.fromARGB(90, 255, 255, 255),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        onPressed: () {
          setState(() {
            activeMode = text; // highlight this button
          });

          // Call different functions depending on which was pressed
          if (text == "Add Locations") {
            _onAddLocations();
          } else if (text == "Generate Routes") {
            _onGenerateRoutes();
          } else if (text == "Modify") {
            _onModify();
          } else if (text == "Boundaries") {
            _onBoundaries();
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

  void _onGenerateRoutes() {
    debugPrint("Generate Routes button pressed");
    // TODO: implement route generation logic
  }

  void _onModify() {
    debugPrint("Modify button pressed");
    // TODO: modify routes or map details
  }

  void _onBoundaries() {
    debugPrint("Boundaries button pressed");
    // TODO: toggle or edit map boundaries
  }
}