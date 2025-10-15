import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});
  static const String routeName = '/signup';

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool accountExists = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      body: Center(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sign Up',
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
                    return (value != null && !value.contains('@'))
                        ? 'Your email should have an @.'
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
                    return (value != null && value.length < 8)
                        ? 'Please type in a password at least 8 characters.'
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
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    labelText: "Confirm Password *",
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password.';
                    } else if (value != passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: screenHeight * .05),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: Text(
                  "Already have an account? Click Here",
                  style: GoogleFonts.quicksand(
                    fontSize: 25,
                    color: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * .01),
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
                    // All fields are valid — proceed with registration logic
                    try {
                      await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                            email: email,
                            password: pass,
                          );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Center(
                              child: Text('Account created successfully.'),
                            ),
                          ),
                        );
                        Future.delayed(const Duration(seconds: 1), () {
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        });
                      }
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'email-already-in-use') {
                        if (mounted) setState(() => accountExists = true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Center(
                                child: Text(
                                  'This email is already registered.',
                                ),
                              ),
                            ),
                          );
                          Future.delayed(const Duration(seconds: 1), () {
                            if (context.mounted) {
                              Navigator.pushNamed(context, '/login');
                            }
                          });
                        }
                      } else if (e.code == 'invalid-email') {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Center(
                                child: Text('The email address is invalid.'),
                              ),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Center(
                                child: Text('Error: ${e.message}'),
                              ),
                            ),
                          );
                        }
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Center(
                          child: Text(
                            'Please fix the errors in red before continuing.',
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  accountExists ? "Login" : "Register",
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
