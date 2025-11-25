import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});
  static const String routeName = '/signup';

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final busNumberController = TextEditingController();
  String _selectedRole = UserService.roleStudent; // Default to student

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    busNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

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
                      'Sign Up',
                      style: GoogleFonts.quicksand(
                        fontSize: 70,
                        fontWeight: FontWeight.w700,
                        color: const Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                    SizedBox(height: screenHeight * .03),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
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
                        labelText: "Full Name *",
                        labelStyle: TextStyle(color: Colors.white),
                        hintText: "e.g., Alex Johnson",
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * .03),
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
                          return 'Your email should have an @.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * .03),
                    TextFormField(
                      controller: busNumberController,
                      keyboardType: TextInputType.number,
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
                        labelText: "Assigned Bus Number *",
                        labelStyle: TextStyle(color: Colors.white),
                        hintText: "e.g., 12",
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide a bus assignment.';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Bus numbers should be numeric.';
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
                        if (value == null || value.isEmpty) {
                          return 'Nothing entered for password.';
                        }
                        if (value.length < 8) {
                          return 'Please type in a password at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * .03),
                    TextFormField(
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
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
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
                    SizedBox(height: screenHeight * .03),
                    // Role Selection Slider
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'I am a:',
                            style: GoogleFonts.quicksand(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: UserService.roleStudent,
                                label: Text('Student/Parent'),
                                icon: Icon(Icons.family_restroom),
                              ),
                              ButtonSegment<String>(
                                value: UserService.roleDriver,
                                label: Text('Bus Driver'),
                                icon: Icon(Icons.drive_eta),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _selectedRole = newSelection.first;
                              });
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white.withOpacity(0.3);
                                  }
                                  return Colors.transparent;
                                },
                              ),
                              foregroundColor: WidgetStateProperty.all(Colors.white),
                              side: WidgetStateProperty.all(
                                const BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
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
                      onPressed: () async {
                        String email = emailController.text.trim();
                        String pass = passwordController.text.trim();

                        if (_formKey.currentState!.validate()) {
                          try {
                            // Create user account
                            final userCredential = await FirebaseAuth.instance
                                .createUserWithEmailAndPassword(
                                  email: email,
                                  password: pass,
                                );

                            // Save user role to Firestore
                            bool roleSaved = false;
                            if (userCredential.user != null) {
                              try {
                                roleSaved = await UserService.saveUserProfile(
                                  userCredential.user!.uid,
                                  role: _selectedRole,
                                  busNumber: busNumberController.text.trim(),
                                  displayName: nameController.text.trim(),
                                );
                                
                                if (!roleSaved) {
                                  // If profile save fails, log error but continue
                                  print('Warning: Profile could not be saved to Firestore');
                                }
                              } catch (e) {
                                // Catch any errors saving role
                                print('Error saving role: $e');
                                roleSaved = false;
                              }
                            }

                            if (context.mounted) {
                              // Show success message
                              String message = roleSaved
                                  ? 'Account created successfully!'
                                  : 'Account created but profile could not be saved. Please contact support.';
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Center(child: Text(message)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              
                              // Navigate to home - AuthWrapper will handle role-based redirect
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/',
                                (route) => false, // Remove all previous routes
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            String errorMessage = 'An error occurred. Please try again.';
                            
                            if (e.code == 'email-already-in-use') {
                              errorMessage = 'This email is already registered.';
                            } else if (e.code == 'invalid-email') {
                              errorMessage = 'The email address is invalid.';
                            } else if (e.code == 'operation-not-allowed') {
                              errorMessage = 'Email/password accounts are not enabled.';
                            } else if (e.code == 'weak-password') {
                              errorMessage = 'The password is too weak.';
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Center(child: Text(errorMessage)),
                                ),
                              );
                              
                              if (e.code == 'email-already-in-use') {
                                Future.delayed(const Duration(seconds: 1), () {
                                  if (context.mounted) {
                                    Navigator.pushNamed(context, '/login');
                                  }
                                });
                              }
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
                        } else {
                          if (context.mounted) {
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
                        }
                      },
                      child: Text(
                        "Register",
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

