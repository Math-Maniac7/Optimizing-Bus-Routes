import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/maps.dart';
import '../widgets/location_upload_drawer.dart';
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
  Phase? selectedPhase;
  bool isModified = false;

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
              isModified ? 'Edit Mode' : 'Bus Route Optimizer',
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
                        if (!isModified) ...[
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
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      foregroundDecoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.overlay,
                        color: isModified
                            ? const Color.fromARGB(126, 255, 255, 255)
                            : const Color.fromARGB(0, 255, 255, 255),
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
    setState(() => isModified = true);
  }

  void _onSave() {
    debugPrint("Save button pressed");
    // TODO: add save logic
  }

  void _onCancel() {
    debugPrint("Cancel button pressed");
    setState(() => isModified = false);
  }
}
