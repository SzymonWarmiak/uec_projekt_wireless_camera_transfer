import 'dart:io';

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
