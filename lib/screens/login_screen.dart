import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/premium_button.dart';
import 'admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSignInMode = true;
  String? _errorMessage;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignInMode = !_isSignInMode;
      _errorMessage = null;
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
    });
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      if (_isSignInMode) {
        // Sign In Flow
        await authService.login(
          _emailController.text.trim().isNotEmpty ? _emailController.text : _usernameController.text,
          _passwordController.text,
        );
      } else {
        // Registration Flow
        await authService.register(
          _usernameController.text,
          _emailController.text,
          _passwordController.text,
        );
        
        // Show success / pending dialog
        _showPendingDialog(_emailController.text);
        
        // Switch back to login mode automatically
        _toggleMode();
      }
    } on PendingApprovalException {
      _showPendingDialog(_emailController.text.isNotEmpty ? _emailController.text : _usernameController.text);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Premium interactive dialog for pending account status
  void _showPendingDialog(String userEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_outlined, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Account Pending', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your registration request was successfully saved in the database!',
              style: TextStyle(fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 12),
            Text(
              'User account:\n$userEmail',
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            const Text(
              'To log in, an administrator must manually approve and activate your account status. \n\nFor testing, tap the "Developer Console" link at the bottom of the login screen, select your account, and hit "ACTIVATE".',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // Triggers interactive popup for Google Accounts selection
  Future<void> _handleGoogleLogin() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    final googleAccounts = [
      {'name': 'Alex Carter', 'email': 'alex.carter@gmail.com'},
      {'name': 'Sophia Patel', 'email': 'sophia.patel@gmail.com'},
      {'name': 'Marcus Vance', 'email': 'marcus.vance@gmail.com'},
    ];

    final Map<String, String>? selectedAccount = await showModalBottomSheet<Map<String, String>>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        final customEmailController = TextEditingController();
        final customNameController = TextEditingController();

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Google Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...googleAccounts.map((account) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent.withAlpha(20),
                    child: Text(account['name']![0], style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(account['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(account['email']!),
                  onTap: () => Navigator.of(ctx).pop({'email': account['email']!, 'name': account['name']!}),
                );
              }),
              const Divider(height: 24),
              const Text(
                'Or Type Custom Google Account:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customEmailController,
                decoration: InputDecoration(
                  labelText: 'Google Email',
                  hintText: 'name@gmail.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customNameController,
                decoration: InputDecoration(
                  labelText: 'Google Display Name',
                  hintText: 'John Doe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final email = customEmailController.text.trim();
                    final name = customNameController.text.trim();
                    if (email.isNotEmpty && name.isNotEmpty) {
                      Navigator.of(ctx).pop({'email': email, 'name': name});
                    }
                  },
                  child: const Text('Login with Custom Google ID', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedAccount == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.googleLogin(selectedAccount['email']!, selectedAccount['name']!);
    } on PendingApprovalException {
      _showPendingDialog(selectedAccount['email']!);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
                : [const Color(0xFF74ebd5), const Color(0xFFACB6E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Dynamic Header
                    const SizedBox(height: 16),
                    
                    // Logo Image
                    Card(
                      elevation: 6,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 90,
                          height: 90,
                          color: isDark ? const Color(0xFF1E3C72) : Colors.white,
                          child: Image.asset(
                            'assets/company_logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Elegant fallback if the logo image is missing
                              return Container(
                                color: Colors.blueAccent,
                                child: const Center(
                                  child: Icon(Icons.token, color: Colors.white, size: 40),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ProdTrack',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white : const Color(0xFF1E3C72),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignInMode ? 'Secure Business Tracking Suite' : 'Create Enterprise Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Main Glassmorphic Form Card
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(235),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSignInMode ? 'Account Access' : 'Sign-up Form',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              
                              // Display Error Messages beautifully
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.redAccent.withAlpha(80)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_outlined, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Username / Identifier Field
                              CustomTextField(
                                controller: _isSignInMode ? _emailController : _usernameController,
                                label: _isSignInMode ? 'Username or Email' : 'Username',
                                icon: Icons.person_outline,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter a ${_isSignInMode ? 'username or email' : 'username'}';
                                  }
                                  if (!_isSignInMode && val.trim().length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),

                              // Email Field (Only visible in Register Mode)
                              if (!_isSignInMode) ...[
                                CustomTextField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter an email address';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // Password Field
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (!_isSignInMode && val.trim().length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Submit Button
                              PremiumButton(
                                text: _isSignInMode ? 'AUTHENTICATE' : 'REGISTER ACCOUNT',
                                isLoading: _isLoading,
                                onPressed: _handleSubmit,
                                gradientColors: [
                                  const Color(0xFF1E3C72),
                                  const Color(0xFF2A5298),
                                ],
                              ),

                              // Google Auth Switcher
                              if (_isSignInMode) ...[
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Text(
                                        'OR CONNECT VIA',
                                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Beautiful Google button
                                PremiumButton(
                                  text: 'Sign in with Google',
                                  isSecondary: true,
                                  icon: Icons.g_mobiledata,
                                  onPressed: _handleGoogleLogin,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Toggle Register vs Sign In
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignInMode ? "New to ProdTrack? " : "Already have an account? ",
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isSignInMode ? "Create Account" : "Access Console",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),

                    // Direct Developer Bypass Shortcut
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.blueAccent),
                      label: const Text(
                        'Launch Developer Control Console',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
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
