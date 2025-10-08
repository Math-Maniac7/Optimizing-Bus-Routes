import 'package:flutter/material.dart';

void main(){
  runApp(Router());
}

class Router extends StatefulWidget {
  const Router({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}