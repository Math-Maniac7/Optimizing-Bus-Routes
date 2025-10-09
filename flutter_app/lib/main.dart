import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/route_page.dart';

void main() {
  runApp(MyApp());
}

///A StatefulWidget that represents app's home route
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      routes: {RouteOptimization.routeName: (_) => const RouteOptimization()},
    );
  }
}
