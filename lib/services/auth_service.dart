import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/log_model.dart';
import 'firebase_service.dart';

class PendingApprovalException implements Exception {
  final String message;
  PendingApprovalException(this.message);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  UserModel? _currentUser;
  String? _sessionToken;
  DateTime? _loginTime;
  bool _isLoading = false;
  Timer? _sessionTimer;

  UserModel? get currentUser => _currentUser;
  String? get sessionToken => _sessionToken;
  DateTime? get loginTime => _loginTime;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _sessionToken != null && _currentUser != null;

  // Returns the duration remaining for the 1-hour session token
  Duration get remainingSessionTime {
    if (_loginTime == null) return Duration.zero;
    final expiryTime = _loginTime!.add(const Duration(hours: 1));
    final difference = expiryTime.difference(DateTime.now());
    return difference.isNegative ? Duration.zero : difference;
  }

  AuthService() {
    checkSession();
  }

  // --- Auth Actions ---

  // Check on startup if session token is valid (valid for 1 hour)
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final savedLoginTimeStr = prefs.getString('auth_login_time');
      final savedUid = prefs.getString('auth_uid');

      if (token != null && savedLoginTimeStr != null && savedUid != null) {
        final savedLoginTime = DateTime.parse(savedLoginTimeStr);
        final elapsed = DateTime.now().difference(savedLoginTime);

        if (elapsed.inHours < 1) {
          // Token is valid! Fetch user status to verify they are still active
          final user = await _firebaseService.getUser(savedUid);
          if (user != null && user.status == 'active') {
            _currentUser = user;
            _sessionToken = token;
            _loginTime = savedLoginTime;
            
            // Start expiration timer
            _startSessionTimer(const Duration(hours: 1) - elapsed);
          } else {
            // User was deactivated or deleted
            await logout(autoLoggedOut: true, reason: user != null ? 'Account is pending approval' : 'Account not found');
          }
        } else {
          // Session expired
          await logout(autoLoggedOut: true, reason: 'Session expired (over 1 hour)');
        }
      }
    } catch (e) {
      print("Check session error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // User Registration
  Future<UserModel> register(String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final cleanUsername = username.trim();
    final cleanEmail = email.trim();

    try {
      // 1. Check if user already exists
      final existingUser = await _firebaseService.getUserByUsernameOrEmail(cleanUsername);
      final existingEmail = await _firebaseService.getUserByUsernameOrEmail(cleanEmail);

      if (existingUser != null || existingEmail != null) {
        final errorMsg = "Registration failed: Username or Email already exists.";
        await _writeLog(
          type: 'failure',
          who: cleanEmail.isNotEmpty ? cleanEmail : cleanUsername,
          action: errorMsg,
        );
        throw Exception("Username or Email is already registered.");
      }

      // 2. Create User Model (status is pending by default)
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = UserModel(
        uid: uid,
        username: cleanUsername,
        email: cleanEmail,
        status: 'pending', // Pending state
        isGoogleUser: false,
        createdAt: DateTime.now(),
      );

      // 3. Save User Profile in Realtime DB
      await _firebaseService.saveUser(newUser);

      // 4. Save User Credentials (Secure simulation)
      await _saveCredentials(uid, password);

      // 5. Log this registration attempt
      await _writeLog(
        type: 'failure', // Registration is pending activation, so they cannot login yet
        who: cleanEmail,
        action: 'Account registered successfully. Status: PENDING approval.',
      );

      return newUser;
    } catch (e) {
      print("Registration error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Standard Username / Password Login
  Future<void> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    notifyListeners();

    final identifier = usernameOrEmail.trim();

    try {
      // 1. Fetch user by email or username
      final user = await _firebaseService.getUserByUsernameOrEmail(identifier);
      if (user == null) {
        final errorMsg = "Login failed: User not found.";
        await _writeLog(type: 'failure', who: identifier, action: errorMsg);
        throw Exception("Incorrect username/email or password.");
      }

      // 2. Validate Password
      final isPasswordCorrect = await _verifyCredentials(user.uid, password);
      if (!isPasswordCorrect) {
        final errorMsg = "Login failed: Incorrect password for account.";
        await _writeLog(type: 'failure', who: user.email, action: errorMsg);
        throw Exception("Incorrect username/email or password.");
      }

      // 3. Check Account Status (Pending state check!)
      if (user.status == 'pending') {
        final errorMsg = "Login blocked: Account is in PENDING approval state.";
        await _writeLog(type: 'failure', who: user.email, action: errorMsg);
        throw PendingApprovalException("Your account is pending approval by the administrator. Please wait.");
      }

      // 4. Successful login: Generate and Save 1-hour Token
      final token = 'token_${DateTime.now().millisecondsSinceEpoch}_${user.uid}';
      final now = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_login_time', now.toIso8601String());
      await prefs.setString('auth_uid', user.uid);

      _currentUser = user;
      _sessionToken = token;
      _loginTime = now;

      // Log success
      await _writeLog(
        type: 'success',
        who: user.email,
        action: 'User logged in successfully using credentials.',
      );

      // Start 1-hour session countdown timer
      _startSessionTimer(const Duration(hours: 1));

    } catch (e) {
      print("Login error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Google Login implementation
  Future<void> googleLogin(String googleEmail, String displayName) async {
    _isLoading = true;
    notifyListeners();

    final email = googleEmail.trim();
    final username = displayName.trim().replaceAll(' ', '_').toLowerCase();

    try {
      // 1. Check if user already exists
      UserModel? user = await _firebaseService.getUserByUsernameOrEmail(email);

      if (user == null) {
        // First-time Google Login: Automatically create account with PENDING status!
        final uid = 'google_${DateTime.now().millisecondsSinceEpoch}';
        user = UserModel(
          uid: uid,
          username: username,
          email: email,
          status: 'pending', // PENDING by default
          isGoogleUser: true,
          createdAt: DateTime.now(),
        );

        await _firebaseService.saveUser(user);
        
        final errorMsg = "Google Sign-Up: Account created. Login blocked - PENDING manual activation.";
        await _writeLog(type: 'failure', who: email, action: errorMsg);
        
        throw PendingApprovalException("Your Google account was registered successfully! However, it is pending manual activation by the administrator. Please wait.");
      }

      // 2. Check status of existing user
      if (user.status == 'pending') {
        final errorMsg = "Google Login blocked: Account is in PENDING state.";
        await _writeLog(type: 'failure', who: email, action: errorMsg);
        throw PendingApprovalException("Your Google account is registered but pending manual activation by the administrator.");
      }

      // 3. Successful login: Generate and Save 1-hour Token
      final token = 'google_token_${DateTime.now().millisecondsSinceEpoch}_${user.uid}';
      final now = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_login_time', now.toIso8601String());
      await prefs.setString('auth_uid', user.uid);

      _currentUser = user;
      _sessionToken = token;
      _loginTime = now;

      // Log success
      await _writeLog(
        type: 'success',
        who: email,
        action: 'User logged in successfully via Google Sign-In.',
      );

      // Start 1-hour session countdown timer
      _startSessionTimer(const Duration(hours: 1));

    } catch (e) {
      print("Google Login error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout({bool autoLoggedOut = false, String reason = 'User initiated logout'}) async {
    final who = _currentUser?.email ?? 'unknown_user';
    
    _sessionTimer?.cancel();
    _sessionTimer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_login_time');
    await prefs.remove('auth_uid');

    if (_currentUser != null) {
      await _writeLog(
        type: 'success',
        who: who,
        action: autoLoggedOut ? 'Session auto-terminated: $reason' : 'User logged out.',
      );
    }

    _currentUser = null;
    _sessionToken = null;
    _loginTime = null;
    
    notifyListeners();
  }

  // Trigger manual validation check (can be run on user events to verify token has not expired)
  void validateSessionAlive() {
    if (_loginTime != null) {
      final elapsed = DateTime.now().difference(_loginTime!);
      if (elapsed.inHours >= 1) {
        logout(autoLoggedOut: true, reason: 'Session expired (over 1 hour)');
      }
    }
  }

  // --- Internals & Helper Methods ---

  void _startSessionTimer(Duration duration) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(duration, () {
      logout(autoLoggedOut: true, reason: 'Session expired (1-hour limit reached)');
    });
  }

  // Writes logs in the background to ensure responsive UI
  Future<void> _writeLog({
    required String type,
    required String who,
    required String action,
  }) async {
    final log = LogModel(
      id: 'log_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      who: who,
      action: action,
      when: DateTime.now(),
    );
    await _firebaseService.writeLog(log);
  }

  // Credentials Mock Storage helpers
  Future<void> _saveCredentials(String uid, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mock_creds') ?? '{}';
    final Map<String, dynamic> creds = json.decode(jsonStr);
    creds[uid] = password; // simple demo storage
    await prefs.setString('mock_creds', json.encode(creds));
  }

  Future<bool> _verifyCredentials(String uid, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mock_creds') ?? '{}';
    final Map<String, dynamic> creds = json.decode(jsonStr);
    
    // Seed default admin password if empty
    if (uid == 'admin_test') {
      return password == 'admin123';
    }
    if (uid == 'pending_test') {
      return password == 'pending123';
    }

    return creds[uid] == password;
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
