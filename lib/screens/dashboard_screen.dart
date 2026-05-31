import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'admin_panel_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _remainingTime = authService.remainingSessionTime;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      final auth = Provider.of<AuthService>(context, listen: false);
      setState(() {
        _remainingTime = auth.remainingSessionTime;
      });

      // If token expired (reached zero), the AuthService timer will auto-logout,
      // but we also trigger it here to ensure immediate UI redirection.
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        auth.logout(autoLoggedOut: true, reason: 'Session expired (1-hour token validity reached)');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final user = authService.currentUser;
    final isDark = themeService.isDarkMode;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ProdTrack Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Theme toggler
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? Colors.yellow : Colors.blueGrey,
            ),
            tooltip: 'Switch Theme',
            onPressed: () => themeService.toggleTheme(),
          ),
          // Developer Panel shortcut
          IconButton(
            icon: const Icon(Icons.developer_mode_outlined),
            tooltip: 'Developer Console',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () => authService.logout(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
                : [const Color(0xFFECE9E6), const Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.blueAccent.withAlpha(50), Colors.purpleAccent.withAlpha(20)]
                          : [Colors.blueAccent.withAlpha(15), Colors.lightBlueAccent.withAlpha(10)],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.blueAccent.withAlpha(40),
                        child: Text(
                          user.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.username,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'ACTIVE SESSION',
                                    style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Expiration countdown card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty_outlined, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text(
                            'Session Expiry Monitor',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Live Countdown Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.black.withAlpha(8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blueAccent.withAlpha(50)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _formatDuration(_remainingTime),
                              style: TextStyle(
                                fontSize: 44,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: _remainingTime.inMinutes < 10 ? Colors.redAccent : Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TOKEN VALIDITY REMAINING (1 HOUR MAX)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your security token is generated upon login. After exactly 1 hour, your credentials will automatically terminate and return you to the login screen for safety.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          authService.validateSessionAlive();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session verified. Token status: ALIVE.')),
                          );
                        },
                        icon: const Icon(Icons.verified_user_outlined, size: 16),
                        label: const Text('Verify Token Status', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Profile details section
              const Text(
                'Account Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.email_outlined, 'Email Address', user.email, isDark),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.security_outlined, 
                        'Authorization status', 
                        user.status.toUpperCase(), 
                        isDark,
                        valueColor: Colors.green,
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.settings_input_component_outlined, 
                        'Provider type', 
                        user.isGoogleUser ? 'Google Sign-In' : 'Email/Password Credentials', 
                        isDark
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.calendar_today_outlined, 
                        'Registered Date', 
                        DateFormat('yyyy-MM-dd HH:mm').format(user.createdAt), 
                        isDark
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.key_outlined, 
                        'Active Session Token', 
                        authService.sessionToken ?? 'None', 
                        isDark,
                        isMonospace: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dev flow guide banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Testing Pending States?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap the Developer Console shortcut in the top right. You can immediately register a new user, view them as PENDING, and activate them manually to complete the login sequence.',
                      style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open Console Now', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, {Color? valueColor, bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: isMonospace ? 'monospace' : null,
                  color: valueColor ?? (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
