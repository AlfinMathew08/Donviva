import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_store.dart';

/// Central service that wraps Firebase Auth and Firestore operations.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Auth ────────────────────────────────────────────────────────────────

  /// Currently signed-in user (null if not logged in).
  User? get currentUser => _auth.currentUser;

  /// Stream that emits whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email + password and save extra profile data to Firestore.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String age,
    required String gender,
    required String bloodGroup,
    required String location,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(name);

    // Save profile to Firestore
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'name': name,
      'email': email.trim(),
      'phone': phone,
      'age': age,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'location': location,
      'donationCount': 0,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  /// Sign in with email + password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Send a password-reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out from both Firebase and Google.
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// Sign in with Google account — creates Firestore profile on first login.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);

    // Save profile to Firestore only on first sign-in
    final doc = await _db.collection('users').doc(userCred.user!.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'name': userCred.user!.displayName ?? '',
        'email': userCred.user!.email ?? '',
        'phone': userCred.user!.phoneNumber ?? '',
        'age': '',
        'gender': '',
        'bloodGroup': '',
        'location': '',
        'donationCount': 0,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return userCred;
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  /// Fetch the current user's Firestore profile document.
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      final userStore = UserStore.instance;
      userStore.isAdmin = data['isAdmin'] ?? false;
      // You might want to sync other fields here if needed
    }
    return data;
  }

  /// Update specific fields in the current user's profile.
  Future<void> updateUserProfile(Map<String, dynamic> fields) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update(fields);
  }

  // ─── Blood Requests ───────────────────────────────────────────────────────

  /// Post a new blood request to Firestore.
  Future<DocumentReference> postBloodRequest({
    required String patientName,
    required String hospital,
    required String contact,
    required String bloodGroup,
    required String urgency,
    double? latitude,
    double? longitude,
  }) async {
    final uid = currentUser?.uid;
    return _db.collection('bloodRequests').add({
      'patientName': patientName,
      'hospital': hospital,
      'contact': contact,
      'bloodGroup': bloodGroup,
      'urgency': urgency,
      'latitude': latitude,
      'longitude': longitude,
      'status': 'Pending',
      'submittedBy': uid ?? 'anonymous',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of blood requests submitted by the current user.
  /// Note: sorted client-side to avoid requiring a composite Firestore index.
  Stream<QuerySnapshot> myBloodRequestsStream() {
    final uid = currentUser?.uid ?? 'anonymous';
    return _db
        .collection('bloodRequests')
        .where('submittedBy', isEqualTo: uid)
        .snapshots();
  }

  /// Stream of ALL blood requests (for home feed / discover), newest first.
  Stream<QuerySnapshot> allBloodRequestsStream() {
    return _db
        .collection('bloodRequests')
        .orderBy('submittedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Update the status of a blood request (e.g. 'Active', 'Fulfilled').
  Future<void> updateRequestStatus(String docId, String newStatus) async {
    await _db.collection('bloodRequests').doc(docId).update({
      'status': newStatus,
    });
  }

  // ─── Donation Interest ────────────────────────────────────────────────────

  /// Record that the current user wants to donate blood.
  Future<void> submitDonationInterest({
    required String bloodGroup,
    required String location,
    required String notes,
  }) async {
    final uid = currentUser?.uid;
    final profile = await fetchUserProfile();
    await _db.collection('donationInterests').add({
      'uid': uid ?? 'anonymous',
      'donorName': profile?['name'] ?? 'Anonymous',
      'bloodGroup': bloodGroup,
      'location': location,
      'notes': notes,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of donation interests for the current user.
  /// Note: sorted client-side to avoid requiring a composite Firestore index.
  Stream<QuerySnapshot> myDonationInterestsStream() {
    final uid = currentUser?.uid ?? 'anonymous';
    return _db
        .collection('donationInterests')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // ─── Chat History ─────────────────────────────────────────────────────────

  /// Save a single chat message for the current user.
  Future<void> saveChatMessage({
    required String text,
    required bool isUser,
    required DateTime timestamp,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .add({
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
    });
  }

  /// Load the last [limit] chat messages for the current user, oldest first.
  Future<List<Map<String, dynamic>>> loadChatHistory({int limit = 100}) async {
    final uid = currentUser?.uid;
    if (uid == null) return [];
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// Delete all chat history for the current user.
  Future<void> clearChatHistory() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ─── Emergency Banners ─────────────────────────────────────────────────────

  /// Real-time stream of all active emergency banners (newest first).
  Stream<QuerySnapshot> emergencyBannersStream() {
    return _db
        .collection('emergencyBanners')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Add a new emergency banner visible to all users.
  Future<void> addEmergencyBanner({
    required String name,
    required int age,
    required String bloodType,
    required String hospital,
    required String location,
    required String contact,
    double? latitude,
    double? longitude,
  }) async {
    await _db.collection('emergencyBanners').add({
      'name': name,
      'age': age,
      'bloodType': bloodType,
      'hospital': hospital,
      'location': location,
      'contact': contact,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'postedBy': currentUser?.uid ?? 'anonymous',
    });
  }

  /// Delete a specific emergency banner by its Firestore document ID.
  Future<void> deleteEmergencyBanner(String docId) async {
    await _db.collection('emergencyBanners').doc(docId).delete();
  }
}
