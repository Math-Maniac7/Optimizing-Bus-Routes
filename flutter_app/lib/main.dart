import 'package:flutter/material.dart';
import 'package:flutter_app/forms/login_form.dart';
import 'package:flutter_app/forms/signup_form.dart';
import 'pages/home_page.dart';
import 'pages/route_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Core idea: prepare bindings for async init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
