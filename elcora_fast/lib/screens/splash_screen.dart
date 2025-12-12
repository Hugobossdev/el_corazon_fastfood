import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/error_handler_service.dart';
import 'package:elcora_fast/services/performance_service.dart';
import 'package:elcora_fast/screens/client/main_navigation_screen.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/theme.dart';

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
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
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
    // Initialize app services with performance monitoring
    await _initializeAppWithPerformance();

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  /// Initialize app services with performance monitoring
  Future<void> _initializeAppWithPerformance() async {
    final performanceService = context.read<PerformanceService>();
    final errorHandler = context.read<ErrorHandlerService>();

    try {
      await performanceService.measureOperation('app_initialization', () async {
        final appService = context.read<AppService>();
        await appService.initialize();
      });
    } catch (e) {
      errorHandler.logError('Failed to initialize app', details: e.toString());
    }
  }

  void _navigateToNextScreen() {
    final appService = context.read<AppService>();

    try {
      if (appService.currentUser != null && appService.isLoggedIn) {
        // Utiliser le service de navigation pour naviguer vers l'écran approprié selon le rôle
        NavigationService.navigateBasedOnRole(context, appService.currentUser!);
      } else {
        // Naviguer vers l'écran d'accueil pour les invités (Mode Invité)
        // On suppose que l'utilisateur est un client par défaut
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(),
          ),
        );
      }
    } catch (e) {
      // En cas d'erreur, rediriger vers l'authentification
      NavigationService.navigateToAuth(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
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
                    // Logo de l'application
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'lib/assets/logo/logo.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.restaurant,
                            size: 80,
                            color: AppColors.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
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
