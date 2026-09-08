import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // තත්පර 3ක් ඇතුළත Progress bar එක 0 සිට 1 දක්වා පිරීමට Animation එක සකසයි
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {}); // Animation එක වෙනස් වන විට Screen එක Rebuild කරයි
      })
      ..addStatusListener((status) {
        // Bar එක පිරී ඉවර වූ පසු (Completed) ඊළඟ Screen එකට යයි
        if (status == AnimationStatus.completed) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      });

    _controller.forward(); // Animation එක ආරම්භ කරයි
  }

  @override
  void dispose() {
    _controller.dispose(); // Memory Leaks වැළැක්වීමට Controller එක Dispose කරයි
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image එක
          Positioned.fill(
            child: Image.asset(
              'assets/images/plants_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Dark Overlay එක
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),

          // 3. Animated Progress Bar එක සහ Text එක
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Smooth Rounded Progress Bar
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: _animation
                            .value, // මෙතැනින් පිරෙන ප්‍රමාණය පාලනය වේ
                        color: Colors.white,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Percentage % හෝ LOADING Text එක
                  Text(
                    'LOADING ${(_animation.value * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
