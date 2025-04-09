import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import 'package:logger/logger.dart';
import 'home_screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  final CameraDescription camera;

  const LoginScreen({super.key, required this.camera});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Add these focus nodes
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final _secureStorage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _rememberCredentials = false;
  String _errorMessage = '';
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    // Fix keyboard focus issue by scheduling focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _emailController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_emailFocusNode);
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldRemember = prefs.getBool('remember_credentials') ?? false;

      if (shouldRemember) {
        final email = await _secureStorage.read(key: 'saved_email');
        final password = await _secureStorage.read(key: 'saved_password');

        if (email != null && password != null) {
          setState(() {
            _emailController.text = email;
            _passwordController.text = password;
            _rememberCredentials = true;
          });
        }
      }
    } catch (e) {
      _logger.e('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_credentials', _rememberCredentials);

      if (_rememberCredentials) {
        await _secureStorage.write(
          key: 'saved_email',
          value: _emailController.text,
        );
        await _secureStorage.write(
          key: 'saved_password',
          value: _passwordController.text,
        );

        // Set expiration time (30 days from now)
        final expiryTime =
            DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
        await prefs.setInt('credentials_expiry', expiryTime);
      } else {
        // Clear saved credentials if remember me is unchecked
        await _secureStorage.delete(key: 'saved_email');
        await _secureStorage.delete(key: 'saved_password');
        await prefs.remove('credentials_expiry');
      }
    } catch (e) {
      _logger.e('Error saving credentials: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    // Add these disposes too
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Add this method for enhanced error display
  Widget _buildErrorMessage() {
    if (_errorMessage.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: const Color(0xFFFFCCCC)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29FF0000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Color(0xFFB71C1C),
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        // Save credentials in background
        _saveCredentials(); // No await here

        if (!mounted) return;

        // Show success indicator without waiting
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Login successful!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 600), // Shorter duration
          ),
        );

        // Navigate immediately - no animation delay
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    HomeScreen(camera: widget.camera),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(
              milliseconds: 300,
            ), // Shorter transition
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      _logger.e('Login error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
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
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      // Add this to prevent keyboard dismissal when tapping on empty areas
      onTap: () {
        // Do nothing, which prevents the focus from being lost
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF3E0),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3E0), Color(0xFFFFF8E1)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        screenSize.width > 600 ? screenSize.width * 0.15 : 24.0,
                    vertical: 24.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo/Icon with slight bounce animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      // Replace deprecated withAlpha
                                      color: Color(
                                        0x64FF7F50,
                                      ), // Alpha 100 (0x64)
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.credit_card,
                                    size: 50,
                                    color: Color(0xFFFF7F50),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // App Title
                        const Text(
                          'ID Card Scanner',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6347),
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black12,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 42),

                        // Email field with improved styling
                        Material(
                          elevation: 1,
                          shadowColor: Colors.black12,
                          borderRadius: BorderRadius.circular(15),
                          child: TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode, // Add this line
                            keyboardType: TextInputType.emailAddress,
                            textInputAction:
                                TextInputAction.next, // Add this line
                            autofocus:
                                _emailController.text.isEmpty, // Add this line
                            onTap: () {
                              // Ensure keyboard appears on tap
                              if (!_emailFocusNode.hasFocus) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_emailFocusNode);
                              }
                            },
                            onFieldSubmitted: (_) {
                              // Add this line
                              FocusScope.of(
                                context,
                              ).requestFocus(_passwordFocusNode);
                            },
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: const Icon(
                                Icons.email,
                                color: Color(0xFFFF7F50),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF7F50),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              // Simple email format validation
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password field with improved styling and visibility toggle
                        Material(
                          elevation: 1,
                          shadowColor: Colors.black12,
                          borderRadius: BorderRadius.circular(15),
                          child: TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode, // Add this line
                            obscureText: !_passwordVisible,
                            textInputAction:
                                TextInputAction.done, // Add this line
                            onTap: () {
                              // Ensure keyboard appears on tap
                              if (!_passwordFocusNode.hasFocus) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocusNode);
                              }
                            },
                            onFieldSubmitted: (_) {
                              // Just unfocus the keyboard without triggering login
                              _passwordFocusNode.unfocus();
                              // DO NOT call _login here
                            },
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Color(0xFFFF7F50),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF7F50),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Remember Me checkbox with improved styling
                        Row(
                          children: [
                            Theme(
                              data: ThemeData(
                                checkboxTheme: CheckboxThemeData(
                                  fillColor: WidgetStateProperty.resolveWith<
                                    Color
                                  >((Set<WidgetState> states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return const Color(0xFFFF7F50);
                                    }
                                    return Colors.grey.shade400;
                                  }),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              child: Checkbox(
                                value: _rememberCredentials,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberCredentials = value ?? false;
                                  });
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberCredentials = !_rememberCredentials;
                                });
                              },
                              child: Text(
                                'Remember me for 30 days',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Error message with enhanced styling
                        if (_errorMessage.isNotEmpty) _buildErrorMessage(),

                        const SizedBox(height: 24),

                        // Login Button with enhanced styling
                        SizedBox(
                          height: 55,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7F50), Color(0xFFFF6347)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 4),
                                  blurRadius: 5.0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                minimumSize: const Size(double.infinity, 55),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        'LOGIN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
