import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'forms/login_form.dart';
import 'forms/signup_form.dart';
import 'services/user_service.dart';

// Firebase configuration for storage project
const firebaseConfig = FirebaseOptions(
  apiKey: "AIzaSyBEH7h_od-ZYOqwJGgAHR0N8_Ak3z0insc",
  authDomain: "bus-mobile-app-4bebd.firebaseapp.com",
  databaseURL: "https://bus-mobile-app-4bebd-default-rtdb.firebaseio.com",
  projectId: "bus-mobile-app-4bebd",
  storageBucket: "bus-mobile-app-4bebd.firebasestorage.app",
  messagingSenderId: "593453456089",
  appId: "1:593453456089:web:1e8a13dd8c8699e65cbcc8",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Bus Tracker',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(57, 103, 136, 1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(57, 103, 136, 1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.quicksandTextTheme(),
      ),
      home: const AuthWrapper(),
      routes: {
        LoginForm.routeName: (_) => const LoginForm(),
        SignupForm.routeName: (_) => const SignupForm(),
      },
    );
  }
}

/// Wrapper widget that checks authentication state
/// Shows login page if not authenticated, HomePage if authenticated
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: GoogleFonts.quicksand(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If user is logged in, show RoleBasedHomePage
        if (snapshot.hasData && snapshot.data != null) {
          return RoleBasedHomePage(userId: snapshot.data!.uid);
        }

        // If user is not logged in, show LoginForm
        return const LoginForm();
      },
    );
  }
}

/// HomePage that checks user role and redirects automatically
class RoleBasedHomePage extends StatefulWidget {
  final String userId;
  
  const RoleBasedHomePage({super.key, required this.userId});

  @override
  State<RoleBasedHomePage> createState() => _RoleBasedHomePageState();
}

class _RoleBasedHomePageState extends State<RoleBasedHomePage> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<UserProfile?>(
      stream: UserService.watchUserProfile(widget.userId),
      builder: (context, profileSnapshot) {
        // Show loading while fetching profile
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const _FullScreenLoader(message: 'Loading your profile...');
        }

        final profile = profileSnapshot.data;

        if (profile == null) {
          // No profile document yet (legacy accounts) – ask for bus assignment.
          return BusAssignmentScreen(
            userId: widget.userId,
            initialBusNumber: '',
            role: null,
            allowBackNavigation: false,
          );
        }

        if (!profile.hasBusAssignment) {
          // Profile exists but missing a bus assignment.
          return BusAssignmentScreen(
            userId: widget.userId,
            initialBusNumber: profile.busNumber,
            role: profile.role,
            allowBackNavigation: false,
          );
        }

        final role = profile.role;

        // Navigate based on role (only once)
        if (!_hasNavigated && role.isNotEmpty) {
          _hasNavigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (role == UserService.roleDriver) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => BusDriverPage(
                    userId: widget.userId,
                    assignedBusNumber: profile.busNumber,
                  ),
                ),
              );
            } else if (role == UserService.roleStudent) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => ParentStudentPage(
                    userId: widget.userId,
                    assignedBusNumber: profile.busNumber,
                  ),
                ),
              );
            }
          });
        }

        // Show loading during redirect
        if (role.isNotEmpty && _hasNavigated) {
          return _FullScreenLoader(
            message: role == UserService.roleDriver
                ? 'Redirecting to driver page...'
                : 'Redirecting to student/parent page...',
          );
        }

        // If role missing, show fallback landing page
        return HomePage(
          user: user,
          userId: widget.userId,
          profile: profile,
        );
      },
    );
  }
}

/// Fallback HomePage shown when role is not found
class HomePage extends StatelessWidget {
  final User? user;
  final String userId;
  final UserProfile? profile;
  
