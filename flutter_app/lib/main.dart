import 'package:flutter/material.dart';
import 'package:flutter_app/forms/login_form.dart';
import 'package:flutter_app/forms/signup_form.dart';
import 'pages/home_page.dart';
import 'pages/route_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_storage_options.dart';

Future<void> main() async {
  //Test to make sure interop works
  /*
  await Future.delayed(Duration(seconds: 4));
  
    print("Calling C++ code");
    final out = await phase_1('''{
    "school" : {"lat": 30.455773, "lon": -97.798242},
    "bus_yard" : {"lat": 30.455773, "lon": -97.798242},
    "students" : [
        {"id": 0, "pos": {"lat": 30.4524471, "lon": -97.8115005}},
        {"id": 1, "pos": {"lat": 30.4427579, "lon": -97.8028133}},
        {"id": 2, "pos": {"lat": 30.4423536, "lon": -97.808608}},
        {"id": 3, "pos": {"lat": 30.4475907, "lon": -97.8188957}},
        {"id": 4, "pos": {"lat": 30.4543126, "lon": -97.8183026}}
    ],
    "buses" : [
        {"id": 0, "capacity": 100}
    ],
    "stops" : [
        {"id": 0, "pos": {"lat": 30.4524471, "lon": -97.8115005}, "students": [0]},
        {"id": 1, "pos": {"lat": 30.4427579, "lon": -97.8028133}, "students": [1]},
        {"id": 2, "pos": {"lat": 30.4423536, "lon": -97.808608}, "students": [2]},
        {"id": 3, "pos": {"lat": 30.4475907, "lon": -97.8188957}, "students": [3]},
        {"id": 4, "pos": {"lat": 30.4543126, "lon": -97.8183026}, "students": [4]}
    ],
    "assignments" : [
        {"id": 0, "bus": 0, "stops": [0, 1, 2, 3, 4]}
    ]
}''');
    print('Result from C++: $out');
  */
  

  //Actual calls
  WidgetsFlutterBinding.ensureInitialized(); // Core idea: prepare bindings for async init
  
  // Initialize the OAuth Firebase app (default - route-optimization-474616)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
    name: '[DEFAULT]', // This is the default app for OAuth
  );
  
  // Initialize the storage Firebase app (bus-mobile-app-4bebd) for Firestore
  await Firebase.initializeApp(
    options: FirebaseStorageOptions.currentPlatform,
    name: 'storage',
  );
  
  runApp(const MyApp());
}

///A StatefulWidget that represents app's home route
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
      routes: {
        RouteOptimization.routeName: (_) => const RouteOptimization(),
        SignupForm.routeName: (_) => const SignupForm(),
        LoginForm.routeName: (_) => const LoginForm(),
      },
    );
  }
}
