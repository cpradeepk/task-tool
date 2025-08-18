import 'package:socket_io_client/socket_io_client.dart' as IO;

class Realtime {
  late final IO.Socket socket;
  bool _isConnected = false;

  Realtime(String baseUrl) {
    socket = IO.io(baseUrl, IO.OptionBuilder()
      .setPath('/task/socket.io/')
      .setTransports(['websocket', 'polling']) // Add polling as fallback
      .disableAutoConnect()
      .setTimeout(5000) // 5 second timeout
      .build());

    // Add connection event handlers
    socket.onConnect((_) {
      print('Socket.IO connected');
      _isConnected = true;
    });

    socket.onDisconnect((_) {
      print('Socket.IO disconnected');
      _isConnected = false;
    });

    socket.onConnectError((error) {
      print('Socket.IO connection error: $error');
      _isConnected = false;
    });

    socket.onError((error) {
      print('Socket.IO error: $error');
    });
  }

  void connect() {
    if (!_isConnected) {
      socket.connect();
    }
  }

  void on(String event, Function(dynamic) handler) => socket.on(event, (data) => handler(data));

  void dispose() {
    socket.dispose();
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}