  const HomePage({
    super.key,
    required this.userId,
    this.user,
    this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'School Bus Tracker',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigate back to root so AuthWrapper can handle redirect
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome!',
              style: GoogleFonts.quicksand(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (user?.email != null) ...[
              const SizedBox(height: 10),
              Text(
                user!.email!,
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (profile != null && profile!.role.isNotEmpty) ...[
              Text(
                'Current role: ${profile!.role.toUpperCase()}',
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (profile != null && profile!.busNumber.isNotEmpty) ...[
              Text(
                'Assigned bus: ${profile!.busNumber}',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
            ],
            const Icon(
              Icons.directions_bus,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 32),
            Text(
              'Please contact an administrator to finish setting up your role, or update your bus assignment below.',
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BusAssignmentScreen(
                      userId: userId,
                      role: profile?.role,
                      initialBusNumber: profile?.busNumber ?? '',
                      allowBackNavigation: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: Text(
                'Update Bus Assignment',
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                backgroundColor: const Color.fromARGB(117, 255, 255, 255),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenLoader extends StatelessWidget {
  final String message;

  const _FullScreenLoader({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.quicksand(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusAssignmentScreen extends StatefulWidget {
  final String userId;
  final String? role;
  final String initialBusNumber;
  final bool allowBackNavigation;

  const BusAssignmentScreen({
    super.key,
    required this.userId,
    required this.initialBusNumber,
    this.role,
    this.allowBackNavigation = true,
  });

  @override
  State<BusAssignmentScreen> createState() => _BusAssignmentScreenState();
}

class _BusAssignmentScreenState extends State<BusAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _busController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _busController = TextEditingController(text: widget.initialBusNumber);
  }

  @override
  void dispose() {
    _busController.dispose();
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final success = await UserService.updateBusAssignment(
      widget.userId,
      _busController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            success
                ? 'Bus assignment updated.'
                : 'Unable to update bus assignment. Please try again.',
          ),
        ),
      ),
    );

    if (success && widget.allowBackNavigation) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.allowBackNavigation,
        title: Text(
          'Bus Assignment',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every account must be assigned to a single bus so drivers and families only see the vehicles that matter to them.',
                  style: GoogleFonts.quicksand(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.role != null && widget.role!.isNotEmpty)
                  Text(
                    'Detected role: ${widget.role}',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                if (widget.role != null && widget.role!.isNotEmpty)
                  const SizedBox(height: 16),
                TextFormField(
                  controller: _busController,
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
                    labelText: 'Assigned Bus Number',
                    labelStyle: TextStyle(color: Colors.white),
                    hintText: 'e.g., 12',
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a bus number.';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'Bus numbers should be numeric.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAssignment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color.fromARGB(117, 255, 255, 255),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Save Bus Assignment',
                            style: GoogleFonts.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Once saved, we will redirect you automatically.',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// BUS DRIVER PAGE
class BusDriverPage extends StatefulWidget {
  final String assignedBusNumber;
  final String userId;

  const BusDriverPage({
    super.key,
    required this.assignedBusNumber,
    required this.userId,
  });

  @override
  State<BusDriverPage> createState() => _BusDriverPageState();
}

class _BusDriverPageState extends State<BusDriverPage> {
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String busNumber;
  bool _isSigningOut = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _attendanceSubscription;
  Map<String, bool> _attendance = {};

  @override
  void initState() {
    super.initState();
    busNumber = widget.assignedBusNumber;
    _subscribeToAttendance();
  }

  Future<void> _refreshAssignment() async {
    final profile = await UserService.getUserProfile(widget.userId);
    if (!mounted || profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Unable to reload profile.')),
        ),
      );
      return;
    }

    if (profile.busNumber.isNotEmpty && profile.busNumber != busNumber) {
      setState(() {
        busNumber = profile.busNumber;
      });
    _subscribeToAttendance();
      _subscribeToAttendance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text('Bus assignment updated to ${profile.busNumber}.'),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('No new bus assignment found.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (busNumber.isEmpty) {
      return BusAssignmentScreen(
        userId: widget.userId,
        initialBusNumber: '',
        role: UserService.roleDriver,
        allowBackNavigation: false,
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'Track Bus $busNumber',
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.people_alt),
              tooltip: 'Passengers',
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Change bus',
              onPressed: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => BusAssignmentScreen(
                      userId: widget.userId,
                      role: UserService.roleDriver,
                      initialBusNumber: busNumber,
                    ),
                  ),
                )
                    .then((_) => _refreshAssignment());
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            onPressed: _isSigningOut
                ? null
                : () async {
                    setState(() => _isSigningOut = true);
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isSigningOut = false);
                      }
                    }
                  },
            ),
          ],
        ),
        endDrawer: _PassengerDrawer(
          busNumber: busNumber,
          attendance: _attendance,
          onToggle: _setAttendance,
          onClear: _clearAttendance,
        ),
        body: BusDriverMapPage(busNumber: busNumber),
      ),
    );
  }

  void _subscribeToAttendance() {
    _attendanceSubscription?.cancel();
    if (busNumber.isEmpty) {
      setState(() {
        _attendance = {};
      });
      return;
    }

    _attendanceSubscription = _firestore
        .collection('bus_attendance')
        .doc(busNumber)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      if (data == null || data['statuses'] == null) {
        setState(() {
          _attendance = {};
        });
        return;
      }
      final statuses = data['statuses'];
      if (statuses is Map) {
        final Map<String, bool> next = {};
        statuses.forEach((key, value) {
          next[key.toString()] = value == true;
        });
        setState(() {
          _attendance = next;
        });
      }
    });
  }

  Future<void> _setAttendance(String userId, bool isPresent) async {
    if (busNumber.isEmpty) return;
    await _firestore.collection('bus_attendance').doc(busNumber).set({
      'statuses': {userId: isPresent},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearAttendance() async {
    if (busNumber.isEmpty) return;
    await _firestore.collection('bus_attendance').doc(busNumber).set({
      'statuses': {},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Center(child: Text('Attendance cleared.')),
      ),
    );
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}

class _PassengerDrawer extends StatelessWidget {
  final String busNumber;
  final Map<String, bool> attendance;
  final Future<void> Function(String userId, bool isPresent) onToggle;
  final Future<void> Function() onClear;

  const _PassengerDrawer({
    required this.busNumber,
    required this.attendance,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passengers',
                        style: GoogleFonts.quicksand(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Bus $busNumber',
                        style: GoogleFonts.quicksand(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  onClear();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Clear statuses'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: firestore
                      .collection('users')
                      .where('bus_number', isEqualTo: busNumber)
                      .where('role', isEqualTo: UserService.roleStudent)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No passengers assigned yet.',
                          style: GoogleFonts.quicksand(),
                        ),
                      );
                    }
                    final docs = List.of(snapshot.data!.docs);
                    docs.sort((a, b) {
                      final aName =
                          (a.data()['display_name'] as String?)?.toLowerCase() ??
                              '';
                      final bName =
                          (b.data()['display_name'] as String?)?.toLowerCase() ??
                              '';
                      return aName.compareTo(bName);
                    });
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final name = (data['display_name'] as String?)?.trim();
                        final subtitle = 'ID: ${doc.id.substring(0, 6)}';
                        final userId = doc.id;
                        final isPresent = attendance[userId] ?? false;
                        return CheckboxListTile(
                          value: isPresent,
                          onChanged: (value) {
                            onToggle(userId, value ?? false);
                          },
                          title: Text(
                            name?.isNotEmpty == true ? name! : 'Unnamed user',
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: subtitle.isNotEmpty
                              ? Text(subtitle, style: GoogleFonts.quicksand())
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// BUS DRIVER MAP PAGE
class BusDriverMapPage extends StatefulWidget {
  final String busNumber;

  const BusDriverMapPage({super.key, required this.busNumber});

  @override
  State<BusDriverMapPage> createState() => _BusDriverMapPageState();
}

class _BusDriverMapPageState extends State<BusDriverMapPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Timer? _locationTimer;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Marker? _busMarker;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _routeSubscription;
  Set<Polyline> _routePolylines = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _listenToRoutes();
  }

  @override
  void didUpdateWidget(covariant BusDriverMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busNumber != widget.busNumber) {
      _routeSubscription?.cancel();
      setState(() {
        _routePolylines = {};
      });
      _listenToRoutes();
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied')),
        );
      }
      return;
    }

    _getCurrentLocation();
    _startLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        // Create/update the bus marker
        _busMarker = Marker(
          markerId: MarkerId('my_bus_${widget.busNumber}'),
          position: LatLng(position.latitude, position.longitude),
          rotation: position.heading,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '🚌 Bus ${widget.busNumber} (You)',
            snippet: 'Speed: ${position.speed.toStringAsFixed(1)} m/s',
          ),
        );
      });

      _updateLocationInDatabase(position);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _getCurrentLocation();
    });
  }

  Future<void> _updateLocationInDatabase(Position position) async {
    try {
      await _database.child('buses/${widget.busNumber}').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentPosition == null) {
      return const Center(child: Text('Unable to get location'));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        zoom: 17,
        bearing: _currentPosition!.heading,
        tilt: 45,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      markers: _busMarker != null ? {_busMarker!} : {},
      polylines: _routePolylines,
      myLocationEnabled: false, // Disabled - we use custom marker instead
      myLocationButtonEnabled: true,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    _routeSubscription?.cancel();
    // COMMENTED OUT FOR TESTING - keeps bus data in database
    // Uncomment this line later for production use:
    // _database.child('buses/${widget.busNumber}').remove();
    super.dispose();
  }

  void _listenToRoutes() {
    _listenToRoutesForBus(
      busNumber: widget.busNumber,
      onData: (polylines) {
        if (!mounted) return;
        setState(() {
          _routePolylines = polylines;
        });
      },
      currentSubscription: _routeSubscription,
      setter: (sub) => _routeSubscription = sub,
      color: Colors.deepPurpleAccent,
    );
  }
}

// PARENT/STUDENT PAGE
class ParentStudentPage extends StatefulWidget {
  final String assignedBusNumber;
  final String userId;

  const ParentStudentPage({
    super.key,
    required this.assignedBusNumber,
    required this.userId,
  });

  @override
  State<ParentStudentPage> createState() => _ParentStudentPageState();
}

class _ParentStudentPageState extends State<ParentStudentPage> {
  GoogleMapController? _mapController;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, Marker> _busMarkers = {};
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _busesSubscription;
  late String _assignedBusNumber;
  bool _hasAutoCentered = false;
  bool _isOnBus = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _attendanceSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _routeSubscription;
  Set<Polyline> _routePolylines = {};

  @override
  void initState() {
    super.initState();
    _assignedBusNumber = widget.assignedBusNumber;
    _listenToBuses();
    _listenToAttendance();
    _listenToRoutes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _listenToBuses() {
    _busesSubscription = _database.child('buses').onValue.listen((event) {
      if (!mounted) return; // Don't update if widget is disposed
      
      if (event.snapshot.value != null) {
        final data = _normalizeBusSnapshot(event.snapshot.value);
        final Map<String, Marker> filteredMarkers = {};

        data.forEach((busNumber, busData) {
          if (busNumber != _assignedBusNumber) return;
          final bus = Map<String, dynamic>.from(busData as Map);
          final double lat = (bus['latitude'] as num).toDouble();
          final double lng = (bus['longitude'] as num).toDouble();
          final double heading = (bus['heading'] as num?)?.toDouble() ?? 0.0;

          filteredMarkers[busNumber] = Marker(
            markerId: MarkerId(busNumber),
            position: LatLng(lat, lng),
            rotation: heading,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: 'Your Bus ($busNumber)',
              snippet: 'Heading: ${heading.toStringAsFixed(0)}°',
            ),
          );
        });

        if (!mounted) return;
        setState(() {
          _busMarkers = filteredMarkers;
          _isLoading = false;
        });
        if (_mapController != null &&
            !_hasAutoCentered &&
            filteredMarkers.isNotEmpty) {
          unawaited(
            _focusOnAssignedBus(
              showSnackOnMissing: false,
              recordAutoFocus: true,
            ),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _busMarkers = {};
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Text('Unable to load buses: $error'),
          ),
        ),
      );
    });
  }

  Map<String, dynamic> _normalizeBusSnapshot(Object? raw) {
    final Map<String, dynamic> result = {};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value != null) {
          result[key.toString()] = value;
        }
      });
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final value = raw[i];
        if (value != null) {
          result[i.toString()] = value;
        }
      }
    }
    return result;
  }

  Future<void> _focusOnAssignedBus({
    bool showSnackOnMissing = true,
    bool recordAutoFocus = false,
  }) async {
    final marker = _busMarkers[_assignedBusNumber];
    if (_mapController != null && marker != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(marker.position, 15),
      );
      if (recordAutoFocus) {
        _hasAutoCentered = true;
      }
    } else if (showSnackOnMissing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Text('Bus $_assignedBusNumber is not currently active.'),
          ),
        ),
      );
    }
  }

  Future<void> _refreshAssignment() async {
    final profile = await UserService.getUserProfile(widget.userId);
    if (!mounted || profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Unable to reload profile.')),
        ),
      );
      return;
    }

    if (profile.busNumber.isNotEmpty && profile.busNumber != _assignedBusNumber) {
      setState(() {
        _assignedBusNumber = profile.busNumber;
        _hasAutoCentered = false;
      });
      _listenToAttendance();
      _listenToRoutes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text('Bus assignment updated to ${profile.busNumber}.'),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('No new bus assignment found.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Track Buses',
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color.fromRGBO(57, 103, 136, 1),
          automaticallyImplyLeading: false, // Remove back button
          actions: [
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Change bus',
              onPressed: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => BusAssignmentScreen(
                      userId: widget.userId,
                      role: UserService.roleStudent,
                      initialBusNumber: _assignedBusNumber,
                    ),
                  ),
                )
                    .then((_) => _refreshAssignment());
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // Navigate back to root so AuthWrapper can handle redirect
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: const LatLng(31.5493, -97.1467), // Baylor, fallback center
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (!_hasAutoCentered) {
                      unawaited(
                        _focusOnAssignedBus(
                          showSnackOnMissing: false,
                          recordAutoFocus: true,
                        ),
                      );
                    }
                  },
                  markers: Set<Marker>.of(_busMarkers.values),
                  polylines: _routePolylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                ),
                if (_busMarkers.isEmpty)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        'Bus $_assignedBusNumber is not currently active',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          color: const Color.fromRGBO(57, 103, 136, 1),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your assigned bus: $_assignedBusNumber',
                          style: GoogleFonts.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(57, 103, 136, 1),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            unawaited(_focusOnAssignedBus());
                          },
                          icon: const Icon(Icons.center_focus_strong),
                          label: Text(
                            'Center on my bus',
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(117, 255, 255, 255),
                            foregroundColor: const Color.fromRGBO(57, 103, 136, 1),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isOnBus ? Icons.check_circle : Icons.bus_alert,
                              color:
                                  _isOnBus ? Colors.green : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnBus ? 'Status: On bus' : 'Status: Waiting to board',
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                color: _isOnBus
                                    ? Colors.green
                                    : Colors.orangeAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _busMarkers.isEmpty
                              ? 'Live location unavailable until the driver starts sharing.'
                              : 'Bus is actively broadcasting its location.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.quicksand(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  void _listenToAttendance() {
    _attendanceSubscription?.cancel();
    if (_assignedBusNumber.isEmpty) return;
    _attendanceSubscription = FirebaseFirestore.instance
        .collection('bus_attendance')
        .doc(_assignedBusNumber)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      if (data == null || data['statuses'] == null) {
        setState(() {
          _isOnBus = false;
        });
        return;
      }
      final statuses = data['statuses'];
      if (statuses is Map) {
        final bool onBus = statuses[widget.userId] == true;
        setState(() {
          _isOnBus = onBus;
        });
      }
    });
  }

  @override
  void dispose() {
    _busesSubscription?.cancel(); // Cancel Firebase listener
    _mapController?.dispose();
    _attendanceSubscription?.cancel();
    _routeSubscription?.cancel();
    super.dispose();
  }

  void _listenToRoutes() {
    _listenToRoutesForBus(
      busNumber: _assignedBusNumber,
      onData: (polylines) {
        if (!mounted) return;
        setState(() {
          _routePolylines = polylines;
        });
      },
      currentSubscription: _routeSubscription,
      setter: (sub) => _routeSubscription = sub,
      color: const Color.fromRGBO(57, 103, 136, 1),
    );
  }
}

