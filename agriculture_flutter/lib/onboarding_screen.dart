import 'dart:ui'; // BackdropFilter භාවිතා කිරීමට අවශ්‍ය වේ
import 'package:agriculture_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';

// ignore: unused_element
class _LoginScreenPlaceholder extends StatelessWidget {
  const _LoginScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(child: Text('Login screen placeholder')),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image එක
          Positioned.fill(
            child: Image.asset(
              'assets/images/plants_bg.jpg', // ඔබේ image path එක මෙතනට දෙන්න
              fit: BoxFit.cover, // screen එක පුරාම image එක fill වීමට
            ),
          ),

          // 2. Blur effect (Glassmorphism effect) එක සහිත container එක
          Center(
            child: Container(
              width:
                  MediaQuery.of(context).size.width *
                  0.85, // Screen width එකෙන් 85% ක්
              height:
                  MediaQuery.of(context).size.height *
                  0.80, // Screen height එකෙන් 80% ක්
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  30,
                ), // මුළු screen එකටම වටකුරු දාර
              ),
              clipBehavior: Clip.antiAlias, // Clip කිරීම සඳහා
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10.0,
                  sigmaY: 10.0,
                ), // Blur ප්‍රමාණය
                child: Container(
                  color: Colors.white.withValues(
                    alpha: 0.1,
                  ), // ඉතා අඩුවෙන් පෙනෙන සුදු පැහැති layer එකක්
                  padding: const EdgeInsets.all(30.0), // ඇතුලතින් ඉඩ ලබාදීම
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // vertical ලෙස මධ්‍යගත කිරීමට
                    children: [
                      const Spacer(), // ඉහලින් ඉඩක් තැබීමට
                      // 3. Main Text එක
                      const Text(
                        "The best\napp for\nyour plants", // \n මගින් අලුත් පේලියකට ගනී
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          height: 1.2, // පේළි අතර පරතරය
                        ),
                        textAlign: TextAlign.center, // මැදට පෙළගැස්වීමට
                      ),

                      const SizedBox(
                        height: 100,
                      ), // Text එක සහ Button එක අතර පරතරය
                      // 4. Sign in Button එක
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1,
                            ), // සුදු පැහැති බෝඩරය
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            "Sign in",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ), // Button එක සහ text එක අතර පරතරය
                      // 5. Create an account Text එක
                      InkWell(
                        onTap: () {
                          // Register Screen එකට navigate වීමට
                        },
                        child: const Text(
                          "Create an account",
                          style: TextStyle(
                            color: Colors
                                .white70, // තරමක් අඩුවෙන් පෙනෙන සුදු පැහැය
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const Spacer(), // පහලින් ඉඩක් තැබීමට
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
