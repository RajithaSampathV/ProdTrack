import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/log_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _dbUrlController = TextEditingController();
  
  List<UserModel> _users = [];
  List<LogModel> _logs = [];
  bool _isLoading = false;
  bool _isUsingFirebase = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbUrl = await _firebaseService.getDatabaseUrl();
      final isFirebase = await _firebaseService.isUsingFirebase();
      
      if (!mounted) return;
      _dbUrlController.text = dbUrl;
      _isUsingFirebase = isFirebase;

      final users = await _firebaseService.getAllUsers();
      final logs = await _firebaseService.getAllLogs();

      if (!mounted) return;
      setState(() {
        _users = users;
        _logs = logs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading admin console: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    final newStatus = user.status == 'active' ? 'pending' : 'active';
    final authService = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseService.updateUserStatus(user.uid, newStatus);
      
      if (!mounted) return;
      
      // If we deactivated the current logged-in user, auto-log them out!
      if (authService.currentUser?.uid == user.uid && newStatus == 'pending') {
        await authService.logout(autoLoggedOut: true, reason: 'Account deactivated by Administrator.');
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('${user.username} status updated to ${newStatus.toUpperCase()}!'),
          backgroundColor: newStatus == 'active' ? Colors.green : Colors.orange,
        ),
      );
      
      await _loadAdminData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveDatabaseUrl() async {
    final url = _dbUrlController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseService.setCustomDatabaseUrl(url);
      
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Database configuration updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadAdminData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving database config: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Logs?'),
        content: const Text('Are you sure you want to permanently delete all successful and failed access logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
      await _firebaseService.clearLogs();
      await _loadAdminData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ProdTrack Developer Console',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Users Management'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'System Logs'),
              Tab(icon: Icon(Icons.settings_outlined), text: 'Firebase Setup'),
            ],
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: _loadAdminData,
            )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildUsersTab(isDark),
                  _buildLogsTab(isDark),
                  _buildSetupTab(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildUsersTab(bool isDark) {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 64, color: isDark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 16),
            const Text(
              'No users registered yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _users.length,
      itemBuilder: (ctx, idx) {
        final user = _users[idx];
        final isPending = user.status == 'pending';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: user.isGoogleUser ? Colors.redAccent.withAlpha(30) : Colors.blueAccent.withAlpha(30),
                child: Icon(
                  user.isGoogleUser ? Icons.g_mobiledata : Icons.person_outline,
                  color: user.isGoogleUser ? Colors.redAccent : Colors.blueAccent,
                  size: user.isGoogleUser ? 32 : 24,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (user.uid == 'admin_test')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SYSTEM ADMIN',
                        style: TextStyle(fontSize: 8, color: Colors.purple, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(user.email),
                  const SizedBox(height: 2),
                  Text(
                    'Registered: ${DateFormat('yyyy-MM-dd HH:mm').format(user.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.orange.withAlpha(35) : Colors.green.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPending ? Colors.orange.withAlpha(150) : Colors.green.withAlpha(150),
                      ),
                    ),
                    child: Text(
                      user.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPending ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: user.uid == 'admin_test' ? null : () => _toggleUserStatus(user),
                      child: Text(
                        isPending ? 'ACTIVATE' : 'PENDING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: user.uid == 'admin_test' ? Colors.grey : (isPending ? Colors.green : Colors.orange),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab(bool isDark) {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: isDark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 16),
            const Text(
              'No security logs recorded yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Logs: ${_logs.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              TextButton.icon(
                onPressed: _clearLogs,
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                label: const Text('Clear All Logs', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (ctx, idx) {
              final log = _logs[idx];
              final isSuccess = log.type == 'success';

              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                  color: isSuccess 
                      ? Colors.green.withAlpha(isDark ? 8 : 5) 
                      : Colors.red.withAlpha(isDark ? 8 : 5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  log.who,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm:ss').format(log.when),
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.action,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSetupTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Firebase Realtime Database Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect this app directly to your Firebase cloud account. Specify your Realtime Database URL below. It must be in the format: https://<project-id>-default-rtdb.firebaseio.com/',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isUsingFirebase ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isUsingFirebase 
                            ? 'CONNECTED TO FIREBASE CLOUD' 
                            : 'LOCAL SANDBOX DATABASE ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isUsingFirebase ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dbUrlController,
                    decoration: InputDecoration(
                      labelText: 'Firebase RTDB URL',
                      hintText: 'https://your-project-default-rtdb.firebaseio.com/',
                      prefixIcon: const Icon(Icons.cloud_queue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _dbUrlController.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveDatabaseUrl,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Apply Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  if (!_isUsingFirebase) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Running in sandbox fallback! Local data and system logs are saved in SharedPreferences. Register accounts, update their status, and logs will persist locally instantly.',
                              style: TextStyle(fontSize: 11, color: Colors.blue, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Firebase Security Rules (Reference)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: const Text(
              '{\n  "rules": {\n    ".read": true,\n    ".write": true\n  }\n}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste the rules above into your Firebase Realtime DB rules tab in the console to allow direct read/write REST operations for testing.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
