import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service for managing bus routes in Firebase Firestore
/// Uses a separate Firebase project (bus-mobile-app-4bebd) for storage
/// while OAuth uses the default project (route-optimization-474616)
class FirebaseRouteService {
  // Use the 'storage' Firebase app instance for Firestore
  static FirebaseFirestore get _firestore {
    final storageApp = Firebase.app('storage');
    return FirebaseFirestore.instanceFor(app: storageApp);
  }
  
  // Use the default Firebase app instance for Auth (OAuth project)
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection names
  static const String _routesCollection = 'bus_routes';
  static const String _routeSessionsCollection = 'route_sessions';
  
  /// Gets the current user's email from OAuth project, returns null if not authenticated
  /// We use email as identifier since auth is in a different project
  static String? get _currentUserEmail => _auth.currentUser?.email;
  
  /// Gets the current user ID from OAuth project, returns null if not authenticated
  static String? get _currentUserId => _auth.currentUser?.uid;
  
  /// Converts nested arrays to Firestore-compatible format
  /// Firestore doesn't support nested arrays, so we convert paths to array of maps
  /// Input: paths = [[{lat, lon}, {lat, lon}], [{lat, lon}]]
  /// Output: paths = [{segments: [{lat, lon}, {lat, lon}]}, {segments: [{lat, lon}]}]
  static dynamic _convertPathsForFirestore(dynamic paths) {
    if (paths == null) return null;
    if (paths is! List) return paths;
    
    // paths is an array of path segments (each segment is an array of coordinates)
    // Each coordinate is already a map {lat: ..., lon: ...} from the C++ code
    final List<dynamic> convertedPaths = [];
    
    for (final pathSegment in paths) {
      if (pathSegment is List) {
        // Wrap the array in a map with 'segments' key
        // This converts [[...]] to [{segments: [...]}]
        convertedPaths.add({'segments': pathSegment});
      } else if (pathSegment is Map) {
        // Already a map, just wrap it
        convertedPaths.add({'segments': [pathSegment]});
      } else {
        // Unknown format, try to preserve it
        convertedPaths.add({'segments': [pathSegment]});
      }
    }
    
    return convertedPaths;
  }
  
  /// Converts routes array, replacing nested paths with Firestore-compatible format
  static List<dynamic> _convertRoutesForFirestore(List<dynamic> routes) {
    return routes.map((route) {
      if (route is Map<String, dynamic>) {
        final convertedRoute = Map<String, dynamic>.from(route);
        if (convertedRoute.containsKey('paths')) {
          convertedRoute['paths'] = _convertPathsForFirestore(convertedRoute['paths']);
        }
        return convertedRoute;
      }
      return route;
    }).toList();
  }
  
  /// Saves bus routes to Firestore after route generation completes
  /// 
  /// [routes] - List of route data from Phase 3
  /// [sessionData] - Optional full session data (school, bus_yard, students, stops, assignments, etc.)
  /// 
  /// Returns the document ID of the saved route session, or null if user is not authenticated
  static Future<String?> saveBusRoutes(
    List<dynamic> routes, {
    Map<String, dynamic>? sessionData,
  }) async {
    final userEmail = _currentUserEmail;
    final userId = _currentUserId;
    
    if (userEmail == null || userId == null) {
      print('ERROR: User not authenticated. Cannot save routes to Firestore.');
      return null;
    }
    
    try {
      final timestamp = FieldValue.serverTimestamp();
      
      // Convert routes to Firestore-compatible format (handle nested arrays)
      final convertedRoutes = _convertRoutesForFirestore(routes);
      
      // Create a route session document that contains metadata and all routes
      // Store both email and user_id for flexibility (email for matching, user_id for reference)
      final routeSessionData = <String, dynamic>{
        'user_email': userEmail, // Primary identifier from OAuth project
        'user_id': userId, // User ID from OAuth project for reference
        'created_at': timestamp,
        'updated_at': timestamp,
        'route_count': routes.length,
        'routes': convertedRoutes,
      };
      
      // Add optional session data if provided
      if (sessionData != null) {
        // Include relevant session data (school, bus_yard, etc.) but not the full graph
        if (sessionData.containsKey('school')) {
          routeSessionData['school'] = sessionData['school'];
        }
        if (sessionData.containsKey('bus_yard')) {
          routeSessionData['bus_yard'] = sessionData['bus_yard'];
        }
        if (sessionData.containsKey('students')) {
          routeSessionData['students'] = sessionData['students'];
        }
        if (sessionData.containsKey('buses')) {
          routeSessionData['buses'] = sessionData['buses'];
        }
        if (sessionData.containsKey('stops')) {
          routeSessionData['stops'] = sessionData['stops'];
        }
        if (sessionData.containsKey('assignments')) {
          routeSessionData['assignments'] = sessionData['assignments'];
        }
        if (sessionData.containsKey('evals')) {
          routeSessionData['evals'] = sessionData['evals'];
        }
      }
      
      // Save to route_sessions collection
      final sessionDocRef = await _firestore
          .collection(_routeSessionsCollection)
          .add(routeSessionData);
      
      print('Successfully saved route session to Firestore: ${sessionDocRef.id}');
      
      // Also save individual routes for easier querying
      final batch = _firestore.batch();
      for (final route in routes) {
        if (route is Map<String, dynamic>) {
          final routeDocRef = _firestore
              .collection(_routesCollection)
              .doc();
          
          // Convert paths to Firestore-compatible format
          final convertedPaths = _convertPathsForFirestore(route['paths']);
          
          final routeData = <String, dynamic>{
            'user_email': userEmail, // Primary identifier from OAuth project
            'user_id': userId, // User ID from OAuth project for reference
            'session_id': sessionDocRef.id,
            'route_id': route['id'],
            'assignment_id': route['assignment'],
            'stops': route['stops'],
            'paths': convertedPaths, // Firestore-compatible format
            'travel_time': route['travel_time'],
            'created_at': timestamp,
          };
          
          // Get bus ID from assignment if available in sessionData
          if (sessionData != null && sessionData.containsKey('assignments')) {
            final assignments = sessionData['assignments'] as List<dynamic>?;
            if (assignments != null) {
              final assignmentId = route['assignment'];
              final assignment = assignments.firstWhere(
                (a) => a['id'] == assignmentId,
                orElse: () => null,
              );
              if (assignment != null && assignment['bus'] != null) {
                routeData['bus_id'] = assignment['bus'];
              }
            }
          }
          
          batch.set(routeDocRef, routeData);
        }
      }
      
      await batch.commit();
      print('Successfully saved ${routes.length} individual routes to Firestore');
      
      return sessionDocRef.id;
    } catch (e) {
      print('ERROR: Failed to save routes to Firestore: $e');
      rethrow;
    }
  }
  
