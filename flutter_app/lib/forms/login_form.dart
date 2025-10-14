import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});
  static const String routeName = '/login';

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Color.fromRGBO(57, 103, 136, 1),
      body: Center(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Log In',
                style: GoogleFonts.quicksand(
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              SizedBox(height: screenHeight * .03),
              Padding(
                padding: EdgeInsets.only(
                  left: screenWidth / 2.5,
                  right: screenWidth / 2.5,
                ),
                child: TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    labelText: "Enter Email *",
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  validator: (String? value) {
                    return (value == null || value.isEmpty)
                        ? 'Nothing entered for email.'
                        : null;
                  },
                ),
              ),
              SizedBox(height: screenHeight * .05),
              Padding(
                padding: EdgeInsets.only(
                  left: screenWidth / 2.5,
                  right: screenWidth / 2.5,
                ),
                child: TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    labelText: "Enter Password *",
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  validator: (String? value) {
                    return (value == null || value.isEmpty)
                        ? 'Nothing entered for password.'
                        : null;
                  },
                ),
              ),
              SizedBox(height: screenHeight * .05),
              TextButton(
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
                onPressed: () async {
                  String email = emailController.text.trim();
                  String pass = passwordController.text.trim();

                  if (_formKey.currentState!.validate()) {
                    try {
                      final credential = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(
                            email: email,
                            password: pass,
                          );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Center(child: Text('Login success!')),
                          ),
                        );
                        Future.delayed(const Duration(seconds: 1), () {
                          if (context.mounted) {
                            Navigator.pushNamed(context, '/routes');
                          }
                        });
                      }
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'user-not-found') {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Center(
                                child: Text('This user does not exist.'),
                              ),
                            ),
                          );
                        }
                      } else if (e.code == 'wrong-password') {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Center(
                                child: Text('Password is incorrect.'),
                              ),
                            ),
                          );
                        }
                      }
                    }
                  }
                },
                child: Text(
                  "Log In",
                  style: GoogleFonts.quicksand(
                    fontSize: 25,
                    color: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
