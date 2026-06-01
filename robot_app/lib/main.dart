import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const RobotPadApp());
}

const int bitUp = 0x01;
const int bitRight = 0x02;
const int bitDown = 0x04;
const int bitLeft = 0x08;

class RobotPadApp extends StatelessWidget {
  const RobotPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Basys Cam Pad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        useMaterial3: true,
      ),
      home: const PadPage(),
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
  final TextEditingController _hostController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '1234',
  );
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'padKeyboard');
  final Set<int> _pressedBits = <int>{};
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  UdpCamClient? _client;
  String _status = 'UDP gotowe';
  int _lastMask = 0;
  bool _sending = false;

  static final Map<LogicalKeyboardKey, int> _keyMap = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.arrowUp: bitUp,
    LogicalKeyboardKey.digit1: bitUp,
    LogicalKeyboardKey.arrowRight: bitRight,
    LogicalKeyboardKey.digit2: bitRight,
    LogicalKeyboardKey.arrowDown: bitDown,
    LogicalKeyboardKey.digit4: bitDown,
    LogicalKeyboardKey.arrowLeft: bitLeft,
    LogicalKeyboardKey.digit8: bitLeft,
    LogicalKeyboardKey.keyZ: bitUp,
    LogicalKeyboardKey.keyX: bitRight,
    LogicalKeyboardKey.keyC: bitDown,
    LogicalKeyboardKey.keyV: bitLeft,
  };

  @override
  void dispose() {
    _client?.close();
    _hostController.dispose();
    _portController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  UdpCamClient? _ensureClient() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() => _status = 'Niepoprawny host albo port');
      return null;
    }

    final current = _client;
    if (current == null || current.host != host || current.port != port) {
      current?.close();
      _client = UdpCamClient(host: host, port: port);
    }
    return _client;
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
    if (client == null) return;

    setState(() => _sending = true);
    try {
      await client.sendMask(mask);
      if (!mounted) return;
      setState(() {
        _lastMask = mask & 0x0F;
        _status =
            'UDP -> ${client.host}:${client.port}  maska=0x${_lastMask.toRadixString(16).toUpperCase()}';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Blad UDP: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _press(int bit) {
    _pressedBits.add(bit);
    unawaited(_sendMask(_currentMask()));
  }

  void _release(int bit) {
    _pressedBits.remove(bit);
    unawaited(_sendMask(_currentMask()));
  }

  void _stop() {
    _pressedBits.clear();
    _pressedKeys.clear();
    unawaited(_sendMask(0));
  }

  Future<void> _sendTextCommand(String command) async {
    final client = _ensureClient();
    if (client == null) return;

    setState(() => _sending = true);
    try {
      await client.sendText(command);
      if (!mounted) return;
      setState(() => _status = 'Wyslano: $command');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Blad UDP: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7DEE8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _hostController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Host ESP',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 94,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                _sending ? Icons.sync : Icons.wifi_tethering,
                size: 18,
                color: _sending ? Colors.orange : Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _streamControls() {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () => unawaited(_sendTextCommand('start')),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start wideo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => unawaited(_sendTextCommand('stop')),
            icon: const Icon(Icons.stop),
            label: const Text('Stop wideo'),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'Stop IN',
          onPressed: _stop,
          icon: const Icon(Icons.block),
        ),
      ],
    );
  }

  Widget _padButton({
    required IconData icon,
    required int bit,
    required String tooltip,
    double size = 78,
  }) {
    final pressed = (_lastMask & bit) != 0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(bit),
      onPointerUp: (_) => _release(bit),
      onPointerCancel: (_) => _release(bit),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: pressed ? const Color(0xFF2563EB) : const Color(0xFFE8EDF5),
            border: Border.all(
              color: pressed
                  ? const Color(0xFF1E40AF)
                  : const Color(0xFFC9D3E1),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: pressed ? 0.16 : 0.08),
                blurRadius: pressed ? 5 : 9,
                offset: Offset(0, pressed ? 2 : 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: size * 0.42,
            color: pressed ? Colors.white : const Color(0xFF263241),
          ),
        ),
      ),
    );
  }

  Widget _dPad({double size = 78}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _padButton(
          icon: Icons.keyboard_arrow_up,
          bit: bitUp,
          tooltip: 'Przod',
          size: size,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _padButton(
              icon: Icons.keyboard_arrow_left,
              bit: bitLeft,
              tooltip: 'Lewo',
              size: size,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: size,
              height: size,
              child: IconButton.filledTonal(
                tooltip: 'Stop',
                onPressed: _stop,
                icon: const Icon(Icons.circle),
              ),
            ),
            const SizedBox(width: 8),
            _padButton(
              icon: Icons.keyboard_arrow_right,
              bit: bitRight,
              tooltip: 'Prawo',
              size: size,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _padButton(
          icon: Icons.keyboard_arrow_down,
          bit: bitDown,
          tooltip: 'Tyl',
          size: size,
        ),
      ],
    );
  }

  Widget _faceButtons({double size = 72}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _letterButton('A', bitUp, 'IN1 / przod', size),
        const SizedBox(width: 8),
        _letterButton('B', bitRight, 'IN2 / prawo', size),
        const SizedBox(width: 8),
        _letterButton('X', bitDown, 'IN4 / tyl', size),
        const SizedBox(width: 8),
        _letterButton('Y', bitLeft, 'IN3 / lewo', size),
      ],
    );
  }

  Widget _letterButton(String text, int bit, String tooltip, double size) {
    final pressed = (_lastMask & bit) != 0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(bit),
      onPointerUp: (_) => _release(bit),
      onPointerCancel: (_) => _release(bit),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? const Color(0xFF0F766E) : Colors.white,
            border: Border.all(
              color: pressed
                  ? const Color(0xFF115E59)
                  : const Color(0xFFC9D3E1),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: pressed ? Colors.white : const Color(0xFF263241),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7DEE8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF263241),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _body(BoxConstraints constraints) {
    final wide = constraints.maxWidth >= 760;
    final controls = wide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _section('D-pad', _dPad(size: 86)),
              const SizedBox(width: 18),
              _section('Przyciski', _faceButtons(size: 78)),
            ],
          )
        : Column(
            children: <Widget>[
              _section('D-pad', _dPad()),
              const SizedBox(height: 14),
              _section('Przyciski', _faceButtons()),
            ],
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _networkBar(),
              const SizedBox(height: 12),
              _streamControls(),
              const SizedBox(height: 16),
              controls,
              const SizedBox(height: 14),
              Text(
                'Maska: 0x${_lastMask.toRadixString(16).toUpperCase()}  (${_lastMask.toRadixString(2).padLeft(4, '0')})',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF263241),
                ),
              ),
            ],
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
          appBar: AppBar(
            title: const Text('Basys Cam Pad'),
            centerTitle: true,
            actions: <Widget>[
              IconButton(
                tooltip: 'Stop',
                onPressed: _stop,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => _body(constraints),
          ),
        ),
      ),
    );
  }
}