  /// Retrieves all route sessions for the current user
  /// Returns a stream of route session documents
  static Stream<QuerySnapshot> getUserRouteSessions() {
    final userEmail = _currentUserEmail;
    if (userEmail == null) {
      throw Exception('User not authenticated');
    }
    
    return _firestore
        .collection(_routeSessionsCollection)
        .where('user_email', isEqualTo: userEmail)
        .orderBy('created_at', descending: true)
        .snapshots();
  }
  
  /// Retrieves all routes for a specific session
  static Future<QuerySnapshot> getRoutesForSession(String sessionId) async {
    final userEmail = _currentUserEmail;
    if (userEmail == null) {
      throw Exception('User not authenticated');
    }
    
    return await _firestore
        .collection(_routesCollection)
        .where('user_email', isEqualTo: userEmail)
        .where('session_id', isEqualTo: sessionId)
        .get();
  }
  
  /// Retrieves a specific route session by document ID
  static Future<DocumentSnapshot> getRouteSession(String sessionId) async {
    final userEmail = _currentUserEmail;
    if (userEmail == null) {
      throw Exception('User not authenticated');
    }
    
    final doc = await _firestore
        .collection(_routeSessionsCollection)
        .doc(sessionId)
        .get();
    
    // Verify the session belongs to the current user
    if (doc.exists && doc.data()?['user_email'] == userEmail) {
      return doc;
    } else {
      throw Exception('Route session not found or access denied');
    }
  }
  
  /// Retrieves all routes for a specific bus (across all sessions)
  static Stream<QuerySnapshot> getRoutesForBus(int busId) {
    final userEmail = _currentUserEmail;
    if (userEmail == null) {
      throw Exception('User not authenticated');
    }
    
    return _firestore
        .collection(_routesCollection)
        .where('user_email', isEqualTo: userEmail)
        .where('bus_id', isEqualTo: busId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }
  
  /// Deletes a route session and all associated routes
  static Future<void> deleteRouteSession(String sessionId) async {
    final userEmail = _currentUserEmail;
    if (userEmail == null) {
      throw Exception('User not authenticated');
    }
    
    // Verify ownership
    final sessionDoc = await _firestore
        .collection(_routeSessionsCollection)
        .doc(sessionId)
        .get();
    
    if (!sessionDoc.exists || sessionDoc.data()?['user_email'] != userEmail) {
      throw Exception('Route session not found or access denied');
    }
    
    // Delete all routes for this session
    final routesSnapshot = await _firestore
        .collection(_routesCollection)
        .where('session_id', isEqualTo: sessionId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in routesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete the session document
    batch.delete(sessionDoc.reference);
    
    await batch.commit();
    print('Successfully deleted route session and ${routesSnapshot.docs.length} routes');
  }
}

