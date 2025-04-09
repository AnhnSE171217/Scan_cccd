import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'check_event_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final CameraDescription camera;

  const HomeScreen({super.key, required this.camera});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _username = 'User';
  String _userRole = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controller with shorter duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // Half the original duration
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Start animation immediately
    _animationController.forward();

    // Load user data in the background after animation
    Future.microtask(() => _loadUserData());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? prefs.getString('username') ?? '';

    String displayName = 'User';
    if (email.isNotEmpty) {
      // Extract the name part from the email (before the @ symbol)
      final nameFromEmail = email.split('@').first;

      // Capitalize the first letter of the name
      if (nameFromEmail.isNotEmpty) {
        displayName =
            nameFromEmail[0].toUpperCase() +
            (nameFromEmail.length > 1 ? nameFromEmail.substring(1) : '');
      }
    }

    if (mounted) {
      setState(() {
        _username = displayName;
        _userRole = prefs.getString('userRole') ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Đăng xuất'),
                content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();

      // Remove all user-related data
      await prefs.clear();

      // Animate out before navigating
      _animationController.reverse();
      await Future.delayed(const Duration(milliseconds: 300));

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen(camera: widget.camera)),
          (route) => false,
        );
      }
    }
  }

  void _navigateToEventScreen() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckEventScreen(camera: widget.camera),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_rounded, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Trang chủ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _logout(context),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF7F50),
                        ),
                      ),
                    )
                    : _buildHomeContent(),
          );
        },
      ),
    );
  }

  // Extract the home content to a separate method
  Widget _buildHomeContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadUserData,
        color: const Color(0xFFFF7F50),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Welcome card with animated entrance
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuad,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA07A), Color(0xFFFFDAB9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Hero(
                              tag: 'userAvatar',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      // Replace withOpacity with Color.fromARGB
                                      color: const Color(
                                        0x1A000000,
                                      ), // 10% black opacity
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 30,
                                  child: Icon(
                                    Icons.person,
                                    size: 35,
                                    color: Color(0xFFFF7F50),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Xin chào,',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.brown[800],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _username,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown[800],
                                      letterSpacing: 0.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_userRole.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              // Fix 1: Replace withOpacity with Color.fromARGB
                              color: const Color(0x80FFFFFF), // 50% white
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                // Fix 2: Replace withOpacity with Color.fromARGB
                                color: const Color(0x80FFFFFF), // 50% white
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _userRole == 'ADMIN'
                                      ? Icons.shield
                                      : _userRole == 'MANAGER'
                                      ? Icons.business_center
                                      : Icons.person,
                                  size: 18,
                                  color: Colors.brown[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _userRole,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.brown[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Action buttons
            const SizedBox(height: 8),

            // Main action button with bounce animation
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.95, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 8,
                    ),
                    height: 65,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7F50), Color(0xFFFF6347)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40FF6347), // 25% opacity
                          offset: Offset(0, 4),
                          blurRadius: 12.0,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      // Fix 3: Replace non-existent icon
                      icon: const Icon(
                        Icons.qr_code_scanner, // Changed icon
                        color: Colors.white,
                        size: 24,
                      ),
                      label: const Text(
                        'Kiểm tra sự kiện',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _navigateToEventScreen,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
