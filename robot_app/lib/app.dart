import 'package:flutter/material.dart';

import 'pages/splash_page.dart';

class JezdzikApp extends StatelessWidget {
  const JezdzikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jezdzik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1018),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}
