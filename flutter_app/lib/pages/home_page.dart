import 'package:flutter/material.dart';
import 'route_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Bus Route Optimizer'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    debugPrint('Get Started tapped');
                    Navigator.pushNamed(context, RouteOptimization.routeName);
                  },
                  child: const Text("Get Started!"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
