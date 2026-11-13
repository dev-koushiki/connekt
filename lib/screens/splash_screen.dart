import 'dart:async';
import 'package:flutter/material.dart';

/// Clean White Splash Screen displaying the official CONNEKT emblem and brandmark.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({
    super.key,
    required this.onFinish,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    // Show splash for ~2.2 seconds then proceed smoothly
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Official CONNEKT Brandmark on pure white background
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Image.asset(
                      'assets/images/connekt_official_logo.png',
                      width: 290,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                    ),
                  ),
                  const Spacer(),
                  // Subtle loading indicator at bottom
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F3B82)),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/connekt_emblem.png',
              width: 54,
              height: 54,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'Roboto',
                ),
                children: [
                  TextSpan(
                    text: 'CONN',
                    style: TextStyle(color: Color(0xFF0F3B82)),
                  ),
                  TextSpan(
                    text: 'E',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                  TextSpan(
                    text: 'KT',
                    style: TextStyle(color: Color(0xFF0F3B82)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'CONNECTING THE UNCONNECTED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
