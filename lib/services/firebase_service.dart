import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/log_model.dart';
import '../firebase_config.dart';

class FirebaseService {
  // Use a singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  String? _customDatabaseUrl;

  // Allows the administrator to dynamically set/update the Firebase URL in-app
  Future<void> setCustomDatabaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      await prefs.remove('custom_db_url');
      _customDatabaseUrl = null;
    } else {
      // Ensure the URL has a protocol and ends properly
      if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
        trimmedUrl = 'https://$trimmedUrl';
      }
      if (!trimmedUrl.endsWith('.json') && !trimmedUrl.endsWith('/')) {
        trimmedUrl = '$trimmedUrl/';
      }
      await prefs.setString('custom_db_url', trimmedUrl);
      _customDatabaseUrl = trimmedUrl;
    }
  }

  Future<String> getDatabaseUrl() async {
    if (_customDatabaseUrl != null) return _customDatabaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_db_url');
    if (saved != null && saved.isNotEmpty) {
      _customDatabaseUrl = saved;
      return saved;
    }
    return FirebaseConfig.databaseUrl;
  }

  Future<bool> isUsingFirebase() async {
    final url = await getDatabaseUrl();
    return url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));
  }

  // --- Users Operations ---
  
  // Fetch user by UID
  Future<UserModel?> getUser(String uid) async {
    final isFirebase = await isUsingFirebase();
    if (!isFirebase) {
      return _getMockUser(uid);
    }
    
    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}users/$uid.json';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200 && response.body != 'null') {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return UserModel.fromJson(data);
      }
      return _getMockUser(uid); // fallback to local mock user if not found in Firebase (e.g. local seeds)
    } catch (e) {
      print("Firebase GET user error: $e");
      return _getMockUser(uid); // Robust fallback
    }
  }

  // Save or update a user profile
  Future<void> saveUser(UserModel user) async {
    // Always save locally to maintain local state fallback
    await _saveMockUser(user);

    final isFirebase = await isUsingFirebase();
    if (!isFirebase) return;

    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}users/${user.uid}.json';
      
      final response = await http.put(
        Uri.parse(url),
        body: json.encode(user.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        throw Exception("Failed to save user in Firebase. Code: ${response.statusCode}");
      }
    } catch (e) {
      print("Firebase PUT user error: $e. Saved locally.");
    }
  }

  // Update a user's status (Pending <-> Active)
  Future<void> updateUserStatus(String uid, String status) async {
    // Update local state
    final user = await _getMockUser(uid);
    if (user != null) {
      await _saveMockUser(user.copyWith(status: status));
    }

    final isFirebase = await isUsingFirebase();
    if (!isFirebase) return;

    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}users/$uid.json';
      
      final response = await http.patch(
        Uri.parse(url),
        body: json.encode({'status': status}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        throw Exception("Failed to update status in Firebase");
      }
    } catch (e) {
      print("Firebase PATCH user status error: $e. Updated locally.");
    }
  }

  // Fetch a user by their username or email
  Future<UserModel?> getUserByUsernameOrEmail(String identifier) async {
    final users = await getAllUsers();
    final lowerId = identifier.trim().toLowerCase();
    for (var u in users) {
      if (u.username.toLowerCase() == lowerId || u.email.toLowerCase() == lowerId) {
        return u;
      }
    }
    return null;
  }

  // Retrieve all registered users (for admin panel status toggling)
  Future<List<UserModel>> getAllUsers() async {
    final mockUsers = await _getAllMockUsers();
    
    final isFirebase = await isUsingFirebase();
    if (!isFirebase) {
      return mockUsers;
    }

    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}users.json';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.body != 'null') {
        final Map<String, dynamic> usersMap = json.decode(response.body);
        final List<UserModel> list = [];
        usersMap.forEach((key, value) {
          if (value != null) {
            list.add(UserModel.fromJson(Map<String, dynamic>.from(value)));
          }
        });
        
        // Sync Firebase users to our local database for persistent backup
        for (var firebaseUser in list) {
          await _saveMockUser(firebaseUser);
        }
        return list;
      }
      return mockUsers;
    } catch (e) {
      print("Firebase GET all users error: $e. Loading local list.");
      return mockUsers;
    }
  }

  // --- Logs Operations ---

  // Write a success or failure log to Firebase
  Future<void> writeLog(LogModel log) async {
    // Always write locally
    await _writeMockLog(log);

    final isFirebase = await isUsingFirebase();
    if (!isFirebase) return;

    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}logs/${log.id}.json';
      
      final response = await http.put(
        Uri.parse(url),
        body: json.encode(log.toJson()),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        throw Exception("Failed to write log in Firebase");
      }
    } catch (e) {
      print("Firebase PUT log error: $e. Logged locally.");
    }
  }

  // Retrieve all system logs (success & failure)
  Future<List<LogModel>> getAllLogs() async {
    final mockLogs = await _getAllMockLogs();

    final isFirebase = await isUsingFirebase();
    if (!isFirebase) {
      return mockLogs;
    }

    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}logs.json';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.body != 'null') {
        final Map<String, dynamic> logsMap = json.decode(response.body);
        final List<LogModel> list = [];
        logsMap.forEach((key, value) {
          if (value != null) {
            list.add(LogModel.fromJson(Map<String, dynamic>.from(value)));
          }
        });
        // Sort descending by timestamp
        list.sort((a, b) => b.when.compareTo(a.when));
        return list;
      }
      return mockLogs;
    } catch (e) {
      print("Firebase GET all logs error: $e. Loading local logs.");
      return mockLogs;
    }
  }

  // Clear logs completely
  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mock_logs');

    final isFirebase = await isUsingFirebase();
    if (!isFirebase) return;

    try {
      final baseUrl = await getDatabaseUrl();
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final url = '${cleanUrl}logs.json';
      await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 4));
    } catch (e) {
      print("Firebase DELETE logs error: $e");
    }
  }

  // --- SharedPreferences Local Sandbox / Mock DB Logic ---

  Future<UserModel?> _getMockUser(String uid) async {
    final users = await _getAllMockUsers();
    try {
      return users.firstWhere((u) => u.uid == uid);
    } catch (_) {
      return null;
    }
  }

  Future<List<UserModel>> _getAllMockUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mock_users');
    if (jsonStr == null) {
      // Seed initial credentials for quick testing out-of-the-box!
      final defaultUsers = [
        UserModel(
          uid: 'admin_test',
          username: 'admin',
          email: 'admin@prodtrack.com',
          status: 'active',
          isGoogleUser: false,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        UserModel(
          uid: 'pending_test',
          username: 'pending_user',
          email: 'pending@prodtrack.com',
          status: 'pending',
          isGoogleUser: false,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      await prefs.setString('mock_users', json.encode(defaultUsers.map((u) => u.toJson()).toList()));
      return defaultUsers;
    }
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((item) => UserModel.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<void> _saveMockUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _getAllMockUsers();
    final index = users.indexWhere((u) => u.uid == user.uid);
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    await prefs.setString('mock_users', json.encode(users.map((u) => u.toJson()).toList()));
  }

  Future<List<LogModel>> _getAllMockLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('mock_logs');
    if (jsonStr == null) return [];
    final List<dynamic> list = json.decode(jsonStr);
    final sorted = list.map((item) => LogModel.fromJson(Map<String, dynamic>.from(item))).toList();
    sorted.sort((a, b) => b.when.compareTo(a.when));
    return sorted;
  }

  Future<void> _writeMockLog(LogModel log) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await _getAllMockLogs();
    logs.add(log);
    await prefs.setString('mock_logs', json.encode(logs.map((l) => l.toJson()).toList()));
  }
}
