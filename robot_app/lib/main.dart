import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const Jezdzik());
}

const int bitUp = 0x01;
const int bitDown = 0x02;
const int bitLeft = 0x04;
const int bitRight = 0x08;

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

class UdpCamClient {
  UdpCamClient({required this.host, required this.port});

  final String host;
  final int port;
  RawDatagramSocket? _socket;

  Future<void> _ensureSocket() async {
    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
      ..broadcastEnabled = true;
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

  Future<void> sendTextTo(String text, String targetHost) async {
    await _ensureSocket();
    final address = InternetAddress(targetHost);
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
  static const int _port = 1234;
  final TextEditingController _hostController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'padKeyboard');
  final Set<int> _pressedBits = <int>{};
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  UdpCamClient? _client;
  String _host = '192.168.4.1';
  String _configStatus = '';
  bool _hasConnectionError = false;
  Timer? _controlRepeatTimer;
  Timer? _stopFlashTimer;
  bool _stopPressed = false;

  static final Map<LogicalKeyboardKey, int> _keyMap = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.arrowUp: bitUp,
    LogicalKeyboardKey.keyW: bitUp,
    LogicalKeyboardKey.digit1: bitUp,
    LogicalKeyboardKey.arrowRight: bitRight,
    LogicalKeyboardKey.keyD: bitRight,
    LogicalKeyboardKey.digit8: bitRight,
    LogicalKeyboardKey.arrowDown: bitDown,
    LogicalKeyboardKey.keyS: bitDown,
    LogicalKeyboardKey.digit2: bitDown,
    LogicalKeyboardKey.arrowLeft: bitLeft,
    LogicalKeyboardKey.keyA: bitLeft,
    LogicalKeyboardKey.digit4: bitLeft,
    LogicalKeyboardKey.keyZ: bitUp,
    LogicalKeyboardKey.keyX: bitRight,
    LogicalKeyboardKey.keyC: bitDown,
    LogicalKeyboardKey.keyV: bitLeft,
  };

  @override
  void dispose() {
    _controlRepeatTimer?.cancel();
    _stopFlashTimer?.cancel();
    _client?.close();
    _hostController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  UdpCamClient _ensureClient() {
    final requestedHost = _hostController.text.trim().isEmpty
        ? _host
        : _hostController.text.trim();
    final current = _client;
    if (current == null ||
        current.host != requestedHost ||
        current.port != _port) {
      current?.close();
      _host = requestedHost;
      _client = UdpCamClient(host: _host, port: _port);
    }
    return _client!;
  }

  String? _subnetBroadcastFor(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;

    final bytes = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
      bytes.add(value);
    }

    return '${bytes[0]}.${bytes[1]}.${bytes[2]}.255';
  }

  Future<void> _sendWifiConfig() async {
    final currentHost = _hostController.text.trim();
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;
    if (currentHost.isEmpty || ssid.isEmpty) {
      setState(() {
        _hasConnectionError = true;
        _configStatus = 'Wpisz IP ESP station teraz i nazwe Wi-Fi.';
      });
      return;
    }

    const stationIp = 'AUTO';
    final command = 'CFG\n$ssid\n$password\n$stationIp\n';

    try {
      final client = UdpCamClient(host: currentHost, port: _port);
      final targets = <String>{currentHost, '255.255.255.255'};
      final subnetBroadcast = _subnetBroadcastFor(currentHost);
      if (subnetBroadcast != null) targets.add(subnetBroadcast);

      for (var i = 0; i < 6; i++) {
        for (final target in targets) {
          await client.sendTextTo(command, target);
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      client.close();

      if (!mounted) return;
      _client?.close();
      setState(() {
        _client = UdpCamClient(host: _host, port: _port);
        _hasConnectionError = false;
        _configStatus =
            'Wysłano Wi-Fi. Potem wpisz nowe IP ESP_station w polu u góry.';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _hasConnectionError = true;
        _configStatus = 'Nie udalo sie wyslac konfiguracji.';
      });
    }
  }

  Future<void> _resetToSetupWifi() async {
    final currentHost = _hostController.text.trim();
    if (currentHost.isNotEmpty) {
      try {
        final client = UdpCamClient(host: currentHost, port: _port);
        await client.sendText('RESET_SETUP');
        client.close();
      } on Object catch (_) {
        // UI reset ma zadzialac nawet wtedy, gdy ESP jest juz poza zasiegiem.
      }
    }

    _client?.close();
    _client = null;
    setState(() {
      _host = '192.168.4.1';
      _hostController.text = '192.168.4.1';
      _ssidController.clear();
      _passwordController.clear();
      _hasConnectionError = false;
      _configStatus = 'Ustawiono Robot_jezdzik i IP 192.168.4.1.';
    });
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
        _hasConnectionError = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _hasConnectionError = true);
    }
  }

  void _startControlRepeat() {
    _controlRepeatTimer ??= Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) {
      final mask = _currentMask();
      if (mask == 0) {
        _controlRepeatTimer?.cancel();
        _controlRepeatTimer = null;
        return;
      }
      unawaited(_sendMask(mask));
    });
  }

  void _stopControlRepeatIfIdle() {
    if (_currentMask() != 0) return;
    _controlRepeatTimer?.cancel();
    _controlRepeatTimer = null;
  }

  void _press(int bit) {
    _pressedBits.add(bit);
    final mask = _currentMask();
    unawaited(_sendMask(mask));
    _startControlRepeat();
  }

  void _release(int bit) {
    _pressedBits.remove(bit);
    final mask = _currentMask();
    unawaited(_sendMask(mask));
    _stopControlRepeatIfIdle();
  }

  void _stop() {
    _pressedBits.clear();
    _pressedKeys.clear();
    _controlRepeatTimer?.cancel();
    _controlRepeatTimer = null;
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openWifiConfigDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, refreshDialog) {
            return Dialog(
              backgroundColor: const Color(0xFF0B1018),
              insetPadding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      _wifiConfigPanel(
                        refreshDialog: () => refreshDialog(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _wifiConfigPanel({VoidCallback? refreshDialog}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF263244), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _hostController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'IP ESP_station',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _ssidController,
            decoration: const InputDecoration(
              labelText: 'Nazwa Wi-Fi',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Haslo Wi-Fi',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await _sendWifiConfig();
                refreshDialog?.call();
              },
              child: const Text('Zapisz Wi-Fi w ESP'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await _resetToSetupWifi();
                refreshDialog?.call();
              },
              child: const Text('Reset do Robot_jezdzik'),
            ),
          ),
          if (_configStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _configStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _hasConnectionError
                    ? const Color(0xFFF87171)
                    : const Color(0xFFE2E8F0),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controlFrame(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
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
    final pressed = _pressedBits.contains(bit);
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
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: IconButton(
                onPressed: _openWifiConfigDialog,
                icon: const Icon(Icons.menu),
                iconSize: 30,
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'photos/jezdzik_title.png',
                      width: wide ? 260 : 205,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 14),
                    _networkBar(),
                    Expanded(
                      child: Center(
                        child: _controlFrame(_dPad(size: wide ? 118 : 90)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFF0B1018),
          body: LayoutBuilder(
            builder: (context, constraints) => _body(constraints),
          ),
        ),
      ),
    );
  }
}
