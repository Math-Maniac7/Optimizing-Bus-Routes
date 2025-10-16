import 'package:flutter/material.dart';
import 'package:flutter_app/forms/login_form.dart';
import 'package:flutter_app/forms/signup_form.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Color.fromRGBO(57, 103, 136, 1),
      body: Center(
        child: Padding(
          padding: EdgeInsets.only(top: screenHeight * 0.15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Bus Route Optimizer',
                style: GoogleFonts.quicksand(
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(padding: EdgeInsets.only(top: screenHeight * 0.05)),
                  Text(
                    "Sign up to get started, or log in if you already have an account.",
                    style: GoogleFonts.quicksand(
                      fontSize: 20,
                      color: const Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll<Color>(
                              const Color.fromARGB(117, 255, 255, 255),
                            ),
                            padding: WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(
                                horizontal: screenWidth * .01,
                                vertical: screenHeight * .01,
                              ),
                            ),
                          ),
                          onPressed: () {
                            // debugPrint('Get Started tapped');
                            Navigator.pushNamed(context, SignupForm.routeName);
                          },
                          child: Text(
                            "Sign up",
                            style: GoogleFonts.quicksand(
                              fontSize: 25,
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll<Color>(
                              const Color.fromARGB(117, 255, 255, 255),
                            ),
                            padding: WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(
                                horizontal: screenWidth * .01,
                                vertical: screenHeight * .01,
                              ),
                            ),
                          ),
                          onPressed: () {
                            // debugPrint('Get Started tapped');
                            Navigator.pushNamed(context, LoginForm.routeName);
                          },
                          child: Text(
                            "Login",
                            style: GoogleFonts.quicksand(
                              fontSize: 25,
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ),
                      ),
                    ],
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
