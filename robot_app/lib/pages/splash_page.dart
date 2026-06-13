import 'dart:async';

import 'package:flutter/material.dart';

import 'pad_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const List<String> _frames = <String>[
    'photos/robot_lewo_przod.png',
    'photos/robot_przod.png',
    'photos/robot_prawo_przod.png',
    'photos/robot_prawo.png',
    'photos/robot_prawo_tyl.png',
    'photos/robot_tyl.png',
    'photos/robot_lewo_tyl.png',
    'photos/robot_lewo.png',
    'photos/robot_lewo_przod.png',
  ];

  static const Duration _initialFrameDuration = Duration(milliseconds: 500);
  static const Duration _frameDuration = Duration(milliseconds: 450);
  int _frameIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_initialFrameDuration, _startFrameTimer);
  }

  void _startFrameTimer() {
    if (!mounted) return;
    setState(() => _frameIndex++);
    _timer = Timer.periodic(_frameDuration, (_) {
      if (!mounted) return;
      if (_frameIndex >= _frames.length - 1) {
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const PadPage()),
        );
        return;
      }
      setState(() => _frameIndex++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final frame in _frames) {
      precacheImage(AssetImage(frame), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Image.asset(
                    _frames[_frameIndex],
                    key: ValueKey<int>(_frameIndex),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                'photos/jezdzik_title.png',
                width: 230,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