void _listenToRoutesForBus({
  required String busNumber,
  required void Function(Set<Polyline>) onData,
  required StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      currentSubscription,
  required void Function(StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?)
      setter,
  Color color = Colors.orange,
}) {
  currentSubscription?.cancel();
  if (busNumber.isEmpty) {
    onData({});
    setter(null);
    return;
  }

  final subscription = FirebaseFirestore.instance
      .collection('bus_routes')
      .snapshots()
      .listen((snapshot) {
    final filtered = _buildPolylinesForBus(snapshot.docs, busNumber, color);
    onData(filtered);
  });
  setter(subscription);
}

Set<Polyline> _buildPolylinesForBus(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  String busNumber,
  Color color,
) {
  final polylines = <Polyline>{};
  final normalized = busNumber.trim();
  final num? numericId = num.tryParse(normalized);
  int polylineIndex = 0;

  for (final doc in docs) {
    final data = doc.data();
    final busId = data['bus_id'];
    if (!_busMatches(busId, normalized, numericId)) continue;

    final paths = data['paths'];
    if (paths is! List) continue;

    for (final path in paths) {
      if (path is! Map) continue;
      final segments = path['segments'];
      if (segments is! List) continue;
      final points = <LatLng>[];
      for (final coord in segments) {
        if (coord is Map) {
          final lat = (coord['lat'] as num?)?.toDouble();
          final lon = (coord['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            points.add(LatLng(lat, lon));
          }
        }
      }
      if (points.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_${doc.id}_${polylineIndex++}'),
            points: points,
            color: color,
            width: 4,
            patterns: [PatternItem.dash(30), PatternItem.gap(12)],
          ),
        );
      }
    }
  }
  return polylines;
}

bool _busMatches(dynamic value, String normalized, num? numericId) {
  if (value == null) return false;
  if (value is num) {
    if (numericId == null) return false;
    return value.toInt() == numericId.toInt();
  }
  return value.toString().trim() == normalized;
}