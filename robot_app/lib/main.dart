import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const Jezdzik());
}

const int bitUp = 0x01;
const int bitRight = 0x02;
const int bitDown = 0x04;
const int bitLeft = 0x08;

class Jezdzik extends StatelessWidget {
  const Jezdzik({super.key});

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

class UdpCamClient {
  UdpCamClient({required this.host, required this.port});

  final String host;
  final int port;
  RawDatagramSocket? _socket;

  Future<void> _ensureSocket() async {
    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  }

  Future<void> sendMask(int mask) async {
    await _ensureSocket();
    final address = InternetAddress(host);
    _socket!.send(<int>[mask & 0x0F], address, port);
  }

  Future<void> sendText(String text) async {
    await _ensureSocket();
    final address = InternetAddress(host);
    _socket!.send(text.codeUnits, address, port);
  }

  void close() {
    _socket?.close();
    _socket = null;
  }
}

class PadPage extends StatefulWidget {
  const PadPage({super.key});

  @override
  State<PadPage> createState() => _PadPageState();
}

class _PadPageState extends State<PadPage> {
  static const String _host = '192.168.4.1';
  static const int _port = 1234;
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'padKeyboard');
  final Set<int> _pressedBits = <int>{};
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  UdpCamClient? _client;
  bool _hasConnectionError = false;
  int _lastMask = 0;
  Timer? _stopFlashTimer;
  bool _stopPressed = false;

  static final Map<LogicalKeyboardKey, int> _keyMap = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.arrowUp: bitUp,
    LogicalKeyboardKey.keyW: bitUp,
    LogicalKeyboardKey.digit1: bitUp,
    LogicalKeyboardKey.arrowRight: bitRight,
    LogicalKeyboardKey.keyD: bitRight,
    LogicalKeyboardKey.digit2: bitRight,
    LogicalKeyboardKey.arrowDown: bitDown,
    LogicalKeyboardKey.keyS: bitDown,
    LogicalKeyboardKey.digit4: bitDown,
    LogicalKeyboardKey.arrowLeft: bitLeft,
    LogicalKeyboardKey.keyA: bitLeft,
    LogicalKeyboardKey.digit8: bitLeft,
    LogicalKeyboardKey.keyZ: bitUp,
    LogicalKeyboardKey.keyX: bitRight,
    LogicalKeyboardKey.keyC: bitDown,
    LogicalKeyboardKey.keyV: bitLeft,
  };

  @override
  void dispose() {
    _stopFlashTimer?.cancel();
    _client?.close();
    _keyboardFocus.dispose();
    super.dispose();
  }

  UdpCamClient _ensureClient() {
    final current = _client;
    if (current == null || current.host != _host || current.port != _port) {
      current?.close();
      _client = UdpCamClient(host: _host, port: _port);
    }
    return _client!;
  }

  int _currentMask() {
    var mask = 0;
    for (final bit in _pressedBits) {
      mask |= bit;
    }
    return mask & 0x0F;
  }

  Future<void> _sendMask(int mask) async {
    final client = _ensureClient();

    try {
      await client.sendMask(mask);
      if (!mounted) return;
      setState(() {
        _lastMask = mask & 0x0F;
        _hasConnectionError = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _hasConnectionError = true);
    }
  }

  void _press(int bit) {
    _pressedBits.add(bit);
    final mask = _currentMask();
    unawaited(_sendMask(mask));
  }

  void _release(int bit) {
    _pressedBits.remove(bit);
    final mask = _currentMask();
    unawaited(_sendMask(mask));
  }

  void _stop() {
    _pressedBits.clear();
    _pressedKeys.clear();
    _flashStop();
    unawaited(_sendMask(0));
  }

  void _flashStop() {
    _stopFlashTimer?.cancel();
    setState(() => _stopPressed = true);
    _stopFlashTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _stopPressed = false);
    });
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _stop();
      return KeyEventResult.handled;
    }

    final bit = _keyMap[key];
    if (bit == null) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (_pressedKeys.add(key)) _press(bit);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
      _release(bit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _networkBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF263244), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$_host:$_port',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _hasConnectionError
              ? const Color(0xFFF87171)
              : const Color(0xFFE2E8F0),
          fontFamily: 'monospace',
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _controlFrame(Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF263244), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _padButton({
    required IconData icon,
    required int bit,
    double size = 78,
  }) {
    final pressed = (_lastMask & bit) != 0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(bit),
      onPointerUp: (_) => _release(bit),
      onPointerCancel: (_) => _release(bit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pressed ? const Color(0xFF2563EB) : const Color(0xFF243044),
          border: Border.all(
            color: pressed ? const Color(0xFF60A5FA) : const Color(0xFF3B4A63),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: pressed ? 0.34 : 0.24),
              blurRadius: pressed ? 6 : 12,
              offset: Offset(0, pressed ? 2 : 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size * 0.42,
          color: pressed ? Colors.white : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _dPad({double size = 78}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _padButton(icon: Icons.keyboard_arrow_up, bit: bitUp, size: size),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _padButton(
              icon: Icons.keyboard_arrow_left,
              bit: bitLeft,
              size: size,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: size,
              height: size,
              child: IconButton.filledTonal(
                onPressed: _stop,
                style: IconButton.styleFrom(
                  backgroundColor: _stopPressed
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF243044),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.circle),
              ),
            ),
            const SizedBox(width: 8),
            _padButton(
              icon: Icons.keyboard_arrow_right,
              bit: bitRight,
              size: size,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _padButton(icon: Icons.keyboard_arrow_down, bit: bitDown, size: size),
      ],
    );
  }

  Widget _body(BoxConstraints constraints) {
    final wide = constraints.maxWidth >= 760;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'photos/jezdzik_title.png',
                  width: wide ? 240 : 210,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                _networkBar(),
                Expanded(
                  child: Center(
                    child: _controlFrame(_dPad(size: wide ? 96 : 82)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _keyboardFocus.requestFocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFF0B1018),
          body: LayoutBuilder(
            builder: (context, constraints) => _body(constraints),
          ),
        ),
      ),
    );
  }
}
