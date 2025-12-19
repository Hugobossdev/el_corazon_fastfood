import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_service.dart';
import 'package:elcora_dely/screens/auth/driver_auth_screen.dart';
import 'delivery/delivery_navigation_screen.dart';
import '../ui/ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
    _startSplashSequence();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startSplashSequence() async {
    // Initialize AppService immediately
    final initFuture = _initializeAppService();

    // Ensure initialization is complete before navigating
    await initFuture;

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _initializeAppService() async {
    if (!mounted || !context.mounted) return;
    try {
      final appService = context.read<AppService>();
      if (!appService.isInitialized) {
        await appService.initialize();
      }
    } catch (e) {
      debugPrint('Error initializing AppService in Splash: $e');
    }
  }

  void _navigateToNextScreen() {
    if (!mounted || !context.mounted) return;
    final appService = context.read<AppService>();

    Widget nextScreen;
    if (appService.currentUser != null && appService.isLoggedIn) {
      nextScreen = const DeliveryNavigationScreen();
    } else {
      nextScreen = const DriverAuthScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _opacityAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.16),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.delivery_dining,
                            size: 80,
                            color: scheme.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(color: scheme.onPrimary, strokeWidth: 3),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Extension for easier usage
extension SplashScreenExtension on BuildContext {
  void showSplashScreen() {
    Navigator.of(this).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  }
}
