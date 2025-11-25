import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user data and roles
class UserProfile {
  final String role;
  final String busNumber;
  final String displayName;
  const UserProfile({
    required this.role,
    required this.busNumber,
    required this.displayName,
  });
  
  bool get hasRole => role.isNotEmpty;
  bool get hasBusAssignment => busNumber.isNotEmpty;
  
  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      role: (data['role'] as String?)?.trim() ?? '',
      busNumber: (data['bus_number'] as String?)?.trim() ?? '',
      displayName: (data['display_name'] as String?)?.trim() ?? '',
    );
  }
}

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _fieldRole = 'role';
  static const String _fieldBusNumber = 'bus_number';
  static const String _fieldDisplayName = 'display_name';
  static const String _fieldCreated = 'created_at';
  static const String _fieldUpdated = 'updated_at';
  
  /// User roles
  static const String roleDriver = 'driver';
  static const String roleStudent = 'student';
  
  /// Saves/updates the user's role and bus assignment in Firestore.
  static Future<bool> saveUserProfile(
    String userId, {
    required String role,
    required String busNumber,
    required String displayName,
  }) async {
    try {
      final docRef = _firestore.collection(_usersCollection).doc(userId);
      final existing = await docRef.get();
  
      await docRef.set({
        _fieldRole: role,
        _fieldBusNumber: busNumber,
        _fieldDisplayName: displayName,
        _fieldUpdated: FieldValue.serverTimestamp(),
        if (!existing.exists) _fieldCreated: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
  
      print('Successfully saved user profile for $userId (role: $role, bus: $busNumber)');
      return true;
    } catch (e) {
      print('ERROR: Failed to save user profile: $e');
      return false;
    }
  }
  
  /// Backwards-compatible helper that only stores the role.
  /// Prefer [saveUserProfile] which also tracks bus assignments.
  static Future<bool> saveUserRole(String userId, String role) async {
    return saveUserProfile(
      userId,
      role: role,
      busNumber: '',
      displayName: '',
    );
  }
  
  /// Retrieves the full user profile (role + bus assignment).
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } on FirebaseException catch (e) {
      print('ERROR: Failed to get user profile: ${e.message}');
      if (e.code == 'permission-denied') {
        return null;
      }
      return null;
    } catch (e) {
      print('ERROR: Failed to get user profile: $e');
      return null;
    }
  }
  
  /// Convenience getters for just the role to avoid breaking older callers.
  static Future<String?> getUserRole(String userId) async {
    final profile = await getUserProfile(userId);
    return profile?.role;
  }
  
  static Future<String?> getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return getUserRole(user.uid);
  }
  
  /// Stream any profile changes.
  static Stream<UserProfile?> watchUserProfile(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    });
  }
  
  /// Update only the bus assignment.
  static Future<bool> updateBusAssignment(String userId, String busNumber) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        _fieldBusNumber: busNumber,
        _fieldUpdated: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } on FirebaseException catch (e) {
      print('ERROR: Failed to update bus assignment: ${e.message}');
      return false;
    } catch (e) {
      print('ERROR: Failed to update bus assignment: $e');
      return false;
    }
  }
}

