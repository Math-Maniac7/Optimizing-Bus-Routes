import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'route_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.only(top: screenHeight * 0.15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Bus Route Optimizer',
                style: GoogleFonts.oswald(
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      // debugPrint('Get Started tapped');
                      Navigator.pushNamed(context, RouteOptimization.routeName);
                    },
                    child: Text("Get Started!"),
                  ),
                ],
              ),
              SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
