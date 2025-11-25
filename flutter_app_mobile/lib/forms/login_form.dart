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
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    void submitForm() async {
      String email = emailController.text.trim();
      String pass = passwordController.text.trim();

      if (_formKey.currentState!.validate()) {
        try {
          final credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: pass);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Center(child: Text('Login success!'))),
            );
            Future.delayed(const Duration(seconds: 1), () {
              if (context.mounted) {
                // Navigate to home page
                Navigator.of(context).pushReplacementNamed('/');
              }
            });
          }
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'An error occurred. Please try again.';
          if (e.code == 'user-not-found') {
            errorMessage = 'This user does not exist.';
          } else if (e.code == 'wrong-password') {
            errorMessage = 'Password is incorrect.';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'The email address is invalid.';
          } else if (e.code == 'user-disabled') {
            errorMessage = 'This user account has been disabled.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many attempts. Please try again later.';
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Center(child: Text(errorMessage)),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Center(child: Text('Error: $e')),
              ),
            );
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Log In',
                      style: GoogleFonts.quicksand(
                        fontSize: 70,
                        fontWeight: FontWeight.w700,
                        color: const Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                    SizedBox(height: screenHeight * .05),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                        labelText: "Enter Email *",
                        labelStyle: TextStyle(color: Colors.white),
                        hintText: "example@email.com",
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Nothing entered for email.';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * .03),
                    TextFormField(
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
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                        labelText: "Enter Password *",
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      validator: (String? value) {
                        return (value == null || value.isEmpty)
                            ? 'Nothing entered for password.'
                            : null;
                      },
                      onFieldSubmitted: (value) {
                        submitForm();
                      },
                    ),
                    SizedBox(height: screenHeight * .05),
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: Text(
                        "Need to make an account? Click Here",
                        style: GoogleFonts.quicksand(
                          fontSize: 18,
                          color: const Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * .02),
                    TextButton(
                      style: ButtonStyle(
                        backgroundColor: const WidgetStatePropertyAll<Color>(
                          Color.fromARGB(117, 255, 255, 255),
                        ),
                        padding: WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(
                            horizontal: screenWidth * .15,
                            vertical: screenHeight * .02,
                          ),
                        ),
                        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      onPressed: submitForm,
                      child: Text(
                        "Log In",
                        style: GoogleFonts.quicksand(
                          fontSize: 25,
                          color: const Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

