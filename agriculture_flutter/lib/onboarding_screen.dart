import 'package:agriculture_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:agriculture_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _video = VideoPlayerController.asset('assets/images/plants_bg.mp4');
  bool _ready = false;
  bool _foreground = true;
  bool _openingPage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _video.initialize();
      if (!mounted) return;
      await _video.setVolume(0);
      if (!mounted) return;
      await _video.setLooping(true);
      if (!mounted) return;
      await _video.setPlaybackSpeed(0.25);
      if (!mounted) return;
      setState(() => _ready = true);
      _syncPlayback();
    } catch (error) {
      debugPrint('Welcome video could not load: $error');
    }
  }

  void _syncPlayback() {
    if (!_ready) return;
    if (_foreground &&
        !_openingPage &&
        !MediaQuery.disableAnimationsOf(context)) {
      _video.play();
    } else {
      _video.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  Future<void> _openPage(Widget page) async {
    _openingPage = true;
    _syncPlayback();
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    _openingPage = false;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video.dispose();
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
              errorBuilder: (_, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF244D38)),
              'assets/images/plants_bg.jpg', // ඔබේ image path එක මෙතනට දෙන්න
              fit: BoxFit.cover, // screen එක පුරාම image එක fill වීමට
            ),
          ),

          if (_ready && !MediaQuery.disableAnimationsOf(context))
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _video.value.size.width,
                        height: _video.value.size.height,
                        child: VideoPlayer(_video),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 2. Lightweight panel that keeps the background image sharp.
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.80,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(30),
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Text(
                    'The best app for\nyour plants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 92),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: TextButton(
                      onPressed: () => _openPage(const LoginScreen()),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => _openPage(const RegisterScreen()),
                    child: const Text(
                      'Create an account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
